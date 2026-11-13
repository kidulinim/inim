# ADR-003: Serialization and INIM application kind registry

Status: draft (Phase 0) — freeze before Phase 2

## Context
INIM-own wire structures need one canonical encoding; Marmot events must stay byte-for-byte as MDK produces them (Nostr event JSON).

## Decision (to freeze)
- INIM-own structures: CBOR with deterministic encoding. Freeze the exact profile (canonical key order, integer widths, float policy, tagged/untagged) in this ADR before Phase 2 code exists.
- Domain separation: every INIM signature covers `"INIM/<object>/<v>" || canonical_cbor(fields)` (e.g. "INIM/card/v1").
- Marmot events are carried as opaque JSON; never re-encode or normalize them.
- Frame format (§6.3): v, t, id[16], frag, body. Registry of FrameType values and REQ/RESP pairs; reserve MAILBOX_PUT/GET/ACK, KP_PUBLISH/KP_LOOKUP, HUB_JOIN/HUB_EVENT/HUB_SYNC types now (§19).

## Reserved type table
| Type | Status |
|---|---|
| HELLO, EVENT, ACK, KP_FETCH, KP_RESP, SYNC_REQ, SYNC_RESP, ENROLL_REQ, ENROLL_RESP, PING | defined §6.3 |
| MAILBOX_PUT, MAILBOX_GET, MAILBOX_ACK, KP_PUBLISH, KP_LOOKUP | reserved for relays (§19) |
| HUB_JOIN, HUB_EVENT, HUB_SYNC | reserved for group hubs (§19) |
