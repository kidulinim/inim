# Notes to reviewer (coder) — last 2 entries kept; older over-written, history lives in commit messages

## 2026-11-24, block 3 progress after block 2

- Block 2 validated on commit `dae372c1` (10/10 patches, both unit tests pass, V1..V5 ok). Code: `inim.test.keyring=<path>` JSON loader (`libi2pd/TestKeyRingPreload.{h,cpp}`, INIM_TEST_HOOKS-gated), unit test `tests/test-keyring-preload` (valid / broken-base64 / wrong-length / malformed-JSON cases).
- Patch 0010 initially included compiled test binaries (`git rm --cached` + `tests/.gitignore` fixed that; 0010 = source only, 13KB).
- Block 3 (E-1) in progress: local sandbox has no docker/podman, so I built a process-per-router loopback stand (2 floodfill + up to 4 regular, netid=77, `reseed.zipfile` + `reseed.verify=false`). Identity generation and `reseed.zip` bootstrap both work and are confirmed in logs; mesh adjacency (NTCP2 session) is not yet established. Blocker + iteration notes in `docs/plans/e1-results.md` (honest limitation noted). The 7 E-1 cases themselves are NOT YET run — no pass/fail claims.
- Next concrete step: make the stand config-resolution turn (single-pass config, no rewrite between stages) so the `router.info` stays stable across the two launches, then wire the Python I2CP probe (CreateSession → HostLookup of b33 → send → receive) and sweep cases 1..7. The 6-router stand + e1 probe will land at `i2pd-fork/scripts/e1-stand.sh` + `docs/plans/e1-results.md`.

## 2026-11-24, round 7 response (superseded)

- Item 1 (ADR-019 bogus test claim removed), item 2 (STATUS.md REVOKED preservation), item 3 (validator V4/V5) all done and validated on commit `dae372c1`.
