# Installation

## For Humans

Open a Claude Code session **in the project you want to add OmO to**, then paste:

```
Install and configure omo-claude-code by following the instructions here:
https://raw.githubusercontent.com/leedj1076/omo-claude-code/refs/heads/master/docs/installation.md
```

That's it. Claude reads this guide, downloads everything, and sets it up in your project's `.claude/` directory. Repeat for each project you want OmO in.

---

## For LLM Agents

> **IMPORTANT: Use `curl` to fetch this file, NOT WebFetch.** WebFetch summarizes content and loses critical details (file lists, merge logic, verification commands). Always use:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/leedj1076/omo-claude-code/refs/heads/master/docs/installation.md
> ```

You're installing omo-claude-code, an agent orchestration framework for Claude Code. It adds 13 specialized agents, 11 slash-command skills, 11 lifecycle hooks, behavioral rules, plan-based work tracking, and Agent Teams support.

**This is a repo-local install.** Everything goes into `.claude/` relative to the current working directory. Make sure you're in the project root before proceeding.

Follow these steps in order.

### Step 0: Pre-flight

Check that required tools exist:

```bash
# jq is required by hooks
if ! command -v jq &>/dev/null; then
  echo "MISSING: jq. Install it first (brew install jq / apt install jq)"
fi

# Claude Code CLI
if ! command -v claude &>/dev/null; then
  echo "MISSING: Claude Code CLI. Install: npm install -g @anthropic-ai/claude-code"
fi
```

If either is missing, tell the user and stop.

### Step 1: Download the repo

Download and extract the repository to a temp directory. No git clone needed.

```bash
TEMP_DIR=$(mktemp -d)
curl -fsSL https://github.com/leedj1076/omo-claude-code/archive/refs/heads/master.tar.gz | tar xz -C "$TEMP_DIR"
SRC="$TEMP_DIR/omo-claude-code-master"
echo "Downloaded to: $SRC"
```

Verify the download succeeded:

```bash
ls "$SRC/agents" "$SRC/hooks" "$SRC/skills" "$SRC/settings.json" >/dev/null 2>&1 && echo "OK" || echo "DOWNLOAD FAILED"
```

If the download fails, tell the user and stop.

### Step 2: Run the installer

```bash
bash "$SRC/install.sh"
```

The installer handles:
- Copying all agents, skills, hooks, rules, scripts, and output styles to `.claude/`
- Making hooks and scripts executable
- Smart CLAUDE.md handling (creates or appends, never overwrites custom content)
- Smart settings.json merging (replaces hooks, combines permissions, merges env vars, preserves user's plugins and other settings)
- Backing up existing settings.json before merging
- Creating runtime directories (plans/, notepads/, drafts/)
- Platform detection with warnings for non-macOS systems

Watch the output for any warnings or errors.

### Step 3: Verify installation

Run all of these checks:

```bash
# Count agents (expect 13)
echo "Agents: $(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')"

# Count skills (expect 11)
echo "Skills: $(ls .claude/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')"

# Count hooks (expect 11)
echo "Hooks: $(ls .claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')"

# Non-executable hooks (expect empty)
echo "Non-executable hooks: $(find .claude/hooks -name '*.sh' ! -perm -u+x 2>/dev/null)"

# Agent Teams env var (expect "1")
echo "Agent Teams: $(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // "NOT SET"' .claude/settings.json 2>/dev/null)"

# Hooks registered (expect 10 event types)
echo "Hook events: $(jq '.hooks | keys | length' .claude/settings.json 2>/dev/null)"

# CLAUDE.md references baseline
echo "Baseline ref: $(grep -c 'sisyphus-baseline' .claude/CLAUDE.md 2>/dev/null) (expect >= 1)"

# Status line exists
echo "Status line: $(test -x .claude/statusline-command.sh && echo 'OK' || echo 'MISSING')"
```

Expected results:
- Agents: 13
- Skills: 11
- Hooks: 11
- Non-executable hooks: (empty)
- Agent Teams: 1
- Hook events: 10
- Baseline ref: >= 1
- Status line: OK

If any check fails, fix it before continuing.

### Step 4: Clean up temp directory

```bash
rm -rf "$TEMP_DIR"
```

### Step 5: Platform-specific adjustments

Detect the platform and warn about issues:

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macOS detected. All features supported."
else
  echo "Non-macOS detected. Two hooks need adjustment:"
  echo ""
  echo "1. .claude/hooks/notify-idle.sh uses osascript (macOS only)"
  echo "   Fix: Replace osascript line with: notify-send 'Claude Code' 'Waiting for input'"
  echo ""
  echo "2. .claude/hooks/run-tests-async.sh uses stat -f %m (macOS)"
  echo "   Fix: Change 'stat -f %m' to 'stat -c %Y'"
fi
```

If on Linux, apply those fixes now. Ask the user if they want you to make the changes.

### Step 6: Tell the user what they got

After successful installation, explain what's set up:

**What's installed:**
- **13 agents**: coordinator, forge, worker, planner, oracle, librarian, reviewer, verifier, gap-analyzer, quick-fix, explore, codex-deep, gemini-ui
- **11 skills**: /delegate, /start-work, /stop-work, /handoff, /git-master, /refactor, /ralph-loop, /ultrawork, /init-deep, /dev-browser, /frontend-ui-ux
- **11 hooks**: session-start, post-compact, stop (agent-type), write-guard, comment-checker, edit-recovery, run-tests-async, ultrawork-detector, notify-idle, subagent-stop, teammate-idle, task-completed
- **Behavioral rules**: intent classification, evidence standards, anti-slop enforcement, delegation bias
- **Agent Teams**: enabled for parallel work within plans
- **Status line**: shows model name, context %, token count, session cost, git branch

**Quick start commands:**
```
claude                       # Normal session (hooks inject context automatically)
claude --agent planner       # Plan a new feature (interview -> structured plan)
claude --agent coordinator   # Execute a plan (delegates, verifies, tracks progress)
/delegate fix the bug in X   # Delegate a task (auto-picks agent and model)
/start-work plan-name        # Start or resume a plan
/stop-work                   # Pause current plan
/handoff                     # Create handoff notes for next session
```

**Key behaviors they'll notice immediately:**
1. Status line at bottom showing model, context usage, cost
2. Session-start hook injects git branch, recent commits, and any active plan state
3. Write tool is blocked on existing files (forces Edit to prevent accidental overwrites)
4. AI filler language is blocked in written content (comment-checker catches it)
5. Stop hook pushes back if they try to end a session with incomplete plan tasks
6. Including "ultrawork" or "ulw" in a prompt activates autonomous mode

Tell the user to read `.claude/USAGE.md` for the full guide on all features, delegation categories, and the Agent Teams system.

### Step 7: Quick test

Ask the user if they want to test the setup. If yes:

```
Start a new Claude Code session in a project directory. You should see:
1. The status line at the bottom
2. Git context injected automatically
3. Try: /delegate explain what hooks are registered in my settings.json
```

This verifies the delegate skill routes correctly and hooks are firing.

---

## What NOT to install

These are local/session state. Never copy them from someone else's setup:
- `boulder.json` (active plan state)
- `handoff.md` (session handoff notes)
- `plans/` contents (user-generated plans)
- `notepads/` contents (accumulated wisdom per plan)
- `transcripts/`, `tasks/`, `sessions/`, `cache/`, `ide/`
- `settings.local.json` (personal overrides)
- API keys or credentials

---

## Minimal install (behavioral rules only)

If the user just wants the behavioral improvements without the full agent/skill system, install only:

1. `sisyphus-baseline.md` -> `.claude/sisyphus-baseline.md`
2. `rules/anti-slop.md` -> `.claude/rules/anti-slop.md`
3. `CLAUDE.md` -> `.claude/CLAUDE.md` (contains `@.claude/sisyphus-baseline.md`)
4. These hooks (make executable):
   - `hooks/comment-checker.sh` -> `.claude/hooks/comment-checker.sh`
   - `hooks/write-guard.sh` -> `.claude/hooks/write-guard.sh`
   - `hooks/edit-recovery.sh` -> `.claude/hooks/edit-recovery.sh`
   - `hooks/session-start.sh` -> `.claude/hooks/session-start.sh`
5. Register the hooks in `.claude/settings.json`

This gives: intent classification, evidence standards, anti-slop enforcement, edit safety, and git context injection. No agents, no skills, no plans.
