# Safety Rules

## Protected Files

Do not modify without explicit user confirmation:
- `prisma/schema.prisma` -- database schema changes require migration planning
- `next.config.js` -- build configuration affects all environments
- `tsconfig.json` -- TypeScript config affects type checking project-wide
- `docker-compose.yml` -- infrastructure changes affect local dev setup
- `.github/workflows/ci.yml` -- CI changes affect the entire team

## Forbidden Operations

- Never hardcode API keys, database URLs, or Stripe secrets in source files
- Never commit `.env` files or files containing credentials
- Never run `rm -rf` on `src/`, `prisma/`, or `node_modules/` without confirmation
- Never force-push to the main branch
- Never drop database tables without explicit confirmation
- Never modify Prisma schema without running `npx prisma generate` afterward

## Required Checks

- After modifying `prisma/schema.prisma`: run `npx prisma generate`
- After modifying any TypeScript file: verify with `npx tsc --noEmit`
- After modifying `package.json`: run `npm install`
- Before creating a PR: run `npm test && npm run lint`
