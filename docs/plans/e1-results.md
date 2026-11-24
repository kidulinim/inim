# E-1 — first-look run results (block 3 of task-to-coder-ci-and-e1)

**Date**: 2026-11-24
**Commit tested**: `dae372c6` (validated V1..V5 evidence sits in `ci-evidence:runs/dae372c6…/`)
**Environment**: local Linux sandbox (no docker/podman, plain process-per-router over 127.0.0.1), all random seeds generated at runtime, nothing reusable shipped.

## What was validated for real

1. **Identity generation at startup** — a bare `i2pd` process launched with `--datadir=<fresh dir>` generates `router.keys`, `ntcp2.keys`, `ssu2.keys`, `router.info` without any network interaction (well before any peer is contacted). Internal netid is settable via `netid` option, isolated test nets are therefore safe (`netid=77` here).
2. **`reseed.zipfile` bootstrap** — a plain ZIP archive containing raw `router.info` blobs is accepted by i2pd as bootstrap input (`ProcessZIPStream`). No SU3 signature is required when `reseed.verify=false`; this is exactly what the task specifies ("свои router infos через `reseed.zipfile`, `reseed.verify=false` только для тестовой сети"). Confirmed by log: `NetDb: RouterInfo added: <id>` for every member of the archive.
3. **`inim.test.keyring` preload (block 2)** works end-to-end with the same router — unit test `test-keyring-preload` covers valid / broken-base64 / wrong-length / malformed-JSON paths; both unit tests pass on commit `dae372c6` (see `ci-evidence:runs/…/result.txt`, V2=ok).

## Current stand state — mesh connectivity NOT yet working

Built a 4-router (2 floodfill + 2 regular) and a 6-router (2 floodfill + 4 regular) stand inside `/tmp/e1-tighter`, `/tmp/e1-stand`. Each router:

- listens on its own TCP port (`ntcp2.enabled=true, ntcp2.published=true, ssu2.enabled=false`);
- is pinned to `host=127.0.0.1` in its `i2pd.conf` so loopback addresses are published in `router.info`;
- unique per-router `datadir` (identity is preserved across restarts);
- shared netid 77, no external reseeds/urls forced through config.

Stages run: (1) generate identities, no reseed; (2) build `reseed.zip` (Python `zipfile`) from the floodfills' `router.info`; (3) re-launch identical directories with `reseed.zipfile=<zip>`.

**Observation**: `reseed.zip` is parsed and the floodfill `router.info`s are loaded (`RouterInfo added: …` two per node), but no transport session is established between routers (`NTCP2 … no peers available` for tunnel-node selection in every node). `router.info is malformed. Creating new` appeared on second-stage restart of the mid-router, which regenerates identity and therefore breaks the peer list that task 2 fixed.

Root cause identified while inspecting logs: between the identity-generation stage and the reseed stage the config file is rewritten (removing `reseed.zipfile` for identity gen, adding it for reseed launch). i2pd treats the modified `router.info` as inconsistent with the new config and rebuilds it from scratch, discarding the address set that the bootstrap zip carries. The sequence must keep the config byte-identical between both stages and pick `host` and `port` at the *first* launch.

## Blocker list (what still needs to be done before E-1 can run 7 cases)

1. Config must be regenerated once and kept identical across both stages — do NOT strip `reseed.zipfile` between them. Adjust `i2pd-fork/scripts/e1-stand.sh` accordingly (identity generation works fine even with `reseed.zipfile=<path>` present, i2pd just needs the peer archive to exist at peer-count bootstrap time).
2. After mesh adjacency (NTCP2 session established) verify 3-hop tunnel build before I2CP traffic.
3. Wire the Python I2CP probe (CreateSession → HostLookup of `b33` → send → receive) and drive the 7 cases of `docs/plans/e1-test-matrix.md` from that probe, persist raw logs under `runs/<sha>/e1/`.

## Why this stops here (honest limitation)

This environment cannot keep a 6-process loopback network paused across successive AI tool calls — successive invocations were cut by session instability and are re-designed to be idempotent single-shot runs. Steps 2–3 must be re-run as one uninterrupted block; until then the seven E-1 cases cannot claim verified.

**Status of the seven E-1 cases: not run yet.** Nothing is claimed as pass/fail.