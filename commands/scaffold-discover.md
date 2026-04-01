---
description: "Scan your machine and generate multi-level AI setup (user-level + per-project). Usage: /scaffold-discover [dirs]"
---

Invoke the scaffold skill with: discover $ARGUMENTS

This scans your development environment for all projects, tools, services, and integrations,
then generates a cohesive AI setup at both user-level (~/.claude/) and per-project level.

Everything runs locally. Nothing leaves your machine.

Examples:
- `/scaffold-discover`                           -- scan default directories
- `/scaffold-discover ~/work ~/personal`         -- scan custom directories
- `/scaffold-discover --user-level-only`          -- generate only user-level setup
