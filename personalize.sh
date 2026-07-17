#!/usr/bin/env bash
#
# personalize.sh — rewrite the `example-org` placeholder to your GitHub
# username or org across this repo's docs and manifests.
#
# - ghcr.io image references get the LOWERCASED name (GHCR requires it).
# - github.com repo URLs keep the case exactly as you typed it.
# - Workflows under .github/workflows are intentionally untouched: they
#   derive the image name from ${{ github.repository }} at runtime, so
#   forks need zero workflow edits.
set -euo pipefail

cd "$(dirname "$0")"

# Portable in-place sed: GNU sed takes -i, BSD/macOS sed takes -i ''.
if sed --version >/dev/null 2>&1; then SEDI=(-i); else SEDI=(-i ''); fi

read -r -p "GitHub username or org for your forks: " GH_OWNER
if [ -z "${GH_OWNER}" ]; then
  echo "No username/org given — nothing to do." >&2
  exit 1
fi
# Lowercased copy for container image references (GHCR names are lowercase).
GH_OWNER_LC=$(printf '%s' "${GH_OWNER}" | tr '[:upper:]' '[:lower:]')

echo "Rewriting example-org -> ${GH_OWNER} (images: ${GH_OWNER_LC}) ..."

# All *.md files, plus any *.yaml outside .github/workflows.
find . \
    -path './.git' -prune -o \
    -type f \( -name '*.md' -o \( -name '*.yaml' ! -path './.github/workflows/*' \) \) \
    -print0 |
  while IFS= read -r -d '' f; do
    sed -E "${SEDI[@]}" \
      -e "s|ghcr\.io/example-org|ghcr.io/${GH_OWNER_LC}|g" \
      -e "s|github\.com/example-org|github.com/${GH_OWNER}|g" \
      "$f"
    echo "  updated: $f"
  done

echo "Done. Review with 'git diff', then commit and push."
