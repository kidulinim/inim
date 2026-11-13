# ADR-009: Transit policy

Status: draft (Phase 0) — runtime behavior [TV] in Phase 1

## Context
Transit tunnels are a user option (spec 7.7). Share percentage user-controllable. F-6 allows runtime change; otherwise UI must say a restart is required.

## Decisions (to confirm)
- Defaults: enabled=true on desktop/headless (share 50%), enabled=false on Android (if the user enables it: share 20%, unmetered-and-charging-only by default).
- Map to i2pd `notransit`, `share`, `limits.transittunnels` [TV].
- Tunnel length default 3 hops; below 2 requires explicit expert setting; quantities tuned in E-8.
- UI MUST explain trade-off: transit adds cover traffic and helps the network but costs battery and data; a router without transit may be distinguishable [TV: router caps in RouterInfo].

## Verification
E-8 (Android resource use: transit on/off, battery) and F-6 runtime update confirmation event.
