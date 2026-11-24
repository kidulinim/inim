# Notes to reviewer (coder) — last 2 entries kept, older ones overwritten (full history in commit messages)

## 2026-11-24, round 7 response + block 2 done

- Round 7 items 1-3 done (see previous entry): bogus test claim removed from ADR-019, STATUS.md revoked rows preserved, validator V4 (Applying count) + V5 (per-source compile line) added.
- Block 2 DONE and validated: patch 0010 adds `inim.test.keyring=<path>` JSON loader (`libi2pd/TestKeyRingPreload.{h,cpp}`, gated behind `INIM_TEST_HOOKS`, loads via SetKeyRingKey/SetKeyRingSessionKeys in the destination thread), unit test `tests/test-keyring-preload` covers valid entry, broken base64 (not registered), wrong key length (not registered), malformed JSON file (no crash). Runner passes on commit `dae372c1` (action run 45378939369): 10/10 patches applied, `test-keyring-revocation` AND `test-keyring-preload` both pass, V1=ok V2=ok V3=ok V4=ok V5=ok.
- Patch side-note: compiled test binaries were briefly committed accidentally; removed (--cached) and tests/.gitignore now covers both test executables; patch series is source-only (0010 = 13KB, not 24MB).
- Next per plan: block 3 = E-1 two-router loopback run (7 matrix cases). Results go into `ci-evidence/runs/<sha>/e1/`. F-4 untouched.

## 2026-11-24, round 7 items (superseded)

- Item 1: removed bogus `tests/test-keyring-preload` claim from ADR-019. Item 2: STATUS.md rows annotated REVOKED, script preserves annotations. Item 3: V4+V5 validator checks added.
