# E-1 test matrix — Secret LeaseSet with DH auth (two independent routers)

Status: **planned** (run not started). Companion to `docs/experiments-phase1.md` E-1.
Separates experiment status from implementation status: the fork patches (F-1,
F-11) are in place, but living evidence comes only from an actual two-router run.

## Setup

- Two independent i2pd routers (A and B), built from the pinned base 2.61.0 +
  patch series (`i2pd-fork/patches`), no shared config.
- Each side has an Encrypted LeaseSet (type 5, auth type DH).
- Router A is the "server" (owns the Secret Destination); Router B resolves it
  through F-11 (`HostLookup` case 1, blinded address) with the client key ring (F-1).

## Cases

| # | Client key on B | Expected result | Log check |
|---|---|---|---|
| 1 | Correct per-contact key registered in B's key ring | `HostReply` returns the resolved identity; subsequent `SendMsgTo` works via cached LeaseSet | No key material in the log; entry/lookup lines only name the blinded ident |
| 2 | Wrong key registered (valid format, not the one A issued) | Lookup fails closed: LeaseSet can't be decrypted | Warning mentions lookup/decode only, **no key bytes** |
| 3 | No key registered (empty key ring for that contact) | Fail closed (per ADR-019): no silent legacy fallback once any key-ring entry exists; session key alone must not decrypt | Same as above |
| 4 | Key removed **after** a session was established (revocation of an already established session) | `RemoveKeyRingKey` + F-11 re-resolution under rotate/refresh fails; already-cached LeaseSet may persist until its expiry — must **not** be re-resolvable with a new key attempt | No key bytes in log; revocation visible by name only |

Notes:
- Case 3 also serves as the "no key" slot already referenced by Reviewer 1:
  unauthorized peers must get a refusal, and the log must contain nothing secret
  (spec-cache clear; only ident/b33, never the raw key).
- Case 4 depends on the future F-8 control channel for live key removal; until
  then run it as a restart with the key absent (approximation, documented here).

## Pass criteria (from spec Appendix C, E-1)

Authorized connects; unauthorized fails. In addition: no secrets in logs,
fail-closed behavior in per-contact mode (ADR-019), and a repeatable run
artifact (chronological log excerpts of the two routers, minus secrets).