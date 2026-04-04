---
description: "Run migration workflow. Usage: /scaffold migrate [--from X --to Y | --auto-detect | --status | --validate | --next | --cleanup | --rollback]"
---

Invoke the scaffold skill with migration mode: migrate $ARGUMENTS

This detects active migrations in the target repository, assesses risk, helps select a strategy, and generates a phased MIGRATION-PLAN.md with migration-specific AI agents, rules, and skills.

## Sub-commands

### Fully automated (scripts + agents)
- `/scaffold migrate` — auto-detect migrations and generate full setup
- `/scaffold migrate --from django --to fastapi` — explicit migration type
- `/scaffold migrate --status` — show migration progress (reads MIGRATION-PLAN.md)
- `/scaffold migrate --validate` — validate current phase completion criteria

### AI-assisted (LLM reads plan and edits it; no dedicated script)
- `/scaffold migrate --next` — validate current phase, then advance to next if it passes
- `/scaffold migrate --cleanup` — list and remove migration artifacts after completion
- `/scaffold migrate --rollback` — display rollback instructions for current phase

> **Note:** `--next`, `--cleanup`, and `--rollback` are orchestrated by the LLM
> reading MIGRATION-PLAN.md — they do not have dedicated scripts. The LLM edits
> the plan file directly. Results depend on the plan content generated during
> the initial `/scaffold migrate` setup.
