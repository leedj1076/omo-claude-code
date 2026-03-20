#!/bin/bash
# Query OpenAI GPT. Usage: ask-gpt.sh "your prompt" [model]
# Primary: Codex CLI with ChatGPT OAuth. Fallback: OPENAI_API_KEY + curl.

PROMPT="${1:?Usage: ask-gpt.sh \"prompt\" [model]}"
MODEL="${2:-}"

# Primary: use Codex CLI if available (ChatGPT OAuth, no API key needed)
if command -v codex &>/dev/null; then
  MODEL_FLAG=""
  if [ -n "$MODEL" ]; then
    MODEL_FLAG="--model $MODEL"
  fi
  RAW=$(codex exec --skip-git-repo-check $MODEL_FLAG "$PROMPT" 2>&1)
  if [ $? -eq 0 ] && ! echo "$RAW" | grep -q "^ERROR:"; then
    echo "$RAW" | sed -n '/^codex$/,/^tokens used$/{ /^codex$/d; /^tokens used$/d; p; }'
    exit 0
  fi
fi

# Fallback: API key + curl
if [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: Codex CLI failed and OPENAI_API_KEY not set. Run 'codex login' or set OPENAI_API_KEY." >&2
  exit 1
fi

CURL_MODEL="${MODEL:-gpt-4o}"
curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg p "$PROMPT" --arg m "$CURL_MODEL" '{
    model: $m,
    messages: [{role: "user", content: $p}]
  }')" | jq -r '.choices[0].message.content // .error.message // "No response"'
