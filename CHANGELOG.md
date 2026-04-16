# Changelog

## 1.0.0 — 2026-04-16

- Initial Cloudron package: DeerFlow **v2.0-m1** upstream pin, gateway mode (nginx + Next.js + FastAPI), `localstorage` + `postgresql` + `docker` addons, Better Auth secret on `/app/data`, optional Postgres checkpointer merge at boot, `cloudron-postgresql` skill, tooling (pandoc, poppler, qpdf, ffmpeg, ImageMagick, zip/unzip, `postgresql-client`, Docker CLI).
- Default `config.yaml` seeds an **Ollama** model; Docker image installs **`deerflow-harness[ollama]`** (same as upstream’s optional extra) so operators do not run extra `uv pip` steps.
