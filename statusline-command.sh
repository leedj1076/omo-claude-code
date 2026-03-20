#!/bin/sh
# Claude Code status line
# Format: "Claude Opus 4.6 | 12% | 120K/1M"

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

used_pct=$(echo "$input"  | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input"  | jq -r '.context_window.context_window_size // empty')
# Sum all input token types for accurate count
cur_input=$(echo "$input" | jq -r '
  .context_window.current_usage |
  ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Git branch
git_branch=$(git branch --show-current 2>/dev/null)

# Format percentage
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  pct_str="${used_int}%"
else
  pct_str="?%"
fi

# Format token counts as e.g. "120K" or "1.2M"
format_tokens() {
  val="$1"
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    echo "?"
    return
  fi
  if [ "$val" -ge 1000000 ]; then
    awk -v v="$val" 'BEGIN { printf "%.1fM", v/1000000 }'
  elif [ "$val" -ge 1000 ]; then
    awk -v v="$val" 'BEGIN { printf "%dK", int(v/1000) }'
  else
    echo "$val"
  fi
}

if [ -n "$cur_input" ] && [ -n "$ctx_size" ]; then
  used_fmt=$(format_tokens "$cur_input")
  total_fmt=$(format_tokens "$ctx_size")
  tok_str="${used_fmt}/${total_fmt}"
else
  tok_str=""
fi

# Format cost
if [ -n "$total_cost" ] && [ "$total_cost" != "0" ]; then
  cost_str=$(printf "$%.2f" "$total_cost")
else
  cost_str=""
fi

# Assemble the line
line="$model | Context: $pct_str"

if [ -n "$tok_str" ]; then
  line="$line | Token: $tok_str"
fi

if [ -n "$cost_str" ]; then
  line="$line | Cost: $cost_str"
fi

if [ -n "$git_branch" ]; then
  line="$line | $git_branch"
fi

printf "%s" "$line"
