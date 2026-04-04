---
name: service-extractor
description: "Extracts a bounded context from {{MONOLITH_NAME}} into a standalone microservice"
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
model: sonnet
maxTurns: 30
---

# MIGRATION: Remove after {{MONOLITH_NAME}} decomposition completes

## Placeholders

| Variable | Description | Example |
|----------|-------------|---------|
| `{{MONOLITH_NAME}}` | Name of the monolith application | `Rails monolith` |
| `{{MONOLITH_DIR}}` | Root directory of the monolith | `app/` |
| `{{SERVICES_DIR}}` | Directory where extracted services live | `services/` |
| `{{SERVICE_NAME}}` | Name of the service being extracted | `billing-service` |
| `{{BOUNDED_CONTEXT}}` | Domain boundary being extracted | `Billing (invoices, payments, subscriptions)` |
| `{{SHARED_DB}}` | Shared database connection string or reference | `PostgreSQL (shared)` |
| `{{COMMUNICATION_PATTERN}}` | Inter-service communication pattern | `REST API calls` |
| `{{DOMAIN_MAP}}` | Path to the domain/services map document | `docs/services-map.md` |

## Context

Extracting the {{BOUNDED_CONTEXT}} bounded context from {{MONOLITH_NAME}} into a standalone microservice at {{SERVICES_DIR}}/{{SERVICE_NAME}}/.

## Workflow

1. Read the domain map ({{DOMAIN_MAP}}) for this bounded context
2. Identify all models, controllers, and background jobs belonging to {{BOUNDED_CONTEXT}}
3. Map cross-boundary dependencies:
   - What does this context call in other contexts?
   - What other contexts call into this one?
4. Create service directory structure:
   ```
   {{SERVICES_DIR}}/{{SERVICE_NAME}}/
   ├── Dockerfile
   ├── README.md
   ├── src/
   │   ├── api/          (routes/controllers)
   │   ├── models/       (domain models)
   │   ├── services/     (business logic)
   │   └── events/       (event handlers if applicable)
   └── tests/
   ```
5. Extract models — copy to service, add API endpoint for cross-service access
6. Extract controllers — convert to service API controllers
7. Add anti-corruption layer in monolith (calls service API instead of local model)
8. Write integration tests (service ↔ monolith)
9. Update docker-compose.yml with the new service
10. Update MIGRATION-PLAN.md progress

## Rules

- Never move a model that is directly referenced by 5+ other models — add API first
- Always add database migration to copy data, never move-in-place
- Extracted service MUST have a health check endpoint (`/health`)
- Monolith must be independently deployable at every step
- Start with read-only access to shared DB, convert to own DB only in the data decomposition phase
- Always create integration tests verifying the anti-corruption layer works
- Do not extract more than one bounded context per session
