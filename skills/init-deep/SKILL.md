---
name: init-deep
description: Generate hierarchical CLAUDE.md files throughout the project for directory-specific context
allowed-tools: [Read, Write, Glob, Grep, Bash, Agent]
user-invocable: true
argument-hint: "[target-directory] [--max-depth=N]"
---

Generate CLAUDE.md files throughout the project to give Claude directory-specific context.

## Step 1: Scan Directory Structure

```
Glob("$ARGUMENTS/**/*") or Glob("./**/*") if no target specified
```

Skip these directories entirely:
`node_modules/`, `.git/`, `build/`, `dist/`, `.next/`, `__pycache__/`, `Pods/`, `DerivedData/`, `.build/`, `.gradle/`, `target/`, `vendor/`, `.venv/`, `venv/`

## Step 2: Score Each Directory

Apply this scoring matrix:

| Criterion | Points |
|---|---|
| Has source code files (.ts, .py, .swift, .go, .rs, etc.) | +5 |
| Has >10 files | +3 |
| Has its own package.json / Cargo.toml / go.mod / Package.swift | +5 |
| Is a distinct domain boundary (separate concern from parent) | +5 |
| Root directory | +999 (always gets CLAUDE.md) |

Decision:
- Score >15: create CLAUDE.md
- Score 8-15: create if distinct domain
- Score <8: skip

## Step 3: Analyze Each Qualifying Directory

For each directory that scored high enough:

### 3a. Read Key Files
Read the 3-5 most important files to understand purpose, conventions, patterns.

### 3b. Generate LSP Codemap (if LSP available)
Use LSP to build a structural map of the directory:
```
LSP document_symbols on the main entry file (index.ts, mod.rs, __init__.py, etc.)
LSP workspace_symbols filtered to this directory path
```

This produces an API surface map:
- Exported functions/classes with signatures
- Public types/interfaces
- Entry points and their dependencies

### 3c. Trace Integration Points
```
Grep for imports FROM this directory across the project
Grep for imports TO external modules within this directory
```

### 3d. Understand:
1. **Module purpose**: What does this directory do?
2. **Key files**: Which files are most important and why?
3. **Public API**: What does this module export? (from LSP codemap)
4. **Conventions**: Naming patterns, export styles, test placement
5. **Patterns**: Common code patterns used here
6. **Integration**: Who imports from here? What does it import? (from Grep)
7. **Build/test**: Any directory-specific commands?

Use `Agent(librarian)` for external library documentation if needed.

## Step 4: Write CLAUDE.md Files

In each qualifying directory, write a CLAUDE.md with:

```markdown
# {Directory Name}

{1-2 sentence purpose}

## Key Files
- `file.ts` — {role}

## Conventions
- {naming pattern, export style, etc.}

## Patterns
- {common patterns used here}

## Integration
- Imports from: {other modules}
- Imported by: {other modules}

## Build/Test
- `{command}` — {what it does}
```

Keep each CLAUDE.md concise (30-60 lines). Dense and specific beats long and vague.

## Step 5: Report

```
CLAUDE.md Generation Complete

Created: [N] files
Skipped: [M] directories (below threshold)
Root: ./ (always created)
Directories: [list of paths where CLAUDE.md was created]
```

Target: $ARGUMENTS
