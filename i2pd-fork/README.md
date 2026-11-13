# INIM i2pd fork

This directory contains the INIM-specific patch series against the pinned upstream
`PurpleI2P/i2pd` base (see [DEPENDENCIES.md](../DEPENDENCIES.md)) plus the fork
requirements from the specification (Appendix A).

## Why a fork

Stock `i2pd` gives us `i2cp.leaseSetPrivKey` as **one key per session** — useless for
INIM's per-contact credentials (§7, Appendix A F-1). The fork adds the missing runtime
control surface and hardens I2CP so no other app can reach it.

## Requirements (Appendix A)

| ID | Requirement | Status |
|---|---|---|
| F-1 | Key ring: register client-auth **private** keys per remote Destination (b33/hash) at runtime; router picks the right key when resolving that Destination's encrypted LeaseSet. | patch `patches/0001-f1-key-ring.patch` written and verified on base 2.61.0: compiles clean, `git apply --check` passes on untouched base. Core plumbing is in (`SetKeyRingKey`/`RemoveKeyRingKey`/`LookupKeyRing`). Remaining for F-1 "at runtime": exposing registration over I2CP — deliberately folded into the F-2 event/control surface in one interface |
| F-2 | Runtime add/remove/replace of authorized client entries + LeaseSet republish + **confirmation event** (revocation must be provable, not assumed). | pending |
| F-3 | Pad the client list with dummy entries in size buckets (hide real contact count). | pending |
| F-4 | Router-level allowlist of remote Destinations; drop others; `close sessions of Destination X`. | pending |
| F-5 | Events over I2CP: tunnel readiness, LeaseSet published, peer connect/drop, auth failure counters. | pending |
| F-6 | Runtime transit policy (enable, share %, max tunnels). | pending |
| F-7 | Strip everything not needed: proxies, SAM/BOB, address-book subscriptions, web console beyond a local diagnostic socket, tunnels.conf defaults. | pending |
| F-8 | I2CP over Unix socket / in-process pipe; no TCP listener by default (other apps must not reach I2CP — it has no auth). | pending |
| F-9 | Datagram2 (proto 19) and Datagram3 (20) over I2CP. | **already in upstream 2.61.0** (see [docs/verification/i2pd-2.61.0-phase0.md](../docs/verification/i2pd-2.61.0-phase0.md)); only I2CP exposure may need work |
| F-10 | Reproducible builds, Android JNI library target, pinned upstream base, patch series kept rebased. | ongoing |

## Layout

- `patches/` — one patch per fork feature, applied in order on the pinned base.
- `UPSTREAM.md` — pinned base tag/commit, rebase instructions, patch ordering.

## Building (base + patches)

On the pinned base tag, apply patches and build:

```bash
git clone https://github.com/PurpleI2P/i2pd.git
cd i2pd
git checkout <pinned-tag>          # see UPSTREAM.md
for p in ../i2pd-fork/patches/*.patch; do git apply "$p"; done
make -j$(nproc)
```

Targets are unchanged from upstream (`i2pd`, client/lang libs); on Android the patch
series additionally builds a JNI library (F-10, later).