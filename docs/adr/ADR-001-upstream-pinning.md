# ADR-001: Upstream pinning

Status: draft (Phase 0) — decide before Phase 1

## Context
The spec (§4) requires exact pins for MDK, OpenMLS, the Marmot MIP commit and the i2pd fork base, tracked in DEPENDENCIES.md. MIPs are in "Review" status; upstream moves under us.

## Decision (to confirm in Phase 0)
- mdK-core 0.8.0 + mdk-storage-traits 0.8.0 (crates.io).
- openmls: the version resolved by mdk-core 0.8.0's own dependency tree (0.8.1 at spec review; 0.9.2 exists). Do not upgrade openmls independently of mdk-core.
- Marmot protocol: commit f825024f7eb92157d12a0b8985bc6c5db5531d6d (master @ 2026-11-09). Diff MIPs on every upgrade.
- i2pd fork base: 2.61.0 OR the 2.58 reference in which the I2CP option names were verified [TV]. Choose after checking that the verified option names still exist in 2.61.0.

## Consequences
- Every upgrade needs the §15 compatibility tests first.
- License audit: MDK/OpenMLS are MIT [V]; do NOT copy code from whitenoise-rs (AGPL-3.0).

## Verification
- `cargo build` of an mdk smoke test on MSRV 1.90.
- MIP diff between pinned commit and previous pin goes into the PR description.
