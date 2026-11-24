#!/bin/sh
# ci-evidence.sh — collect and commit CI run evidence for a build-i2pd-fork run
# to the ci-evidence branch (never main). Run from the repository root after
# build.log has been accumulated by prior workflow steps.
#
# Round 6 hardening: "success" is declared only after *validating* build.log
# (works even when step outcomes claim success). The checks are:
#   V1  build.log contains "OK: N patch(es) applied" with N == number of
#       files in i2pd-fork/patches
#   V2  build.log contains "test-keyring-revocation: all checks passed"
#   V3  build.log does NOT contain "No rule to make target"
#   V4  number of "Applying:" lines equals number of patch files (round 7)
#   V5  at least one build-log line per patched source .cpp (round 7)
# If any check fails the record is written as overall: invalid regardless of
# what the actions runner reports. Default status is "unconfirmed", not
# "success". This is called *even on red runs* (if: always()).
#
# Usage (from the workflow Record evidence step, or locally for a manual run):
#   SHA=<full sha> OVERALL=<job.status: success|failure> \
#   WF_NAME=... RUN_URL=... \
#   S_DEPS=success S_FETCH=success ... (step outcomes) \
#   [CLONE_URL=<authenticated clone url>] [PUSH=0] \
#   i2pd-fork/scripts/ci-evidence.sh
set -eu

SHA="${SHA:-$(git rev-parse HEAD)}"
JOB_OVERALL="${OVERALL:-unconfirmed}"
WF_NAME="${WF_NAME:-build-i2pd-fork}"
RUN_URL="${RUN_URL:-}"
S_DEPS="${S_DEPS:-not_run}"
S_FETCH="${S_FETCH:-not_run}"
S_PATCHES="${S_PATCHES:-not_run}"
S_BUILD="${S_BUILD:-not_run}"
S_TESTS="${S_TESTS:-not_run}"
PUSH="${PUSH:-1}"
DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG_FILE="build.log"

# ---------- validation of build.log (the authoritative record) ----------
overall="$JOB_OVERALL"
evidence_notes=""
if [ ! -f "$LOG_FILE" ]; then
  overall="invalid"
  evidence_notes="$evidence_notes V1=missing-log V2=missing-log V3=missing-log V4=missing-log V5=missing-log"
else
  expected=$(ls i2pd-fork/patches/*.patch 2>/dev/null | wc -l)
  ok_line=$(grep -c '^OK: [0-9]* patch(es) applied' "$LOG_FILE" || true)
  ok_n=$(grep -o 'OK: [0-9]* patch(es) applied' "$LOG_FILE" | head -1 | cut -d' ' -f2 || true)
  if [ "$ok_line" -ge 1 ] && [ "$ok_n" = "$expected" ]; then
    v1=ok
    echo "V1 patches applied: $ok_n/$expected -- ok"
  else
    v1=FAIL
    echo "V1 patches applied: saw '${ok_n:-none}', expected $expected -- FAIL" >&2
  fi

  if grep -q 'test-keyring-revocation: all checks passed' "$LOG_FILE"; then
    v2=ok
    echo "V2 unit-test marker: ok" >&2
  else
    v2=FAIL
    echo "V2 unit-test marker: NOT FOUND -- FAIL" >&2
  fi

  if grep -q 'No rule to make target' "$LOG_FILE"; then
    v3=FAIL
    echo "V3 'No rule to make target' present (patch 2..n NOT applied) -- FAIL" >&2
  else
    v3=ok
    echo "V3 'No rule to make target' absent -- ok" >&2
  fi

  # V4 (round 7 item 3): every patch must have been really applied --
  # count "Applying:" lines == number of patch files.
  applying_n=$(grep -c '^Applying:' "$LOG_FILE" || true)
  if [ "$applying_n" = "$expected" ]; then
    v4=ok
    echo "V4 Applying: lines $applying_n/$expected -- ok"
  else
    v4=FAIL
    echo "V4 Applying: lines $applying_n/$expected -- FAIL" >&2
  fi

  # V5 (round 7 item 3): at least one compiler line per source file changed by
  # the patch series (Destination|Blinding|LeaseSet|I2CP|Garlic cpp files).
  v5=ok
  for src in Destination Blinding LeaseSet I2CP Garlic; do
    # the patch hunks modify "$src.cpp" under some directory; we require the
    # build log to contain at least one compile/mention line for that file.
    if ! grep -q "$src\.cpp" "$LOG_FILE"; then
      v5=FAIL
      echo "V5 no compile line for $src.cpp -- FAIL" >&2
    fi
  done
  if [ "$v5" = ok ]; then
    echo "V5 compile lines present for all patched sources -- ok"
  fi

  if [ "$v1" = "FAIL" ] || [ "$v2" = "FAIL" ] || [ "$v3" = "FAIL" ] || [ "$v4" = "FAIL" ] || [ "$v5" = "FAIL" ]; then
    overall="invalid"
    evidence_notes="$evidence_notes V1=$v1 V2=$v2 V3=$v3 V4=$v4 V5=$v5"
    echo "evidence validation FAILED -- record marked invalid (job status was: $JOB_OVERALL)" >&2
  else
    evidence_notes="$evidence_notes V1=ok V2=ok V3=ok V4=ok V5=ok"
    echo "evidence validation PASS"
  fi
fi

# ---------- write result.txt ----------
{
  echo "workflow: $WF_NAME"
  echo "run: $RUN_URL"
  echo "commit: $SHA"
  echo "date_utc: $DATE_UTC"
  echo "steps:"
  echo "  checkout: success"
  echo "  install_deps: $S_DEPS"
  echo "  fetch_upstream: $S_FETCH"
  echo "  apply_patches: $S_PATCHES"
  echo "  build: $S_BUILD"
  echo "  unit_tests: $S_TESTS"
  echo "evidence_validation:$evidence_notes"
  echo "overall: $overall"
} > result.txt

# receipt of the exact patch contents committed in this repo at $SHA
( cd i2pd-fork/patches && sha256sum ./*.patch ) > patches.sha256

# ---------- get/create ci-evidence branch in scratch checkout ----------
rm -rf .evidence-workdir
git init -q .evidence-workdir
cd .evidence-workdir
git config user.name "inim-ci"
git config user.email "ci@inim.local"
if [ -n "${CLONE_URL:-}" ]; then
  git remote add origin "$CLONE_URL"
else
  git remote add origin "$(git -C .. remote get-url origin)"
fi
if git fetch -q origin ci-evidence; then
  git checkout -q -b ci-evidence FETCH_HEAD
else
  git checkout -q --orphan ci-evidence
  echo "# CI evidence index" > STATUS.md
fi

mkdir -p "runs/$SHA"
cp ../result.txt ../build.log ../patches.sha256 "runs/$SHA/"

# STATUS.md: newest first, table of the latest 20 runs, filled by CI.
# Existing rows keep any "REVOKED" annotations verbatim (round 7 item 2): a row
# is only ever trimmed after 20 entries, never rewritten or reclassified here.
if ! grep -q '^| commit |' STATUS.md 2>/dev/null; then
  {
    echo '# CI evidence index'
    echo ''
    echo 'Generated by the `build-i2pd-fork` workflow (Record evidence step). To verify any'
    echo 'build/test claim for a commit: read `runs/<sha>/` in this branch.'
    echo ''
    echo '| commit | date_utc | overall | unit_tests | validation | run |'
    echo '|---|---|---|---|---|---|'
  } > STATUS.md
fi
row="| $SHA | $DATE_UTC | $overall | $S_TESTS | $evidence_notes | $RUN_URL |"
{ sed -n '1,7p' STATUS.md; echo "$row"; sed -n '8,$p' STATUS.md | head -19; } > STATUS.md.tmp
mv STATUS.md.tmp STATUS.md

git add -A
git commit -q -m "evidence: $SHA $overall ($DATE_UTC)"
if [ "$PUSH" = 1 ]; then
  git push -q origin HEAD:ci-evidence
  echo "evidence for $SHA pushed to ci-evidence (overall: $overall)"
else
  echo "evidence for $SHA recorded locally (PUSH=0, overall: $overall)"
fi
cd ..
rm -rf .evidence-workdir