# Cortex

**AI development setup, automated.**

One command. Any repo. Generates AI configuration for Claude Code, Cursor, and Codex.

## What it does

Point it at any repo:

```
/scaffold https://github.com/your-org/your-project
```

Cortex will:
1. **Analyze** your codebase (architecture, patterns, domain, services)
2. **Detect opportunities** — subagents, skills, and integrations that match your project
3. **Ask what you want** — interactive selection with smart defaults (or `--all` to accept everything)
4. **Generate tailored setup** for all three AI coding tools with correct model routing
5. **Review quality** before writing any files

Or scan your entire dev environment:

```
/scaffold discover
```

Cortex will find all your projects, tools, services, and integrations, then generate a cohesive setup at both user-level (`~/.claude/`) and per-project level.

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

## Modes

| Command | What it does |
|---------|-------------|
| `/scaffold [repo]` | Analyze repo, interactive suggestions, generate AI setup |
| `/scaffold [repo] --all` | Accept all suggestions (no prompts — good for CI/overnight) |
| `/scaffold [repo] --minimal` | Generate only CLAUDE.md + safety rules |
| `/scaffold audit` | Scan existing setup for duplicates, stale configs, broken references |
| `/scaffold optimize` | Run evals, check freshness, auto-improve skills |
| `/scaffold discover` | Scan your machine, generate user-level + per-project setup |

### Interactive Mode

By default, Cortex detects what your project uses and suggests:

- **Subagents** — test-runner (haiku), lint-format (haiku), code-reviewer (sonnet), pr-writer (sonnet), architecture-advisor (opus)
- **Soft skills** — avoid-ai-slop, devils-advocate, grill-me, think-out-loud
- **Integrations** — Jira, Confluence, Slack, Linear, Notion, Sentry, Datadog, GitHub/GitLab

You choose which to generate. Each suggestion includes a model tier and description.

### Model Routing

Generated subagents are assigned the right model tier automatically:

| Tier | Model | Used for |
|------|-------|----------|
| Mechanical | haiku | Test running, linting, build watching, commit messages |
| Creative | sonnet | Code review, PR writing, integration management |
| Architectural | opus | Architecture advice, complex refactoring |

## Install

```bash
git clone https://github.com/learnaiforlife/cortex
cd cortex
./install.sh
```

## How it compares

| Feature | Cortex | Manual Setup | Template Tools |
|---------|--------|--------------|----------------|
| Multi-tool output (Claude + Cursor + Codex) | Yes | One at a time | Usually one tool |
| Dynamic codebase analysis | Yes | Manual | No (templates) |
| Recommends official plugins first | Yes | You research | No awareness |
| Audits existing setup | Yes | Manual review | No |
| Quality scoring (0-100) | Yes | No | No |
| Self-improving via autoresearch loop | Yes | No | No |
| Machine-wide discovery | Yes | No | No |
| Variant dispatch (monorepo, minimal) | Yes | N/A | No |

**Related projects:** [ai-nexus](https://github.com/AiNexusHub/ai-nexus) (rule routing), [rule-porter](https://github.com/bosun-ai/rule-porter) (format conversion), [akm](https://github.com/rinormaloku/akm) (rule indexing). Cortex differs by performing per-repo analysis + multi-artifact generation + measurement-driven self-improvement.

## Architecture

```
/scaffold [repo]
    |
    v
[Variant Dispatch] --> SKILL-monorepo.md or SKILL-minimal.md (if signals match)
    |
    v
[Heuristic Pre-scan] --> [Opportunity Detection] --> [Interactive Selection]
                              |                           |
                         detect-opportunities.sh     AskUserQuestion x3
                         (subagents, skills,         (or --all to skip)
                          integrations)                   |
                              |                           v
                              v                    [FilteredManifest]
                    [2 Parallel Subagents]                 |
                         |           |                    v
                    Repo Analyzer  Skill Recommender  [Quality Review] --> Files
                    (deep arch)    (official first)
                         |
                    Codex Specialist
                    (AGENTS.md)

/scaffold discover
    |
    v
[Permission] --> [6 Discovery Scripts] --> [DeveloperDNA] --> [Cross-Project Analysis]
                      |                         |                    |
                 Projects, Tools,          Classification      User-level +
                 Services, Integrations    (user vs project)   Project-level generation
```

**13 specialized subagents** | **16 scripts** | **2 skill variants** | **18 eval cases** | **10 reference docs** | **17 subagent templates** | **4 soft skill templates**

## Key Design Decisions

- **Official-first.** Plugin catalog checked before generating custom skills. If superpowers covers TDD, recommend it — don't generate a custom version.
- **Multi-tool parity.** Every run generates for Claude Code, Cursor, AND Codex.
- **Quality gate.** Reviewer subagent validates all files before writing. 0-100 scoring across 4 dimensions.
- **Autoresearch-inspired.** Every run is scored, logged, and optionally improved via iterative loop targeting the weakest dimension. Borrowed from [karpathy/autoresearch](https://github.com/karpathy/autoresearch).
- **Variant dispatch.** Monorepos and minimal projects get specialized handling via dispatch table — no SKILL.md bloat.
- **Multi-level generation.** Discover mode classifies patterns as user-level (>50% of repos) vs project-level, avoiding duplication.
- **Privacy-first discovery.** Machine scanning is read-only, local-only, explicit-consent. Never reads credential values.

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/score.sh` | Score scaffold output (0-100 JSON) |
| `scripts/run-skill-evals.sh` | Run assertion-based evals |
| `scripts/log-result.sh` | Append to experiment log |
| `scripts/auto-improve.sh` | Autoresearch loop for SKILL.md |
| `scripts/discover-orchestrator.sh` | Machine-wide discovery engine |
| `scripts/schedule-autorun.sh` | Setup weekly/monthly automation |
| `scripts/validate.sh` | Basic format validation |
| `scripts/analyze.sh` | Heuristic project profile |
| `scripts/detect-opportunities.sh` | Detect subagent, skill, and integration opportunities |

## Status

**v0.3.0** — Interactive scaffold with smart suggestions, model routing, and integration detection. Tested against 3 fixture projects and 3 OSS repos (shadcn-ui, FastAPI, Express). Eval suite: 100% pass rate (52/52 assertions). Autoresearch baseline: 97.3/100.

Contributions and feedback welcome.

## License

MIT
