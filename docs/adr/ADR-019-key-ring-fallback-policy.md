# ADR-019: Key-ring policy for blinded LeaseSet decryption (v2, per spec v0.10)

Status: accepted — **rewritten 2026-11-16 after Reviewer 1 round 3**
(supersedes the first version, which allowed a legacy single-key mode)

## Context

In i2pd a client-auth private key decrypts the per-client portion of a remote
Encrypted (blinded) LeaseSet2. Stock i2pd has one per-session key
(`i2cp.leaseSetPrivKey`); the INIM fork adds a per-remote-destination key ring
(F-1, keyed by the stable blinded identity `SHA256(stA || A)`).

The first ADR version allowed the shared session key as a fallback when the key
ring was **empty**. Reviewer 1 rejected mode inference from ring emptiness:
revoking the **last** contact would silently re-enable a shared key that no
contact is authorized for — exactly the fail-closed violation the policy exists
to prevent.

## Decision (spec v0.10, section 0.7)

1. **No legacy shared-key mode exists in the INIM fork.**
   `i2cp.leaseSetPrivKey` is **rejected at parse time**: a CREATE SESSION that
   carries the option is **refused** (`eI2CPSessionStatusRefused`, session not
   created), with a critical log line; the value is never stored, never used.
2. **A missing key-ring entry always means "decrypt without a key".** There is
   no mode to infer: per-contact keys are the only source.
3. **All remote LeaseSets must use per-client auth (DH)**: an Encrypted
   LeaseSet without client auth decrypts with an empty key and is not private.
   The core must require auth type DH before accepting any remote LeaseSet;
   E-1 includes an "auth type / no client auth" rejection case.

## Rationale

- Fail-closed must hold unconditionally: any peer without an explicitly
  authorized credential simply cannot read our Secret LeaseSet.
- A mode inferred from ring size breaks exactly at the edge of the last
  revocation — one rule is auditable at a glance.
- Rejecting `i2cp.leaseSetPrivKey` removes the temptation to configure it.

## Consequences

- `SetKeyRingKey` / `RemoveKeyRingKey` are the only levers; runtime exposure
  comes with F-8, E-1 uses a test-only preload file (not shipped).
- `RemoveKeyRingKey` also evicts the peer's cached remote LeaseSet (ident +
  store hash) and its routing session — the cache otherwise bypasses the ring.
- On LeaseSet decryption failure the request completes immediately with a null
  reply (no timeout wait); a timeout applies only when no floodfill answers
  (F-11, spec v0.10).
- E-1 verifies: right key / wrong key / no key / no-auth LeaseSet rejected /
  key removed → cache evicted / expired LeaseSet → re-resolve via HostLookup.
- As of Reviewer 1 round 5 the worker path (key ring set/get/remove, session +
  tag-set revoke, LeaseSet cache eviction) is unit-tested
  (`tests/test-keyring-revocation`, green CI run 45278900262); the two-router
  matrix cases 5/7 remain for E-1 (they need real delivery through the network).
- **Threading rule (ADR-008):** revoke-path operations run in the destination's
  `io_context` thread; the future F-8 control channel dispatches them with
  `m_Service.post(...)`.
- Any change to this policy requires a new ADR.