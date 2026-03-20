#!/bin/bash
# Hook: edit-recovery.sh
# Registered on PostToolUse + PostToolUseFailure for Edit tool
# Detects Edit failures and injects recovery guidance via additionalContext

INPUT=$(cat)

TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // .error // empty')

# No output or empty — successful edit, exit silently
if [[ -z "$TOOL_OUTPUT" ]]; then
  exit 0
fi

# Lowercase for case-insensitive matching
LOWER_OUTPUT=$(echo "$TOOL_OUTPUT" | tr '[:upper:]' '[:lower:]')

CONTEXT=""

if [[ "$LOWER_OUTPUT" == *"found multiple times"* ]] || \
   [[ "$LOWER_OUTPUT" == *"multiple matches"* ]] || \
   [[ "$LOWER_OUTPUT" == *"multiple times"* ]]; then
  CONTEXT="EDIT FAILED: multiple matches found. RECOVERY: Read the target file to identify unique surrounding context, then retry the Edit with a longer, unique oldString that appears only once in the file."
elif [[ "$LOWER_OUTPUT" == *"oldstring not found"* ]] || \
     [[ "$LOWER_OUTPUT" == *"not found in file"* ]] || \
     [[ "$LOWER_OUTPUT" == *"not found"* ]]; then
  CONTEXT="EDIT FAILED: oldString not found. RECOVERY: Read the target file immediately to get current content, then retry the Edit with the correct oldString. Do NOT guess - use the exact text from the file."
elif [[ "$LOWER_OUTPUT" == *"file not found"* ]] || \
     [[ "$LOWER_OUTPUT" == *"does not exist"* ]]; then
  CONTEXT="EDIT FAILED: file does not exist. RECOVERY: Verify the file path is correct. Use Write tool to create the file if it should be new."
fi

if [[ -n "$CONTEXT" ]]; then
  jq -n --arg ctx "$CONTEXT" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
fi

exit 0
