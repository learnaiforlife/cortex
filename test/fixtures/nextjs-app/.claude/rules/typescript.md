---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
---

# TypeScript Conventions

- Use `interface` for component props and API response shapes
- Use `type` for unions, intersections, and utility types
- Prefer `const` over `let`; never use `var`
- Use `unknown` instead of `any` wherever possible
- Enable strict mode (already configured in tsconfig.json)
- Use explicit return types on exported functions
- Prefer named exports over default exports (except for page components required by Next.js)
- Import React types from `react` (e.g., `import type { FC } from 'react'`)
