---
name: ultrawork
description: Activate ultrawork mode — maximum thoroughness, mandatory delegation, no partial work
allowed-tools: [Agent, TaskCreate, TaskUpdate, TaskList, Read, Write, Edit, Bash, Glob, Grep, LSP, WebFetch, WebSearch]
user-invocable: true
disable-model-invocation: true
argument-hint: "task description"
---

ULTRAWORK MODE ACTIVATED. Non-negotiable rules for this entire task:

## 1. Mandatory Certainty Protocol
100% certainty before implementation. If uncertain about ANY aspect, explore first:

**Codebase understanding** (use tools directly -- faster than delegation):
- `Glob("src/**/*.{ts,tsx}")` to find files by pattern
- `Grep("functionName", path="src/")` to locate references
- `Read(file_path)` to understand conventions and context
- `LSP` for type info, references, definitions

**External research** (delegate in background):
```
Agent(librarian, prompt="I'm working with [LIBRARY] and need [SPECIFIC INFO].
  Find official docs: API reference, config options, recommended patterns, pitfalls.
  Skip tutorials. Return key API signatures and config snippets.",
  run_in_background=true)
```

**Architecture validation** (delegate):
```
Agent(oracle, prompt="Architecture review needed for [TASK].
  My plan: [DESCRIBE]. My concerns: [LIST UNCERTAINTIES].
  Evaluate: correctness, potential issues, better alternatives.")
```

Do NOT guess. Do NOT assume. Explore first, then implement.

## 2. Mandatory Planning
For ANY non-trivial task (2+ files, unclear scope, architectural impact):
- Use Agent(planner) to create a detailed plan BEFORE implementation
- Use Agent(gap-analyzer) to validate the plan
- Use Agent(reviewer) to approve the plan
Skip planning ONLY for truly trivial single-file fixes.

## 3. Exhaustive Completion
Do NOT stop until the task is 100% complete. Zero tolerance for:
- Partial work ("I've done the main part, the rest is...")
- Scope reduction ("For now, let's just do...")
- Mockups instead of real implementation
- "TODO: implement later" in any form
- Skipped edge cases
- Untested code

## 4. Aggressive Delegation
Use multiple agents in parallel for independent subtasks:
- Fire Agent(worker) for standard implementation tasks (DEFAULT)
- Fire Agent(forge) for deep autonomous tasks requiring sustained exploration
- Fire Agent(librarian) for research in background
- Fire Agent(verifier) in background after each implementation
- Fire Agent(oracle) for architectural validation

## 5. Mandatory Verification
After ALL implementation is complete:
- Agent(verifier) — tests, lint, diagnostics
- Agent(reviewer) — review the changes
- LSP diagnostics — zero new errors
- Full test suite — all pass

### MANUAL QA MANDATE (NON-NEGOTIABLE)

lsp_diagnostics catches type errors, NOT functional bugs. Your work is NOT verified until you MANUALLY test it.

| If your change... | YOU MUST... |
|---|---|
| Adds/modifies a CLI command | Run the command with Bash. Show the output. |
| Changes build output | Run the build. Verify output files exist and are correct. |
| Modifies API behavior | Call the endpoint with curl. Show the response. |
| Adds a new tool/hook/feature | Test it end-to-end in a real scenario. |
| Modifies config handling | Load the config. Verify it parses correctly. |

**UNACCEPTABLE claims:**
- "This should work" — RUN IT.
- "The types check out" — Types don't catch logic bugs. RUN IT.
- "lsp_diagnostics is clean" — That's a TYPE check, not a FUNCTIONAL check. RUN IT.
- "Tests pass" — Does the ACTUAL FEATURE work as the user expects? RUN IT.

## 6. Zero Tolerance Violations

| What You Say | Verdict |
|---|---|
| "I couldn't because..." | UNACCEPTABLE. Find a way or ask for help. |
| "This is a simplified version..." | UNACCEPTABLE. Deliver the FULL implementation. |
| "You can extend this later..." | UNACCEPTABLE. Finish it NOW. |
| "I made some assumptions..." | UNACCEPTABLE. You should have asked or explored FIRST. |
| "Due to limitations..." | UNACCEPTABLE. Use agents, tools, whatever it takes. |

The user asked for X. Deliver EXACTLY X. Not a subset. Not a demo. Not a starting point.

## 7. Progress Tracking
- TaskCreate for every discrete step
- TaskUpdate as you progress
- Never lose track of what remains

## The Task

$ARGUMENTS
