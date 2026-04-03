---
name: docker-dev
description: "Manage Docker development environment. Use when starting services, rebuilding containers, checking logs, or managing local infrastructure."
allowed-tools: Bash, Read
---

# Docker Dev Environment

## Steps

1. Start local services: `docker compose up -d`
2. Wait for PostgreSQL to be ready: `docker compose exec db pg_isready`
3. Run Prisma migrations against the database: `npx prisma migrate dev`
4. Start the Next.js dev server: `npm run dev`

## Common Operations

```bash
docker compose up -d              # Start postgres + redis
docker compose down               # Stop all services
docker compose logs -f db         # Follow postgres logs
docker compose logs -f redis      # Follow redis logs
docker compose ps                 # Check service status
docker build -t my-nextjs-app .   # Build production image
docker run -p 3000:3000 my-nextjs-app  # Run production container
```

## Rules

- Always check if services are running before starting them.
- Use `docker compose down` to clean up, not `docker kill`.
- Never run database commands against production containers.
- PostgreSQL runs on port 5432, Redis on port 6379.
