#!/bin/bash
set -euo pipefail

PORT="${PORT:-8000}"
export PORT

mkdir -p /app/data/deer-flow /app/data/home /run/nginx /run/supervisor
# Nginx runs as cloudron; it must not mkdir() under /run/nginx as non-root (permission denied).
mkdir -p /run/nginx/client_temp /run/nginx/proxy_temp /run/nginx/fastcgi_temp /run/nginx/uwsgi_temp /run/nginx/scgi_temp
: >>/run/nginx/access.log 2>/dev/null || true
: >>/run/nginx/error.log 2>/dev/null || true
chown -R cloudron:cloudron /app/data /run/nginx

# Better Auth secret (persist across restarts)
_secret="/app/data/.better-auth-secret"
if [[ -z "${BETTER_AUTH_SECRET:-}" ]]; then
  if [[ -f "${_secret}" ]]; then
    export BETTER_AUTH_SECRET
    BETTER_AUTH_SECRET="$(cat "${_secret}")"
  else
    BETTER_AUTH_SECRET="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
    printf '%s' "${BETTER_AUTH_SECRET}" >"${_secret}"
    chmod 600 "${_secret}"
    chown cloudron:cloudron "${_secret}"
  fi
  export BETTER_AUTH_SECRET
fi

# First boot: seed config from packaging defaults
if [[ ! -f /app/data/config.yaml ]]; then
  cp /app/code/cloudron/default-config.yaml /app/data/config.yaml
  chown cloudron:cloudron /app/data/config.yaml
fi
if [[ ! -f /app/data/extensions_config.json ]]; then
  cp /app/code/cloudron/default-extensions_config.json /app/data/extensions_config.json
  chown cloudron:cloudron /app/data/extensions_config.json
fi

# LangGraph API runtime files — must live under a path Cloudron marks writable (see CloudronManifest.json
# `runtimeDirs`). /app/code is read-only; we cannot symlink into it from /app/data.
mkdir -p /app/code/backend/.langgraph_api
chown -R cloudron:cloudron /app/code/backend/.langgraph_api

# Cloudron docker addon → Docker CLI
if [[ -n "${CLOUDRON_DOCKER_HOST:-}" ]]; then
  export DOCKER_HOST="${CLOUDRON_DOCKER_HOST}"
fi

# Optional Postgres checkpointer
python3 /app/code/cloudron/scripts/merge_runtime_config.py
chown cloudron:cloudron /app/data/config.yaml 2>/dev/null || true

# Gateway worker count from cgroup memory (Cloudron skill pattern)
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
  memory_limit="$(cat /sys/fs/cgroup/memory.max)"
  [[ "${memory_limit}" == "max" ]] && memory_limit=$((2 * 1024 * 1024 * 1024))
else
  memory_limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo 268435456)"
fi
GATEWAY_WORKERS=$((memory_limit / 1024 / 1024 / 150))
GATEWAY_WORKERS=$((GATEWAY_WORKERS > 8 ? 8 : GATEWAY_WORKERS))
GATEWAY_WORKERS=$((GATEWAY_WORKERS < 1 ? 1 : GATEWAY_WORKERS))
# Postgres LangGraph checkpointer runs migrations at import; multiple uvicorn workers
# race and hit UniqueViolation (e.g. pg_type_typname_nsp_index / checkpoint_migrations_pkey).
if [[ -n "${CLOUDRON_POSTGRESQL_URL:-}" ]]; then
  GATEWAY_WORKERS=1
fi
export GATEWAY_WORKERS

# Nginx: gateway mode — LangGraph compat on same uvicorn
export LANGGRAPH_UPSTREAM="127.0.0.1:8001"
export LANGGRAPH_REWRITE="/api/"
envsubst '$PORT $LANGGRAPH_UPSTREAM $LANGGRAPH_REWRITE' </app/code/nginx/nginx.conf.template >/run/nginx/nginx.conf

# Supervisord [program:frontend] replaces the child environment. Capture Better Auth URLs from
# the full container env (Python sees the same dict as PID1 had before exec supervisord).
python3 /app/code/cloudron/scripts/write_frontend_better_auth_env.py

exec /usr/bin/supervisord -c /app/code/supervisord.conf
