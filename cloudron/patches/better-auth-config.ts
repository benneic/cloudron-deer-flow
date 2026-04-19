/**
 * Cloudron packaging: pass explicit `baseURL` so Better Auth does not rely on
 * `process.env.BETTER_AUTH_BASE_URL` at runtime (Next production bundles often
 * inline env at build time). Resolved URL is written at container start to
 * `/run/supervisor/frontend_cloudron_next.json` by write_frontend_better_auth_env.py.
 */
import { readFileSync } from "node:fs";

import { betterAuth } from "better-auth";

const RUNTIME_BASE_JSON = "/run/supervisor/frontend_cloudron_next.json";

function resolveBaseURL(): string | undefined {
  try {
    const j = JSON.parse(readFileSync(RUNTIME_BASE_JSON, "utf8")) as {
      baseURL?: string;
    };
    const fromFile = j.baseURL?.trim();
    if (fromFile) return fromFile;
  } catch {
    // Local dev / build: file absent
  }

  const explicit = process.env["BETTER_AUTH_BASE_URL"]?.trim();
  if (explicit) return explicit;
  const origin = process.env["CLOUDRON_APP_ORIGIN"]?.trim();
  if (origin) return origin;
  const dom = process.env["CLOUDRON_APP_DOMAIN"]?.trim();
  if (dom) return `https://${dom.replace(/^\/+/, "")}`;
  return undefined;
}

export const auth = betterAuth({
  baseURL: resolveBaseURL(),
  emailAndPassword: {
    enabled: true,
  },
});

export type Session = typeof auth.$Infer.Session;
