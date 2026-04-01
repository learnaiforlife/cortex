---
description: "Generate AI dev setup for a project. Usage: /scaffold [github-url-or-path]"
---

Invoke the scaffold skill with: $ARGUMENTS

This will analyze the target repository and generate a complete AI development setup including CLAUDE.md, agents, skills, rules, MCP servers, and hooks for Claude Code, Cursor, and Codex.

Examples:
- `/scaffold` -- scaffold the current directory
- `/scaffold https://github.com/user/repo` -- scaffold a GitHub repo
- `/scaffold /path/to/local/repo` -- scaffold a local repo
