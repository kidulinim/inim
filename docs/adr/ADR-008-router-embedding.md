# ADR-008: Router embedding, I2CP access control, Android service type

Status: draft (Phase 0) — decide before Phase 7; I2CP shape needed in Phase 1

## Context
Other Android apps must not reach I2CP (it has no authentication). Frontends never talk to i2pd; only the core does (spec 3).

## Decisions (to confirm)
- i2pd fork embedded as a native library on Android (JNI); child process on desktop/headless.
- I2CP over Unix socket or in-process pipe. No open TCP listener by default (fork F-8).
- **F-8 thread rule (Reviewer 1 round 5 item 1):** the control channel runs on its own thread, but `m_ECIESx25519Sessions` / `m_ECIESx25519Tags` and the revoke path are owned by the destination's `io_context` thread. Any control command that mutates them (key-ring add/remove, session revoke, LeaseSet cache eviction) MUST be dispatched with `m_Service.post(...)` into the destination's thread — the channel thread must never touch those maps directly. This also closes the window where a LeaseSet decrypted before key removal could land in the cache after `RemoveKeyRingKey` returns. Documented in `libi2pd/Destination.h` (F-1 key ring section) and `ADR-019`.
- No externally reachable I2CP port; no dependency on a separate i2pd app.
- Android foreground-service type: evaluate `specialUse` + battery-optimization exemption in sideloaded builds; Play policy review does not apply. Android 15 limits `dataSync` foreground services in time [TV].
- Updates: releases as signed artifacts through GitHub (manual download); later over I2P with signed release manifest verified against pinned release key (ADR-008 in spec 10.1). The app never contacts GitHub or any clearnet host itself.

## Verification
Traffic audit E-9: the only non-router-link traffic the fork may originate is INIM's (router link layer and reseed excepted, per spec 1).
