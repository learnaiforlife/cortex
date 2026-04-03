# my-api — Codex Agent Configuration

## Project Overview

FastAPI REST API with Redis integration, containerized with Docker. Python 3.12, PEP 517 packaging via pyproject.toml.

## Architecture

```
app/main.py          — FastAPI app instance + route handlers (entry point: app.main:app)
tests/conftest.py    — Pytest fixtures and shared test setup
Dockerfile           — Container image (python:3.12-slim, uvicorn)
openapi.yaml         — OpenAPI 3.0 spec (single GET / endpoint)
pyproject.toml       — Project config: fastapi, uvicorn, redis, pytest, ruff
.github/workflows/   — CI: install + pytest on push
```

## Development Commands

```bash
# Setup
pip install ".[dev]"

# Run
uvicorn app.main:app --reload

# Test
pytest
pytest -v                    # Verbose with test names

# Lint & Format
ruff check .                 # Lint
ruff check . --fix           # Auto-fix
ruff format .                # Format

# Docker
docker build -t my-api .
docker run -p 8000:8000 my-api
```

## Dependencies

- **Runtime**: fastapi>=0.110.0, uvicorn>=0.29.0, redis>=5.0.0
- **Dev**: pytest>=8.0.0, ruff>=0.4.0

## Conventions

- PEP 517 packaging (pyproject.toml, no setup.py)
- Ruff for both linting and formatting (line-length = 100)
- Tests in `tests/` using pytest
- App module under `app/` package
- OpenAPI spec in `openapi.yaml` — keep in sync with route handlers
- Use dependency injection for shared resources
- Use Pydantic BaseModel for request/response schemas
- Use async def for I/O-bound route handlers
- Use `lifespan` context manager for startup/shutdown (not deprecated `on_event`)

## Testing

- Framework: pytest
- Test directory: `tests/`
- Fixtures: `tests/conftest.py`
- CI runs: `pip install ".[dev]" && pytest` on every push
- FastAPI test client requires httpx

## Safety Rules

- Never hardcode API keys, tokens, Redis URLs, or credentials
- Never run destructive commands on `app/` or `tests/`
- Never force-push to main
- After modifying `app/main.py`, run `pytest`
- After modifying any `.py` file, run `ruff check .`
- Keep `openapi.yaml` in sync with route handlers
- Do not modify `pyproject.toml`, `Dockerfile`, or `.github/workflows/test.yml` without review

## Gotchas

- Redis is declared as a dependency but not yet imported or connected in `app/main.py`
- Dockerfile CMD uses `uvicorn app.main:app` without `--host 0.0.0.0` — container port may be unreachable
- `tests/conftest.py` only imports pytest — no TestClient fixture is set up yet
- httpx is not in dev dependencies but is needed for FastAPI's TestClient
- Ruff line-length is 100 (not default 88) — configured in pyproject.toml
- OpenAPI spec only documents GET / — it's a placeholder, not a source of truth

## Agent Instructions

When working on this project:
1. Always run `pytest` after modifying source code
2. Always run `ruff check .` after modifying any Python file
3. Use `gh` CLI for GitHub operations (PR creation, issue management)
4. Check `openapi.yaml` when adding or modifying API routes
5. Use `${ENV_VAR}` syntax for any credentials or connection strings
