# i2pd 2.61.0 — Phase 0 [TV] verification (source-level)

Base pin decision: **i2pd 2.61.0** (owner, 2026-11-14). This record closes the Phase 0
"[TV] items that block Phase 1" for the I2CP/Datagram surface by inspecting the released
sources. Runtime behavior is still confirmed only by the two-router experiments in Phase 1
(E-1…E-10); source inspection does not prove live behavior.

Source: `github.com/PurpleI2P/i2pd` tag `2.61.0` (BSD-3-Clause).

## Appendix B — I2CP option names (source presence)

| Option | Present in 2.61.0 source | Where |
|---|---|---|
| `i2cp.leaseSetType` | yes | `libi2pd/Destination.h` `I2CP_PARAM_LEASESET_TYPE` |
| `i2cp.leaseSetEncType` | yes | `libi2pd/Destination.h` `I2CP_PARAM_LEASESET_ENCRYPTION_TYPE` |
| `i2cp.leaseSetAuthType` | yes | `libi2pd/Destination.h` `I2CP_PARAM_LEASESET_AUTH_TYPE` |
| `i2cp.leaseSetClient.dh.nnn` | yes (group) | `I2CP_PARAM_LEASESET_CLIENT_DH`; read via `ReadAuthKey(...)` in `Destination.cpp` |
| `i2cp.leaseSetClient.psk.nnn` | yes (group, unused) | `I2CP_PARAM_LEASESET_CLIENT_PSK` |
| `i2cp.leaseSetPrivKey` | yes | `I2CP_PARAM_LEASESET_PRIV_KEY` (single session key — replaced by milestone F-1) |
| `i2cp.leaseSetSecret` | **NOT present** | no symbol in 2.61.0 sources → confirmed absent; do not rely on a blinding secret |

Direction/lifecycle (runtime update, republish timing, slot reuse) remains **experiment
work (E-1..E-5)** — source tells us the option exists, not when/i2pd accepts it live.

## Milestone F-9 — Datagram2 (proto 19) / Datagram3 (proto 20)

**Resolved in the base tree (no fork work needed for presence).**

- `libi2pd/Datagram.h` defines `enum DatagramVersion { eDatagramV1, eDatagramV2, eDatagramV3 }`,
  `DATAGRAM2_FLAG_OPTIONS`, `DATAGRAM2_FLAG_OFFLINE_SIGNATURE`, `DATAGRAM3_FLAG_OPTIONS`,
  and handlers `HandleDatagram2(...)`, `HandleDatagram3(...)`.
- `libi2pd/Datagram.cpp` `HandleDataMessagePayload(...)` dispatches on `protocolType`:
  `PROTOCOL_TYPE_RAW` → `HandleRawDatagram`, `PROTOCOL_TYPE_DATAGRAM3` → `HandleDatagram3`,
  `PROTOCOL_TYPE_DATAGRAM` (V1) → `HandleDatagram`, `PROTOCOL_TYPE_DATAGRAM2` → `HandleDatagram2`.

So both Datagram2 and Datagram3 are routed in upstream 2.61.0. Remaining fork scope for
ADR-002 is not "does 19/20 exist" but "expose a usable I2CP send/receive path and confirm
behavior+MTU under load" — that is E-3/E-10, not code absence.

## What this unblocks

- Phase 1 experiments E-1, E-2 (key ring is fork work F-1, independent of Datagram),
  E-3 (datagram vs streaming), E-10 (MTU) can start against 2.61.0.
- `i2cp.leaseSetSecret` is documented as absent — the "blinding secret as an additional
  layer" idea in Appendix B is not available in the pinned base and is out of scope unless
  the fork adds it (tracked in ADR-002/Appendix B as a non-requirement).

## Still open before Phase 1 is "proof-complete"

- E-1 two-router Secret LeaseSet + DH auth end-to-end (code exists, live proof pending).
- F-1 per-remote-destination key ring (fork feature, source does not have it).
- F-2 runtime auth add/remove + confirmation event (fork feature).
- The `OpenMLS` version resolved by `mdk-core 0.8.0`'s dependency tree (build, not source).
