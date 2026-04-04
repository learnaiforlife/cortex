# Multi-stage build supporting both Python and TypeScript during migration
FROM python:3.11-slim AS python-api
WORKDIR /app
COPY pyproject.toml .
RUN pip install --no-cache-dir .
COPY src/python/ src/python/
CMD ["uvicorn", "src.python.main:app", "--host", "0.0.0.0", "--port", "8000"]

FROM node:20-slim AS typescript-api
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --production
COPY src/typescript/ src/typescript/
COPY tsconfig.json .
RUN npx tsc
CMD ["node", "dist/server.js"]
