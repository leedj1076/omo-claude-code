#!/bin/bash
# OmO Claude Code Setup - Installation Script
# Installs the OmO agent framework into ~/.claude/
#
# Usage: bash install.sh [--dry-run] [--force]
#   --dry-run  Show what would be done without making changes
#   --force    Overwrite existing files without prompting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.claude"
DRY_RUN=false
FORCE=false
BACKED_UP=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    --help|-h) echo "Usage: bash install.sh [--dry-run] [--force]"; exit 0 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

log() { echo "[omo] $1"; }
warn() { echo "[omo] WARNING: $1" >&2; }

backup_file() {
  local file="$1"
  if [ -f "$file" ] && [ "$FORCE" = false ]; then
    local backup="${file}.backup.$(date +%Y%m%d%H%M%S)"
    if [ "$DRY_RUN" = true ]; then
      log "Would backup: $file -> $backup"
    else
      cp "$file" "$backup"
      log "Backed up: $file -> $backup"
    fi
    BACKED_UP+=("$backup")
  fi
}

copy_dir() {
  local src="$1"
  local dest="$2"
  if [ "$DRY_RUN" = true ]; then
    log "Would copy: $src/ -> $dest/"
    return
  fi
  mkdir -p "$dest"
  cp -R "$src"/* "$dest"/
  log "Copied: $src/ -> $dest/"
}

copy_file() {
  local src="$1"
  local dest="$2"
  if [ "$DRY_RUN" = true ]; then
    log "Would copy: $src -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  log "Copied: $(basename "$src")"
}

# --- Pre-flight checks ---

if ! command -v jq &>/dev/null; then
  warn "jq is required but not installed. Install it first:"
  echo "  macOS:  brew install jq"
  echo "  Ubuntu: sudo apt install jq"
  echo "  Arch:   sudo pacman -S jq"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  warn "Claude Code CLI not found. Install it first:"
  echo "  npm install -g @anthropic-ai/claude-code"
  exit 1
fi

log "Installing OmO Claude Code setup..."
log "Source: $SCRIPT_DIR"
log "Target: $TARGET"
if [ "$DRY_RUN" = true ]; then
  log "DRY RUN - no changes will be made"
fi
echo ""

# --- Create target directory ---

if [ "$DRY_RUN" = false ]; then
  mkdir -p "$TARGET"
fi

# --- Copy agent files ---

copy_dir "$SCRIPT_DIR/agents" "$TARGET/agents"

# --- Copy skill files ---

for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  if [ "$DRY_RUN" = true ]; then
    log "Would copy skill: $skill_name"
  else
    mkdir -p "$TARGET/skills/$skill_name"
    cp "$skill_dir"SKILL.md "$TARGET/skills/$skill_name/"
  fi
done
log "Copied all skills"

# --- Copy hooks ---

copy_dir "$SCRIPT_DIR/hooks" "$TARGET/hooks"
if [ "$DRY_RUN" = false ]; then
  chmod +x "$TARGET"/hooks/*.sh
  log "Made hooks executable"
fi

# --- Copy rules ---

copy_dir "$SCRIPT_DIR/rules" "$TARGET/rules"

# --- Copy output styles ---

copy_dir "$SCRIPT_DIR/output-styles" "$TARGET/output-styles"

# --- Copy scripts ---

if [ -d "$SCRIPT_DIR/scripts" ]; then
  copy_dir "$SCRIPT_DIR/scripts" "$TARGET/scripts"
  if [ "$DRY_RUN" = false ]; then
    chmod +x "$TARGET"/scripts/*.sh
    log "Made scripts executable"
  fi
fi

# --- Copy core files ---

copy_file "$SCRIPT_DIR/sisyphus-baseline.md" "$TARGET/sisyphus-baseline.md"
copy_file "$SCRIPT_DIR/statusline-command.sh" "$TARGET/statusline-command.sh"
copy_file "$SCRIPT_DIR/USAGE.md" "$TARGET/USAGE.md"

if [ "$DRY_RUN" = false ]; then
  chmod +x "$TARGET/statusline-command.sh"
fi

# --- Handle CLAUDE.md (don't overwrite if user has custom content) ---

if [ -f "$TARGET/CLAUDE.md" ]; then
  EXISTING=$(cat "$TARGET/CLAUDE.md")
  if echo "$EXISTING" | grep -q "sisyphus-baseline"; then
    log "CLAUDE.md already references sisyphus-baseline.md - skipping"
  else
    log "CLAUDE.md exists with custom content - appending reference"
    if [ "$DRY_RUN" = false ]; then
      echo "" >> "$TARGET/CLAUDE.md"
      echo "@~/.claude/sisyphus-baseline.md" >> "$TARGET/CLAUDE.md"
    fi
  fi
else
  copy_file "$SCRIPT_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"
fi

# --- Handle settings.json (merge, don't overwrite) ---

if [ -f "$TARGET/settings.json" ]; then
  log "Existing settings.json found - merging..."
  if [ "$DRY_RUN" = false ]; then
    backup_file "$TARGET/settings.json"

    # Deep merge: OmO settings take priority for hooks/env,
    # but preserve user's existing permissions, plugins, and other settings
    MERGED=$(jq -s '
      # $existing = .[0], $omo = .[1]
      .[0] as $existing | .[1] as $omo |

      # Start with existing settings
      $existing

      # Overwrite hooks entirely (OmO hooks are the full set)
      | .hooks = $omo.hooks

      # Merge permissions (combine allow/deny arrays, deduplicate)
      | .permissions.allow = (($existing.permissions.allow // []) + ($omo.permissions.allow // []) | unique)
      | .permissions.deny = (($existing.permissions.deny // []) + ($omo.permissions.deny // []) | unique)

      # Merge env vars (OmO values win on conflict)
      | .env = (($existing.env // {}) + ($omo.env // {}))

      # Set statusLine, thinking, effort from OmO
      | .statusLine = $omo.statusLine
      | .alwaysThinkingEnabled = $omo.alwaysThinkingEnabled
      | .effortLevel = $omo.effortLevel
    ' "$TARGET/settings.json" "$SCRIPT_DIR/settings.json")

    echo "$MERGED" | jq '.' > "$TARGET/settings.json"
    log "Settings merged successfully"
  fi
else
  copy_file "$SCRIPT_DIR/settings.json" "$TARGET/settings.json"
fi

# --- Create runtime directories ---

if [ "$DRY_RUN" = false ]; then
  mkdir -p "$TARGET/plans" "$TARGET/notepads" "$TARGET/drafts"
  log "Created runtime directories (plans/, notepads/, drafts/)"
fi

# --- Platform-specific notes ---

echo ""
log "=== Installation complete ==="
echo ""

if [[ "$OSTYPE" == "darwin"* ]]; then
  log "Platform: macOS (all features supported)"
else
  warn "Platform: Linux/other"
  warn "  - notify-idle.sh uses osascript (macOS only) - notifications won't work"
  warn "  - run-tests-async.sh uses stat -f (macOS) - may need stat -c on Linux"
  warn "  Consider editing these hooks for your platform."
fi

echo ""
log "What's installed:"
echo "  - 13 agent definitions (coordinator, forge, worker, planner, oracle, ...)"
echo "  - 11 skills (/delegate, /start-work, /stop-work, /handoff, ...)"
echo "  - 11 hooks (session-start, post-compact, write-guard, comment-checker, ...)"
echo "  - Behavioral rules (sisyphus-baseline, anti-slop, concise output style)"
echo "  - Status line with model, context %, token count, cost, git branch"
echo "  - Agent Teams enabled for parallel work"
echo ""
log "Quick start:"
echo "  claude                    # Start a session (hooks inject context automatically)"
echo "  claude --agent planner    # Plan a new feature"
echo "  claude --agent coordinator # Execute a plan"
echo "  /delegate fix the bug in auth.ts  # Delegate a task"
echo ""
log "Read ~/.claude/USAGE.md for the full guide."

if [ ${#BACKED_UP[@]} -gt 0 ]; then
  echo ""
  log "Backups created:"
  for b in "${BACKED_UP[@]}"; do
    echo "  $b"
  done
fi
