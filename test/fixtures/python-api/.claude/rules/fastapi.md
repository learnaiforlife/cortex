---
paths:
  - "app/**/*.py"
---

# FastAPI Conventions

- Use dependency injection for shared resources (Redis client, DB sessions)
- Define request/response models with Pydantic `BaseModel`
- Use appropriate HTTP status codes (201 for creation, 204 for deletion)
- Use `async def` for route handlers that perform I/O
- Add type hints to all function signatures
- Group related routes with `APIRouter`
- Use `lifespan` context manager for startup/shutdown events (not deprecated `on_event`)
- Validate path and query parameters with FastAPI's built-in type validation
