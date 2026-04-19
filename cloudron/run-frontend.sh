#!/bin/bash
set -euo pipefail
# start.sh writes export lines (shlex-quoted) before exec supervisord — see
# cloudron/scripts/write_frontend_better_auth_env.py
if [[ -f /run/supervisor/frontend_cloudron.env ]]; then
  # shellcheck disable=SC1091
  source /run/supervisor/frontend_cloudron.env
fi
export BETTER_AUTH_BASE_URL="${BETTER_AUTH_BASE_URL:-${CLOUDRON_APP_ORIGIN:-}}"
cd /app/code/frontend
exec corepack pnpm start
