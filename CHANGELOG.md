# Changelog

## [Unreleased]

### Changed
- Documentation alignment pass after deep audit:
  - Updated architecture/count references to reflect current repository state (13 subagents, 16 scripts, 10 reference docs).
  - Clarified eval runner coverage as 18 eval cases with 15 assertion types.
  - Added explicit note that version metadata is currently split across `VERSION` and `.claude-plugin/plugin.json`.

## [0.2.0] - 2026-04-01

### Added
- **Discover Mode** (`/scaffold discover`): Machine-wide discovery engine that scans all projects, tools, services, and integrations to generate cohesive multi-level AI setups
  - 6 discovery scripts: projects, tools, services, integrations, company signals, orchestrator
  - DeveloperDNA profile with cross-project pattern detection
  - User-level vs project-level classification (frequency-based + overrides)
  - 3 new agents: cross-project-analyzer, dna-synthesizer, user-level-generator
  - 2 new reference docs: discover-integration-catalog, user-level-formats
- **Variant Dispatch**: Auto-selects specialized SKILL variants based on repo signals
  - dispatch-table.json with signal evaluation spec
  - SKILL-monorepo.md variant for Turborepo/Nx/Lerna/pnpm workspaces
  - SKILL-minimal.md variant for small projects (<10 files, no framework)
  - variant-dispatcher agent for auto-extracting DERIVED changes
- **Scheduled Auto-Improve**: Automated weekly improvement + monthly re-discovery
  - schedule-autorun.sh with launchd (macOS) and cron (Linux) support
  - Post-scaffold hook suggesting auto-improve when score < 70
- **Evolution Taxonomy**: FIX/DERIVED/CAPTURED classification for skill-improver changes
- **Per-Subagent Metrics**: Extended log-result.sh with qr_verdict, qr_score, improver_ran, improver_helped, subagent_timeouts
- **Post-Execution Suggestions**: Actionable guidance when scaffold score < 70
- **Auto-Research Module** (`claude-code-auto-research/`): Autonomous subagent prompt optimization inspired by karpathy/autoresearch
  - prepare.py, measure.py, run.py, progress.py
  - Composite scoring (expectation pass rate + structural + hallucination)
  - Per-subagent expectations decomposed from main evals
- **MCP Catalog Extensions**: Added Jira, Linear, Notion, Datadog server entries
- **14 eval cases** (up from 9): Added discover, variant dispatch, and cross-project evals
- **install.sh backup**: Backs up existing installation before overwriting

### Changed
- SKILL.md extended with Variant Dispatch section and Discover Mode (Steps D1-D11)
- install.sh now shows component counts and scheduling instructions

### Fixed
- Command injection risks in shell scripts (heredoc + file-based I/O)
- `export -f` reliability on macOS bash 3.2 (temp script approach)
- `eval echo` tilde expansion (safe `${dir/#\~/$HOME}`)
- `which` replaced with POSIX `command -v` across all scripts
- `set -uo pipefail` consistency across all scripts
- Float arithmetic in auto-improve.sh (int() wrapping)
- Subagent `${CLAUDE_SKILL_DIR}` resolution for catalog references
- Quality-reviewer variant-aware scoring for minimal projects

## [0.1.0] - 2026-04-01

### Added
- Initial release: scaffold, audit, optimize modes
- 7 subagents: repo-analyzer, skill-recommender, quality-reviewer, codex-specialist, setup-auditor, scaffold-improver, skill-improver
- Quality scoring engine (score.sh) with 4 dimensions
- 9 eval cases across 3 test fixtures
- Official plugins catalog and MCP server catalog
- Autoresearch-inspired auto-improve loop
