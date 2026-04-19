#!/usr/bin/env python3
"""Write runtime files for the Next.js frontend (Better Auth).

- frontend_cloudron.env — shell exports for run-frontend.sh / pnpm.
- frontend_cloudron_next.json — explicit base URL read by patched better-auth config.ts
  (Next.js production builds often inline process.env at build time, so Node never sees
  BETTER_AUTH_BASE_URL from the shell even when set correctly).

If CLOUDRON_APP_ORIGIN is missing, derive https://<CLOUDRON_APP_DOMAIN> per Cloudron cheat sheet.
"""
from __future__ import annotations

import grp
import json
import os
import pwd
import shlex
from pathlib import Path

OUT = Path("/run/supervisor/frontend_cloudron.env")
OUT_JSON = Path("/run/supervisor/frontend_cloudron_next.json")


def _origin() -> str:
    v = (os.environ.get("CLOUDRON_APP_ORIGIN") or "").strip()
    if v:
        return v
    dom = (os.environ.get("CLOUDRON_APP_DOMAIN") or "").strip()
    if not dom:
        return ""
    dom = dom.lstrip("/").strip()
    return f"https://{dom}"


def _explicit_base() -> str:
    return (os.environ.get("BETTER_AUTH_BASE_URL") or "").strip()


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    origin = _origin()
    explicit = _explicit_base()
    effective = explicit or origin

    lines = [
        f"export CLOUDRON_APP_ORIGIN={shlex.quote(origin)}",
        f"export BETTER_AUTH_BASE_URL={shlex.quote(effective)}",
    ]
    text = "\n".join(lines) + "\n"
    OUT.write_text(text, encoding="utf-8")
    OUT_JSON.write_text(
        json.dumps({"baseURL": effective}, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    try:
        uid = pwd.getpwnam("cloudron").pw_uid
        gid = grp.getgrnam("cloudron").gr_gid
        os.chown(OUT, uid, gid)
        os.chown(OUT_JSON, uid, gid)
    except (KeyError, OSError):
        pass
    os.chmod(OUT, 0o640)
    os.chmod(OUT_JSON, 0o640)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
