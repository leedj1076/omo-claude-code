# OmO Architecture Reference

## Agent Tier System

| Agent | Model | Effort | Tools | Purpose | When to Use |
|---|---|---|---|---|---|
| coordinator | sonnet | high | Agent, Read, Write, Edit, Bash, Glob, Grep, LSP, WebFetch, WebSearch, Tasks | Orchestrates full plans via delegation and verification | Plans with 5+ tasks needing wave-based parallel execution |
| forge | opus | high | Read, Write, Edit, Bash, Glob, Grep, LSP, WebFetch, WebSearch, Tasks | Autonomous deep worker, end-to-end ownership | Complex multi-step work requiring sustained focus |
| worker | sonnet | medium | Read, Write, Edit, Bash, Glob, Grep, LSP, WebFetch, WebSearch | General-purpose implementation | Default executor for delegated coding tasks |
| planner | opus | high | Read, Write, Edit, Glob, Grep, LSP, WebFetch, WebSearch, AskUser, Agent | Interview-driven plan generation (no code) | Before starting complex features or refactors |
| oracle | opus | high | Read, Glob, Grep, LSP, WebFetch, WebSearch | Architecture analysis, debugging consultation (read-only) | Hard debugging, design decisions, security/perf review |
| reviewer | opus | high | Read, Glob, Grep, LSP | Plan and code review, APPROVE/REJECT | After creating plans or before merging significant code |
| gap-analyzer | opus | high | Read, Glob, Grep, LSP, WebFetch, WebSearch | Pre-planning consultant (read-only) | Before finalizing plans, to catch missing requirements |
| verifier | sonnet | medium | Bash, Read, Glob, Grep, LSP | Test/lint/diagnostic runner, pass/fail reports | After implementation to confirm changes work |
| quick-fix | haiku | low | Read, Edit, Glob, Grep | Typos, single-line fixes, trivial config edits | When the change is obviously small and contained |
| explore | haiku | low | Read, Glob, Grep, LSP, Bash | Read-only codebase search (parallelizable) | Broad discovery, fire multiple in parallel |
| librarian | haiku | low | WebFetch, WebSearch, Read, Grep, Glob, Bash | External docs, API references, OSS examples | When unfamiliar libraries are involved |
| codex-deep | - | medium | Read, Glob, Grep + MCP (modelhub) | GPT/Codex second opinion via MCP | Tricky implementations, debugging branches, edge cases |
| gemini-ui | - | medium | Read, Glob, Grep + MCP (modelhub) | Gemini visual/frontend analysis via MCP | UI review, design feedback, screenshot analysis |

**Model tiers**: opus (deep reasoning) > sonnet (balanced) > haiku (fast/cheap).
codex-deep and gemini-ui use external models via MCP, not Claude.

## Hook Lifecycle

| Hook | Event | Matcher | Script | Purpose |
|---|---|---|---|---|
| ultrawork-detector | UserPromptSubmit | - | ultrawork-detector.sh | Detects autonomous mode requests |
| intent-classifier | UserPromptSubmit | - | (prompt hook) | Classifies search/analyze/normal intent |
| comment-checker | PreToolUse | Edit\|Write | comment-checker.sh | Blocks AI-filler language in file content |
| write-guard | PreToolUse | Write | write-guard.sh | Blocks Write on existing files (forces Edit) |
| bash-guard | PreToolUse | Bash | (inline jq) | Blocks rm -rf, git push --force, git reset --hard, push to main/master |
| run-tests-async | PostToolUse | Edit\|Write | run-tests-async.sh | Runs tests in background after edits |
| edit-recovery | PostToolUse | Edit | edit-recovery.sh | Recovery after edit operations |
| edit-recovery | PostToolUseFailure | Edit | edit-recovery.sh | Recovery after failed edits |
| stop-guard | Stop | - | (agent hook) | Blocks session stop if plan tasks remain incomplete |
| session-start | SessionStart | - | session-start.sh | Injects git context, handoff notes, active plan |
| post-compact | PostCompact | - | post-compact.sh | Reinjects boulder state after context compaction |
| notify-idle | Notification | idle_prompt | notify-idle.sh | OS notification when session goes idle |
| subagent-stop | SubagentStop | - | subagent-stop.sh | Captures subagent IDs into boulder state |
| teammate-idle | TeammateIdle | - | teammate-idle.sh | Tracks teammate sessions, enforces continuation |
| task-completed | TaskCompleted | - | task-completed.sh | Updates plan progress when team tasks finish |

**Event types**: PreToolUse blocks before execution. PostToolUse runs after. UserPromptSubmit intercepts user input. Stop prevents premature session exit.

## Skill Reference

| Skill | Purpose | Usage |
|---|---|---|
| delegate | Classify task and route to optimal specialist agent | `/delegate fix the auth bug in login.ts` |
| start-work | Begin executing an implementation plan | `/start-work plan-name` |
| stop-work | Pause boulder state and cancel in-flight work | `/stop-work` |
| handoff | Create context summary for continuing in a new session | `/handoff optional context` |
| git-master | Expert git operations (commits, rebase, blame, conflicts) | `/git-master rebase onto main` |
| refactor | LSP-aware refactoring with reference tracking | `/refactor rename UserService to AuthService` |
| ralph-loop | Self-continuing autonomous loop with boulder tracking | `/ralph-loop` |
| ultrawork | Maximum thoroughness mode with mandatory delegation | `/ultrawork` |
| init-deep | Generate hierarchical CLAUDE.md files for directory context | `/init-deep` |
| dev-browser | Browser automation with persistent page state | `/dev-browser go to localhost:3000` |
| frontend-ui-ux | Designer-developer for UI/UX, styling, layout, animation | `/frontend-ui-ux redesign the settings panel` |

## Output Styles

The `output-styles/` directory contains response format presets. Currently available:

| Style | Description |
|---|---|
| concise | Ultra-concise responses: lead with action, skip preamble, bullets over paragraphs |

Activate with `--output-style concise` when launching a session.

## How to Customize

### Adding a new agent

Create `.claude/agents/name.md` with YAML frontmatter:

```yaml
---
name: my-agent
description: What this agent does
tools: [Read, Edit, Bash, Glob, Grep]
model: sonnet
effort: medium
---

Agent instructions here.
```

### Adding a new hook

1. Create the script in `.claude/hooks/my-hook.sh`
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Register in `settings.json` under the appropriate event:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": ".claude/hooks/my-hook.sh" }]
      }
    ]
  }
}
```

Hook exit codes: 0 = allow, 2 = block (for PreToolUse).
stdin receives JSON with tool input. stderr output is shown to the model.

### Adding a new rule

Create `.claude/rules/name.md` with optional path scoping:

```yaml
---
paths: ["src/frontend/**"]
---

Rule content here. Applied only to files matching the paths glob.
```

Rules without `paths:` frontmatter apply globally.

### Modifying the baseline

Edit `.claude/rules/sisyphus-baseline.md`. This file is loaded via `@` import in CLAUDE.md and applies to every session. Changes take effect on next session start.
