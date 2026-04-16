# Cloudron package for DeerFlow — final stage MUST be cloudron/base (see .cursor/skills/cloudron-app-packaging).
# Pin upstream with: docker build --build-arg DEERFLOW_VERSION=v2.0-m1 .
# Default pin is read from DEERFLOW_VERSION file in build context.

ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.7.20
FROM ${UV_IMAGE} AS uv-source

# ── Fetch upstream DeerFlow (pinned tag or branch) ───────────────────────────
FROM alpine:3.20 AS fetch
RUN apk add --no-cache git
ARG DEERFLOW_VERSION=v2.0-m1
WORKDIR /src
RUN git clone --depth 1 --branch "${DEERFLOW_VERSION}" https://github.com/bytedance/deer-flow.git repo

# ── Frontend build (Node 22, glibc) ─────────────────────────────────────────
FROM node:22-bookworm AS frontend-build
ARG NPM_REGISTRY
WORKDIR /build
COPY --from=fetch /src/repo/frontend ./frontend
RUN if [ -n "${NPM_REGISTRY}" ]; then export COREPACK_NPM_REGISTRY="${NPM_REGISTRY}"; fi \
  && corepack enable && corepack install -g pnpm@10.26.2 \
  && if [ -n "${NPM_REGISTRY}" ]; then pnpm config set registry "${NPM_REGISTRY}"; fi \
  && cd frontend && pnpm install --frozen-lockfile \
  && SKIP_ENV_VALIDATION=1 pnpm build

# ── Backend venv (built on same libc family as cloudron/base = Ubuntu 24.04) ─
FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c AS backend-build
ARG UV_INDEX_URL=https://pypi.org/simple
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    pkg-config \
    libssl-dev \
    libffi-dev \
    python3-dev \
    git \
  && rm -rf /var/lib/apt/lists/*
COPY --from=uv-source /uv /uvx /usr/local/bin/
WORKDIR /build
COPY --from=fetch /src/repo/backend ./backend
# Plain RUN (no BuildKit --mount cache): remote Cloudron/docker builders often run without BuildKit.
RUN cd backend && UV_INDEX_URL="${UV_INDEX_URL:-https://pypi.org/simple}" uv sync --frozen \
  && UV_INDEX_URL="${UV_INDEX_URL:-https://pypi.org/simple}" uv pip install langgraph-checkpoint-postgres 'psycopg[binary]' psycopg-pool \
  && UV_INDEX_URL="${UV_INDEX_URL:-https://pypi.org/simple}" uv pip install 'deerflow-harness[ollama]'

# ── Runtime image ─────────────────────────────────────────────────────────────
FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c

ARG DEERFLOW_VERSION=v2.0-m1
LABEL org.opencontainers.image.source="https://github.com/bytedance/deer-flow" \
      io.cloudron.deerflow.version="${DEERFLOW_VERSION}"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    nginx \
    supervisor \
    gosu \
    git \
    jq \
    python3 \
    python3-yaml \
    pandoc \
    poppler-utils \
    qpdf \
    ffmpeg \
    imagemagick \
    unzip \
    zip \
    postgresql-client \
    gettext-base \
  && rm -rf /var/lib/apt/lists/*

# Node.js 22 (DeerFlow frontend + npx MCP)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable && corepack install -g pnpm@10.26.2

COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker

RUN mkdir -p /app/code /run/nginx /run/supervisor \
  && rm -f /etc/nginx/sites-enabled/default || true

COPY --from=uv-source /uv /uvx /usr/local/bin/

WORKDIR /app/code

# Application tree
COPY --from=fetch /src/repo/skills ./skills
COPY --from=fetch /src/repo/config.example.yaml /app/code/config.example.yaml
COPY --from=backend-build /build/backend ./backend
COPY --from=frontend-build /build/frontend ./frontend

# Cloudron-specific files (this packaging repo)
COPY start.sh /app/code/start.sh
COPY supervisord.conf /app/code/supervisord.conf
COPY nginx/nginx.conf.template /app/code/nginx/nginx.conf.template
COPY cloudron/scripts/merge_runtime_config.py /app/code/cloudron/scripts/merge_runtime_config.py
COPY cloudron/default-config.yaml /app/code/cloudron/default-config.yaml
COPY cloudron/default-extensions_config.json /app/code/cloudron/default-extensions_config.json
COPY skills/cloudron-postgresql /app/code/skills/cloudron-postgresql

RUN chmod +x /app/code/start.sh /app/code/cloudron/scripts/merge_runtime_config.py \
  && printf '%s\n' "${DEERFLOW_VERSION}" > /app/code/DEERFLOW_UPSTREAM_VERSION

ENV DEER_FLOW_REPO_ROOT=/app/code \
    DEER_FLOW_HOME=/app/data/deer-flow \
    DEER_FLOW_CONFIG_PATH=/app/data/config.yaml \
    DEER_FLOW_EXTENSIONS_CONFIG_PATH=/app/data/extensions_config.json \
    PYTHONPATH=/app/code/backend \
    PORT=8000

EXPOSE 8000

CMD [ "/app/code/start.sh" ]
