#!/bin/bash
# Query Google Gemini via API. Usage: ask-gemini.sh "your prompt"
# Requires GOOGLE_API_KEY environment variable.

if [ -z "$GOOGLE_API_KEY" ]; then
  echo "Error: GOOGLE_API_KEY not set" >&2
  exit 1
fi

PROMPT="${1:?Usage: ask-gemini.sh \"prompt\"}"
MODEL="${2:-gemini-2.0-flash}"

curl -s "https://generativelanguage.googleapis.com/v1/models/${MODEL}:generateContent?key=$GOOGLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg p "$PROMPT" '{contents:[{parts:[{text:$p}]}]}')" \
  | jq -r '.candidates[0].content.parts[0].text // .error.message // "No response"'
