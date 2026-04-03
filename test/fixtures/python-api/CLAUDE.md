# my-api

FastAPI REST API with Redis integration, containerized with Docker.

## Architecture

```
app/
  main.py           # FastAPI app instance + route handlers
tests/
  conftest.py       # Pytest fixtures and shared test setup
Dockerfile          # Container image (python:3.12-slim)
openapi.yaml        # OpenAPI 3.0 spec
pyproject.toml      # PEP 517 project config, deps, ruff config
.github/workflows/
  test.yml          # CI: install + pytest on push
```

Entry point: `app.main:app` (FastAPI instance)

## Development Commands

```bash
pip install ".[dev]"                  # Install with dev dependencies
uvicorn app.main:app --reload         # Run dev server (port 8000)
pytest                                # Run test suite
ruff check .                          # Lint
ruff format .                         # Format
docker build -t my-api .              # Build container
docker run -p 8000:8000 my-api        # Run container
```

## Key Conventions

- PEP 517 packaging via `pyproject.toml` (no setup.py)
- Ruff for both linting and formatting (line-length = 100)
- Tests in `tests/` directory using pytest
- App module under `app/` package
- OpenAPI spec in `openapi.yaml` (keep in sync with route handlers)

## Dependencies

- **Runtime**: fastapi, uvicorn, redis
- **Dev**: pytest, ruff

## Important Patterns

- Redis is declared as a dependency but not yet wired up in `app/main.py`
- Dockerfile CMD uses `uvicorn app.main:app` — add `--host 0.0.0.0` for container accessibility
- CI runs `pip install ".[dev]" && pytest` on every push

## Things to Avoid

- Do not modify `openapi.yaml` without updating corresponding route handlers
- Do not hardcode Redis connection strings — use environment variables
- Do not use line lengths other than 100 (configured in pyproject.toml)
- Never commit `.env` files or credentials
