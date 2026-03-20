#!/bin/bash
# Runs tests asynchronously after file edits. Does not block Claude.
# Uses lockfile + cooldown to prevent redundant runs on rapid edits.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Skip non-source files
case "$FILE_PATH" in
  *.md|*.json|*.yml|*.yaml|*.txt|*.png|*.jpg|*.gif|*.svg|*.ico|*.lock)
    exit 0
    ;;
esac

# Throttle: skip if lockfile exists and is recent (<10 seconds old)
LOCKFILE="/tmp/claude-tests-running"
if [ -f "$LOCKFILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCKFILE" 2>/dev/null || stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt 10 ]; then
    exit 0
  fi
fi

# Create lockfile
touch "$LOCKFILE"

# Detect test framework and run
if [ -f "package.json" ]; then
  if grep -q '"test"' package.json 2>/dev/null; then
    npm test 2>&1 | tail -20
  fi
elif [ -f "Cargo.toml" ]; then
  cargo test 2>&1 | tail -20
elif [ -f "go.mod" ]; then
  go test ./... 2>&1 | tail -20
elif [ -f "pytest.ini" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
  pytest --tb=short 2>&1 | tail -20
fi

# Cleanup lockfile
rm -f "$LOCKFILE"

exit 0
