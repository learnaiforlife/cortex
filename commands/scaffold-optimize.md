---
description: "Optimize existing skills using evals, freshness checks, or auto-improvement. Usage: /scaffold-optimize [path|auto-improve]"
---

If `$ARGUMENTS` is **"auto-improve"**, invoke the scaffold skill with: optimize auto-improve

Otherwise, invoke the scaffold skill with: optimize $ARGUMENTS

**optimize** mode inventories your existing skills, checks evals, verifies CLAUDE.md freshness, and audits MCP configs. Produces an optimization report with actions.

**optimize auto-improve** mode applies the autoresearch pattern: it measures scaffold quality across test fixtures, dispatches the skill-improver agent to edit SKILL.md, re-measures, and keeps only improvements. This is autonomous skill prompt engineering.
