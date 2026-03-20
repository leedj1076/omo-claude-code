#!/bin/bash
# Updates boulder.json progress when a CC team task is marked complete.
# Triggered by CC's TaskCompleted event.
# Input (stdin): JSON with task_id, task_subject, teammate_name, team_name, session_id, transcript_path
# Exits 0 on success. Exits 2 if plan checkboxes don't confirm the task is actually done.

INPUT=$(cat)

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""' 2>/dev/null)
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // ""' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)

BOULDER=".claude/boulder.json"

if [ ! -f "$BOULDER" ]; then exit 0; fi

# Resolve task_key from task_subject prefix "todo:N | ..." or "final-wave:fN | ..."
TASK_KEY=$(echo "$TASK_SUBJECT" | grep -o '^[a-z-]*:[0-9a-z]*' | head -1 2>/dev/null || true)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Recount checkboxes from plan file to update progress
PLAN_PATH=$(jq -r '.active_plan // .plan // ""' "$BOULDER" 2>/dev/null)
if [ -n "$PLAN_PATH" ] && [ -f "$PLAN_PATH" ]; then
  REMAINING=$(grep -c '^\- \[ \]' "$PLAN_PATH" 2>/dev/null || echo "0")
  COMPLETED=$(grep -c '^\- \[x\]' "$PLAN_PATH" 2>/dev/null || echo "0")
  TOTAL=$((REMAINING + COMPLETED))
  PERCENT=0
  if [ "$TOTAL" -gt 0 ]; then
    PERCENT=$((COMPLETED * 100 / TOTAL))
  fi

  # Update progress in boulder.json
  UPDATED=$(jq \
    --argjson comp "$COMPLETED" \
    --argjson rem "$REMAINING" \
    --argjson tot "$TOTAL" \
    --argjson pct "$PERCENT" \
    '.progress = {total: $tot, completed: $comp, remaining: $rem, percent: $pct}' \
    "$BOULDER" 2>/dev/null)
  if [ -n "$UPDATED" ]; then
    echo "$UPDATED" > "$BOULDER"
  fi
fi

# Mark matching teammate session as completed
if [ -n "$SESSION_ID" ]; then
  # Direct match by session_id
  UPDATED=$(jq \
    --arg sid "$SESSION_ID" \
    --arg ts "$TIMESTAMP" \
    'if .teammate_sessions[$sid] != null then
      .teammate_sessions[$sid].status = "completed" | .teammate_sessions[$sid].updated_at = $ts
    else
      .
    end' \
    "$BOULDER" 2>/dev/null)
  if [ -n "$UPDATED" ]; then
    echo "$UPDATED" > "$BOULDER"
  fi
elif [ -n "$TASK_KEY" ]; then
  # Fallback: scan teammate_sessions for matching task_key (+ teammate_name if available)
  UPDATED=$(jq \
    --arg tk "$TASK_KEY" \
    --arg tn "$TEAMMATE_NAME" \
    --arg now "$TIMESTAMP" \
    '(.teammate_sessions // {}) as $tms |
    reduce ($tms | keys[]) as $sid (.;
      if $tms[$sid].task_key == $tk and ($tn == "" or $tms[$sid].teammate_name == $tn) then
        .teammate_sessions[$sid].status = "completed" | .teammate_sessions[$sid].updated_at = $now
      else
        .
      end
    )' \
    "$BOULDER" 2>/dev/null)
  if [ -n "$UPDATED" ]; then
    echo "$UPDATED" > "$BOULDER"
  fi
fi

exit 0
