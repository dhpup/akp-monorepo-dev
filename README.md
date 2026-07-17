# akp-monorepo

The **application monorepo** in a three-repo [Akuity Platform](https://akuity.io) quickstart:

| Repo | Role |
|------|------|
| [akp-platform](https://github.com/example-org/akp-platform) | GitOps configuration — Argo CD apps, Kargo pipelines, deployment manifests |
| **akp-monorepo** (this repo) | Application source code + CI that builds and tags container images |
| [akp-infra](https://github.com/example-org/akp-infra) | Terraform for the Akuity Platform resources (clusters, Argo CD, Kargo) |

The division of labor is strict: **CI in this repo only builds and tags images — it never touches a cluster.** Kargo (configured in [akp-platform](https://github.com/example-org/akp-platform)) watches the container registry, detects new tags, and promotes them through environments via Git commits. If you're looking for deployment manifests, promotion pipelines, or cluster config, they live in the platform repo, not here.

```
push to main ──► GitHub Actions ──► ghcr.io image tag ──► Kargo Warehouse (akp-platform) ──► promotion
```

## Apps

| App | Source | Image |
|-----|--------|-------|
| rollouts-app | [`apps/rollouts-app/`](apps/rollouts-app/) | `ghcr.io/example-org/akp-monorepo-rollouts-app` |

rollouts-app is a small Go web app that renders a grid of colored tiles — the color is baked in at build time, so you can see at a glance which build is running in each environment.

## Image tag contract

Kargo Warehouses in the platform repo select images by tag regex, so the tag scheme is a **contract** — don't change it without changing the platform side too. The two patterns are mutually exclusive: release Warehouses never match preview tags and vice versa.

| Kind | Pattern | Regex | Example | Color derivation |
|------|---------|-------|---------|------------------|
| Release | `<run_number>-<color>` | `^\d+-[a-z]+$` | `42-blue` | workflow run number % 6 |
| Preview | `pr-<N>-<color>` | `^pr-\d+-.+$` | `pr-7-green` | PR number % 6 |

Colors cycle through `[red, green, blue, yellow, purple, orange]`. Releases also push a floating `:latest` tag (for humans — Kargo ignores it).

Images are published to `ghcr.io/example-org/akp-monorepo-rollouts-app`. The workflows derive the image name from `${{ github.repository }}` (lowercased) plus the `-rollouts-app` suffix, so forks publish to their own namespace with **zero workflow edits**.

## Setup

1. **Fork this repo.** Keep the name `akp-monorepo` and keep it **public** (the platform repo's manifests reference it by name, and Kargo pulls tags anonymously).
2. **Personalize it.** Replaces the `example-org` placeholder with your GitHub username/org in docs and image references (workflows need no changes — they derive everything from the repo name):
   ```bash
   ./personalize.sh
   git add -A && git commit -m "Personalize" && git push
   ```
3. **Enable GitHub Actions on the fork.** GitHub disables workflows on forks by default — go to the *Actions* tab and click *"I understand my workflows, enable them"*.
4. **Make the GHCR package public** after the first publish run: on GitHub go to your profile/org → *Packages* → `akp-monorepo-rollouts-app` → *Package settings* → *Change visibility* → *Public*. Kargo watches the registry anonymously, so a private package is invisible to it.

Platform-side wiring (Warehouses, promotion pipelines, ephemeral preview environments) is documented in the platform repo — see [akp-platform `docs/add-monorepo.md`](https://github.com/example-org/akp-platform/blob/main/docs/add-monorepo.md).

## Triggering a release

Edit anything under `apps/rollouts-app/` (even a comment), open a PR, and merge to `main`. The [`publish-rollouts-app`](.github/workflows/publish-rollouts-app.yml) workflow then:

1. Builds a multi-arch (amd64 + arm64) image.
2. Pushes it as `:latest` and `:<run_number>-<color>` (e.g. `42-blue`).
3. Pushes a matching git tag `<run_number>-<color>`.

Within its polling interval, Kargo notices the new release tag and makes it available for promotion in the platform repo's pipeline.

## PR previews

Opening a PR that touches `apps/rollouts-app/` builds a single-arch image tagged `pr-<N>-<color>`. Add the **`preview`** label to the PR to get a sticky comment with the image tag; once the platform repo's ephemeral-environments example is enabled, that label also provisions a per-PR preview environment in namespace `demo-ephemeral-pr-<N>`. Closing the PR triggers a best-effort cleanup of its `pr-<N>-*` image versions from GHCR.

## Adding a second app

1. Create `apps/<name>/` with a self-contained build (its own `go.mod`/`package.json` and a `Dockerfile`).
2. Copy the workflow pair: `publish-rollouts-app.yml` → `publish-<name>.yml` and `preview-rollouts-app.yml` → `preview-<name>.yml`. Change the path filters to `apps/<name>/**` (plus the workflow file itself), the build context/Dockerfile paths, and the image-name suffix (`-rollouts-app` → `-<name>`).
3. **Never invent a new tag scheme.** Reuse the release/preview patterns above verbatim — the platform repo's Warehouse regexes depend on them.
4. Wire up the platform side following [akp-platform `docs/add-monorepo.md`](https://github.com/example-org/akp-platform/blob/main/docs/add-monorepo.md).

## Workflows

| Workflow | Trigger | Does |
|----------|---------|------|
| [`publish-rollouts-app.yml`](.github/workflows/publish-rollouts-app.yml) | push to `main` touching `apps/rollouts-app/**` | multi-arch build, push `:latest` + `:<run#>-<color>`, push git tag |
| [`preview-rollouts-app.yml`](.github/workflows/preview-rollouts-app.yml) | PR opened/updated/labeled touching `apps/rollouts-app/**` | single-arch build, push `:pr-<N>-<color>`, sticky comment if labeled `preview` |
| [`cleanup-preview-rollouts-app.yml`](.github/workflows/cleanup-preview-rollouts-app.yml) | PR closed | best-effort deletion of `pr-<N>-*` GHCR versions |
| [`create-release.yml`](.github/workflows/create-release.yml) | manual tag push | `gh release create --generate-notes` (tags pushed by CI's own token don't re-trigger workflows) |

All workflows authenticate to GHCR with the built-in `GITHUB_TOKEN` — no secrets or repo variables to configure.
