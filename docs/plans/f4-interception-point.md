# F-4 design note — interception point and static-key lifecycle (Reviewer 2, item 3)

Written **before** the F-4 patch, as requested. Based on the actual code of
i2pd 2.61.0 (`libi2pd/ECIESX25519AEADRatchetSession.cpp`, `Garlic.cpp`).

## Interception point

New Session (NS) handling: `ECIESX25519AEADRatchetSession::HandleNextMessage`
— the section that decrypts the NS "flags/static" block (line ~335-375):

1. The 48-byte flags/static section is AEAD-decrypted into `fs[32]` — this is
   the **sender's ephemeral-or-static X25519 public key** ("apk", Alice's static
   when present).
2. `isStatic = !Tag<32>(fs).IsZero()` distinguishes anonymous NS (zero key)
   from keyed NS.
3. If static: `SetRemoteStaticKey (cryptoType, fs)` **immediately before** the
   session computes the shared secret `Decrypt (fs, sharedSecret, ...)` and
   before any payload/clove is decrypted or handed to the application.

**F-4 gate placement:** exactly between steps 2 and 3, right after the sender's
static key is known and **before** `SetRemoteStaticKey` + payload processing:

```cpp
bool isStatic = !i2p::data::Tag<32> (fs).IsZero ();
// [F-4] allowlist check here:
//   - anonymous (zero) static key  -> drop (default policy from spec 6.7/v0.9)
//   - static key not in allowlist  -> drop + rate-limited counter
//   - allowlisted                  -> continue
if (isStatic) { SetRemoteStaticKey (...); ... }
```

Justification: at this point nothing has been delivered to the application yet
(payload decrypts only after the KDF step below), so rejecting here means the
cloves of a non-allowlisted sender are never decrypted — rule "drop before
parsing" from the spec §6.3 is satisfied at the router level.

## Lifecycle of the sender's ECIES-X25519 static key

| Stage | Where | Notes |
|---|---|---|
| Learned | `SetRemoteStaticKey` (`ECIESX25519AEADRatchetSession:175`) during NS | `m_RemoteStaticKey[32]` + `m_RemoteStaticKeyType` |
| Stored in session | per-session `m_RemoteStaticKey` | one session = one remote static |
| Stored across sessions | **not stored by i2pd by default** | the router doesn't remember keys between sessions — the allowlist must provide the memory layer (F-4) |
| (Future) consumed by app layer | F-11 lookup replies / ContactCard exchange | spec §6.5 as amended: ContactCard carries the peer's ECIES static keys |

Consequence: the allowlist (F-4) needs its own map `static key -> contact`
because the router state is per-session only. That map is owned by the core
through the F-8 control channel (per v0.9) — or, before F-8 exists, by a
test-only injector for the E-1 run.

## Revocation semantics (must invalidate live state)

Reviewer 2 requirement: revocation must invalidate **active sessions and tag
sets**, not just block new sessions. Target behavior for the patch:

1. Remove the static key from the allowlist (new sessions blocked).
2. For every live `ECIESX25519AEADRatchetSession` whose `m_RemoteStaticKey`
   matches: terminate it (close the session) — see `Garlic.cpp` session map
   `m_ECIESx25519Sessions`.
3. Drop **tag sets** derived from that session (they are the message-level
   capability of the revoked peer) — without this a revoked peer could keep
   sending over tags minted before the revocation.

This is why F-4's patch touches both `Transports`/`Garlic` (session map) and
the tag-set registry; a simple bool check at NS creation time is **not**
sufficient — the doc item stands and the patch will carry the full behavior
plus the test matrix in `docs/plans/f4-test-matrix.md`.