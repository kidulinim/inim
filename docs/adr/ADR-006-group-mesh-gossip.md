# ADR-006: Group mesh and gossip bounds

Status: draft (Phase 0) — bound before Phase 8

## Context
Tier A mesh groups (spec 6.6): each member needs reachability to every other member, solved inside MLS via transport.offer messages. Catch-up relies on member-as-relay; gossip fan-out must be bounded to prevent amplification (6.8).

## Decisions (to fix)
- Tier A default cap 32 members until E-6/E-11 give measured numbers; client-list slots budgeted against 7.5.
- `group_transport_policy`: auto | ask | never; default ask (humans), auto (agents, per profile).
- gossip fan-out bound: max re-sends per event per peer per window; dedup by event id always.
- sync_window: 14 days or 5000 events (default), configurable per profile via settings.
- Removing a member (MLS) never revokes transport; revoking transport never changes MLS membership (7.9).

## Verification
Phase 8 tests: fan-out amplification attempt returns bounded sends; catch-up from N peers recovers missing epochs via MLS rules only.
