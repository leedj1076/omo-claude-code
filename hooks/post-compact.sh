#!/bin/bash
# Re-injects structured context after context compaction.
# Mirrors OmO's 8-section compaction preservation template.
# Critical for maintaining continuity in long sessions.

SECTIONS=""

# Section 1: Work State (boulder) - handles both enriched and legacy schemas
if [ -f ".claude/boulder.json" ]; then
  STATUS=$(jq -r '.status // "unknown"' .claude/boulder.json 2>/dev/null)
  if [ "$STATUS" != "completed" ]; then
    # Try enriched fields first, then fall back to legacy fields
    PLAN_NAME=$(jq -r '.plan_name // ""' .claude/boulder.json 2>/dev/null)
    ACTIVE_PLAN=$(jq -r '.active_plan // .plan // "unknown"' .claude/boulder.json 2>/dev/null)
    CURRENT_TASK_TITLE=$(jq -r '.current_task.title // ""' .claude/boulder.json 2>/dev/null)
    PROGRESS_PERCENT=$(jq -r 'if .progress.percent != null then (.progress.percent | tostring) + "%" else "" end' .claude/boulder.json 2>/dev/null)
    PROGRESS_COMPLETED=$(jq -r '.progress.completed // ""' .claude/boulder.json 2>/dev/null)
    PROGRESS_TOTAL=$(jq -r '.progress.total // ""' .claude/boulder.json 2>/dev/null)

    if [ -n "$PLAN_NAME" ] && [ -n "$PROGRESS_PERCENT" ]; then
      # Enriched schema: show progress details with current task
      TASK_DETAIL=""
      if [ -n "$CURRENT_TASK_TITLE" ]; then
        TASK_DETAIL="
Current task: $CURRENT_TASK_TITLE"
      fi
      SECTIONS="## Work In Progress (Boulder State)
Plan: $PLAN_NAME ($PROGRESS_PERCENT complete - ${PROGRESS_COMPLETED}/${PROGRESS_TOTAL} tasks)$TASK_DETAIL
Status: $STATUS
Read the plan file and continue from the current task."
    else
      # Legacy schema: show basic boulder info
      PLAN=$(jq -r '.plan // .active_plan // "unknown"' .claude/boulder.json 2>/dev/null)
      STARTED=$(jq -r '.started // .started_at // "unknown"' .claude/boulder.json 2>/dev/null)
      SECTIONS="## Work In Progress
Plan: $PLAN (status: $STATUS, started: $STARTED)
Read the plan file to see remaining tasks and resume execution."
    fi

    # Live progress from plan file (both schemas use active_plan or plan)
    if [ -n "$ACTIVE_PLAN" ] && [ "$ACTIVE_PLAN" != "unknown" ] && [ -f "$ACTIVE_PLAN" ]; then
      REMAINING=$(grep -c '^\- \[ \]' "$ACTIVE_PLAN" 2>/dev/null || echo "0")
      DONE=$(grep -c '^\- \[x\]' "$ACTIVE_PLAN" 2>/dev/null || echo "0")
      SECTIONS="$SECTIONS
Live progress: $DONE done, $REMAINING remaining"
    fi
  fi
fi

# Section 2: Active Working Context (recently modified files)
RECENT_FILES=$(git diff --name-only HEAD~3 2>/dev/null | head -10)
STAGED=$(git diff --cached --name-only 2>/dev/null | head -5)
UNSTAGED=$(git diff --name-only 2>/dev/null | head -5)
if [ -n "$RECENT_FILES" ] || [ -n "$STAGED" ] || [ -n "$UNSTAGED" ]; then
  SECTIONS="$SECTIONS

## Active Working Context
Branch: $(git branch --show-current 2>/dev/null)"
  if [ -n "$UNSTAGED" ]; then
    SECTIONS="$SECTIONS
Uncommitted changes: $UNSTAGED"
  fi
  if [ -n "$STAGED" ]; then
    SECTIONS="$SECTIONS
Staged: $STAGED"
  fi
  if [ -n "$RECENT_FILES" ]; then
    SECTIONS="$SECTIONS
Recently modified (last 3 commits): $RECENT_FILES"
  fi
fi

# Section 3: Handoff Context
if [ -f ".claude/handoff.md" ]; then
  HANDOFF=$(head -30 .claude/handoff.md)
  SECTIONS="$SECTIONS

## Session Handoff (preserved through compaction)
$HANDOFF"
fi

# Section 4: Plan files available
PLANS=$(ls .claude/plans/*.md 2>/dev/null | head -5)
if [ -n "$PLANS" ]; then
  SECTIONS="$SECTIONS

## Available Plans
$PLANS"
fi

# Section 5: Plan-scoped notepad hints
if [ -d ".claude/notepads" ]; then
  NOTEPAD_PLANS=$(ls .claude/notepads/ 2>/dev/null | head -5)
  if [ -n "$NOTEPAD_PLANS" ]; then
    SECTIONS="$SECTIONS

## Plan-Scoped Notepads Available
Plans with accumulated wisdom: $NOTEPAD_PLANS
Read their notepad files (.claude/notepads/{plan}/) before delegating to benefit from prior learnings."
  fi
fi

# Section 7: Active Tasks (from todo state)
TODO_ITEMS=""
if [ -d ".claude/todos" ]; then
  for TODO_FILE in $(ls -t .claude/todos/*.json 2>/dev/null | head -5); do
    TASKS=$(jq -r 'if type == "array" then .[] | select(.status != null and .status != "completed" and .status != "cancelled" and .status != "deleted") | "- [" + .status + "] " + (.subject // .title // "unknown") else empty end' "$TODO_FILE" 2>/dev/null)
    if [ -n "$TASKS" ]; then
      TODO_ITEMS="$TODO_ITEMS$TASKS
"
    fi
  done
fi
if [ -n "$TODO_ITEMS" ]; then
  SECTIONS="$SECTIONS

## Active Tasks (from TaskList)
$TODO_ITEMS
Read these tasks with TaskList to get full details. Resume any in-progress tasks."
fi

# Output
if [ -n "$SECTIONS" ]; then
  HEADER="CONTEXT PRESERVED THROUGH COMPACTION. Review before continuing:"
  jq -n --arg ctx "$HEADER
$SECTIONS" '{
    hookSpecificOutput: {
      hookEventName: "PostCompact",
      additionalContext: $ctx
    }
  }'
fi

exit 0
