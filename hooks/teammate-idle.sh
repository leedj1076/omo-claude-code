#!/bin/bash
# Tracks teammate sessions in boulder.json when a teammate goes idle.
# Triggered by CC's TeammateIdle event.
# Input (stdin): JSON with teammate_name, team_name, session_id, transcript_path
# Exits 0 normally. Exits 2 with stderr message if teammate's task still has incomplete plan work.

INPUT=$(cat)

TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // ""' 2>/dev/null)
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // ""' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)

BOULDER=".claude/boulder.json"
TASKS_ROOT="${CLAUDE_TASKS_ROOT:-$HOME/.claude/tasks}"

if [ ! -f "$BOULDER" ]; then exit 0; fi
STATUS=$(jq -r '.status // ""' "$BOULDER" 2>/dev/null)
if [ "$STATUS" != "in_progress" ]; then exit 0; fi

# Resolve task_key (priority order — native team state first, transcript fallback last):
TASK_KEY=""

# Strategy 1: Native team task list — find task assigned to this teammate
if [ -n "$TEAM_NAME" ] && [ -d "$TASKS_ROOT/$TEAM_NAME" ]; then
  for TASK_FILE in "$TASKS_ROOT/$TEAM_NAME"/*.json; do
    if [ -f "$TASK_FILE" ]; then
      OWNER=$(jq -r '.teammate_name // .owner // ""' "$TASK_FILE" 2>/dev/null)
      if [ "$OWNER" = "$TEAMMATE_NAME" ]; then
        SUBJECT=$(jq -r '.task_subject // .subject // ""' "$TASK_FILE" 2>/dev/null)
        KEY=$(echo "$SUBJECT" | grep -o '^[a-z-]*:[0-9a-z]*' | head -1 2>/dev/null || true)
        if [ -n "$KEY" ]; then
          TASK_KEY="$KEY"
          break
        fi
      fi
    fi
  done
fi

# Strategy 2: Reuse prior entry if this session was already recorded
if [ -z "$TASK_KEY" ] && [ -n "$SESSION_ID" ]; then
  TASK_KEY=$(jq -r --arg sid "$SESSION_ID" '.teammate_sessions[$sid].task_key // ""' "$BOULDER" 2>/dev/null)
fi

# Strategy 3: TASK_KEY from transcript first lines
if [ -z "$TASK_KEY" ] && [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TASK_KEY=$(head -5 "$TRANSCRIPT_PATH" | grep -o 'TASK_KEY: [a-z-]*:[0-9a-z]*' | head -1 | sed 's/TASK_KEY: //' 2>/dev/null || true)
fi

# Strategy 4: Fallback to current_task.key (only for sequential single-teammate execution)
if [ -z "$TASK_KEY" ]; then
  TASK_KEY=$(jq -r '.current_task.key // ""' "$BOULDER" 2>/dev/null)
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Append session_id to session_ids array for lineage tracking
if [ -n "$SESSION_ID" ]; then
  UPDATED=$(jq --arg sid "$SESSION_ID" \
    'if (.session_ids | index($sid)) == null then .session_ids += [$sid] else . end' \
    "$BOULDER" 2>/dev/null)
  if [ -n "$UPDATED" ]; then
    echo "$UPDATED" > "$BOULDER"
  fi

  # Upsert into teammate_sessions
  UPDATED=$(jq \
    --arg sid "$SESSION_ID" \
    --arg tk "$TASK_KEY" \
    --arg tn "$TEAMMATE_NAME" \
    --arg ts "$TIMESTAMP" \
    '.teammate_sessions[$sid] = {task_key: $tk, teammate_name: $tn, updated_at: $ts, status: "idle"}' \
    "$BOULDER" 2>/dev/null)
  if [ -n "$UPDATED" ]; then
    echo "$UPDATED" > "$BOULDER"
  fi
fi

# Continuation enforcement: if plan has incomplete tasks for this teammate's key, block idle
if [ -n "$TASK_KEY" ]; then
  PLAN_PATH=$(jq -r '.active_plan // .plan // ""' "$BOULDER" 2>/dev/null)
  if [ -n "$PLAN_PATH" ] && [ -f "$PLAN_PATH" ]; then
    REMAINING=$(grep -c '^\- \[ \]' "$PLAN_PATH" 2>/dev/null || echo "0")
    if [ "$REMAINING" -gt 0 ]; then
      echo "Incomplete tasks remain for TASK_KEY $TASK_KEY. Continue working." >&2
      exit 2
    fi
  fi
fi

exit 0
