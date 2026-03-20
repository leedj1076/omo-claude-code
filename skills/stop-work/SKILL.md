---
name: stop-work
description: Cancel all autonomous work - pauses boulder state and cancels ralph-loop
allowed-tools: [Read, Write, Edit, Bash, TaskList, TaskUpdate]
user-invocable: true
argument-hint: "[reason for stopping]"
---

# Stop Work

Cancels all autonomous work mechanisms and signals readiness to stop.

## Step 1: Cancel Ralph Loop

Check if `.claude/ralph-loop.local.md` exists in the current project directory.

- If it exists: read it to extract the current iteration number, then delete it:
  ```bash
  rm .claude/ralph-loop.local.md
  ```
- Report: `Cancelled Ralph loop (was at iteration N)`
- If absent: report `Ralph loop not running`

## Step 2: Pause Boulder State

Read `.claude/boulder.json` if it exists.

Handle BOTH the enriched schema (with `active_plan`, `plan_name`, `progress`) and the legacy schema (with just `plan`, `started`):

- Read plan path from `active_plan` field; fall back to `plan` field
- Read plan name from `plan_name` field; fall back to basename of plan path

**Progress snapshot** (show before pausing):
- If plan file exists, count `- [ ]` (unchecked) and `- [x]` (checked) top-level checkboxes to calculate live progress
- If enriched schema: display "Pausing at {percent}% ({completed}/{total} tasks). Current task: {current_task.title or first unchecked checkbox text}"
- If legacy schema: display "Pausing plan: {plan name}"

**Update boulder.json**:
- If it exists AND `status` is `in_progress` or `paused`:
  - Set `status` to `"paused"`
  - Add `paused_at` field with current UTC timestamp (ISO 8601)
  - If `$ARGUMENTS` is non-empty, add `paused_reason` field with its value
  - If `session_ids` array exists, append current session ID if not already present (skip gracefully if old schema has no session_ids)
  - Preserve all other fields including BOTH legacy aliases (`plan`, `started`) and new fields — don't remove anything
  - Use Edit tool for targeted changes
- Report: "Paused boulder state. Plan: [plan name], progress: {X}/{Y} tasks"
- If `boulder.json` is absent or status is already not `in_progress`: report `No active boulder state`

**Do NOT delete `boulder.json`** — preserve state so work can be resumed later.

**Resume instructions**: After displaying progress, also display: "To resume: /start-work {plan_name}"

## Step 3: Pause In-Progress Tasks

Use `TaskList` to find all tasks with status `in_progress`.

- For each task found: use `TaskUpdate` to set its status to `pending` (TaskUpdate doesn't support a `paused` status, so `pending` resets the task for potential resume)
- Report: `Reset N in-progress task(s) to pending`
- If no in-progress tasks found: report `No in-progress tasks`

## Step 4: Signal Ready to Stop

Output a single summary line:

```
Work stopped. [ralph-loop status]. [boulder status]. [N tasks reset]. Safe to stop.
```

The Stop hook in settings.json checks `boulder.json` status — `paused` allows stopping (unlike `in_progress` which blocks it). By setting status to `paused` in Step 2, the hook will no longer prevent exit.

## State Files Reference

| File | Action | Why |
|------|--------|-----|
| `.claude/ralph-loop.local.md` | Delete | Cancels the loop iteration — plugin won't continue |
| `.claude/boulder.json` | Pause (set status to `paused`) | Preserves work context for resume while unblocking the Stop hook |

Task: $ARGUMENTS
