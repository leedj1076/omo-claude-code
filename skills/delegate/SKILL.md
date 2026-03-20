---
name: delegate
description: Classify a task and route it to the optimal specialist agent
allowed-tools: [Agent]
user-invocable: true
disable-model-invocation: true
argument-hint: "describe the task to delegate"
---

Classify the following task into a category, select the agent, inject the category appendix, and delegate using the 6-section format.

## Step 1: Extract True Intent

Map the surface request to the true intent before routing:
- "explain X" = research (but if X is broken, true intent is fix)
- "look into Y" = investigate AND resolve
- "what do you think about Z" = evaluate, decide, act

## Step 2: Classify Into a Category (ZERO TOLERANCE — pick exactly one)

| Task Domain | MUST Use Category |
|---|---|
| UI, styling, animations, layout, design, CSS | `visual-engineering` |
| Hard logic, architecture decisions, algorithms | `ultrabrain` |
| Autonomous research + end-to-end implementation | `deep` |
| Single-file typo, trivial config change (<3 files) | `quick` |
| Prose, docs, READMEs, articles | `writing` |
| Creative/artistic work | `artistry` |
| Moderate unclassifiable work (few files) | `unspecified-low` |
| Substantial unclassifiable work (multiple systems) | `unspecified-high` |

## Step 3: Apply Category Routing and Prompt Appendix

### Category → Agent → Model

| Category | Agent | Model | Why |
|---|---|---|---|
| `quick` | `quick-fix` | haiku | Cheap, fast, trivial changes |
| `deep` | `forge` | opus | Sustained autonomous work needs max capability |
| `visual-engineering` | `forge` or `worker` | opus/sonnet | Design system analysis needs deep reading |
| `ultrabrain` | `oracle` | opus | Architecture decisions need highest reasoning |
| `writing` | `worker` | sonnet | Prose doesn't need opus |
| `artistry` | `forge` or `worker` | opus/sonnet | Creative work benefits from capability |
| `unspecified-low` | `worker` | sonnet | Default executor, cost-effective |
| `unspecified-high` | `forge` | opus | Substantial effort across systems |

### Category Prompt Appendices (prepend to delegation prompt)

**quick**:
> EXHAUSTIVELY EXPLICIT instructions. MUST DO / MUST NOT DO / EXPECTED OUTPUT sections are mandatory. The executing agent uses a smaller model — leave NOTHING to interpretation. If your prompt lacks this structure, REWRITE IT before delegating.

**deep**:
> You are NOT an interactive assistant. You are an autonomous problem-solver. BEFORE making ANY changes: silently explore the codebase extensively (5-15 minutes of reading is normal). Read related files, trace dependencies, understand the full context. DO NOT ask clarifying questions. Minimal status updates — only on phase transitions and blockers. Do not stop until 100% complete and verified.

**visual-engineering**:
> DESIGN SYSTEM WORKFLOW MANDATE. Phase 1: ANALYZE the design system (search for tokens, themes, shared components — read 5-10 existing UI components MINIMUM). Phase 2: No system? BUILD ONE first (color palette, typography scale, spacing scale, component primitives). Phase 3: Build WITH the system (every color uses a token, every spacing uses the scale, never one-off styles). Phase 4: VERIFY (zero hardcoded magic numbers, visual consistency across old and new).

**ultrabrain**:
> Deep reasoning mode. BEFORE writing ANY code, SEARCH the existing codebase to find similar patterns/styles. Bias toward simplicity. One clear recommendation with effort estimate (Quick/Short/Medium/Large). Response format: bottom line (2-3 sentences), action plan (numbered steps), risks and mitigations.

**writing**:
> Apply ~/.claude/rules/anti-slop.md rules (NON-NEGOTIABLE). No em dashes. Banned word list is in that file. Use contractions naturally. Vary sentence length. No consecutive sentences starting with the same word. No filler openings. Write like a human.

**artistry**:
> Push far beyond conventional boundaries. Explore radical, unconventional directions. Surprise and delight. Rich detail and vivid expression. Break patterns deliberately when it serves the creative vision. Balance novelty with coherence.

**unspecified-low**:
> PROVIDE CLEAR STRUCTURE: enumerate required actions, state forbidden actions, define concrete success criteria.

**unspecified-high**:
> PROVIDE CLEAR STRUCTURE: enumerate required actions, state forbidden actions, define concrete success criteria.

## Step 4: Construct Delegation Prompt (6-Section Format — MANDATORY)

Every delegation prompt MUST contain all 6 sections. Under 30 lines = too short, rewrite:

```
## TASK
[what to do — specific, obsessively detailed]

## EXPECTED OUTCOME
- Files created/modified: [exact paths]
- Functionality: [exact behavior]
- Verification: [command that proves it works]

## REQUIRED APPROACH
[tools to use, patterns to follow, order of operations, references to read]

## MUST DO
[non-negotiable requirements]

## MUST NOT DO
[explicit scope limitations and forbidden actions]

## CONTEXT
[relevant codebase info, patterns discovered, inherited wisdom from notepads]
```

For `quick-fix` (haiku model — leave NOTHING to interpretation):
- State exact file, exact line, exact change
- EXPECTED OUTPUT must be a concrete string or command

For `worker` (DEFAULT — clear and scoped):
- Reference specific files and patterns to follow
- Include "Inherited Wisdom" from `.claude/notepads/` if available

For `forge` (SPECIALIST — sustained autonomous work):
- All 6 sections required, substantial detail in each

## Step 5: Delegate

Invoke the selected agent with the category appendix prepended to the 6-section prompt.

Task: $ARGUMENTS
