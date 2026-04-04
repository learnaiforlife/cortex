# Cortex

## Overview

AI development scaffolding plugin for Claude Code, Cursor, and Codex. Analyzes any repository and generates complete, project-specific AI configuration files. Ships as a Claude Code plugin with 5 modes: scaffold (generate), audit (review), optimize (improve), discover (machine-wide), and toolbox (CLI tool installer).

**Tech Stack**: Bash (scripts), Python 3.10+ (autoresearch loop), Markdown (all configuration)
**Plugin System**: Claude Code skills + commands + hooks
**Version**: See `VERSION` and `.claude-plugin/plugin.json` (currently not aligned)

## Architecture

### Directory Structure

```
cortex/
  skills/scaffold/             # Main skill -- master orchestrator (SKILL.md, 962 LOC)
    agents/                    # 20 specialized subagents
      repo-analyzer.md         # Deep codebase exploration (architecture, patterns, commands)
      skill-recommender.md     # Official plugins first, custom skills for gaps
      quality-reviewer.md      # Format validation + content review (PASS/FAIL gate)
      codex-specialist.md      # AGENTS.md generation
      setup-auditor.md         # Audit existing AI setup
      user-level-generator.md  # Generate ~/.claude/ setup (Discover mode)
      dna-synthesizer.md       # DeveloperDNA to GenerationPlan (Discover mode)
      cross-project-analyzer.md # Pattern classification: user-level vs project-level
      scaffold-improver.md     # Targeted regeneration for weak dimensions
      skill-improver.md        # SKILL.md edit proposals (autoresearch)
      variant-dispatcher.md    # Extract conditional logic into variant files
      opportunity-detector.md  # Suggests subagents/skills/integrations per repo
      integration-subagent-gen.md # Fills integration templates + MCP entries
      toolbox-recommender.md   # CLI tool scoring and recommendation (Toolbox mode)
      migration-analyzer.md    # Migration path analysis
      migration-planner.md     # Migration step planning
      migration-agent-generator.md # Generate migration-specific agents
      migration-validator.md   # Validate migration results
      migration-progress-tracker.md # Track migration progress
      risk-assessor.md         # Risk assessment for changes
    scripts/                   # 21 bash utility scripts
      analyze.sh               # Heuristic pre-scan -> ProjectProfile JSON
      detect-opportunities.sh  # Detects subagent/skill/integration opportunities
      detect-cli-tools.sh      # AI agent acceleration CLI tool detection (Toolbox mode)
      install-cli-tools.sh     # Safe cross-platform CLI tool installer (Toolbox mode)
      score.sh                 # Quantitative scoring (0-100, 4 dimensions)
      run-skill-evals.sh       # Assertion-based eval runner (28 cases)
      auto-improve.sh          # Quality measurement (scores fixtures, reports weakest dimension)
      validate.sh              # Format validation
      log-result.sh            # Append-only TSV logger
      audit-existing.sh        # Existing setup inventory for audit mode
      discover-orchestrator.sh # Machine-wide discovery engine
      discover-projects.sh     # Git repo scanner
      discover-tools.sh        # Tool detection (node, python, go, etc.)
      discover-services.sh     # Service detection (docker-compose, cloud configs)
      discover-integrations.sh # Integration scanner (Slack, GitHub, Jira, etc.)
      discover-company.sh      # Company context detection
      log-discover.sh          # DeveloperDNA logger
      schedule-autorun.sh      # Cron automation setup
    references/                # 12 reference catalogs
      official-plugins-catalog.md  # Plugin registry with trigger signals
      mcp-catalog.md              # MCP server registry with configs
      cli-tools-catalog.md        # CLI tools for AI agent acceleration (56 tools)
      claude-code-formats.md      # Claude Code file format specs
      cursor-formats.md           # Cursor file format specs
      codex-formats.md            # Codex file format specs
      user-level-formats.md       # User-level setup formats
      discover-integration-catalog.md # Integration detection signals
      soft-skills-catalog.md      # Productivity skill templates and metadata
      subagent-templates-catalog.md # Template-driven subagent catalog
      integration-subagents-catalog.md # Integration subagent catalog
    variants/                  # Specialized repo-type handlers
      dispatch-table.json      # Variant routing config (signals, priority)
      SKILL-monorepo.md        # Monorepo handling (turbo/nx/lerna/pnpm)
      SKILL-minimal.md         # Minimal project handling (<= 10 files)
    evals/
      evals.json               # 28 test cases with assertions
  claude-code-auto-research/   # Python autoresearch loop
    run.py                     # Autonomous optimization engine
    measure.py                 # Scoring + grading logic
    prepare.py                 # Setup & baseline snapshot
    progress.py                # Progress reporting
    config.json                # Loop settings
    program.md                 # Optimization strategy
  commands/                    # Slash command definitions
    scaffold.md                # /scaffold entry point
    scaffold-audit.md          # /scaffold audit
    scaffold-optimize.md       # /scaffold optimize
    scaffold-discover.md       # /scaffold discover
    scaffold-toolbox.md        # /scaffold-toolbox (CLI tool installer)
    scaffold-migrate.md        # /scaffold migrate
  hooks/
    hooks.json                 # SessionStart/Stop auto-suggest hooks
  test/fixtures/               # Test fixture projects
    nextjs-app/                # Next.js + Prisma + Docker + CI
    python-api/                # FastAPI + pytest + Docker + CI
    minimal/                   # 2 files (index.js, package.json)
  .claude-plugin/
    plugin.json                # Plugin metadata (name, version, homepage)
  docs/                        # Design documentation
  reports/                     # Audit reports
  install.sh                   # Plugin installer
```

### Data Flow

```
/scaffold [repo]
    |
    v
[Variant Dispatch] --> SKILL-monorepo.md or SKILL-minimal.md (if signals match)
    |
    v
[Heuristic Pre-scan (analyze.sh)] --> ProjectProfile JSON
    |
    v
[2 Parallel Subagents]
    |                    |
    v                    v
repo-analyzer      skill-recommender
(deep codebase)    (official plugins first)
    |
    v
codex-specialist (AGENTS.md generation)
    |
    v
[Quality Review] --> PASS/FAIL verdict
    |
    v
[Write Files] --> [Score (0-100)] --> [Log Results]

/scaffold-toolbox
    |
    v
[detect-cli-tools.sh] --> toolbox-recommender --> Present --> Install (dry-run first)
```

## Development Commands

```bash
# Installation
./install.sh                                          # Install to ~/.claude/skills/scaffold/

# Testing & Quality
bash skills/scaffold/scripts/run-skill-evals.sh       # Run all 28 eval cases
bash skills/scaffold/scripts/score.sh <output-dir>    # Score scaffold output (0-100 JSON)
bash skills/scaffold/scripts/validate.sh <output-dir> # Format validation

# Analysis
bash skills/scaffold/scripts/analyze.sh <repo-dir>    # Heuristic pre-scan

# Quality Measurement
bash skills/scaffold/scripts/auto-improve.sh           # Measure scaffold quality (scores fixtures, no edits)
bash skills/scaffold/scripts/log-result.sh             # Log results to TSV

# Discovery
bash skills/scaffold/scripts/discover-orchestrator.sh  # Machine-wide project discovery

# Scheduling
bash skills/scaffold/scripts/schedule-autorun.sh setup # Setup weekly/monthly automation
```

## Conventions

### Code Style

- Shell scripts use strict mode (`set -euo pipefail` or `set -uo pipefail`)
- All scripts are bash (no zsh or other shells)
- Python code requires Python 3.10+ (autoresearch loop only)
- All markdown files use ATX headers (`#`, not underlines)
- YAML frontmatter in agents/skills must be valid YAML

### File Naming

- Subagents: lowercase with hyphens (`repo-analyzer.md`)
- Scripts: lowercase with hyphens (`run-skill-evals.sh`)
- Variants: `SKILL-{type}.md` (e.g., `SKILL-monorepo.md`)
- Rules: lowercase with hyphens, topic-based (`safety.md`)
- Commands: `scaffold-{mode}.md` (e.g., `scaffold-audit.md`)

### Testing Requirements

- All SKILL.md changes must be eval'd against 3 fixture projects
- Score must be >= 70/100 to pass quality gate
- New features require corresponding eval cases in evals.json
- Autoresearch changes require before/after score comparison

### Key Principles

- **Official-first**: Check `references/official-plugins-catalog.md` before generating custom skills
- **Never overwrite**: Read existing files before writing; merge and preserve user customizations
- **Three-tool parity**: Every run generates for Claude Code, Cursor, AND Codex
- **Quality gate**: quality-reviewer subagent must PASS before files are written
- **Variant dispatch**: Route specialized repo types to variant SKILL files

## Agent Instructions

### General Behavior

- Read existing files before making changes (never blindly overwrite)
- Run evals after modifying subagents, SKILL.md, or scoring scripts
- Keep reference catalogs as the single source of truth for plugin/MCP recommendations
- Test against all 3 fixture projects when changing core scaffold logic

### When Modifying Subagents

- Each agent has YAML frontmatter (name, description, tools, model, maxTurns)
- Body must contain a `## Workflow` section with numbered steps
- Model choices: `sonnet` for heavy work, `haiku` for lightweight validation
- After changes, run: `bash skills/scaffold/scripts/run-skill-evals.sh`

### When Modifying Scoring

- Score dimensions: format (25pts), specificity (25pts), completeness (25pts), structure (25pts)
- Changes to scoring weights require full eval suite re-run
- Log all results with: `bash skills/scaffold/scripts/log-result.sh`

### When Adding Eval Cases

- Add to `skills/scaffold/evals/evals.json`
- Include: name, fixture, expectations (human intent), assertions (machine checks)
- 15 assertion types available (`file_exists`, `file_contains`, `score_min`, etc.)
- Verify new evals pass against current SKILL.md before committing

### File Protection

Do NOT modify without explicit confirmation:
- `skills/scaffold/references/*.md` -- authoritative catalogs
- `skills/scaffold/evals/evals.json` -- test assertions
- `skills/scaffold/variants/dispatch-table.json` -- variant routing
- `.claude-plugin/plugin.json` -- plugin metadata
- `test/fixtures/**/*` -- test data

### Debugging Workflows

When scaffold output is low quality:
1. Check which scoring dimension is weakest via `score.sh`
2. Read the relevant subagent (repo-analyzer for specificity, quality-reviewer for format)
3. Run the subagent in isolation against a fixture
4. Compare output against eval expectations
5. Fix the subagent instructions, not the scoring

When evals fail:
1. Read the failing assertion in `evals.json`
2. Run the scaffold against the specified fixture
3. Check if the output file exists and matches expectations
4. Fix the SKILL.md or subagent, not the eval (unless the eval is wrong)
