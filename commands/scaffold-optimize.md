---
description: "Optimize existing skills using evals, freshness checks, or quality measurement. Usage: /scaffold-optimize [auto-improve]"
---

If `$ARGUMENTS` is **"auto-improve"**, invoke the scaffold skill with: optimize auto-improve

Otherwise, invoke the scaffold skill with: optimize

**optimize** mode inventories your existing skills, checks evals, verifies CLAUDE.md freshness, and audits MCP configs. Produces an optimization report with actions.

**optimize auto-improve** mode measures scaffold quality across test fixtures, identifies the weakest scoring dimension, then dispatches the skill-improver agent to make a targeted edit to SKILL.md. After each edit, it re-measures and keeps only changes that improved the score. The measurement step is handled by `auto-improve.sh`; the editing is done by the skill-improver agent within this Claude session.
