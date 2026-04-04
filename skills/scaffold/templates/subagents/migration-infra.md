---
name: migration-infra
description: "Converts {{SOURCE_INFRA}} infrastructure configuration to {{TARGET_INFRA}}"
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
model: sonnet
maxTurns: 20
---

# MIGRATION: remove after {{SOURCE_INFRA}} → {{TARGET_INFRA}} migration completes

## Placeholders

| Variable | Description | Example |
|----------|-------------|---------|
| `{{SOURCE_INFRA}}` | Source infrastructure platform/tool | `Docker Compose` |
| `{{TARGET_INFRA}}` | Target infrastructure platform/tool | `Kubernetes` |
| `{{SOURCE_CONFIG}}` | Path to source infrastructure config | `docker-compose.yml` |
| `{{TARGET_DIR}}` | Directory for target infrastructure configs | `kubernetes/` |
| `{{CONVERSION_RULES}}` | Infrastructure-specific conversion rules | (see migration-catalog.md) |
| `{{VALIDATION_COMMAND}}` | Command to validate target configs | `kubectl apply --dry-run=client -f kubernetes/` |

## Context

Converting {{SOURCE_INFRA}} infrastructure to {{TARGET_INFRA}}.

## Conversion Rules

{{CONVERSION_RULES}}

## Workflow

1. Read {{SOURCE_CONFIG}} completely — identify all services, volumes, networks, and environment variables
2. For each service in the source config:
   a. Create the corresponding {{TARGET_INFRA}} resource definition
   b. Convert volume mounts, port mappings, and environment variables
   c. Handle service dependencies (health checks, readiness probes, init containers)
   d. Convert network configuration
3. Create shared resources (ConfigMaps, Secrets, PersistentVolumeClaims)
4. Write target configs to {{TARGET_DIR}}/
5. Validate configs: `{{VALIDATION_COMMAND}}`
6. Create a deployment checklist documenting:
   - Manual steps required (DNS, certificates, secrets)
   - Order of deployment
   - Rollback procedure
7. Update MIGRATION-PLAN.md progress

## Rules

- Never delete source infrastructure configs until target is validated in production
- Always validate target configs with dry-run before applying
- Convert environment variables to the target platform's secret management (never hardcode)
- Preserve exact same service topology — same ports, same dependencies, same health checks
- Include resource limits and requests in target configs (do not leave unbounded)
- Document any features that cannot be directly converted as TODOs in the target config comments
