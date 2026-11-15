# ADR-019: Key-ring fallback policy for blinded LeaseSet decryption

Status: accepted (2026-11-15, per Reviewer 2)

## Context

In i2pd a client-auth private key decrypts the per-client portion of a remote
Encrypted (blinded) LeaseSet2. Stock i2pd has one per-session key
(`i2cp.leaseSetPrivKey`); the INIM fork adds a per-remote-destination key ring
(F-1, keyed by the stable blinded identity `SHA256(stA || A)`).

Question (Reviewer 2, F-1): what happens when a decryption reply arrives for a
blinded destination that has **no** key-ring entry — may the code silently fall
back to the shared session key?

## Decision

**No silent fallback when a key ring is in use.** The behavior is a strict
three-case policy in `LeaseSetDestination::HandleDatabaseStoreMessage`
(encrypted LeaseSet2 branch), implemented via `IsKeyRingEmpty ()`:

1. **Key-ring entry present** — decrypt with that key (per-contact credential).
2. **Key ring is empty AND a legacy session key is configured** — decrypt with
   the session key and log a *warning*. This is the stock-i2pd single-key mode
   and can only occur when the INIM core has not registered any credential yet
   (development, misconfiguration, or a profile that intentionally runs
   single-key). The warning names the destination (blinded ident, no secrets).
3. **Key ring is non-empty (per-contact mode) but the entry is missing** —
   **do not** substitute the session key; try without any key and fail closed.
   A missing entry means a contact whose credential was never authorized (or
   was revoked); decrypting with the shared key would hide the misconfiguration
   and grant access the operator did not intend.

Rationale: in per-contact mode (which the INIM core always uses) every peer has
its own credential. Falling back to a shared key would (a) leak nothing new but
(b) silently succeed for a peer that should have been rejected, defeating the
allowlist and revocation model (spec 7.6, 7.9). Fail-closed keeps the invariant
"an encrypted LeaseSet is only readable with the credential issued for that
remote".

Rationale for keeping case 2 instead of removing the session key entirely: the
fork remains build-compatible and testable against stock I2CP behavior and
upstream experiments (E-1..E-3) before the control channel (F-8) exists; the
mode is distinguishable by the warning log and by `IsKeyRingEmpty ()`. The
warning message says "legacy mode" so misconfiguration is visible.

## Consequences

- `SetKeyRingKey` / `RemoveKeyRingKey` are the only ways to enter/leave
  per-contact mode (once F-8 exposes them at runtime).
- The E-1 test matrix must include the "no key" case and verify it does **not**
  produce a usable session in per-contact mode (fail closed).
- Any future change of this policy requires a new ADR; the code comment at the
  fallback site references this document.