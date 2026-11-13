# i2pd fork — upstream pin and rebase notes

## Pinned upstream base

- Repository: `https://github.com/PurpleI2P/i2pd` (BSD-3-Clause)
- Tag: **2.61.0** (owner decision 2026-11-14)
- Verified in this base (source inspection): I2CP option names (Appendix B) and
  Datagram2/3 handling (F-9) — see
  [docs/verification/i2pd-2.61.0-phase0.md](../docs/verification/i2pd-2.61.0-phase0.md).

## Patch series

Applied in numeric order on the pinned base:

1. `0001-f1-key-ring.patch` — per-remote-destination client-auth key ring (F-1).

More patches follow for F-2..F-8 (F-9 is done upstream; F-10 is process, not a patch).

## Rebase rules (F-10)

- Keep the series rebased on the pinned base; rebases happen in one dedicated commit
  that touches only `UPSTREAM.md`'s tag and, if needed, re-generated patch files.
- Each patch must apply with `git apply` (no fuzz). CI checks this.
- Every upstream upgrade requires: §15 compatibility tests green + a diff note of what
  changed in the code areas our patches touch.

## Build

See [README.md](README.md#building-base--patches).