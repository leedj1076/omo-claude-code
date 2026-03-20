#!/bin/bash
# Detects ultrawork/ulw keywords in user prompts.
# Strips code blocks before matching to prevent false positives
# when users paste code containing these words.

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""')

# Strip fenced code blocks (```...```) and inline code (`...`)
# to avoid matching keywords inside code samples
CLEAN_PROMPT=$(printf '%s' "$PROMPT" | perl -0pe 's/```.*?```//gs; s/`[^`\n]+`//g')

if echo "$CLEAN_PROMPT" | grep -iqE '\b(ultrawork|ulw)\b'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "ULTRAWORK MODE: Be extremely thorough. Mandatory planning for non-trivial tasks. Use multiple agents in parallel. Do not stop until 100% complete. Zero tolerance for partial work, scope reduction, or mockups. Verify everything with tests and LSP diagnostics."
    }
  }'
  exit 0
fi

exit 0
