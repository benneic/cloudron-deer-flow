#!/usr/bin/env python3
"""When CLOUDRON_POSTGRESQL_URL is set, set DeerFlow Postgres checkpointer in config.yaml."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import yaml


def main() -> int:
    pg_url = os.environ.get("CLOUDRON_POSTGRESQL_URL", "").strip()
    if not pg_url:
        print("merge_runtime_config: CLOUDRON_POSTGRESQL_URL unset, leaving config unchanged")
        return 0

    path = Path(os.environ.get("DEER_FLOW_CONFIG_PATH", "/app/data/config.yaml"))
    if not path.is_file():
        print(f"merge_runtime_config: skip, missing {path}", file=sys.stderr)
        return 0

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    desired = {"type": "postgres", "connection_string": pg_url}
    if data.get("checkpointer") == desired:
        print("merge_runtime_config: checkpointer already matches Postgres addon")
        return 0

    data["checkpointer"] = desired
    path.write_text(
        yaml.safe_dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    print("merge_runtime_config: wrote checkpointer.type=postgres from CLOUDRON_POSTGRESQL_URL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
