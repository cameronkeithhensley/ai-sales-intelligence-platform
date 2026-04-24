# syntax=docker/dockerfile:1.7

# --- Builder: install deps + next build.
#
# The Sprint 2 Dockerfile shape is preserved: multi-stage node:20-alpine,
# non-root runtime user, EXPOSE 8080, HEALTHCHECK on /healthz, and the
# src/index.js entry. The additional COPY lines here exist because Next.js
# needs its app/ directory, next.config.mjs, and tsconfig.json to build.
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json ./
# Stub dependency tree; real lockfile lands when the production build path
# needs reproducibility.
RUN npm install --no-audit --no-fund

COPY next.config.mjs tsconfig.json ./
COPY app ./app
COPY src ./src

RUN npx next build

# --- Runtime: small image, non-root user, only what's needed to serve.
FROM node:20-alpine AS runtime

RUN addgroup -S app && adduser -S -G app app

WORKDIR /app

COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --from=builder --chown=app:app /app/.next ./.next
COPY --chown=app:app next.config.mjs ./
COPY --chown=app:app app ./app
COPY --chown=app:app src ./src

USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --spider -q http://localhost:8080/healthz || exit 1

CMD ["node", "src/index.js"]
