#!/bin/bash
# Blocks the Write tool when the target file already exists.
# Exit 2 + stderr message to block; exit 0 to allow.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# If no file path provided, allow (nothing to guard)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Resolve relative paths using cwd
if [[ "$FILE_PATH" != /* ]]; then
  if [ -n "$CWD" ]; then
    FILE_PATH="$CWD/$FILE_PATH"
  fi
fi

# Block if file already exists
if test -f "$FILE_PATH"; then
  echo "File already exists: $FILE_PATH. Use the Edit tool instead of Write to modify existing files." >&2
  exit 2
fi

exit 0
