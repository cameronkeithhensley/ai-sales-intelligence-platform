# syntax=docker/dockerfile:1.7

# --- Builder: install python dependencies into a user-local tree.
FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Build deps: needed for compiling the handful of wheels that are still
# source-only on slim (psycopg's optional C accelerators for instance).
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# --- Runtime: small image, non-root user.
FROM python:3.12-slim AS runtime

RUN groupadd --system app \
 && useradd --system --gid app --home /home/app --create-home app

COPY --from=builder --chown=app:app /root/.local /home/app/.local

ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY --chown=app:app src ./src

USER app

CMD ["python", "-u", "src/main.py"]
