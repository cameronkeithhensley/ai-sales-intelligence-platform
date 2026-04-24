# syntax=docker/dockerfile:1.7

# --- Builder: installs production dependencies only.
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json ./
# Stub dependencies only — Sprint 3 replaces this with a real tree.
RUN npm install --omit=dev --no-audit --no-fund

# --- Runtime: small image, non-root user, just the app + installed deps.
FROM node:20-alpine AS runtime

RUN addgroup -S app && adduser -S -G app app

WORKDIR /app

COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --chown=app:app src ./src

USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --spider -q http://localhost:8080/healthz || exit 1

CMD ["node", "src/index.js"]
