# Changelog

## 0.2.0 (2026-03-23)

### Safety
- Move comment-checker from PostToolUse to PreToolUse (actually blocks banned content now)
- Add PreToolUse(Bash) hook blocking rm -rf, git push --force, git reset --hard, git clean -f, push to main/master
- Fix comment-checker URL false positives (strips URLs before scanning)

### Agents
- Add effort field to all 13 agents (low/medium/high by model tier)
- Add isolation: worktree to forge agent

### Configuration
- Add priority rules to top of CLAUDE.md for instruction weighting
- Add ENABLE_TOOL_SEARCH env var for lazy MCP tool loading
- Delete truncated duplicate rules/sisyphus-baseline.md

### Install
- Fix hook merge to combine arrays instead of replacing
- Add API key warnings for scripts requiring OPENAI_API_KEY and GOOGLE_API_KEY
- Add uninstall.sh for clean removal

### Structure
- Move sisyphus-baseline.md into rules/ directory
- Add docs/architecture.md with agent and hook references
- Add VERSION file and CHANGELOG.md

## 0.1.0 (2026-03-20)

Initial release: OmO agent orchestration framework for Claude Code.
