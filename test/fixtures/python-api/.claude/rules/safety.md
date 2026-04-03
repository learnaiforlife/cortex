# Safety Rules

## Protected Files

Do not modify without explicit user confirmation:
- `openapi.yaml` — API contract, changes affect consumers
- `pyproject.toml` — project config, dependency changes need review
- `.github/workflows/test.yml` — CI pipeline
- `Dockerfile` — container build

## Forbidden Operations

- Never hardcode API keys, tokens, Redis URLs, or credentials
- Never run `rm -rf` on `app/` or `tests/`
- Never force-push to main
- Never disable ruff rules inline without justification

## Required Checks

- After modifying `app/main.py`, run `pytest` to verify
- After modifying any `.py` file, run `ruff check .`
- Keep `openapi.yaml` in sync with route handlers
