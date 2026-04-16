# Releasing / updating DeerFlow on Cloudron

## Pin upstream

1. Pick a stable [DeerFlow tag](https://github.com/bytedance/deer-flow/tags) (or branch).
2. Update [`DEERFLOW_VERSION`](DEERFLOW_VERSION) in this repository.
3. Update `upstreamVersion` in [`CloudronManifest.json`](CloudronManifest.json) at the repository root to match.
4. Bump semver `version` in `CloudronManifest.json` for the Cloudron package itself.
5. Add an entry to [`CHANGELOG.md`](CHANGELOG.md) (upstream tag, notable manifest or config changes).
6. If upstream bumped `config_version` in `config.example.yaml`, run upstream’s `make config-upgrade` guidance for existing installs, or document manual merge steps in the changelog. The current upstream master template is [`config.example.yaml` on `main`](https://raw.githubusercontent.com/bytedance/deer-flow/refs/heads/main/config.example.yaml).

## Build and deploy

From the repository root (with the [Cloudron CLI](https://docs.cloudron.io/packaging/) logged in):

```bash
docker build --build-arg "DEERFLOW_VERSION=$(tr -d '\n' < DEERFLOW_VERSION)" -t your-registry/org-deerflow-cloudron:$(jq -r .version CloudronManifest.json) .
docker push your-registry/org-deerflow-cloudron:$(jq -r .version CloudronManifest.json)
cloudron install --image "your-registry/org-deerflow-cloudron:$(jq -r .version CloudronManifest.json)"
# later:
cloudron update
```

Or use `cloudron build` / on-server build flows described in the Cloudron packaging skill.

## Optional automation

The workflow [`.github/workflows/upstream-version-reminder.yml`](.github/workflows/upstream-version-reminder.yml) runs weekly (and on demand) and prints the pinned `DEERFLOW_VERSION` alongside the latest GitHub **release** tag for `bytedance/deer-flow`. It does not open PRs; bump the pin and manifest manually per the steps above.
