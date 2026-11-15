#!/usr/bin/env bash
# apply-patches.sh — sequentially apply the INIM i2pd-fork patch series with `git am`.
# Run from the root of a clean i2pd checkout at the pinned base (see ../UPSTREAM.md).
# Used by CI (.github/workflows/build-i2pd-fork.yml) and for local forking.
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches" && pwd)"

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found in $PATCH_DIR" >&2
  exit 1
fi

for p in "${patches[@]}"; do
  echo "== git am $(basename "$p")"
  git am "$p"
done

echo "OK: ${#patches[@]} patch(es) applied on $(git log --oneline -1)"