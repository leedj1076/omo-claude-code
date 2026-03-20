---
name: refactor
description: Intelligent refactoring with LSP analysis, reference tracking, and test verification
allowed-tools: [LSP, Grep, Glob, Read, Edit, Bash, Agent, Write]
user-invocable: true
argument-hint: "<target> [--scope=file|module|project] [--strategy=safe|aggressive]"
---

Perform an intelligent, verified refactoring. Follow this 6-phase process strictly.

## Phase 1: Intent Gate

Parse `$ARGUMENTS` to determine:
- **Target**: symbol name, file path, or pattern to refactor
- **Scope**: file (default), module, or project
- **Strategy**: safe (default) or aggressive
- **Type**: rename, extract, inline, restructure, or migrate

## Phase 2: Codebase Analysis (parallelize everything)

Launch ALL of these simultaneously:
1. `LSP goto_definition` on the target symbol
2. `LSP find_references` for ALL usages across the workspace
3. `Grep` for string-based usage patterns LSP might miss (dynamic access, string interpolation, comments)
4. `Bash("ast-grep --pattern '<target_pattern>' --lang <lang>")` for structural pattern matches across the codebase (if ast-grep installed)
5. `Glob` to find related test files (e.g., `**/target*.test.*`)
6. `LSP diagnostics` on affected files to establish error baseline

If scope=project: use `Agent(oracle)` for architectural impact assessment.

## Phase 3: Build Codemap

From Phase 2 results, produce an **impact matrix**:

| File | Lines Affected | Risk | Reason |
|---|---|---|---|
| `path/to/file.ts` | 15-30 | HIGH | Core type definition, 12 importers |
| `path/to/other.ts` | 42 | LOW | Single usage, test file |

Include:
- Dependency order: leaf files first, root files last
- Files with pre-existing errors (flag, don't fix)
- Dynamic/string access patterns that LSP missed (from Grep/ast-grep)
- Blast radius estimate: number of files, lines, and callers

If blast radius > 20 files: warn user and confirm before proceeding.

## Phase 4: Test Assessment

1. Detect test framework (jest, vitest, pytest, cargo test, go test, etc.)
2. Identify which tests cover the target code
3. Run tests to establish baseline — **must pass before refactoring**
4. If tests fail: STOP and report. Do not refactor broken code.

## Phase 5: Execute

If >5 files affected AND strategy=safe:
- Create a plan in `.claude/plans/refactor-{target}.md` first
- Use `Agent(reviewer)` to validate the plan

### TDD Workflow (when test infrastructure exists)

For each change batch, follow RED-GREEN-REFACTOR:
1. **RED**: If the refactoring changes behavior (not just structure), write a failing test that captures the NEW expected behavior
2. **GREEN**: Make the minimal refactoring change to pass the test
3. **REFACTOR**: Clean up while keeping tests green
4. **CHECKPOINT**: `git stash` the working state before the next batch — enables instant rollback

### Execution Order

Make changes in dependency order (leaf → root):
1. Rename/modify in the deepest dependency first
2. Work upward through the call chain
3. After each batch: run targeted tests for changed files
4. If any test fails: `git stash pop` to rollback, analyze, try different approach

For renames: prefer `LSP rename` when available (workspace-wide, type-aware).
For structural transforms: use `Bash("ast-grep --rewrite '<new>' --pattern '<old>' --lang <lang> <path>")` for bulk changes across many files.
For single-file edits: use `Edit` with careful `old_string` matching.

## Phase 6: Verify

1. Run the FULL test suite — all must pass
2. `LSP diagnostics` on ALL changed files — zero new errors
3. Compare before/after error counts
4. Report:
   - Files changed: [list with summary of each change]
   - Tests: [X passed, Y total]
   - Errors: [before] → [after]
   - Status: COMPLETE or ISSUES FOUND

Target: $ARGUMENTS
