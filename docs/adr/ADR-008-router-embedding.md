# ADR-008: Router embedding, I2CP access control, Android service type

Status: draft (Phase 0) — decide before Phase 7; I2CP shape needed in Phase 1

## Context
Other Android apps must not reach I2CP (it has no authentication). Frontends never talk to i2pd; only the core does (spec 3).

## Decisions (to confirm)
- i2pd fork embedded as a native library on Android (JNI); child process on desktop/headless.
- I2CP over Unix socket or in-process pipe. No open TCP listener by default (fork F-8).
- No externally reachable I2CP port; no dependency on a separate i2pd app.
- Android foreground-service type: evaluate `specialUse` + battery-optimization exemption in sideloaded builds; Play policy review does not apply. Android 15 limits `dataSync` foreground services in time [TV].
- Updates: releases as signed artifacts through GitHub (manual download); later over I2P with signed release manifest verified against pinned release key (ADR-008 in spec 10.1). The app never contacts GitHub or any clearnet host itself.

## Verification
Traffic audit E-9: the only non-router-link traffic the fork may originate is INIM's (router link layer and reseed excepted, per spec 1).
