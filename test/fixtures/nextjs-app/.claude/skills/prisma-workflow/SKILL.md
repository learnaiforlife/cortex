---
name: prisma-workflow
description: "Manage Prisma schema changes, migrations, and client generation. Use when adding models, updating schema, creating migrations, or modifying the database."
allowed-tools: Read, Write, Edit, Bash, Glob
---

# Prisma Workflow

## Steps

1. Read current `prisma/schema.prisma` before making any changes.
2. Make schema modifications (add/update models, relations, indexes).
3. Run `npx prisma generate` to update the Prisma client.
4. Run `npx prisma migrate dev --name <descriptive-name>` to create and apply migration.
5. Verify migration was applied: `npx prisma migrate status`.
6. Update any affected API routes or service files that use the changed models.
7. Run `npm test` to verify nothing broke.

## Rules

- Always read the existing schema before modifying it.
- Use descriptive migration names (e.g., `add-user-profile`, `add-order-items-table`).
- Never use `npx prisma db push` in production -- always use migrations.
- After schema changes, always regenerate the client before writing code that uses new models.
- Database connection requires `DATABASE_URL` environment variable.
