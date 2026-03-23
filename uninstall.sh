#!/bin/bash
# OmO Claude Code - Uninstall Script
# Removes OmO-installed files from ~/.claude/
#
# Usage: bash uninstall.sh [--dry-run]

set -euo pipefail

TARGET="$HOME/.claude"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h) echo "Usage: bash uninstall.sh [--dry-run]"; exit 0 ;;
  esac
done

log() { echo "[omo] $1"; }

remove_file() {
  local file="$1"
  if [ -f "$file" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "Would remove: $file"
    else
      rm "$file"
      log "Removed: $file"
    fi
  fi
}

remove_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "Would remove directory: $dir"
    else
      rm -rf "$dir"
      log "Removed directory: $dir"
    fi
  fi
}

log "Uninstalling OmO Claude Code setup..."
if [ "$DRY_RUN" = true ]; then
  log "DRY RUN - no changes will be made"
fi
echo ""

# Agent files
for agent in coordinator forge worker planner reviewer gap-analyzer oracle explore librarian quick-fix verifier codex-deep gemini-ui; do
  remove_file "$TARGET/agents/$agent.md"
done

# Skill directories
for skill in delegate dev-browser frontend-ui-ux git-master handoff init-deep ralph-loop refactor start-work stop-work ultrawork; do
  remove_dir "$TARGET/skills/$skill"
done

# Hook files
for hook in comment-checker edit-recovery notify-idle post-compact run-tests-async session-start subagent-stop task-completed teammate-idle ultrawork-detector write-guard; do
  remove_file "$TARGET/hooks/$hook.sh"
done

# Rule files
for rule in anti-slop swift tests typescript sisyphus-baseline; do
  remove_file "$TARGET/rules/$rule.md"
done

# Scripts
remove_file "$TARGET/scripts/ask-gemini.sh"
remove_file "$TARGET/scripts/ask-gpt.sh"

# Core files
remove_file "$TARGET/statusline-command.sh"
remove_file "$TARGET/USAGE.md"
remove_file "$TARGET/output-styles/concise.md"

# Don't remove CLAUDE.md, settings.json, plans/, notepads/, drafts/, memory/
# These contain user data

echo ""
log "=== Uninstall complete ==="
echo ""
log "Preserved (contain user data):"
echo "  - ~/.claude/CLAUDE.md (remove @sisyphus-baseline reference manually)"
echo "  - ~/.claude/settings.json (remove OmO hooks manually)"
echo "  - ~/.claude/plans/"
echo "  - ~/.claude/notepads/"
echo "  - ~/.claude/memory/"
