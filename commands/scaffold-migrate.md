---
description: "Run migration workflow. Usage: /scaffold migrate [--from X --to Y | --auto-detect | --status | --validate | --next | --cleanup | --rollback]"
---

Invoke the scaffold skill with migration mode: migrate $ARGUMENTS

This detects active migrations in the target repository, assesses risk, helps select a strategy, and generates a phased MIGRATION-PLAN.md with migration-specific AI agents, rules, and skills.

Sub-commands:
- `/scaffold migrate` — auto-detect migrations and generate full setup
- `/scaffold migrate --from django --to fastapi` — explicit migration type
- `/scaffold migrate --status` — show migration progress
- `/scaffold migrate --validate` — validate current phase completion
- `/scaffold migrate --next` — advance to next phase
- `/scaffold migrate --cleanup` — remove migration artifacts after completion
- `/scaffold migrate --rollback` — show rollback instructions for current phase
