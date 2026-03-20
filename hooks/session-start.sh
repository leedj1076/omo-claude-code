#!/bin/bash
# Injects git context and handoff data at session start.

# Git context
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
RECENT=$(git log --oneline -5 2>/dev/null || echo "")
DIRTY=$(git diff --name-only 2>/dev/null | head -10)
STASH=$(git stash list 2>/dev/null | head -3)

# Check for handoff from previous session
HANDOFF=""
if [ -f ".claude/handoff.md" ]; then
  HANDOFF=$(cat .claude/handoff.md)
fi

# Check for boulder state (work in progress) - handles both enriched and legacy schemas
BOULDER=""
if [ -f ".claude/boulder.json" ]; then
  STATUS=$(jq -r '.status // "unknown"' .claude/boulder.json 2>/dev/null)
  if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "paused" ]; then
    # Try enriched fields first, fall back to legacy
    PLAN_NAME=$(jq -r '.plan_name // ""' .claude/boulder.json 2>/dev/null)
    ACTIVE_PLAN=$(jq -r '.active_plan // .plan // "unknown"' .claude/boulder.json 2>/dev/null)
    CURRENT_TASK_TITLE=$(jq -r '.current_task.title // ""' .claude/boulder.json 2>/dev/null)
    PROGRESS_PERCENT=$(jq -r 'if .progress.percent != null then (.progress.percent | tostring) + "%" else "" end' .claude/boulder.json 2>/dev/null)
    PAUSED_AT=$(jq -r '.paused_at // ""' .claude/boulder.json 2>/dev/null)
    PAUSED_REASON=$(jq -r '.paused_reason // .reason // ""' .claude/boulder.json 2>/dev/null)

    # Fall back plan name to basename if not in enriched schema
    if [ -z "$PLAN_NAME" ] && [ -n "$ACTIVE_PLAN" ] && [ "$ACTIVE_PLAN" != "unknown" ]; then
      PLAN_NAME=$(basename "$ACTIVE_PLAN" .md)
    fi

    # Calculate live progress from plan file if available
    if [ -n "$ACTIVE_PLAN" ] && [ "$ACTIVE_PLAN" != "unknown" ] && [ -f "$ACTIVE_PLAN" ]; then
      LIVE_REMAINING=$(grep -c '^\- \[ \]' "$ACTIVE_PLAN" 2>/dev/null || echo "0")
      LIVE_DONE=$(grep -c '^\- \[x\]' "$ACTIVE_PLAN" 2>/dev/null || echo "0")
      # Find first unchecked task if current_task.title not available
      if [ -z "$CURRENT_TASK_TITLE" ]; then
        CURRENT_TASK_TITLE=$(grep '^\- \[ \]' "$ACTIVE_PLAN" 2>/dev/null | head -1 | sed 's/^- \[ \] //')
      fi
    fi

    if [ "$STATUS" = "paused" ]; then
      # Paused plan — show pause context
      PAUSE_DETAIL=""
      if [ -n "$PAUSED_AT" ]; then
        PAUSE_DETAIL=" at $PAUSED_AT"
      fi
      REASON_DETAIL=""
      if [ -n "$PAUSED_REASON" ]; then
        REASON_DETAIL=" Reason: $PAUSED_REASON."
      fi
      BOULDER="PAUSED PLAN: '$PLAN_NAME' was paused${PAUSE_DETAIL}.${REASON_DETAIL} Run /start-work to resume or /stop-work to cancel."
    elif [ -n "$PROGRESS_PERCENT" ] && [ -n "$CURRENT_TASK_TITLE" ]; then
      # Enriched in-progress plan
      BOULDER="ACTIVE PLAN: '$PLAN_NAME' ($PROGRESS_PERCENT complete). Current task: $CURRENT_TASK_TITLE. Run /start-work to resume or /stop-work to cancel."
    else
      # Legacy in-progress plan
      STARTED=$(jq -r '.started // .started_at // ""' .claude/boulder.json 2>/dev/null)
      BOULDER="WORK IN PROGRESS: Plan '$PLAN_NAME' (status: $STATUS, started: $STARTED). Run /start-work to resume or /stop-work to cancel."
    fi
  fi
fi

# Build context
CONTEXT=""

if [ -n "$BRANCH" ]; then
  CONTEXT="Branch: $BRANCH"
fi

if [ -n "$RECENT" ]; then
  CONTEXT="$CONTEXT
Recent commits:
$RECENT"
fi

if [ -n "$DIRTY" ]; then
  CONTEXT="$CONTEXT
Uncommitted changes: $DIRTY"
fi

if [ -n "$STASH" ]; then
  CONTEXT="$CONTEXT
Stashed work: $STASH"
fi

if [ -n "$BOULDER" ]; then
  CONTEXT="$CONTEXT

$BOULDER"
fi

if [ -n "$HANDOFF" ]; then
  CONTEXT="$CONTEXT

Previous session handoff:
$HANDOFF"
fi

# Only output if we have context
if [ -n "$CONTEXT" ]; then
  jq -n --arg ctx "$CONTEXT" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
fi

exit 0
