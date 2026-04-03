# Markdown & Skill Authoring Conventions

## Subagent Files (skills/scaffold/agents/*.md)

- YAML frontmatter required: name, description, tools, model, maxTurns
- Model must be one of: `sonnet`, `opus`, `haiku`
- Tools must be a YAML list (not comma-separated string)
- Body must contain a `## Workflow` section with numbered steps
- Description drives auto-invocation -- make it specific and action-oriented

## Skill Files (skills/scaffold/SKILL.md, variants/*.md)

- YAML frontmatter required: name, description, allowed-tools
- Steps must be numbered and sequential
- Every command must be a real, copy-pasteable command (no placeholders)
- Variants must state which steps they override from the main SKILL.md

## Reference Catalogs (references/*.md)

- Each entry needs: trigger signals, configuration template, when-to-skip, security notes
- MCP server configs must use `${ENV_VAR}` syntax for credentials
- Plugin entries must include install command and priority level

## Eval Cases (evals/evals.json)

- Each case needs: name, fixture, expectations (human intent), assertions (machine checks)
- Assertions use one of 11 types (file_exists, file_contains, score_min, etc.)
- New features should come with corresponding eval cases
