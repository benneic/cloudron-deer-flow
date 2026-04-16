---
name: cloudron-postgresql
description: Use the Cloudron PostgreSQL addon from DeerFlow when this app is installed with the postgresql addon.
---

# Cloudron PostgreSQL (DeerFlow on Cloudron)

This DeerFlow package can be installed with the **postgresql** Cloudron addon. The platform injects credentials at runtime.

## Environment variables

Read these from the process environment (they may change across restarts):

- `CLOUDRON_POSTGRESQL_URL` — full connection URL (preferred for tools and scripts)
- `CLOUDRON_POSTGRESQL_HOST`, `CLOUDRON_POSTGRESQL_PORT`, `CLOUDRON_POSTGRESQL_USERNAME`, `CLOUDRON_POSTGRESQL_PASSWORD`, `CLOUDRON_POSTGRESQL_DATABASE`

## Command-line access

```bash
psql "$CLOUDRON_POSTGRESQL_URL" -c 'SELECT version();'
```

Or with discrete variables:

```bash
PGPASSWORD="$CLOUDRON_POSTGRESQL_PASSWORD" psql -h "$CLOUDRON_POSTGRESQL_HOST" -p "$CLOUDRON_POSTGRESQL_PORT" -U "$CLOUDRON_POSTGRESQL_USERNAME" -d "$CLOUDRON_POSTGRESQL_DATABASE"
```

## How DeerFlow uses it

When `CLOUDRON_POSTGRESQL_URL` is present, `start.sh` runs `merge_runtime_config.py`, which sets:

```yaml
checkpointer:
  type: postgres
  connection_string: "<value from CLOUDRON_POSTGRESQL_URL>"
```

This is intended for **LangGraph checkpoint persistence**. It is not a general-purpose application schema; avoid dropping tables the harness may create unless you intend to reset agent state.

## Safety

- Prefer **read-only** exploration (`SELECT`) unless the user explicitly wants migrations or data changes.
- Cloudron **backs up the database addon separately** from `/app/data` (localstorage). Plan restores accordingly.
- The addon database is dedicated to this app instance; still use clear table naming and avoid colliding with DeerFlow-managed objects.

## Application data

User uploads, thread files, and Better Auth secrets live under **`/app/data`** (localstorage), not in Postgres unless you add your own integration.
