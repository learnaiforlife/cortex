# Safety Rules

## Protected Files

Do not modify without explicit user confirmation:
- `skills/scaffold/references/*.md` -- authoritative catalogs, changes affect all recommendations
- `skills/scaffold/evals/evals.json` -- test assertions, changes affect quality measurement
- `skills/scaffold/variants/dispatch-table.json` -- variant routing, changes affect repo detection
- `.claude-plugin/plugin.json` -- plugin metadata
- `test/fixtures/**/*` -- test data, must remain stable

## Forbidden Operations

- Never hardcode API keys, tokens, or credentials in any generated file
- Never use `rm -rf` on `skills/`, `test/`, or `claude-code-auto-research/`
- Never force-push to main branch
- Never modify `VERSION` file without updating `CHANGELOG.md`

## Required Checks

- After modifying any subagent in `skills/scaffold/agents/`, run evals: `bash skills/scaffold/scripts/run-skill-evals.sh`
- After modifying `SKILL.md` or variants, run scoring against all 3 fixtures
- After modifying scoring logic in `scripts/score.sh`, verify against known baselines
