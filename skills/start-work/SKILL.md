---
name: start-work
description: Start executing an implementation plan by finding it and working through tasks
allowed-tools: [Read, Glob, Write, Edit, Bash, Agent, TaskCreate, TaskUpdate, TaskList]
user-invocable: true
argument-hint: "[plan-name or path]"
---

Execute an implementation plan step by step.

## Step 1: Find the Plan

If `$ARGUMENTS` specifies a path or name:
- Try to match against `.claude/plans/*.md` by name (e.g. "omo-convergence" matches "omo-convergence.md")
- If not found as a relative name, treat as absolute path and Read directly

If no argument:
- `Glob(".claude/plans/*.md")` to list available plans, sorted by modification time (newest first)
- For each plan, show title, date, and progress if boulder.json references it
- Ask which to execute

## Step 2: Check for Existing Work State

Read `.claude/boulder.json` if it exists.

If boulder.json exists and `status` is `"in_progress"` or `"paused"`:
- Read plan path from `active_plan` field; fall back to `plan` field if missing
- Read plan name from `plan_name` field; fall back to basename of plan path
- Count `- [ ]` (unchecked) and `- [x]` (checked) top-level checkboxes in the plan to calculate live progress
- Extract current task: from `current_task.title` if present, else find first unchecked checkbox text
- Show: "Found work in progress: {plan_name} — {completed}/{total} tasks ({percent}%). Current: {task_title}. Resuming from current task."
- Skip to Step 5, starting from `current_task.key`

If no boulder.json or status is `"completed"`: create enriched boulder state (Step 3).

## Step 3: Create Enriched Boulder State

Read the plan file. Count top-level `- [ ]` and `- [x]` checkboxes (ignore nested ones under QA Scenarios, Acceptance Criteria, Evidence sections).

Create `.claude/boulder.json` with this full schema:

```json
{
  "active_plan": "/absolute/path/to/plan.md",
  "plan_name": "plan-name",
  "started_at": "2026-03-20T00:00:00Z",
  "session_ids": [],
  "agent": "coordinator",
  "status": "in_progress",
  "worktree_path": null,
  "task_sessions": {},
  "teammate_sessions": {},
  "progress": {
    "total": 10,
    "completed": 3,
    "remaining": 7,
    "percent": 30
  },
  "current_task": {
    "key": "todo:1",
    "label": "1",
    "title": "Task title here"
  },
  "plan": "/absolute/path/to/plan.md",
  "started": "2026-03-20T00:00:00Z"
}
```

Field notes:
- `active_plan` and `plan`: BOTH set to the same absolute path. `plan` is a legacy alias for backward compatibility with existing consumers (ralph-loop skill, stop-work skill, post-compact.sh).
- `started_at` and `started`: BOTH set to the same ISO timestamp. `started` is a legacy alias.
- `session_ids`: flat array accumulating all session IDs that participate. Kept for lineage tracking.
- `task_sessions`: empty map `{}` on init. SubagentStop hook is the SOLE producer — maps `task_key -> {agent_id, agent_type, updated_at}`. Do NOT manually write this.
- `teammate_sessions`: empty map `{}` on init. TeammateIdle/TaskCompleted hooks maintain it — maps `session_id -> {task_key, teammate_name, updated_at, status}`. Do NOT manually write this.
- `worktree_path`: set to the git worktree path if the agent is working in an isolated worktree; `null` otherwise.
- `progress.percent`: round to nearest integer. Use `floor(completed / total * 100)`.
- `current_task.key`: format is `"todo:N"` for the Nth task, `"final-wave:fN"` for final verification tasks.
- `current_task.label`: the number as a string (e.g., `"1"`, `"2"`).

Always write BOTH the canonical OmO fields (`active_plan`, `started_at`) AND the legacy aliases (`plan`, `started`) with identical values. Existing consumers read only the legacy fields.

## Step 4: Parse Tasks

Read the plan file. Identify all top-level `- [ ]` task checkboxes from the `## Tasks` section (and `## Final Verification Wave` if present). Ignore nested checkboxes under Acceptance Criteria, QA Scenarios, Evidence, Definition of Done.

Identify wave assignments and dependencies from task descriptions.

## Step 5: Execute Tasks

For each task wave (parallel within wave, sequential between waves):

1. Create `TaskCreate` entries for progress tracking
2. For each task in the wave:
   - `TaskUpdate(status="in_progress")`
   - Route to the appropriate agent:
     - **Most tasks** → `Agent(worker)` — DEFAULT executor (Sonnet)
     - Trivial (1-2 files, simple change) → `Agent(quick-fix)`
     - Deep autonomous work only → `Agent(forge)` — SPECIALIST, not default
     - Research needed → `Agent(librarian)`
     - Architecture question → `Agent(oracle)`
   - After agent completes: verify the result
   - Update plan checkbox: `- [ ]` → `- [x]`
   - Recalculate progress from checkboxes: recount `- [ ]` and `- [x]`, update `boulder.json` fields:
     - `progress.completed`, `progress.remaining`, `progress.percent`
     - `current_task` (next unchecked task, or mark complete if all done)
   - `TaskUpdate(status="completed")`
3. After all tasks in wave: run verification before proceeding to next wave

## Step 6: Progress Update on Checkbox Change

After EACH task completion (checkbox `- [ ]` → `- [x]`):
1. Recount all top-level checkboxes in the plan file
2. Update boulder.json `progress` object with new totals
3. Update `current_task` to the next unchecked task (or remove if all done)
4. Keep both `active_plan`+`plan` and `started_at`+`started` in sync (same values always)

## Step 7: Completion

After all tasks:
1. Set boulder.json `status` to `"completed"` and add `"finished_at": "<ISO timestamp>"`
2. Keep legacy `"plan"` and `"started"` fields in place for backward compatibility
3. Report:
   ```
   PLAN COMPLETE: <plan-name>
   Tasks: N/N completed
   Files modified: [list]
   ```

> **Canonical execution path**: `claude --agent coordinator` is the preferred way to execute plans. Coordinator provides full orchestration with plan-scoped notepad wisdom, parallel agent spawning, 6-section delegation prompts, and mandatory verification after every delegation. Use `/start-work` only for quick 1-5 task plans where Coordinator overhead isn't justified.

Plan: $ARGUMENTS
