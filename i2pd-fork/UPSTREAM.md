# i2pd fork — upstream pin and rebase notes

## Pinned upstream base

- Repository: `https://github.com/PurpleI2P/i2pd` (BSD-3-Clause)
- Tag: **2.61.0** (owner decision 2026-11-14)
- Pinned commit: **635b013a612ff47278ef02acf8580a28e10e26c5** — the commit the
  annotated `2.61.0` tag points at (tag object `4fef5596f366be4b174a4d090d118e7679707a38`,
  verified against the GitHub API 2026-11-23). The CI bases the series on this
  exact commit rather than on an archive tarball (GitHub archive SHA-256 is not
  guaranteed stable; Reviewer 1 round 4 item 3) — see
  [`.github/workflows/build-i2pd-fork.yml`](../.github/workflows/build-i2pd-fork.yml).
- Verified in this base (source inspection): I2CP option names (Appendix B) and
  Datagram2/3 handling (F-9) — see
  [docs/verification/i2pd-2.61.0-phase0.md](../docs/verification/i2pd-2.61.0-phase0.md).

## Patch series

Applied in numeric order on the pinned base (`git format-patch` incremental patches,
applied with `git am`):

1. `0001-F-1-key-ring-by-blinded-ident-….patch` — per-remote client-auth key ring keyed by stable blinded identity (F-1 v2).
2. `0002-F-11-I2CP-HostLookup-….patch` — blinded (b33) destination resolution through I2CP HostLookup backed by the key ring (F-11).
3. `0003-F-1-v3-no-silent-shared-key-fallback-….patch` — fail-closed key-ring policy per ADR-019 + base64 scrub on decode failure (F-1 v3, per Reviewer 2).
4. `0004-F-1-F-11-v0.10-….patch` — spec v0.10 items (Reviewer 1 round 3 items 1–5): reject `i2cp.leaseSetPrivKey` at parse time (no legacy mode), require per-client auth (DH) on remote LS2, F-11 immediate nullptr reply + session-destination only, `RemoveKeyRingKey` evicts LeaseSet cache (ident + store hash) and terminates peer sessions.
5. `0005-F-1-key-ring-round-4-….patch` — restore the `SetKeyRingKey` definition (regression fix), write `m_KeyRingCacheKeys` under `m_KeyRingMutex` (data race fix, locking order documented) (Reviewer 1 round 4 items 1, 2).
6. `0006-I2CP-round-4-….patch` — `CreateSessionMessageHandler` now **refuses** session creation (`eI2CPSessionStatusRefused`) when `i2cp.leaseSetPrivKey` is configured (ADR-019 item 1 wording said "rejected at parse time"; a log line alone was not enforcing) + F-11 blinded branch indentation fix (Reviewer 1 round 4 items 5, 7).
7. `0007-Garlic-round-4-….patch` — `RemoveECIESx25519Session` now drops the terminated session's tag sets from `m_ECIESx25519Tags` (before: terminated session's tags remained usable until the next `m_CleanupTimer` pass) (Reviewer 1 round 4 item 6).
8. `0008-Tests-key-ring-revocation-….patch` — unit test `tests/test-keyring-revocation`: SetKeyRingKey/GetKeyRingKey round trip (catches a vanished `SetKeyRingKey` definition at link/behavior time), tag eviction + session termination on revocation (Reviewer 1 round 4 items 1, 6). Runner: `cd tests && make test-keyring-revocation && ./test-keyring-revocation`; the CI runs it as part of the workflow.

Planned next: test-only key ring preload (for E-1, F-8 until then), then E-1, then F-4 (allowlist in New Session, ECIES static keys), then F-5–F-8 (this list is maintained from [README.md](README.md)).

## Rebase rules (F-10)

- Keep the series rebased on the pinned base; rebases happen in one dedicated commit
  that touches only `UPSTREAM.md`'s pin and, if needed, re-generated patch files.
- Each patch must apply with `git am` (sequential, no fuzz). CI checks this — and
  any build claim ("compiles clean") is only valid with a green CI run attached to
  that commit (Reviewer 1 round 4 item 4); a checked-in `build.log` is not kept,
  it goes stale immediately (it was removed for that reason).
- Every upstream upgrade requires: §15 compatibility tests green + a diff note of what
  changed in the code areas our patches touch.

## Build

See [README.md](README.md#building-base--patches).