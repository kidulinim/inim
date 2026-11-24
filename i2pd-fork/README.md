# INIM i2pd fork

This directory contains the INIM-specific patch series against the pinned upstream
`PurpleI2P/i2pd` base (see [DEPENDENCIES.md](../DEPENDENCIES.md)) plus the fork
requirements from the specification (Appendix A).

## Why a fork

Stock `i2pd` gives us `i2cp.leaseSetPrivKey` as **one key per session** — useless for
INIM's per-contact credentials (§7, Appendix A F-1). The fork adds the missing runtime
control surface and hardens I2CP so no other app can reach it.

## Build evidence status (round 6 — IMPORTANT)

**Current valid evidence:** commit `e687300c` (run https://github.com/kidulinim/inim/actions/runs/45361854919) passes all validation checks V1..V3 in `ci-evidence` (check `runs/e687300c.../result.txt` in the `ci-evidence` branch).

**Earlier claims remain revoked as unproven.** The runs
45278900262 (`95f921a`) and 45300879619 (`965bf59`) looked green, but their `build.log`
showed `git am` never applied any patch: the fresh upstream clone had no committer
identity ("Committer identity unknown"), and the run-command pipeline `git am ... | tee`
without `set -o pipefail` swallowed the real exit code, so the workflow recorded
`apply_patches: success` and `overall: success` on a build that applied **zero** patches
(Reviewer 1 round 6). The `git log --oneline` in the same log proved it — the tree at the
patch step was still at upstream `635b013a`, and the test step printed
`make: *** No rule to make target 'test-keyring-revocation'. Stop.`
(`test-keyring-revocation` only exists after patch 0008).

Fixed now: `set -o pipefail` in every run block, `git config user.name/user.email` set
inside `i2pd-fork/scripts/apply-patches.sh` before `git am`, patch ids logged as
`git log --oneline 635b013a..HEAD`, and `i2pd-fork/scripts/ci-evidence.sh` now **validates
build.log** before writing `result.txt`:

- **V1** build.log must contain `OK: N patch(es) applied` where N == number of files in `i2pd-fork/patches`;
- **V2** build.log must contain `test-keyring-revocation: all checks passed`;
- **V3** build.log must NOT contain `No rule to make target`.

If any check fails, `result.txt` records `overall: invalid` (not `success`), even when
the workflow job itself reports green. Read the `ci-evidence` branch (`runs/<sha>/`) for
authoritative status — that verifier is the only thing that can turn "compiles clean"
into an accepted claim from now on.

## Requirements (Appendix A)

| ID | Requirement | Status |
|---|---|---|
| F-1 | Key ring: register client-auth **private** keys per remote Destination, keyed by the **stable blinded identity** `SHA256(stA ‖ A)` (what b33 carries). | **REWORKED (v3), fixed after Reviewer 1 rounds 4–6.** Patches `0001`, `0003`, `0004` (+ `0005` regression fix, `0006` indent fix, `0007` tag-set revoke split). Lookup driven by `request->requestedBlindedKey->GetIdentHash()`, copies under the mutex, stack/base64 buffers zeroized (scrub always, incl. decode failure). No legacy shared-key mode: `i2cp.leaseSetPrivKey` is rejected at parse time and the session is **refused** (`eI2CPSessionStatusRefused`), missing key-ring entry always means "decrypt without a key" (fail closed, ADR-019). `m_KeyRingCacheKeys` written under `m_KeyRingMutex` (race fixed, locking order documented). `SetKeyRingKey` definition restored (round 4 regression). `RemoveKeyRingKey` evicts cached LeaseSet (ident + store hash) and uses `RevokeECIESx25519Session` (tag sets dropped). Cache-eviction bookkeeping unit-tested (`tests/test-keyring-revocation` via test-only hook `InsertRemoteLeaseSetForTest`). Cases 5/7 of the E-1 matrix need real two-router run (left to E-1). |
| F-2/F-3 | Per-client auth lists and padding-to-buckets are **client side** (v0.10 scope, i2pd only wraps what the core signs). | dropped from the i2pd fork; handled later by the Rust core (ADR-018, decided after E-1). |
| F-11 | I2CP lookup of a **blinded (b33) destination** via the encrypted-LeaseSet request + key ring, returning the resolved Destination. | Implemented in patches `0002` (`HostLookupMessageHandler` case 1) and `0006` (indent fix). Uses only the session's own destination + key ring (no fallback to `context.GetSharedLocalDestination()`). Decryption failure → immediate null `HostReply`, timeout only if no floodfill answers. Daily-key rotation re-resolution works because ring identity `SHA256(stA‖A)` is date-independent. Runtime behavior still needs E-1 verification. |
| F-4..F-8, F-10 | As per spec v0.10 — pending (allowlist in New Session, control channel, transit policy, strip unused surfaces, reproducible builds). | not started (F-4 is gated behind the E-1 run per review order). |
| F-9 | Datagram2/3 over I2CP. | **[TV] — not confirmed.** Handlers exist in upstream's `DatagramDestination`, but `I2CP.cpp` has no protocol-type dispatch — needs its own work. |

## Layout

- `patches/` — one patch per fork feature (currently 0001–0009), applied in order on the pinned base.
- `scripts/apply-patches.sh` — sequential `git am` with committer identity set; prints `OK: N patch(es) applied` and `git log --oneline 635b013a..HEAD`.
- `scripts/ci-evidence.sh` — evidence validator + writer for the `ci-evidence` branch (checks V1..V3, see above).
- `UPSTREAM.md` — pinned base tag/commit, rebase instructions, patch ordering.

## Building (base + patches)

On the pinned base tag, apply patches with `git am` (same as CI) and build — or just run
`scripts/apply-patches.sh` from inside the clean checkout:

```bash
git clone https://github.com/PurpleI2P/i2pd.git
cd i2pd
git checkout 635b013a612ff47278ef02acf8580a28e10e26c5   # pinned commit, see UPSTREAM.md
../i2pd-fork/scripts/apply-patches.sh   # sequential git am
make -j$(nproc)
```

Targets are unchanged from upstream (`i2pd`, client/lang libs); on Android the patch
series additionally builds a JNI library (F-10, later).