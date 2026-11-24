#!/usr/bin/env bash
# apply-patches.sh — sequentially apply the INIM i2pd-fork patch series with `git am`.
# Run from the root of a clean i2pd checkout at the pinned base (see ../UPSTREAM.md).
# Used by CI (.github/workflows/build-i2pd-fork.yml) and for local forking.
#
# Exit status: 0 only when every patch applied; any failure aborts (set -e / -o pipefail).
# Note for CI wrappers: if you pipe this script (`| tee`), enable `set -o pipefail`
# in the caller too, otherwise a failure here is masked by the pipe tail (round 6).
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../patches" && pwd)"
BASE_COMMIT="${BASE_COMMIT:-635b013a612ff47278ef02acf8580a28e10e26c5}"
shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found in $PATCH_DIR" >&2
  exit 1
fi

# git am needs a committer identity; a fresh upstream clone has none — without
# this every `git am` dies with "Committer identity unknown" (round 6).
git config user.name "INIM CI"
git config user.email "ci@inim.local"

echo "=== patch count: ${#patches[@]} ==="
for p in "${patches[@]}"; do
  echo "== git am $(basename "$p")"
  git am "$p" 2>&1
done

echo "OK: ${#patches[@]} patch(es) applied on $(git log --oneline -1)"
echo "=== applied patch ids ($BASE_COMMIT..HEAD) ==="
git log --oneline "$BASE_COMMIT..HEAD"