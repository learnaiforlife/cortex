# Cortex

AI development scaffolding plugin for Claude Code. Analyzes any repo and generates tailored AI setup for Claude Code, Cursor, and Codex.

## Architecture

```
skills/scaffold/           # Main skill (SKILL.md) + variants
  agents/                  # 20 specialized subagents (repo-analyzer, skill-recommender, toolbox-recommender, quality-reviewer, etc.)
  scripts/                 # 21 bash scripts (analyze, score, discover, detect-cli-tools, install-cli-tools, evals)
  references/              # 12 catalogs (official plugins, MCP servers, CLI tools, file formats, templates)
  variants/                # Variant dispatch (monorepo, minimal) + dispatch-table.json
  templates/               # 21 subagent templates + 4 soft skill templates
  evals/                   # 28 assertion-based test cases (evals.json)
claude-code-auto-research/ # Python autoresearch loop (run.py, measure.py, prepare.py, progress.py)
commands/                  # 6 slash commands (scaffold, scaffold-audit, scaffold-optimize, scaffold-discover, scaffold-toolbox, scaffold-migrate)
hooks/                     # SessionStart/Stop hooks (hooks.json)
test/fixtures/             # 3 fixture projects (nextjs-app, python-api, minimal)
.claude-plugin/            # Plugin metadata (plugin.json)
```

## Key Data Flow

```
/scaffold [repo] --> Variant Dispatch --> Heuristic Pre-scan --> 2 Parallel Subagents
                                                                   |           |
                                                              repo-analyzer  skill-recommender
                                                                   |
                                                              codex-specialist
                                                                   v
                                                            Quality Review --> Write Files --> Score + Log

/scaffold-toolbox --> detect-cli-tools.sh --> toolbox-recommender --> Present --> Install (dry-run first)
```

## Development Commands

```bash
./install.sh                                          # Install plugin to ~/.claude/skills/scaffold/
bash skills/scaffold/scripts/score.sh <output-dir>    # Score scaffold output (0-100 JSON)
bash skills/scaffold/scripts/run-skill-evals.sh       # Run assertion-based evals (28 test cases)
bash skills/scaffold/scripts/validate.sh <output-dir> # Format validation
bash skills/scaffold/scripts/auto-improve.sh           # Autoresearch loop (measure-edit-measure)
bash skills/scaffold/scripts/analyze.sh <repo-dir>    # Heuristic pre-scan (ProjectProfile JSON)
```

## Testing

- Fixtures in `test/fixtures/` (nextjs-app, python-api, minimal)
- Evals in `skills/scaffold/evals/evals.json` with 28 test cases and 15 assertion types
- Autoresearch loop in `claude-code-auto-research/` (Python 3.10+)
- Score dimensions: format compliance, specificity, completeness, structural quality (25 pts each)

## Key Conventions

- **Official-first**: Always check `references/official-plugins-catalog.md` before generating custom skills
- **Never overwrite**: Read existing files before writing. Merge, enhance, preserve user customizations
- **Three-tool parity**: Every scaffold run generates for Claude Code, Cursor, AND Codex
- **Quality gate**: quality-reviewer subagent must PASS before files are written
- **Variant dispatch**: Monorepo/minimal repos get specialized SKILL variants via `dispatch-table.json`
- **Subagents are markdown**: All 20 agents live in `skills/scaffold/agents/*.md` with YAML frontmatter

## Things to Avoid

- Do not hardcode paths or credentials in generated `.mcp.json` files -- use `${ENV_VAR}` syntax
- Do not generate custom skills when an official plugin covers the same need
- Do not modify `references/*.md` catalogs without updating the corresponding evals
- Do not modify `variants/dispatch-table.json` without testing against all 3 fixture projects
- Do not change scoring weights in `scripts/score.sh` without re-running the full eval suite
- Generated files must never contain placeholder text like `[YOUR_PROJECT]` or `TODO:`
