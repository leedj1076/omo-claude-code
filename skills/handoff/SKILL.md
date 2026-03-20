---
name: handoff
description: Create a detailed context summary for continuing work in a new session
allowed-tools: [Read, Write, Bash, Glob, Grep, TaskList]
user-invocable: true
argument-hint: "[goal or context]"
---

Create a handoff document summarizing the current session for future continuation.

## Step 1: Gather Context (run in parallel)

```
git diff --stat
git log --oneline -10
git status --short
git stash list
```

Also check TaskList for any remaining tasks.

## Step 1.5: Read Boulder State and Plan Progress

Before writing the handoff document, gather plan context:

If `.claude/boulder.json` exists:
- Read plan path from `active_plan` field; fall back to `plan` field
- Read plan name from `plan_name` field; fall back to basename of plan path
- Read status, progress fields, current_task, session_ids

If a plan file is referenced:
- Count `- [ ]` and `- [x]` top-level checkboxes to get live progress
- Extract next 3 unchecked tasks as "Immediate Next Steps"

If `.claude/notepads/{plan-name}/` exists:
- Read learnings.md and decisions.md to summarize key wisdom

## Step 2: Write Handoff Document

Write to `.claude/handoff.md`:

```markdown
# Session Handoff
> Generated: {date}

## Goal
$ARGUMENTS (or inferred from session context)

## Accomplished
- [specific file:change pairs — what was done]

## In Progress
- [partially completed work with exact file paths and line numbers]
- [what state it's in, what's left]

## Blockers
- [current issues or open questions preventing progress]

## Next Steps
1. [specific action with file path] — [why]
2. [specific action with file path] — [why]
3. [specific action with file path] — [why]

## Decisions Made
- [decision]: [rationale]

## Boulder State (Plan Progress)
[If boulder.json exists, include:]
- Plan: {plan_name} — {percent}% complete ({completed}/{total} tasks)
- Status: {status}
- Current task: {current_task.title}
- Session history: {session_ids}

[If only legacy schema: Plan: {plan} (status: {status}, started: {started})]

## Immediate Next Steps (from plan)
[Next 3 unchecked tasks from the plan file]

## Notepad Wisdom
[Key learnings and decisions from .claude/notepads/{plan-name}/ if it exists]

## Resume Command
To continue this work:
  claude --agent coordinator    # Full orchestration
  /start-work {plan-name}       # Resume from boulder state

## Uncommitted Changes
[git status output]
```

## Step 3: Confirm

Report to user with explicit continuation instructions:

```
Handoff saved to `.claude/handoff.md`

To continue this work:
  claude                          # SessionStart hook auto-injects handoff context
  claude --continue               # Resume the exact session transcript
  claude --resume                 # Pick from recent sessions
  claude --agent coordinator       # Resume orchestrated plan execution
  /start-work                     # Resume from boulder state if plan was in progress
```

Goal: $ARGUMENTS
