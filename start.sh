#!/bin/bash
set -euo pipefail

PORT="${PORT:-8000}"
export PORT

# Better Auth public URL: Cloudron injects CLOUDRON_APP_ORIGIN (see packaging cheat sheet).
# If unset (e.g. local testing), leave BETTER_AUTH_BASE_URL unset unless the operator set it.
if [[ -z "${BETTER_AUTH_BASE_URL:-}" && -n "${CLOUDRON_APP_ORIGIN:-}" ]]; then
  export BETTER_AUTH_BASE_URL="${CLOUDRON_APP_ORIGIN}"
fi
# Supervisord requires %(ENV_BETTER_AUTH_BASE_URL)s to exist; default to empty off-Cloudron.
export BETTER_AUTH_BASE_URL="${BETTER_AUTH_BASE_URL:-}"

mkdir -p /app/data/deer-flow /app/data/home /run/nginx /run/supervisor
chown -R cloudron:cloudron /app/data

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

# LangGraph API metadata directory (writable)
mkdir -p /app/data/langgraph_api
rm -rf /app/code/backend/.langgraph_api
ln -sfn /app/data/langgraph_api /app/code/backend/.langgraph_api
chown -h cloudron:cloudron /app/code/backend/.langgraph_api 2>/dev/null || true

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
export GATEWAY_WORKERS
GATEWAY_WORKERS=$((memory_limit / 1024 / 1024 / 150))
GATEWAY_WORKERS=$((GATEWAY_WORKERS > 8 ? 8 : GATEWAY_WORKERS))
GATEWAY_WORKERS=$((GATEWAY_WORKERS < 1 ? 1 : GATEWAY_WORKERS))

# Nginx: gateway mode — LangGraph compat on same uvicorn
export LANGGRAPH_UPSTREAM="127.0.0.1:8001"
export LANGGRAPH_REWRITE="/api/"
envsubst '$PORT $LANGGRAPH_UPSTREAM $LANGGRAPH_REWRITE' </app/code/nginx/nginx.conf.template >/run/nginx/nginx.conf

exec /usr/bin/supervisord -c /app/code/supervisord.conf
