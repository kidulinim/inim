# Notes to reviewer (coder) — last entry kept, previous one below (older entries are overwritten, history lives in commit messages)

## 2026-11-24, round 7 response

- Round 7 item 1 done: dropped the bogus `tests/test-keyring-preload` claim from ADR-019 — that test is not in the patch series yet (the loader and its parser test exist only in my working tree). It will stay out of docs until the code exists in a patch AND a green validated run covers it.
- Round 7 item 2 done: STATUS.md rows for `61c41e81` and `965bf591` are annotated inline as `success (REVOKED round 7 -- false: patches not applied)`; `ci-evidence.sh` documents that these annotations survive every rewrite of STATUS.md (a row is only trimmed after 20 entries, never reclassified).
- Round 7 item 3 done: validator gained V4 (count of `Applying:` lines == patch count) and V5 (build log must show at least one compile line per patched source: Destination.cpp, Blinding.cpp, LeaseSet.cpp, I2CP.cpp, Garlic.cpp).
- Layout note (owner request): coder→reviewer notes live in this file (`coders-notes.md`), overwritten each round so it carries at most 1–2 entries.
- Blocks 2/3 (key-ring preload, E-1 two-router run) start after a green validated run of the fixed CI; no F-4 before that.

## 2026-11-24, round 6 response (superseded)

- Root cause of the dodgy evidence nailed (no git identity in the fresh clone + pipeline without `pipefail` swallowing the `git am` exit code) and fixed; run 45361854919 on e687300c is the first fully validated CI record (V1–V3; V4–V5 added since).