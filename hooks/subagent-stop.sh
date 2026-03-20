#!/bin/bash
# Captures subagent session identity into boulder.json task_sessions after completion.
# Triggered by CC's SubagentStop event when any subagent finishes.
# Input (stdin): JSON with agent_id, agent_type, agent_transcript_path, last_assistant_message
# Always exits 0 — state capture only, never blocks subagent completion.

INPUT=$(cat)
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null)

BOULDER=".claude/boulder.json"

# No-op if no boulder state or not in_progress
if [ ! -f "$BOULDER" ]; then exit 0; fi
STATUS=$(jq -r '.status // ""' "$BOULDER" 2>/dev/null)
if [ "$STATUS" != "in_progress" ]; then exit 0; fi
if [ -z "$AGENT_ID" ]; then exit 0; fi

# Resolve task_key — two strategies tried in order:
TASK_KEY=""

# Strategy 1: Read first 5 lines of transcript, grep for "TASK_KEY: " prefix
# The coordinator contract requires every delegation to start with "TASK_KEY: todo:N"
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TASK_KEY=$(head -5 "$TRANSCRIPT_PATH" | grep -o 'TASK_KEY: [a-z-]*:[0-9a-z]*' | head -1 | sed 's/TASK_KEY: //' 2>/dev/null || true)
fi

# Strategy 2: Fallback to current_task.key from boulder (correct for sequential work)
if [ -z "$TASK_KEY" ]; then
  TASK_KEY=$(jq -r '.current_task.key // ""' "$BOULDER" 2>/dev/null)
fi

# If still no key, skip gracefully
if [ -z "$TASK_KEY" ]; then exit 0; fi

# Upsert into task_sessions[task_key]
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
UPDATED=$(jq \
  --arg key "$TASK_KEY" \
  --arg aid "$AGENT_ID" \
  --arg atype "$AGENT_TYPE" \
  --arg ts "$TIMESTAMP" \
  '.task_sessions[$key] = {task_key: $key, agent_id: $aid, agent_type: $atype, updated_at: $ts}' \
  "$BOULDER" 2>/dev/null)

if [ -n "$UPDATED" ]; then
  echo "$UPDATED" > "$BOULDER"
fi

exit 0
