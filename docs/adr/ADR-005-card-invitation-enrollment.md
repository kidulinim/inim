# ADR-005: Card / Invitation / Enrollment formats, state machine, migration

Status: draft (Phase 0) — formats frozen before Phase 4 code

## Objects (spec §6.5)
- ContactCard: v, npub, dest_b33 (+flags), features[], created_at, sig. No secrets; may be public.
- Invitation: v, ContactCard(inviter), invite_id[16], bootstrap_auth_priv (X25519), expires_at, policy_hint, sig. SECRET until consumed/expired. Encodings: QR + text URI `inim://i/<base64url(cbor)>`.
- All signatures: BIP-340 by npub over canonical CBOR with domain prefix "INIM/card/v1" etc. An INIM extension, not part of Marmot — document as such.
- SAS: 6-digit code = H(invite_id, alice_npub, bob_npub, alice_dest, bob_dest, kBA_pub).

## State machine to specify and test
All steps idempotent keyed by invite_id: retries, duplicates, interrupted enrollment, restarts, expired KeyPackages. First confirmed npub wins; later claims fail. Credential rotation within 1h (transport.rotate). Bootstrap key ik removed after first post-ENROLL_REQ frame from Bob or 10-min grace.

## Destination migration (lost device)
Unknown Destination may only deliver MLS-protected EVENT frames; `card.update` from a known leaf updates the allowlist; everything else dropped.

## Verification
§15.1 rows: tampered/expired cards, reuse after consumption, replay/concurrent claims, interrupted enrollment at each step.
