# my-nextjs-app

Next.js 14 full-stack application with App Router, Prisma ORM, Stripe payments, and Tailwind CSS.

## Architecture

- `src/app/` - Next.js App Router pages and layouts
- `prisma/` - Database schema and migrations (PostgreSQL via Prisma ORM)
- `.github/workflows/` - GitHub Actions CI pipeline
- `Dockerfile` - Production container (Node 20 Alpine)
- `docker-compose.yml` - Local dev services (PostgreSQL 16, Redis 7)

## Development Commands

```bash
npm run dev          # Start Next.js dev server (port 3000)
npm run build        # Production build (next build)
npm start            # Run production server
npm test             # Run Vitest test suite (vitest run)
npm run lint         # Lint with ESLint (next lint)
npx prettier --check .   # Check formatting
npx prettier --write .   # Fix formatting
```

## Database Commands

```bash
docker compose up -d              # Start PostgreSQL + Redis
npx prisma migrate dev            # Create and apply migration
npx prisma generate               # Regenerate Prisma client
npx prisma db push                # Push schema without migration
npx prisma studio                 # Visual database browser
```

## Key Conventions

- TypeScript strict mode enabled (`tsconfig.json`)
- App Router for all pages (no Pages Router)
- Server Components by default; add `"use client"` only when needed
- Prisma for all database access -- never raw SQL
- Tailwind CSS for styling -- no CSS modules or styled-components
- Vitest for unit/integration tests, Playwright for E2E
- Environment variables via `env("DATABASE_URL")` in Prisma, `process.env` elsewhere

## Important Patterns

- Database connection string comes from `DATABASE_URL` environment variable
- Stripe keys must use `process.env.STRIPE_SECRET_KEY` -- never hardcode
- Docker Compose services: `db` (postgres:16 on 5432), `redis` (redis:7 on 6379)
- CI runs `npm ci && npm test` on every push via GitHub Actions

## Things to Avoid

- Do not use Pages Router (`pages/` directory) -- this project uses App Router only
- Do not write raw SQL -- use Prisma queries
- Do not hardcode database URLs, Stripe keys, or any credentials
- Do not modify `prisma/schema.prisma` without running `npx prisma generate` after
- Do not commit `.env` files
