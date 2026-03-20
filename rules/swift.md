---
paths:
  - "**/*.swift"
---

When working with Swift files:
- Use value types (struct) over reference types (class) unless identity semantics are needed.
- Prefer `let` over `var`. Mutability should be intentional.
- Use Swift naming conventions: lowerCamelCase for functions/properties, UpperCamelCase for types.
- Use guard for early returns. Avoid deeply nested if-let chains.
- Prefer protocol extensions for default implementations.
- Use async/await over completion handlers for new code.
- Mark access control explicitly (private, internal, public).
