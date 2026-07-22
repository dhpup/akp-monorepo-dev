# rollouts-app

Source application for the Akuity Platform quickstart — see the [akp-monorepo-dev README](../../README.md) and the [akp-platform-dev](https://github.com/example-org/akp-platform-dev) repo for the GitOps side.

A simple Go web app that displays a grid of colored tiles. The color is baked in at build time and changes with each image tag, making it easy to visually confirm which build is running in each environment.

Derived from the upstream [argoproj/rollouts-demo](https://github.com/argoproj/rollouts-demo) app — the Go module path (and thus the `rollouts-demo` binary name the Dockerfile expects) is kept as-is.

## Image

Published to: `ghcr.io/example-org/akp-monorepo-dev-rollouts-app`

| Kind | Regex | Example |
|------|-------|---------|
| Release | `^\d+-[a-z]+$` | `42-blue` |
| Preview | `^pr-\d+-.+$` | `pr-7-green` |

Tags are produced by the CI workflows in [`.github/workflows/`](../../.github/workflows/); Kargo (configured in akp-platform-dev) watches the registry and promotes new tags. Don't invent new tag schemes — the platform repo's Warehouse regexes depend on these.

## Local development

```bash
make run          # run on :8080
make build        # build the rollouts-demo binary
make image COLOR=blue   # build a local image
```

`./release.sh` builds the full local color matrix (all six colors, plus slow/error variants) — useful for local experimentation; real releases go through [`publish-rollouts-app.yml`](../../.github/workflows/publish-rollouts-app.yml) on merge to `main`.
