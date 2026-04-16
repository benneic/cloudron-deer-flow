# DeerFlow for Cloudron

This repository packages **[DeerFlow](https://github.com/bytedance/deer-flow)** (an AI agent “harness” that can research, use tools, run sandboxes, and more) so it runs on **[Cloudron](https://www.cloudron.io/)**—a platform that installs web apps on your own server with HTTPS, backups, and a simple dashboard.

You do **not** need to understand Docker or coding to operate the app day to day. You *do* need to add your own AI provider keys and a few settings so logins and the AI work correctly.

---

## What you get

- A web interface for DeerFlow, secured with **Better Auth** (accounts / sessions handled inside the app).
- **Persistent data** (settings, sessions, agent data) stored in Cloudron’s app data area.
- Optional **PostgreSQL** for advanced state storage, and optional **Docker** for isolated “sandbox” tools (browser, shell, etc.)—see below.

---

## Before you install

1. **Server resources**  
   DeerFlow is heavy. This package sets a **8 GB memory** limit in the manifest; your Cloudron server should have enough RAM for that plus the rest of your apps.

2. **Addons** (chosen when you install or later in the app’s **Storage / Services** area):
   - **Local storage** — required (this is normal for most Cloudron apps).
   - **PostgreSQL** — optional; used for LangGraph “checkpoint” data when enabled.
   - **Docker** — optional; **only super-admins** can enable it on many Cloudron servers. It powers DeerFlow’s **AioSandbox** (stronger isolation for tools). If you skip it, you may need to change sandbox settings in `config.yaml` (advanced).

3. **AI backend**  
   The default config uses **Ollama** on your network (no cloud API key required). You can switch to hosted APIs (OpenAI, Anthropic, OpenRouter, etc.) in **`config.yaml`** instead—see [AI models and keys](#3-ai-models-and-keys).

---

## Installing

Packagers and developers build from this repo and push an image, or use Cloudron’s build flow. If you received a pre-built app package, install it from the Cloudron App Store or from your administrator’s instructions.

Technical build/update steps: see [`RELEASING.md`](RELEASING.md).

---

## First-time configuration

### 1. Public URL for login (Better Auth / `BETTER_AUTH_BASE_URL`)

DeerFlow’s login system (**Better Auth**) needs the **public URL** of the app (same address you type in the browser, starting with `https://`).

**On Cloudron you usually do nothing here.** This package sets **`BETTER_AUTH_BASE_URL`** from Cloudron’s built-in **`CLOUDRON_APP_ORIGIN`** at startup when you have not set `BETTER_AUTH_BASE_URL` yourself. That value is the correct HTTPS origin for your app behind Cloudron’s reverse proxy.

**When to set it manually** (in the app **Environment** screen or via `cloudron env set`):

- You use **alias domains** or a special public URL and Better Auth must match that exact origin.
- You are **debugging** and want to force a specific base URL.

Example:

```text
cloudron env set --app deerflow.example.com BETTER_AUTH_BASE_URL=https://deerflow.example.com
```

Use one canonical URL (no trailing slash unless your upstream docs require it).

### 2. Signing secret (`BETTER_AUTH_SECRET`)

- **Usually you do nothing.** On first start, the package generates a random secret and saves it under app data so sessions survive restarts.
- **Advanced:** You can set `BETTER_AUTH_SECRET` yourself in the app environment if you need to rotate secrets or match another environment. If unset, the saved file is used.

### 3. AI models and keys

The packaged default **`/app/data/config.yaml`** includes **one Ollama model** so you can run without cloud API keys if you already use [Ollama](https://ollama.com/) on your network.

**Ollama (default in this package)**

1. Install and run Ollama on a machine that this Cloudron server can reach (another PC, a LAN server, NAS, etc.).
2. Open the app **File manager** and edit **`/app/data/config.yaml`**.
3. Under **`models:`**, find the **`ollama`** entry and set **`base_url`** to that machine’s address and port **`11434`**.  
   Do **not** use `http://127.0.0.1:11434` here: inside the app container, “localhost” is the container itself, not your home PC. Use a **LAN IP** (e.g. `http://192.168.1.50:11434`), **Tailscale IP**, or similar. Adjust **`model`** to match a model you have pulled in Ollama (e.g. `llama3.2`, `qwen2.5`).



**Other providers (OpenAI, Anthropic, OpenRouter, …)**

Add or replace models under **`models:`** and put API keys in the app’s **Environment** (or reference variables like `$OPENAI_API_KEY` from config). The **master reference** for every option is upstream’s  
[master `config.example.yaml` (raw)](https://raw.githubusercontent.com/bytedance/deer-flow/refs/heads/main/config.example.yaml).  
Also: [browse on GitHub](https://github.com/bytedance/deer-flow/blob/main/config.example.yaml) and [Install.md](https://github.com/bytedance/deer-flow/blob/main/Install.md).

### 4. Optional: environment variables for tools

Many tools (search, fetch, etc.) read keys from the environment (e.g. `TAVILY_API_KEY`, `JINA_API_KEY`). Add them the same way as other custom variables ([dashboard **Environment** or `cloudron env set`](#how-cloudron-handles-environment-variables)).

---

## PostgreSQL (optional)

If the **PostgreSQL** addon is enabled, the app automatically updates **`/app/data/config.yaml`** on startup to use the database for LangGraph checkpoint storage. You normally do **not** edit the connection string by hand.

A short guide for agents and operators lives in the bundled skill:  
[`skills/cloudron-postgresql/SKILL.md`](skills/cloudron-postgresql/SKILL.md).

---

## Docker / sandbox (optional)

Full **browser- and container-style** sandbox features expect the **Docker** addon and a working Docker API (`CLOUDRON_DOCKER_HOST`). That is a **powerful** capability—only use it if you understand the security implications. The default packaged `config.yaml` targets **AioSandbox**; your administrator may adjust this for your server.

---

## Where your data lives

| Location | What |
|----------|------|
| `/app/data/` | Main persistent data: config, Better Auth secret file, agent home, etc. |
| Cloudron backups | Include app data; PostgreSQL is backed up separately if that addon is on. |

Use Cloudron’s **backup** features for the app and database as usual.

---

## Updating

When your packager publishes a new version: update the app from the Cloudron dashboard (or CLI) like any other Cloudron app.  
Version pins and upstream DeerFlow tags are described in [`RELEASING.md`](RELEASING.md) and [`CHANGELOG.md`](CHANGELOG.md).

---

## Help and upstream

- **DeerFlow** (features, models, safety): [bytedance/deer-flow](https://github.com/bytedance/deer-flow)  
- **Master DeerFlow `config.example.yaml`** (full schema and comments): [raw on `main`](https://raw.githubusercontent.com/bytedance/deer-flow/refs/heads/main/config.example.yaml)  
- **Cloudron packaging** (including [environment variables cheat sheet](https://docs.cloudron.io/packaging/cheat-sheet/#environment-variables)): [Cloudron docs — packaging](https://docs.cloudron.io/packaging/)  
- **This package** issues: use this repository’s issue tracker if your administrator or packager points you here.

---

## License

See [`LICENSE`](LICENSE). DeerFlow itself is MIT-licensed upstream; this packaging repo adds its own files under the same spirit—check the repository for details.
