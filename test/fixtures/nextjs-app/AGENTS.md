# my-nextjs-app — Codex Agent Configuration

## Project Overview

Next.js 14 full-stack application with App Router, Prisma ORM, Stripe payments, and Tailwind CSS. TypeScript strict mode, Vitest for testing, Playwright for E2E.

## Architecture

```
src/app/              — Next.js App Router pages and layouts
prisma/               — Database schema and migrations (PostgreSQL via Prisma ORM)
.github/workflows/    — GitHub Actions CI pipeline
Dockerfile            — Production container (Node 20 Alpine)
docker-compose.yml    — Local dev services (PostgreSQL 16, Redis 7)
next.config.js        — Next.js configuration
tailwind.config.js    — Tailwind CSS configuration
tsconfig.json         — TypeScript strict mode config
package.json          — Dependencies and scripts
```

## Development Commands

```bash
# Setup
npm install

# Run
npm run dev              # Start Next.js dev server (port 3000)
npm run build            # Production build (next build)
npm start                # Run production server

# Test
npm test                 # Run Vitest test suite (vitest run)

# Lint & Format
npm run lint             # ESLint (next lint)
npx prettier --check .   # Check formatting
npx prettier --write .   # Fix formatting

# Database
docker compose up -d                # Start PostgreSQL + Redis
npx prisma migrate dev              # Create and apply migration
npx prisma generate                 # Regenerate Prisma client
npx prisma db push                  # Push schema without migration
npx prisma studio                   # Visual database browser

# Docker
docker build -t my-nextjs-app .
docker compose up
```

## Dependencies

- **Runtime**: next@14, react@18, @prisma/client@5, tailwindcss@3, stripe@14
- **Dev**: typescript@5, vitest@2, @playwright/test@1, eslint@9, prettier@3

## Conventions

- TypeScript strict mode enabled
- App Router for all pages (no Pages Router)
- Server Components by default; add `"use client"` only when needed
- Prisma for all database access — never raw SQL
- Tailwind CSS for styling — no CSS modules or styled-components
- Vitest for unit/integration tests, Playwright for E2E
- Environment variables via `env("DATABASE_URL")` in Prisma, `process.env` elsewhere

## Testing

- Framework: Vitest (unit/integration), Playwright (E2E)
- Run: `npm test` or `npx vitest run`
- CI runs `npm ci && npm test` on every push via GitHub Actions
- Use `npx playwright test` for E2E tests

## Safety Rules

- Never hardcode database URLs, Stripe keys, or any credentials
- Never use Pages Router (`pages/` directory) — App Router only
- Never write raw SQL — use Prisma queries
- Never modify `prisma/schema.prisma` without running `npx prisma generate`
- Never commit `.env` files
- Never force-push to main

## Gotchas

- Database connection string comes from `DATABASE_URL` environment variable
- Stripe keys must use `process.env.STRIPE_SECRET_KEY`
- Docker Compose services: `db` (postgres:16 on 5432), `redis` (redis:7 on 6379)
- Tailwind config extends default theme — check `tailwind.config.js` before adding utilities

## Agent Instructions

When working on this project:
1. Always run `npm test` after modifying source code
2. Always run `npm run lint` after modifying TypeScript files
3. Run `npx prisma generate` after any schema changes
4. Use `gh` CLI for GitHub operations (PR creation, issue management)
5. Use `${ENV_VAR}` syntax for any credentials or connection strings
6. Prefer Server Components — only add `"use client"` when hooks or browser APIs are needed
