# Using Your Claude Code Setup

## The Mental Model

This setup has two layers: **skills** (slash commands you invoke) and **agents** (specialists Claude spawns internally). You talk to the main session; it routes to the right agent or skill automatically.

---

## How the Framework Loads

Not everything runs on every session. Most of the framework is dormant until you invoke it.

**Loads every session (~2.5K tokens):**
- `CLAUDE.md` -- 5 priority rules + @import of sisyphus-baseline
- `rules/sisyphus-baseline.md` -- behavioral baseline (121 lines)
- `rules/anti-slop.md` -- style enforcement (12 lines)
- Language rules only when working with matching files (paths: scoped)

**Loads on demand (zero cost until invoked):**
- All 13 agents -- read only when delegated to via Agent()
- MCP tools -- lazy-loaded via ENABLE_TOOL_SEARCH
- Skills -- loaded only when slash command is invoked

**Available but not active until you opt in:**
- Agent Teams -- env var enables the feature; teammates only exist when you create them
- Coordinator -- runs only via `claude --agent coordinator`
- Planner -- runs only via `claude --agent planner`
- Boulder state -- only active when a plan is in progress

**Fires automatically on registered events:**
- PreToolUse hooks: comment-checker (Edit|Write), write-guard (Write), destructive blocker (Bash)
- PostToolUse hooks: run-tests-async (Edit|Write), edit-recovery (Edit)
- Session lifecycle: session-start, post-compact, notify-idle, Stop verifier
- Agent lifecycle: subagent-stop, teammate-idle, task-completed

**The default session** (no flags, no commands) gives you: sisyphus baseline + anti-slop + hooks. Direct coding mode. Everything else is opt-in.

---

## Daily Workflows

### Starting a new task or feature

For anything non-trivial, use the planner first:

```
claude --agent planner
```

The planner interviews you, researches the codebase, and produces a structured plan in `.claude/plans/`. Once the plan exists, run it:

```
claude --agent coordinator
```

The coordinator executes the plan wave by wave, spawns specialists, verifies every step, and won't stop until all tasks are done.

For small tasks (1-5 steps), skip the planner and use `/start-work` directly:

```
/start-work plan-name
```

---

### Delegating a single task

```
/delegate fix the auth bug in login.ts
/delegate add dark mode to the settings panel
/delegate write documentation for the API endpoints
```

The delegate skill classifies your task into one of 8 categories (quick, deep, visual-engineering, ultrabrain, writing, artistry, unspecified-low, unspecified-high), picks the right agent and model, injects behavioral instructions, and formats a structured prompt automatically.

You don't pick the agent — describe the work and let delegation handle routing.

---

### Pausing and resuming

```
/stop-work
```

Saves your progress to `.claude/boulder.json` and resets in-flight tasks. Your plan stays intact.

To resume:

```
/start-work plan-name
```

Or just open a new session — `session-start.sh` auto-injects the plan context and tells you where you left off.

---

### Handing off to a future session

```
/handoff optional context about current state
```

Writes `.claude/handoff.md` with what was done, what's next, boulder progress, and the exact resume commands. The next session picks this up automatically.

---

## The Agent Roster

You don't invoke most agents directly — delegation routes to them. But knowing what each does helps you ask for the right thing.

| Agent | Model | When it's used |
|---|---|---|
| **coordinator** | sonnet | Orchestrates full plans. Delegates everything, verifies everything. |
| **worker** | sonnet | Default executor. Multi-file features, bug fixes, tests. |
| **forge** | opus | Deep autonomous work. Explores extensively, doesn't stop until done. |
| **quick-fix** | haiku | Typos, single-line changes, trivial config edits. |
| **planner** | opus | Interview then plan generation. Never writes code. |
| **oracle** | opus | Architecture analysis, debugging consultation. Read-only. |
| **librarian** | haiku | External docs, API references, OSS examples. |
| **reviewer** | opus | Plan or code review. Returns APPROVE or REJECT. |
| **verifier** | sonnet | Runs tests, lint, diagnostics. Produces pass/fail report. |
| **gap-analyzer** | opus | Finds missing requirements before a plan is finalized. |

To invoke any agent directly:

```
claude --agent forge
claude --agent oracle
claude --agent planner
```

---

## Delegation Categories

When you use `/delegate`, the skill classifies your task into a category and routes accordingly. You don't need to pick the category yourself — it's inferred from the task description.

| Category | Routes To | Model | Use When |
|---|---|---|---|
| `quick` | quick-fix | haiku | Single-file, trivial change, typo |
| `deep` | forge | opus | Autonomous research + end-to-end implementation |
| `visual-engineering` | forge or worker | opus/sonnet | Any UI, CSS, animations, layout, design |
| `ultrabrain` | oracle | opus | Hard logic, architecture decisions, algorithms |
| `writing` | worker | sonnet | Prose, docs, READMEs, articles |
| `artistry` | forge or worker | opus/sonnet | Creative or generative work |
| `unspecified-low` | worker | sonnet | Moderate work that fits no other category |
| `unspecified-high` | forge | opus | Substantial work across multiple systems |

---

## Agent Teams

Agent Teams is enabled in this setup (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `settings.json`). The coordinator is the only agent that uses it — it's not something you invoke directly.

This section explains exactly how the coordinator uses Agent Teams, what the three lifecycle hooks do, and what the actual constraints are.

---

### Two delegation modes

The coordinator has two ways to spawn work:

**Subagents** — via the `Agent()` tool. Fast, cheap, share the coordinator's context window. Used for search, review, verification, and single-file fixes. Each one completes a task and disappears.

**Teammates** — full parallel Claude sessions, each with their own context window and their own turn budget. Used for deep implementation tasks within the same wave. Each one persists until cancelled or idle.

The coordinator decides which to use based on a single rule: if the task would benefit from 50+ turns of sustained autonomous work, it's a teammate. Otherwise it's a subagent.

In practice this means:
- `quick-fix`, `librarian`, `verifier`, `oracle` → always subagents
- `worker` on a contained task → subagent
- `forge` or `worker` on a large multi-file feature → teammate

---

### How parallel wave execution works

Plans are structured in waves. Tasks in the same wave have no dependencies on each other and can run simultaneously. For a wave with three independent tasks, the coordinator launches all three in one message:

```
[Coordinator]
  ├── Teammate A: TASK_KEY: todo:1 — implement auth module    (forge, opus)
  ├── Teammate B: TASK_KEY: todo:2 — implement profile module (worker, sonnet)
  └── Teammate C: TASK_KEY: todo:3 — implement notifications  (worker, sonnet)
```

All three run in parallel. The coordinator waits for all to complete, runs 4-phase verification on each, then moves to Wave 2.

The coordinator caps concurrent teammates at 3-5. Beyond that, token costs compound quickly.

---

### The TASK_KEY contract

Every delegation prompt the coordinator writes — whether to a subagent or a teammate — starts with a `TASK_KEY:` line as the very first thing:

```
TASK_KEY: todo:3

## 1. TASK
Implement the notifications module...
```

This is a hard contract, not a convention. Without it, the session state system breaks.

For teammates, the coordinator also creates a shared team task with a matching subject prefix:

```
todo:3 | Implement notifications module
```

The native team task list becomes the primary way to map a teammate name back to a plan task. The `TASK_KEY` in the transcript is the fallback.

---

### The three lifecycle hooks

These run silently in the background whenever Agent Teams events fire. You don't invoke them.

#### `subagent-stop.sh` — runs when any subagent finishes

CC fires `SubagentStop` with the subagent's `agent_id`, `agent_type`, and the path to its transcript file. The hook:

1. Reads the first 5 lines of the transcript looking for `TASK_KEY: todo:N`
2. If found, writes the `agent_id` into `boulder.json` under `task_sessions["todo:N"]`
3. If no TASK_KEY in transcript, falls back to `current_task.key` from boulder state
4. Always exits 0 — never blocks subagent completion

This is what makes subagent session reuse automatic. The coordinator doesn't need to track agent IDs manually — the hook captures them the moment a subagent finishes.

**What gets written to boulder.json:**
```json
"task_sessions": {
  "todo:3": {
    "task_key": "todo:3",
    "agent_id": "agent-abc123",
    "agent_type": "worker",
    "updated_at": "2026-03-20T08:00:00Z"
  }
}
```

Next time the coordinator delegates `todo:3`, it reads this entry and sends `SendMessage` to `agent-abc123` to continue the existing session instead of spawning a new one.

---

#### `teammate-idle.sh` — runs when a teammate goes idle between turns

CC fires `TeammateIdle` with the teammate's name, team name, session ID, and transcript path. The hook resolves which plan task the teammate owns using this priority order:

1. **Native team task list** — reads `.claude/tasks/{team_name}/*.json`, finds the task assigned to this teammate, parses the `task_subject` prefix (`todo:2 | ...`) to get the task key. This is the preferred source because it's authoritative.
2. **Prior boulder entry** — if this session ID already has an entry in `teammate_sessions`, reuses its recorded `task_key`
3. **Transcript** — reads the first 5 lines of the teammate's transcript for a `TASK_KEY:` line
4. **Current task fallback** — uses `current_task.key` from boulder state (only safe for sequential single-teammate execution)

After resolving the task key, the hook:
- Appends the session ID to `boulder.json.session_ids` (lineage tracking)
- Writes the session into `boulder.json.teammate_sessions`
- Checks if the plan still has unchecked tasks. If yes, exits 2 with a continuation message, which tells CC to push the teammate back to work rather than letting it go idle

**What gets written to boulder.json:**
```json
"session_ids": ["s1", "s2"],
"teammate_sessions": {
  "s2": {
    "task_key": "todo:2",
    "teammate_name": "worker-1",
    "updated_at": "2026-03-20T08:01:00Z",
    "status": "idle"
  }
}
```

The coordinator reads `teammate_sessions` before creating a new teammate. If an idle entry exists for the same `task_key`, it resumes that session instead of spawning fresh.

---

#### `task-completed.sh` — runs when a CC team task is marked complete

CC fires `TaskCompleted` with `task_subject`, `session_id`, and optionally `teammate_name`. The hook:

1. Parses `task_subject` for a `todo:N | ...` prefix to get the task key
2. Recounts `- [x]` and `- [ ]` checkboxes in the active plan file
3. Updates `boulder.json.progress` with fresh totals (total, completed, remaining, percent)
4. Marks the matching `teammate_sessions` entry as `status: "completed"`

Progress in boulder state is always derived from live checkbox counts, not from what the coordinator reported. This prevents drift if a teammate marks something done without the coordinator having updated the plan file.

---

### Session reuse in practice

Here's what happens when the coordinator revisits a task that previously failed or needs follow-up:

```
First attempt (Wave 2, task todo:5):
  Coordinator spawns worker subagent
  → SubagentStop fires, writes agent-xyz to task_sessions["todo:5"]
  → Verification fails

Second attempt:
  Coordinator reads task_sessions["todo:5"].agent_id = "agent-xyz"
  → Sends SendMessage to agent-xyz: "Verification failed: X. Fix by: Y"
  → agent-xyz resumes with full context of first attempt
  → No context rebuild, no re-reading files it already read
```

This is the OmO `upsertTaskSessionState()` pattern approximated in shell hooks. OmO does it in TypeScript with direct API access to session IDs at spawn time. Here it's done after the fact via transcript parsing — slightly less elegant, same outcome.

---

### Limitations specific to this setup

**Teammates are ephemeral.** They don't survive session restarts. `teammate_sessions` in boulder.json records what happened but a new session can't resume a teammate from a prior session. Subagent reuse via `task_sessions` has the same constraint — `agent_id` from a previous session is useless in a new one.

**No programmatic teammate API.** OmO's `task()` function returns a `session_id` synchronously. CC creates teammates via natural language and doesn't expose a return value. The hooks work around this by reading from transcript files and the native team task list after the fact.

**TASK_KEY discipline is load-bearing.** If the coordinator writes a delegation prompt without `TASK_KEY: todo:N` as the first line, `subagent-stop.sh` falls back to `current_task.key` — which is correct for sequential work but wrong during parallel waves where multiple subagents are running simultaneously for different tasks.

**TeammateIdle continuation is coarse.** The hook exits 2 (continue working) if any plan tasks remain unchecked, not just the one this teammate owns. In practice this is fine because a teammate that's idle with tasks remaining should continue regardless. But it means a teammate can be pushed back to work even if its specific task is done and something else remains.

---

## The Hook System (automatic)

These fire without you doing anything.

| Hook | What it does |
|---|---|
| **session-start** | Injects git context, handoff notes, and active plan status at session open |
| **post-compact** | Reinjects boulder progress and work state after context compaction |
| **stop** | Blocks the session from ending if plan tasks remain incomplete (unless you explicitly said "stop") |
| **subagent-stop** | Auto-captures subagent IDs into boulder state for session reuse |
| **teammate-idle** | Tracks teammate sessions, enforces continuation if tasks remain |
| **task-completed** | Updates plan progress in boulder state when team tasks finish |
| **write-guard** | Blocks Write on existing files — forces Edit to prevent overwrites |
| **comment-checker** | Blocks AI-filler language in new file content |
| **run-tests-async** | Runs tests in background after every Edit/Write |
| **ultrawork-detector** | Detects when you want autonomous mode |

---

## Boulder State

`.claude/boulder.json` is the persistent work tracker. It records:

- Current plan and progress (X/Y tasks, percent complete)
- Current task title and key
- Session history
- Subagent and teammate session maps (for reuse without re-spawning)

You don't edit this directly. `/start-work` creates it, `/stop-work` pauses it, the coordinator updates it after each task.

---

## Common Patterns

**Build something from scratch**

```
claude --agent planner
# Describe what you want, answer the interview questions
# Planner generates .claude/plans/name.md
claude --agent coordinator
# Coordinator executes the full plan
```

**Fix a specific bug**

```
/delegate fix the race condition in auth/session.ts where concurrent logins overwrite each other
```

**Get architectural advice before coding**

```
claude --agent oracle
# Describe the design question
# Oracle gives a recommendation with effort estimate and risks
```

**Review a plan before executing**

```
claude --agent reviewer
# Point it at .claude/plans/your-plan.md
```

**Resume after something went wrong mid-plan**

```
/stop-work
# Fix the issue manually or ask oracle
/start-work plan-name
# Resumes from the last incomplete task
```

---

## File Structure

```
.claude/
  USAGE.md                    # This file
  settings.json               # Hooks, permissions, env vars
  boulder.json                # Active plan state (created by /start-work)
  handoff.md                  # Session handoff notes (created by /handoff)

  agents/                     # Agent prompt files (13 agents)
    coordinator.md
    worker.md
    forge.md
    planner.md
    oracle.md
    quick-fix.md
    librarian.md
    reviewer.md
    verifier.md
    gap-analyzer.md
    explore.md
    codex-deep.md
    gemini-ui.md

  skills/                     # Slash command implementations
    start-work/SKILL.md
    stop-work/SKILL.md
    delegate/SKILL.md
    handoff/SKILL.md
    git-master/SKILL.md
    refactor/SKILL.md
    ralph-loop/SKILL.md
    ultrawork/SKILL.md
    dev-browser/SKILL.md
    frontend-ui-ux/SKILL.md
    init-deep/SKILL.md

  hooks/                      # Shell scripts that fire on events
    session-start.sh
    post-compact.sh
    subagent-stop.sh
    teammate-idle.sh
    task-completed.sh
    write-guard.sh
    comment-checker.sh
    run-tests-async.sh
    ultrawork-detector.sh
    notify-idle.sh
    edit-recovery.sh

  rules/                      # Behavioral rules loaded at startup
    sisyphus-baseline.md      # Always-on baseline for every session
    anti-slop.md
    swift.md
    tests.md
    typescript.md

  output-styles/              # Response format presets
    concise.md

  scripts/                    # Helper scripts for MCP agents
    ask-gpt.sh
    ask-gemini.sh

  plans/                      # Generated plans (created by planner)
  notepads/                   # Accumulated wisdom per plan (created by coordinator)
  drafts/                     # Working notes during planning (deleted after plan)
```

---

## Tips

- The stop hook pushes back if you try to exit mid-plan. Say "stop" or "pause" explicitly to override it.
- If a task fails 3 times, stop trying the same approach — consult oracle first.
- Plans live in `.claude/plans/`. Wisdom from past runs accumulates in `.claude/notepads/{plan-name}/`.
- Agent Teams is enabled, so the coordinator can run parallel teammates for independent work within a wave.
- The coordinator is the right choice for plans with 5+ tasks. For 1-4 tasks, `/start-work` is sufficient.
- `forge` is not the default -- it's the specialist for genuinely hard autonomous work. Don't route everything there.
- Use `--output-style concise` for ultra-concise responses (lead with action, skip preamble, bullets over paragraphs).

---

## MCP-Dependent Agents

Two agents (`codex-deep` and `gemini-ui`) query external models via a **modelhub MCP server**. They work without it (they report the error and provide their own analysis), but you get better results with the MCP server running.

### Requirements

| Agent | External Model | Required Env Var |
|---|---|---|
| codex-deep | GPT/Codex (OpenAI) | `OPENAI_API_KEY` |
| gemini-ui | Gemini (Google) | `GOOGLE_API_KEY` |

### MCP Server Setup

The MCP server must be available at `.claude/tools/model-hub-mcp.js`. Both agents declare it in their frontmatter:

```yaml
mcpServers:
  - modelhub:
      type: stdio
      command: node
      args: [".claude/tools/model-hub-mcp.js"]
      env:
        OPENAI_API_KEY: "${OPENAI_API_KEY}"
        GOOGLE_API_KEY: "${GOOGLE_API_KEY}"
```

### Where to get the MCP server

The model-hub MCP server is not yet open-sourced. It will be published alongside a future OmO release. In the meantime, these agents gracefully degrade: if the MCP server isn't available, they fall back to analysis using only their built-in tools (Read, Glob, Grep) and report that the external model was unavailable.

### Graceful Degradation

If MCP is unavailable or the API key is missing:
- The agent logs the connection error
- Falls back to codebase analysis with built-in tools
- Returns its own assessment with a note that the external model wasn't consulted
- The coordinator or caller can still act on the analysis
