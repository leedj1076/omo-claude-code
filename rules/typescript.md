---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

When working with TypeScript files:
- Use strict types. Avoid `any` — use `unknown` with type guards instead.
- Prefer interfaces over type aliases for object shapes.
- Use discriminated unions for variant types.
- No `@ts-ignore` or `@ts-expect-error` without a comment explaining why.
- Prefer `const` assertions for literal types.
- Use `satisfies` operator for type-safe object literals when appropriate.
