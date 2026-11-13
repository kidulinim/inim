# DEPENDENCIES.md

Exact pins and provenance for everything INIM depends on (specification §4, §16).
Upgrades require the compatibility tests in §15 before adoption.

Status legend: **PINNED** — frozen for Phase 0/1 · **CANDIDATE** — needs the ADR-001
pinning check (build + tests) before it becomes PINNED · **[TV]** — to verify
(specification §0.1) before relying on it.

## Toolchain

| Item | Pin | Status |
|---|---|---|
| Rust edition | 2024 | PINNED (specification §4) |
| Rust MSRV | ≥ 1.90 (mdk-core 0.8 requirement **[V]**) | PINNED (specification §4) |

## Marmot / MLS engine

| Crate / artifact | Pin | Provenance | Status |
|---|---|---|---|
| `mdk-core` | 0.8.0 | crates.io (max version at 2026-11-13; matches specification review) | CANDIDATE |
| `mdk-storage-traits` | 0.8.0 | crates.io (max version at 2026-11-13) | CANDIDATE |
| `openmls` | version as required by mdk-core 0.8.0's own lockfile (0.8.1 was current at specification review **[V]**; up to 0.9.2 exists on crates.io at 2026-11-13) | crates.io | CANDIDATE — resolve against mdk-core in ADR-001, do not pick independently |
| Marmot protocol (MIP-00..03) | commit `f825024f7eb92157d12a0b8985bc6c5db5531d6d` (branch `master` @ 2026-11-09) | github.com/marmot-protocol/marmot | CANDIDATE — pin and diff on every upgrade; MIPs are in "Review" status **[V]** |
| MLS ciphersuite | `MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519` (only required Marmot suite **[V]**) | RFC 9420 / MDK default | PINNED (specification §4) |

**Do not copy code from `whitenoise-rs`** (AGPL-3.0 licensed — and this repository is
AGPL-3.0 as well; MDK/OpenMLS are MIT **[V]**). MDK code is used as a dependency only.

## I2P router

| Item | Pin | Provenance | Status |
|---|---|---|---|
| i2pd base for the INIM fork | 2.61.0 (newest upstream tag at 2026-11-13; option names [V]-verified in 2.58 sources) | github.com/PurpleI2P/i2pd (BSD-3-Clause) | CANDIDATE — ADR-001 chooses the base tag: newest tag vs. the Debian 2.58 reference in which the I2CP option constants were verified |
| i2pd fork requirements | F-1..F-10 (specification Appendix A) | in this repository (`i2pd-fork/`) | — |

## Storage / serialization

| Item | Pin | Status |
|---|---|---|
| `rusqlite` + `bundled-sqlcipher` | exact crate versions set in Phase 2 | CANDIDATE (ADR-007) |
| `mdk-sqlite-storage` on SQLCipher | to verify **[TV]**; otherwise implement `mdk-storage-traits` on our DB | [TV] (ADR-007) |
| CBOR | deterministic encoding for INIM-own wire structures | PINNED (specification §4, ADR-003 freezes the profile) |

## Protocol profile

| Item | Value |
|---|---|
| Marmot event kinds (MDK) | KeyPackage 30443 (legacy 443 accepted on read), Welcome rumor 444 in gift wrap 1059, group events 445 |
| Group data extension | type `0xF2EE` |
| Compatibility | content-compatible with Marmot; **not** wire-compatible with WhiteNoise clients |

## Rust crates (supporting)

Exact versions are added here when the workspace is created in Phase 2
(`tokio`, `uniffi`, `tracing`, `serde`, …). Every version that ships goes into this file.
