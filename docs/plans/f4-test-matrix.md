# F-4 test matrix — router-level allowlist by ECIES-X25519 static keys

Status: planned (to run together with E-1 / with the F-4 patch). Companion to
`f4-interception-point.md` (Reviewer 2, item 4).

| # | Case | Setup | Expected result |
|---|---|---|---|
| 1 | Allowed key | Peer's static key registered in the allowlist before NS | New Session accepted; message delivered to the app |
| 2 | Unknown key | Fresh peer, key never registered | NS dropped right after static key decode, before payload; rate-limited drop counter, no app notification body |
| 3 | Anonymous (zero static key) | NS with `isStatic == false` (zero `fs`) | Dropped by default (v0.9 rule); only counter, no parser path entered |
| 4 | Revoked, new session | Key was allowed, then removed (revoke) | New NS rejected like case 2 |
| 5 | **Revoked, active session** | Session established, then key revoked (case 4 of E-1 matrix) | Existing session terminated; its tag sets dropped; no further deliveries from that peer even over surviving tags; cached LeaseSets untouched |

Log requirements (all cases): nothing secret — only the static key's ident/hash
form, never raw key bytes; drops counted once per attempt (no log flooding).

Implementation point: `ECIESX25519AEADRatchetSession::HandleNextMessage`, right
after `isStatic` computation and before `SetRemoteStaticKey` (see
`f4-interception-point.md` for the exact placement and revocation semantics).