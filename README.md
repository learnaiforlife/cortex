# Cortex

**The intelligence layer for AI-powered development.**

One command. Any repo. Complete AI setup for Claude Code, Cursor, and Codex.

## What it does

Point it at any GitHub repo or local project:

```
/scaffold https://github.com/your-org/your-project
```

Cortex will:
1. **Deep-analyze** your codebase (architecture, patterns, domain, services)
2. **Recommend official plugins** before generating custom skills
3. **Generate tailored setup** for all three AI coding tools
4. **Review quality** before writing any files

### Generated output (example for a Next.js + Prisma project):

**Claude Code:**
- `CLAUDE.md` -- project-specific context (not a template)
- `.claude/agents/test-engineer.md` -- specialized test agent with your test commands
- `.claude/skills/db-migrate/SKILL.md` -- Prisma migration workflow
- `.claude/rules/nextjs-conventions.md` -- Next.js patterns from YOUR code
- `.mcp.json` -- PostgreSQL + Playwright MCP servers
- `.claude/settings.json` -- auto-lint hooks

**Cursor:**
- `.cursor/rules/*.mdc` -- project context + conventions
- `.cursor/mcp.json` -- MCP servers

**Codex:**
- `AGENTS.md` -- comprehensive agent instructions

**Plugin recommendations:**
- superpowers (TDD, debugging, code review)
- hookify (safety hooks)
- context7 (Next.js + Prisma docs)
- frontend-design (UI components)

## Three Modes

### `/scaffold [repo]` -- Generate
Analyze any repo and generate complete AI setup.

### `/scaffold audit` -- Audit
Scan existing setup for duplicates, stale skills, broken configs.

### `/scaffold optimize` -- Optimize
Run evals on existing skills. A/B test improvements. Auto-fix.

## Install

```bash
git clone https://github.com/learnaiforlife/cortex
cd cortex
./install.sh
```

### Quick start:
```
/scaffold                                    # current directory
/scaffold https://github.com/vercel/next.js  # any GitHub repo
/scaffold /path/to/project                   # local path
/scaffold audit                              # audit existing setup
/scaffold optimize                           # improve existing skills
```

## Why Cortex beats everything else

| Feature | Cortex | Manual Setup | Other tools |
|---------|--------|--------------|-------------|
| Generates for ALL tools | Claude Code + Cursor + Codex | One at a time | Usually one tool |
| AI-powered analysis | Deep code understanding | Manual | Template-based |
| Recommends official plugins | Checks catalog first | You research | No awareness |
| Audits existing setup | Finds stale/broken | Manual review | No |
| Optimizes with evals | A/B tests skills | Manual | No |
| Works on any project | Any language/framework | Each project | Limited |

## How it works

```
Your Repo --> [Heuristic Pre-scan] --> [2 Parallel Subagents + Main Thread] --> [Quality Review] --> Files
                                                    |
                                              ------+------
                                              |     |     |
                                              v     v     v
                                         Repo    Skill   Main
                                        Analyzer Recomm  Thread
                                        (deep   (official (reads key
                                        arch)   first)   files)
                                                    |
                                              ------+------
                                              |           |
                                              v           v
                                         Codex        Quality
                                        Specialist   Reviewer
                                        (AGENTS.md)  (validate)
```

## Architecture

- **5 specialized subagents** for parallel analysis
- **Reference docs** with exact file format specs for all 3 tools
- **Official plugin catalog** -- recommends before generating custom skills
- **MCP server catalog** -- matches services to servers
- **Eval suite** -- verifiable quality via skill-creator
- **Quality gate** -- reviewer subagent validates before writing

## Key Design Decisions

**Official-first philosophy.** The plugin catalog is checked before generating any custom skill. If superpowers already covers TDD and debugging, Cortex recommends it instead of generating redundant custom skills. Custom skills are reserved for project-specific workflows that no official plugin handles.

**Multi-tool output.** Every scaffold run generates files for Claude Code, Cursor, AND Codex simultaneously. No need to run separate tools.

**Quality gate.** A dedicated reviewer subagent validates all generated files before they are written, checking format compliance, specificity (no generic templates), and consistency across tools.

## Contributing

PRs welcome!

## License

MIT
