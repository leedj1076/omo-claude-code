---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
---

When working with test files:
- Use describe/it blocks for organization.
- One assertion focus per test when possible.
- Mock at the boundary (external services, DB), not internal functions.
- Test behavior, not implementation details.
- Name tests as "should [expected behavior] when [condition]".
- Never delete failing tests to make the suite pass. Fix the code.
- Prefer real implementations over mocks when practical.
