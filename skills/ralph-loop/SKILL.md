---
name: ralph-loop
description: Start a self-continuing ralph loop with boulder state tracking
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, LSP, Agent, TaskCreate, TaskUpdate, TaskList]
user-invocable: true
argument-hint: "task description [--max-iterations N] [--completion-promise TEXT]"
---

# Ralph Loop with Boulder State

Wraps the ralph-loop plugin with boulder state integration so the Stop hook and /stop-work skill can track loop lifecycle.

## Step 1: Parse Arguments

Accept `$ARGUMENTS` as the full task description and flags to pass through to `/ralph-loop`.

## Step 2: Create Boulder State

Before invoking the loop, create `.claude/boulder.json` to register the active work:

```bash
cat > .claude/boulder.json << 'BOULDEREOF'
{
  "plan": "ralph-loop",
  "task": "$ARGUMENTS",
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "in_progress",
  "mode": "ralph-loop"
}
BOULDEREOF
```

Write this file using the Write tool with the actual values substituted (don't run the bash literally). The `started` field should use the current UTC timestamp.

## Step 3: Invoke Ralph Loop

Run the existing plugin command:

```
/ralph-loop $ARGUMENTS
```

Pass through all arguments unchanged. The plugin handles iteration state in `.claude/ralph-loop.local.md`.

## Step 4: On Completion

When the ralph-loop completes its work (completion promise fulfilled or task done), update `.claude/boulder.json` to signal completion:

```json
{
  "plan": "ralph-loop",
  "task": "<original task>",
  "started": "<original timestamp>",
  "status": "completed",
  "finished": "<current UTC timestamp>",
  "mode": "ralph-loop"
}
```

The Stop hook checks boulder.json status -- `completed` means it's safe to stop. Until you update this, the Stop hook will block exit.

## State Conventions

These paths are shared with `/stop-work` and the Stop hook:

| File | Purpose | Lifecycle |
|------|---------|-----------|
| `.claude/boulder.json` | Work-in-progress tracker | Created at loop start, updated to `completed` on finish, cleaned up by `/stop-work` |
| `.claude/ralph-loop.local.md` | Plugin iteration state | Created by ralph-loop plugin, cleaned up by `/stop-work` |

Both files exist while a loop is running. The `/stop-work` skill removes both during cleanup.

Task: $ARGUMENTS
