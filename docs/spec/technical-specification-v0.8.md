# Technical Specification
**Project:** INIM — I2P-native serverless P2P messenger for humans and agents (working name)
**Version:** 0.8 (supersedes v0.7)
**Date:** 2026-11-13
**Status:** Implementation specification. Proceed phase by phase. Unresolved consequential behavior requires an ADR or verified upstream behavior. Nothing marked **[TV]** may be relied on before it is verified.

---

## 0. Conventions and changes from v0.4

### 0.1 Conventions

- MUST / SHOULD / MAY are normative.
- **[V]** = verified against a public upstream source on 2026-11-13 (sources in Appendix F). Re-verify against the pinned revision before implementing.
- **[TV]** = to verify (Phase 0/1) before relying on it. A coder MUST NOT treat a [TV] statement as fact.
- "Peer" = another INIM core instance, human-operated or agent-operated. The protocol does not distinguish them.

### 0.2 What changed in v0.5

| Area | Change | Reason |
|---|---|---|
| §6 (new) | **Marmot-over-I2P profile.** Defines how every role that Marmot assigns to Nostr relays (KeyPackage distribution, event ordering, Welcome delivery, epoch catch-up) is performed without relays. | Marmot was designed with relays as the delivery service; removing them leaves gaps v0.4 did not fill. |
| §6.5 / §7.3 | Address Bundle containing a private auth key is **replaced** by Contact Card + Invitation + two-way Enrollment. Permanent auth private keys never travel; bootstrap credentials are short-lived and rotated. | v0.4 exposed a long-lived private credential in a QR code and had no defined reply path. |
| §7 | i2pd is **our fork**. Fork requirements listed (Appendix A). Per-remote-destination client-auth key ring, runtime authorization updates, router-level peer allowlist, I2CP not reachable by other apps. | Stock `i2cp.leaseSetPrivKey` is one key per session, which cannot work with per-contact credentials. |
| §7.4 | **ADR-002 proposes datagram-first transport.** I2CP does not provide streaming; a non-Java I2CP client must implement the streaming library itself. | Discovered during review; changes the transport design. |
| §4 | `sqlx` dropped in favor of `rusqlite` + SQLCipher; MDK (Marmot Development Kit) adopted as the Marmot/MLS engine; single-owner core daemon. | OpenMLS storage is synchronous; atomic MLS+message transactions. |
| §7.7 | Transit tunnels are a user option (on/off, share percentage). | Owner requirement. |
| §10 | Agent interface is first-class: JSON-RPC, idempotent send, event cursors, approval queue, MCP promoted, prompt-injection rules. | Agents are intended users. |
| §13 | Phases reordered: experiments first; CLI/agent early; relay-less protocol before UI. | CLI is the e2e test harness. |
| §19 (new) | Relay readiness: member-as-relay now, I2P-hosted relays later. | Owner requirement. |

### 0.3 What changed in v0.6

| Area | Change | Reason |
|---|---|---|
| §6.6 | **Group tiers:** A (mesh, small), B (hub-hosted MLS, thousands), C (community mode, tens of thousands and more). Replaces the single "≤ 32" mesh limit. | Owner requirement: very large or unlimited groups. A relay-less mesh cannot reach that size; reference products cap MLS groups at ~100. |
| §6.1 | Bridges to Nostr/WhiteNoise removed from scope entirely. | Owner decision: all such paths are clearnet. |
| §7.7 | Desktop/headless transit default share set to 50 %. | Owner decision. |
| §10.1 | Android distribution via GitHub releases; no Google dependency; app never self-updates over the clearnet. | Owner decision. |
| §19, App. C/D | Hub role for relays; experiments E-11/E-12; ADR-016. | Supports tiers B and C. |

### 0.4 What changed in v0.7

| Area | Change | Reason |
|---|---|---|
| §6.6 Tier C | ADR-016 policy: **follow upstream first.** Adopt whatever Marmot/WhiteNoise specify for very large groups; choose between the candidate designs only if upstream has nothing by Phase 12. | Owner decision: do not invent large-group security design. |
| §10.1 | Release-key custody rules; optional wake-up service hosted inside I2P (ADR-017). | Owner questions on key storage and notifications. |
| §19 | Volunteer hubs expected; metadata exposure and per-group hub choice documented. | Owner expectation. |

### 0.5 What changed in v0.8

| Area | Change | Reason |
|---|---|---|
| §10.1 | The optional wake-up service inside I2P is **on by default**; the user picks the host or turns it off. | Owner decision: the user decides, not a hard-coded default of "off". |
| §10.1 | Release keys are generated on the owner's own machine, with an encrypted backup copy on the owner's server. A helper script (`gen-release-keys.sh`) is part of the repository tooling. | Owner decision; keys must never be created in an assistant session or shared environment. |

---

## 1. Goal

Build a privacy-focused messenger, Android first, with:

- End-to-end encryption using the Marmot/MLS design used by WhiteNoise, implemented through MDK on OpenMLS.
- Nostr-compatible identity (secp256k1 `nsec` / `npub`). Importing an existing Nostr key is a **deliberate feature**: any human or agent holding a Nostr private key can open an account and communicate while hiding their network location behind I2P.
- All messenger traffic exclusively through I2P, over Secret (encrypted) LeaseSets with per-client authorization.
- Operation with **no relays and no servers of any kind**. Optional I2P-hosted relays later (§19).
- Direct peer-to-peer delivery with a durable sender outbox.
- Equal access for humans (Android UI) and programs (CLI, Agent API, MCP) on one Rust core.
- Replaceable I2P router: our i2pd fork now, a pure-Rust router later, behind one transport contract.

**Layering (unchanged principle):** I2P protects the network path and restricts who may connect. MLS protects content and group membership. Neither replaces the other. The implementation MUST preserve both.

**Protocol reuse rule:** Reuse Marmot (MIP-00..03) identity, credentials, KeyPackages, Welcome, group data extension, commit/epoch handling, and message encryption **as produced by MDK**, unmodified. Do not invent group cryptography, credential formats, or key mechanisms. Anything INIM adds (§6.2–6.6) consists of signatures made with existing keys over domain-separated bytes and of MLS-protected application messages; it adds no new primitives. Adaptations require an ADR.

**Scope of "no clearnet":** The rule applies to the messaging layer and to every application component: no clearnet messaging, push, STUN/TURN, relay, update check, analytics, or fallback. The I2P router's own link layer (NTCP2/SSU2 between routers) and first-run reseed necessarily use the underlying internet; this is documented to users, and an offline reseed path MUST be provided (§7.8). The application never fetches updates over the clearnet: releases are distributed as signed artifacts through GitHub (manual download) and, later, over I2P (§10.1).

---

## 2. Scope

### 2.1 Product scope

1:1 and private group messaging; files; voice messages; real-time voice/video (subject to feasibility); public groups with discovery (later); Android UI; CLI; Agent API; MCP; I2P-only transport; no mandatory server.

### 2.2 MVP

| Feature | MVP | Notes |
|---|---|---|
| 1:1 text | Required | Core path |
| Contact enrollment (invite → enroll → MLS 1:1) | Required | §6.5 |
| CLI + Agent API (text, contacts, invites, events) | Required | Test harness and first-class user |
| Private groups (text) | Immediately after 1:1 is stable | Needs §6.6–6.8 |
| Android UI | Required | After CLI/Agent are working |
| Files, voice messages | Deferred | Design extension points now |
| Real-time calls | Deferred, experiment-gated | §6.10 |
| Public groups, multi-device, I2P relays | Deferred | Must not be precluded |
| Clearnet or public servers | Never | No fallback |

### 2.3 Coder instructions

- "Deferred" means not implemented yet, not cancelled. Reserve frame types, API methods and storage columns.
- Do not invent cryptography where Marmot/MLS defines it. Do not claim a security property because an option is set; prove it by integration test against the pinned i2pd fork.
- When a consequential behavior is undefined, write an ADR; do not choose silently.

---

## 3. Architecture

```text
┌───────────────────────────────────────────────────────────────┐
│ Frontends: Android (Compose) │ inim-cli │ Agent API │ MCP     │
└──────────────────────────────┬────────────────────────────────┘
                               │ UniFFI (Android, in-process)
                               │ local IPC: Unix socket / named pipe + token (desktop/headless)
┌──────────────────────────────▼────────────────────────────────┐
│ INIM core (Rust) — single owner of a profile                  │
│  identity · marmot (MDK/OpenMLS) · storage (SQLCipher)        │
│  protocol (frames, outbox/inbox, ACK, sync) · enrollment      │
│  group-mesh · permissions/approvals · api                     │
│  transport: I2pTransport  ── inim-i2cp client crate           │
└──────────────────────────────┬────────────────────────────────┘
                               │ I2CP — Unix socket or in-process pipe (never open TCP on shared hosts)
┌──────────────────────────────▼────────────────────────────────┐
│ i2pd fork (embedded library on Android; child process on      │
│ desktop/headless): persistent Destination, Encrypted          │
│ LeaseSet, per-client auth, key ring, allowlist, tunnels       │
└───────────────────────────────────────────────────────────────┘
```

**Hard rules**

- Frontends never talk to i2pd. Only the core does.
- Only the core modifies identity, MLS state, transport keys, authorization lists, messages and permissions.
- All connectivity uses Secret LeaseSets with per-client authorization. No ordinary public LeaseSet, no clearnet fallback.
- **One core process owns a profile** (desktop/headless: daemon `inimd`; Android: the app's core service). CLI, agents, MCP and other UIs are clients of that owner over authenticated local IPC. They do not open the database themselves. This replaces v0.4's multi-process locking approach.
- The router is configured with nothing but INIM's own Destination: no HTTP/SOCKS proxies, no SAM/BOB, no `tunnels.conf` client/server tunnels, no address-book subscriptions, no web console exposed beyond a local diagnostic socket (Appendix A, F-7).

---

## 4. Technology stack

| Layer | Decision | Notes |
|---|---|---|
| Language | Rust 2024, MSRV ≥ 1.90 | MDK 0.8 requires Rust ≥ 1.90 [V] |
| Marmot/MLS engine | **MDK** (`mdk-core`, `mdk-storage-traits`) on **OpenMLS** | MIT licensed [V]. Pin exact versions (mdk-core 0.8.0, openmls 0.8.1 were current at review [V]). **Do not copy code from whitenoise-rs (AGPL-3.0) [V].** |
| Protocol revision | Marmot MIP-00..03 at a pinned commit of `marmot-protocol/marmot` | MIPs are in "Review" status [V]; pin and diff on every upgrade |
| Ciphersuite | `MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519` | Only required Marmot suite [V] |
| Identity | secp256k1, NIP-19 bech32 `nsec`/`npub`, BIP-340 Schnorr | |
| Async | `tokio` | OpenMLS/MDK storage is **synchronous**: run database work on dedicated blocking threads |
| Storage | **`rusqlite` with `bundled-sqlcipher`** | `sqlx` dropped (ADR-007). MLS state, inbox/outbox and app tables share one DB and one transaction. If `mdk-sqlite-storage` can run on SQLCipher, use it; otherwise implement `mdk-storage-traits` on our DB **[TV]** |
| Bindings | `uniffi` → Kotlin | |
| Android UI | Kotlin + Jetpack Compose, Material 3, minSdk 26 | |
| I2P router | **INIM i2pd fork**, base version pinned (BSD-3-Clause) | Appendix A |
| I2P control | **I2CP** via our `inim-i2cp` Rust client crate | SAM not used (it cannot express F-1..F-4 either) |
| I2P data plane | Datagram2 / Datagram3 / raw (default) or streaming (fallback) | ADR-002, §7.4 |
| INIM-own wire structures | CBOR (deterministic encoding) | Freeze in ADR-003. Marmot events stay as Nostr event JSON, byte-for-byte as MDK produces them |
| Logging | `tracing` | Never log secrets, plaintext, auth keys, invite contents, or contact lists |
| Agent protocol | JSON-RPC 2.0 over JSON-Lines; MCP server on top | §10 |

All versions (crates, MIP commit, i2pd fork base, MLS version, cipher suite, CBOR profile) go into `DEPENDENCIES.md`. Upgrades require the compatibility tests in §15.

---

## 5. Identity

### 5.1 User identity

- Long-term Nostr-compatible secp256k1 key. `nsec` is exposed only through explicit, confirmed export.
- Import of an existing `nsec` is supported by design (§1). Generating a fresh identity is the UI default for new users; the import path warns that the `npub` appears in every MLS credential, so all contacts and group members can link this messenger identity to that Nostr identity. I2P hides network location, not the `npub`.
- The same profile is used by UI, CLI and agents through the owning core.
- Optional later: external signer support (e.g., NIP-55 on Android) so the `nsec` never enters the app. The core needs Schnorr signing and NIP-44 ECDH (Welcome gift wraps), so the signer must offer both. ADR when scheduled.

### 5.2 Marmot identity and MLS credentials [V]

- MLS credential type is `BasicCredential` whose identity is the 32-byte Nostr public key.
- **MLS signing keys are separate from the Nostr key** (Ed25519 in the default suite). Compromise of the Nostr key does not by itself expose past MLS content; each device is a separate MLS leaf.
- The binding between npub and MLS participant is the one defined upstream: the KeyPackage is carried in a Nostr event signed by the npub, and the credential carries the npub. Reuse it exactly; add interoperability tests that create and verify credentials and KeyPackage events with MDK.
- The permanent `npub` MUST NOT change when MLS signing keys or device state rotate.

### 5.3 Contact states

Distinguish and display three independent states: **Card imported**, **Transport authorized**, **MLS conversation established**. A scanned QR is never "verified" by itself. Optional out-of-band verification uses a Short Authentication String (§6.5, step 7).

---

## 6. Marmot-over-I2P profile (relay-less)

### 6.1 Principle and compatibility level

INIM uses MDK as its Marmot engine and keeps the **Marmot event objects** (KeyPackage, Welcome inside gift wrap, group events) in their upstream form, carrying them as signed blobs inside INIM frames over I2P instead of publishing them to Nostr relays.

Event kinds currently used by MDK [V]: KeyPackage kind **30443** (addressable; legacy **443** accepted on read), Welcome rumor kind **444** delivered inside a NIP-59 gift wrap (kind **1059**), group events kind **445** (content = `base64(nonce ‖ ChaCha20-Poly1305(MLS message))`, key derived from the MLS exporter secret, published under a fresh ephemeral key, routed by the `h` tag = `nostr_group_id`), group data extension type **0xF2EE**.

Compatibility statement (MUST appear in user-facing docs): INIM is **content-compatible** with Marmot (same MLS groups, credentials, KeyPackages and event encodings) but **not wire-compatible** with WhiteNoise clients, which require Nostr relays. INIM will not implement any bridge to Nostr relays or WhiteNoise: every such path is clearnet and contradicts §1.

Integration traps to check **[TV]**:
- MDK group creation may take a relay list. INIM MUST pass an empty list if allowed; if MDK requires a non-empty value, record an ADR and use a value no client will try to dial.
- MIP-04 (encrypted media) uses Blossom HTTP servers. It is **unusable as specified** under the no-clearnet rule; only its encryption/metadata format may be reused (§6.9).
- Marmot kind-445 publication with ephemeral keys, and gift-wrap timestamp randomization, are relay-side-metadata protections. Keep them (MDK emits them); do not "optimize" them away.

### 6.2 Roles Marmot gives to relays and how INIM replaces them

| Relay role in Marmot | INIM replacement |
|---|---|
| Publish/fetch KeyPackages (kinds 30443/443, relay list 10051) | KeyPackage events delivered in Enrollment and on `KP_FETCH` over an authorized channel (§6.4) |
| Store and order group events | Direct fan-out + member-held event logs + commit ordering rules CR-1..CR-4 (§6.7) |
| Deliver Welcome (gift wrap) | Direct frame to the invitee over the authorized channel (§6.5) |
| Offline buffer | Sender outbox now; member-as-relay sync (§6.8); I2P relays later (§19) |
| Discovery of other members' endpoints | MLS-carried transport offers (§6.6) |

### 6.3 Frames

INIM's own wire object. Version, type and ids are the only clear fields outside the Marmot event.

```rust
struct Frame {
    v: u16,                  // wire version
    t: FrameType,            // see below
    id: [u8; 16],            // random per logical frame; identical on every retry
    frag: Option<(u16,u16)>, // (index, count) when fragmented
    body: Vec<u8>,
}
```

| Type | Body |
|---|---|
| `HELLO` | protocol versions, features, max frame size |
| `EVENT` | one Marmot event as Nostr JSON (30443 / 1059-wrapped 444 / 445) |
| `ACK` | list of frame ids + level (`RECEIVED` or `DELIVERED`) + optional `(epoch, epoch_auth_trunc)` |
| `KP_FETCH` / `KP_RESP` | request/response for a KeyPackage event |
| `SYNC_REQ` / `SYNC_RESP` | missing-commit/event range for a group (§6.8) |
| `ENROLL_REQ` / `ENROLL_RESP` | contact enrollment (§6.5) |
| `PING` | liveness |

Requirements:

- No `sender_npub`, conversation id, file name, call type or plaintext in the frame. The sender's identity is established by MLS processing, never by a frame field.
- The only conversation-linked routing datum visible to a peer is the Marmot `h` tag. It is exposed only to authorized peers inside I2P. Document it.
- Maximum frame size and fragmentation: I2P datagram payloads should stay near 8–10 KB **[TV]**; frames larger than the negotiated MTU MUST be fragmented with per-fragment ACK and selective retransmit. Welcome messages grow with group size (MDK notes problems above ~150 members on relays [V]); fragmentation removes that limit but large groups remain constrained by §6.6.
- Frames from a destination that is not allowlisted are dropped before parsing, except as allowed in §7.6 (migration).
- Fuzz the parser (§15).

### 6.4 KeyPackages without relays

- Each client keeps a pool of single-use KeyPackages (default 20, refill threshold 8) plus one last-resort KeyPackage, as MDK/OpenMLS define.
- A **separate KeyPackage is issued per authorized peer** where practical, so that a peer cannot consume or enumerate the pool used for others.
- Delivery: inside `ENROLL_REQ/RESP`, and on demand via `KP_FETCH` from an authorized peer.
- Private material for a KeyPackage is deleted from storage when a Welcome consumes it (OpenMLS storage-deletion rules; document flash-storage limits, §9.2).
- Expired or invalid KeyPackages are rejected per upstream rules; the peer is asked for a fresh one.

### 6.5 Contact establishment: Card, Invitation, Enrollment

**Objects** (formats in ADR-005; all signatures are BIP-340 by the npub over canonical CBOR with a domain-separation prefix such as `"INIM/card/v1"`; this is an INIM extension, not part of Marmot, and MUST be documented as such):

```text
ContactCard   (no secrets; may be public)
  v, npub, dest_b33 (+flags: secret-required, auth=DH), features[], created_at, sig

Invitation    (SECRET until consumed or expired)
  v, ContactCard (inviter), invite_id[16],
  bootstrap_auth_priv   // X25519 client-auth key for the inviter's Destination
  expires_at, policy_hint, sig (by inviter npub over all fields)
  Encodings: QR, and a text URI  inim://i/<base64url(cbor)>  (agents cannot scan QR)
```

A ContactCard alone grants nothing: without an authorized client key the Encrypted LeaseSet cannot be decrypted. There is intentionally no cold-contact path.

**Protocol** (Alice invites Bob). Private keys marked ⟶ cross the network only inside I2P's end-to-end encrypted, destination-authenticated session, and only as short-lived bootstrap material.

1. **Alice creates the Invitation.** She generates `ik` (X25519), authorizes `ik_pub` in her Destination's client list with label `invite:<id>` and `expires_at` (default: 10 min for in-person QR, 24 h for remote link), and signs the Invitation. Outstanding invitations are limited (default 8) because each consumes a client-list slot (§7.5).
2. **Bob imports it.** He verifies Alice's signature and expiry. He generates `kBA` (client key for **Alice's** Destination; private half stays on Bob forever) and `kAB` (client key for **Bob's** Destination), authorizes `kAB_pub` on his own Destination with label `bootstrap:<id>` and a short expiry, and creates a KeyPackage event.
3. **Bob → Alice `ENROLL_REQ`**, sent using `ik`: `invite_id`, Bob's ContactCard, `kBA_pub`, `kAB_priv` ⟶ (bootstrap, reverse direction), Bob's KeyPackage event, nonce, signature by Bob's npub over `(domain, invite_id, alice_npub, alice_dest, bob_card, kBA_pub, nonce)`.
   *Why `kAB_priv` is sent:* Alice cannot reach Bob until Bob has authorized an Alice key, and a reply over Bob's Encrypted LeaseSet needs exactly that. Whether a server can reply to a client with an unknown encrypted LeaseSet is [TV] (E-4); this design does not depend on the answer.
4. **Alice validates:** invitation valid/unexpired/unused; both signatures; the connecting Destination equals `bob_card.dest`; KeyPackage is valid and its credential identity equals `bob_npub`. Policy: `auto_accept` (agents, trusted contexts) or `ask` (human default; shows Bob's npub, requires confirmation). She then authorizes `kBA_pub` (label `contact:<bob_npub>`), marks the invitation consumed (first confirmed npub wins; later attempts fail), and stores `kAB_priv` in the key ring for Bob's Destination.
5. **Alice → Bob `ENROLL_RESP`**, via a new connection using `kAB_priv`: accept, Alice's card (echo), signature, and, per Marmot, **creates the 1:1 MLS group with Bob's KeyPackage** and sends the Welcome (gift-wrapped) as an `EVENT`. Alice removes `ik` after the first frame from Bob that arrives *after* `ENROLL_REQ` (it can only have used `kBA`, since `ik` is no longer needed once `kBA` is published) or after a 10-minute grace period.
6. **Bob processes the Welcome** (validates group data extension, admins, membership); the conversation becomes *established* only after MLS processing and persistence succeed (§8.4). Bob sends an `ACK`.
7. **Optional SAS:** both sides derive a 6-digit code from `H(invite_id, alice_npub, bob_npub, alice_dest, bob_dest, kBA_pub)` and may compare it out of band. Recommended for remote invitations.
8. **Credential rotation:** within 1 hour of establishment, each side replaces credentials it did not generate. Alice generates `kAB'` (a client key for Bob's Destination) and sends `kAB'_pub` in an MLS application message (`transport.rotate`); Bob authorizes it, confirms in MLS, Alice switches, Bob removes `kAB`. After this, **no private authorization key has ever been transmitted except the bootstrap ones, and those are revoked**. Unrotated bootstrap credentials are auto-revoked at expiry.

Retries, duplicates, interrupted enrollment, restarts and expired KeyPackages follow the state machine in ADR-005; every step is idempotent keyed by `invite_id`.

**Destination migration (lost device / reinstall):** a peer that holds valid credentials but connects from an unknown Destination may only deliver MLS-protected `EVENT` frames; if one decrypts as a `card.update` from a known leaf, the allowlist is updated. All other frames from unknown Destinations are dropped. Details in ADR-005.

### 6.6 Group transport: tiers

**Requirement:** group size must not be architecturally capped at a small number; very large groups (tens of thousands and more) are a goal.

**Why one mechanism cannot serve every size.** In a relay-less network each sender delivers every message to every member, and a mesh needs a credential per member pair. That cannot work from a phone beyond small groups (client-list capacity §7.5, datagrams per message, ACK load). Reference points **[V]**: Vector's MLS group chats are capped at 100 members, and its large "Communities" use a separate, non-MLS protocol (Concord: epoch-keyed channels, roles, rekey on removal); the Marmot ecosystem reports Welcome messages exceeding relay size limits above ~150 members; RFC 9420 targets groups "from two to thousands" and notes tree and commit size can grow linearly with the group; the IETF Light MLS drafts target thousands to millions of members by making most members light clients that cannot commit and have only partial authentication information, with a delivery service keeping public group state. The limits seen in WhiteNoise/Vector are implementation and delivery-service limits, not hard protocol limits.

| Tier | Mechanism | Size target | Needs |
|---|---|---|---|
| **A — mesh** | Full MLS, members connect directly | ≤ 32 (cap set by E-6/E-11) | Nothing beyond Phase 8 |
| **B — hub-hosted** | Full MLS; members connect only to group hubs | Thousands; cap set by measurement (E-11) | I2P hubs (§19), Phase 12 |
| **C — community** | Not a per-member MLS tree (ADR-016) | ≥ 10⁴, aiming at tens of thousands and beyond | Hubs, Phase 12+ |

Tiers B and C are gated on hubs and are specified fully only after experiments E-11/E-12. Phase 8 delivers Tier A and keeps the group abstraction independent of the tier, so a group can be created in a tier without changing the MLS layer, the frame format or the API.

#### Tier A — mesh groups

Group membership (MLS) and transport authorization (I2P) are separate (unchanged from v0.4), but members of a mesh group must be able to reach each other. INIM solves this **inside MLS**, so no secret ever leaves the group:

1. When X joins or sees a new member M, X generates a client key `kXM` **for M's Destination** and sends `kXM_pub` plus X's ContactCard in an MLS application message `transport.offer` (public keys only).
2. Any member can forward the opaque group ciphertext (§6.8), so the offer reaches M even if X cannot yet reach M directly.
3. M, authenticated by MLS as the recipient, authorizes `kXM_pub` per `group_transport_policy` (`auto` | `ask` | `never`; default `ask` for humans, `auto` for agents) and binds `X's npub ↔ X's Destination` in `peer_auth`.
4. Removing a member from a group never revokes anyone's transport access, and revoking transport never changes MLS membership (see §7.9).

Disclosures that the UI MUST state at join time: joining reveals your I2P Destination address to all members; they cannot connect without your approval under `ask`/`never`.

Tier A limit: default ≤ 32 members until experiments E-6/E-11 give measured numbers; client-list slots used by group peers are budgeted against §7.5.

#### Tier B — hub-hosted MLS groups

- Members authorize and connect **only to the group's hubs** (a few Secret-LeaseSet services, §19), never to each other. No N×(N−1) mesh; members do not learn each other's Destinations (a privacy gain over Tier A).
- Every member is still a full MLS client: same Marmot credentials, KeyPackages, Welcome, kind-445 events and application messages as MDK produces. Hubs store and fan out opaque `EVENT` frames, serve `SYNC`, and never hold MLS secrets.
- Commits come only from admins and are **batched** (commit window, e.g. 5–60 s) so that join/leave churn does not produce one epoch per event. A Welcome includes the full ratchet tree (roughly linear in group size) and is delivered as a bulk transfer (fragmented frames or a bulk stream), not as a single datagram.
- A hub learns member Destinations, timing, frame sizes and the `h` tag; it learns no content. The group creator can run their own hub on a headless INIM node; others may volunteer.
- Cap is determined by E-11 (memory for the tree, Welcome size, commit processing time on a mid-range phone at 100 / 1 000 / 5 000 / 10 000 members with the pinned OpenMLS).

#### Tier C — community mode

- Aimed at tens of thousands of members and beyond. A per-member MLS tree at this size has linear tree cost on every device; it must not be promised.
- **Policy: upstream first.** As of 2026-11-13 the Marmot documentation lists lighter Welcome messages for larger groups as work in progress **[V]** and no published design for very large MLS groups was found; Vector's large communities use a separate non-MLS protocol **[V]**. ADR-016 starts by re-checking what Marmot/WhiteNoise have specified. If upstream has a design, INIM adopts it and does not invent its own. The candidates below are used only if upstream has nothing by the start of Phase 12.
- Candidate designs (decided in ADR-016 after E-11/E-12): (i) **Light MLS** (IETF drafts): most members are light clients that cannot commit, handshake messages are public, hubs track public group state; requires an extension that OpenMLS/MDK are not known to support **[TV]** and departs from Marmot; (ii) **epoch-keyed symmetric channels** with rekey on removal (Concord-style): scalable, but weaker per-member forward secrecy and post-compromise security than MLS.
- Whichever is chosen, the UI and docs MUST state the weaker or different guarantees of Tier C groups in plain terms. No Tier C group is described as having MLS-grade properties unless it does.

### 6.7 Commit ordering and forks (the missing Delivery Service)

MLS needs a single agreed order of commits per epoch. Marmot relies on relays and client-side handling; INIM has neither. Rules, to be formalized and model-checked in ADR-004:

- **CR-1 Committers.** Only group admins (as defined in the Marmot group data extension **[TV: confirm admin semantics in MIP-01]**) create commits. Non-admins send MLS proposals (e.g., Update for key rotation); admins commit them. In 1:1 groups both parties are admins; the creator is the tie-break winner.
- **CR-2 Hold before merge.** A committer stages its commit (OpenMLS pending commit), delivers it, and merges only after ACK from every currently reachable member or after `commit_hold` (default 30 s), whichever is later. Sending application messages in the new epoch waits for the merge.
- **CR-3 Conflict.** If a different commit with the same parent epoch arrives while one is staged, the commit with the lowest `SHA-256(commit bytes)` wins. The loser clears its pending commit, processes the winner, and re-submits its proposals.
- **CR-4 Fork detection.** `ACK` frames carry `(epoch, truncated epoch_authenticator)`. A mismatch marks the group `FORKED`: sending stops, the user/agent is notified, and recovery is by re-adding the diverged member from the majority branch. State is never silently rolled back.
- OpenMLS parameters (`max_past_epochs`, out-of-order tolerance, forward distance) are set in the INIM profile and recorded in `DEPENDENCIES.md`.
- Outbox stores **final ciphertext**. Retries resend identical bytes; the core never re-encrypts (that would advance the ratchet and create a new logical message).

### 6.8 Catch-up and member-as-relay

- Every member keeps an encrypted log of recent group events (commits and application ciphertexts) for `sync_window` (default 14 days or 5000 events). The blobs are already encrypted to the group, so serving them to any authorized member discloses nothing new.
- On reconnect, a member sends `SYNC_REQ(group, from_epoch, have_ids)` to any reachable member and processes `SYNC_RESP` through normal MLS rules. Missing or stale state yields a recoverable error, never a bypass of MLS validation.
- Event forwarding ("gossip"): any member may send an `EVENT` it holds to any member that lacks it. Receivers deduplicate by event id. Fan-out is bounded (ADR-006) to prevent amplification.

### 6.9 Files (after text MVP; design now)

- Transfer negotiation, keys and metadata travel in MLS application messages.
- Reuse the **encryption and metadata format** of MIP-04 where compatible (ChaCha20-Poly1305 with per-file keys) **[TV]**, but **never Blossom or any HTTP server**. Content moves over the authorized I2P path as chunks.
- Chunked, resumable, selectively acknowledged transfer at the application layer (this is why datagram-first is viable, §7.4). Per-chunk integrity, whole-file hash, size limits, disk-space checks, safe filenames, cancel/retry/resume. A future relay never sees keys or plaintext. File-transfer ADR (ADR-010) is required before coding.
- Voice messages are files and ship with this phase.

### 6.10 Voice/video (after files; experiment-gated)

- Signaling in MLS application messages. Media only over I2P; no STUN/TURN, public relays, or direct-IP fallback.
- Real-time speech through multi-hop tunnels may not reach usable latency. Phase 10 begins with a measured feasibility experiment (RTT, jitter, loss, bandwidth over raw datagrams); ADR-011 decides. Voice messages are the fallback product.

### 6.11 Security properties

- Content and group membership are protected by MLS/Marmot; transport access by Encrypted LeaseSets and per-client authorization; the two layers are complementary.
- No plaintext message bodies or contact lists on the wire.
- Do not claim: protection from compromised endpoints, forwarding of received content, all traffic analysis, retroactive erasure, or guaranteed Android background delivery (§14.3).

---

## 7. I2P transport

### 7.1 Mandatory model

Every connection uses the Encrypted LeaseSet (type 5) with per-client DH authorization. Ordinary LeaseSets are not a fallback; the core refuses to start a session that is not in this mode and the failure is visible to the user.

I2CP option names present in the i2pd source at 2.58 **[V]**: `i2cp.leaseSetType`, `i2cp.leaseSetEncType`, `i2cp.leaseSetAuthType` (1 = DH, 2 = PSK), `i2cp.leaseSetClient.dh.nnn`, `i2cp.leaseSetClient.psk.nnn`, `i2cp.leaseSetPrivKey`. The I2P spec also lists `i2cp.leaseSetSecret` (blinding secret) [V for the spec, **[TV]** for i2pd]. Direction, lifecycle and runtime-update behavior of each option must be established by the Appendix B mapping and E-1..E-5 before any claim is made.

### 7.2 One persistent Destination per profile

Keep v0.4's decision: one persistent inbound/outbound Destination per profile, stable address, fewer tunnels (important on Android). Each peer receives its own client credential. Never share one credential among peers.

### 7.3 Authorization key direction

Per the I2P design, the client generates a DH key pair and gives the **public** key to the Destination owner. INIM follows this for all long-lived credentials (§6.5, §6.6). The only exception is the bootstrap pair in §6.5, which is short-lived, sent only inside an end-to-end encrypted session, and rotated.

### 7.4 Data plane: datagrams vs streaming (ADR-002)

Finding: I2CP is a message interface. TCP-style streaming is a separate library that a non-Java I2CP client has to implement itself [V: I2P I2CP documentation]. i2pd's own streaming code is internal to the router.

Options:

| | A. Datagram-first (proposed default) | B. Streaming over I2CP | C. Fork-provided stream endpoint |
|---|---|---|---|
| Fit for messages | Excellent: one datagram out, one ACK back, no handshake round trip | Connection setup costs round trips over multi-hop paths | Same as B |
| Files | App-level chunking, selective ACK, simple rate control (already required by §6.9) | Built-in windowing | Same as B |
| Calls | Raw/Datagram3 are the natural fit | Poor (head-of-line blocking) | Poor |
| Sender authentication | Datagram2: authenticated + replay prevention (I2P ≥ 0.9.66) [V]; Datagram3: repliable, unauthenticated, small [V] | Streaming signs SYN | Same |
| Work | Verify/extend Datagram2/3 in the fork; implement frame reliability (needed anyway, §8) | Implement the streaming protocol in Rust | Becomes a private SAM-like API; weakens router replaceability |
| Risk | No built-in congestion control; MTU ~8–10 KB [TV]; i2pd support for protocols 19/20 is [TV] | Large implementation, tuning | Lock-in |

**Proposed:** A for messages, files and calls; keep B as a compatible fallback only if E-3 shows datagram reliability is inadequate. Final decision by experiment E-3 (first-message latency cold/warm, p50/p95 delivery time, loss, throughput, behavior with revoked credentials). The `I2pTransport` contract (§7.10) is written so either choice fits.

Whatever is chosen, the sender of every inbound unit must be an **authenticated Destination** that maps to an authorized contact (§7.6). Datagram3 alone is not sufficient for control frames.

### 7.5 Encrypted LeaseSet capacity and metadata

- The number of authorized clients is visible in the encrypted LeaseSet and the entry list has a size limit. The fork pads the client list with dummy entries to size buckets (F-3). Measure the real maximum (E-6) and publish it; it bounds contacts-per-profile, outstanding invitations, and group-mesh size.
- If a profile needs more peers than one LeaseSet can hold, introduce additional "lanes" (more Destinations) through an ADR; do not silently exceed the limit.

### 7.6 Inbound policy

- The router (fork F-4) and the core both enforce an **allowlist of remote Destinations** bound to contacts in `peer_auth`. Traffic from non-allowlisted Destinations is dropped. The server cannot see which client key a peer used, so key authorization alone cannot identify a contact; the Destination binding does (and also gives instant refusal while cached LeaseSets age out).
- Exception: destination migration (§6.5) permits only MLS-protected `EVENT` frames from a credential holder at an unknown Destination.
- Connection attempts, auth failures and unknown-Destination drops are rate-limited and counted (diagnostics without secrets).

### 7.7 Transit tunnels (user option)

Settings (persisted in profile, editable in UI/CLI/API):

```text
transit.enabled              bool   default: false on Android, true on desktop/headless
transit.share_percent        0..100 bandwidth share offered to transit when enabled;
                                    default 50 on desktop/headless, 20 if a mobile user enables transit
                                    (stock i2pd default is [TV]; INIM sets its own)
transit.max_tunnels          u32    cap on participating tunnels
transit.mobile_conditions    unmetered-and-charging-only (default true on Android when enabled)
```

- Map to i2pd `notransit`, `share` and `limits.transittunnels` **[TV]**. Runtime change without restart is fork requirement F-6; otherwise the UI says a router restart is required.
- UI text MUST explain the trade-off: transit helps the network and adds cover traffic, but costs battery and data, and a router that carries no transit may be distinguishable from one that does **[TV: router caps in RouterInfo]**.
- Tunnel length defaults to 3 hops; values below 2 require an explicit expert setting. Tunnel quantities on Android are tuned in E-8.

### 7.8 Router and network configuration

- Minimal configuration generated by the core; no user-editable `i2pd.conf` in production. `tunnels.conf` is for development only.
- First-run reseed uses the clearnet. Provide: (a) default reseed, (b) reseed from a local/offline bundle (i2pd supports `reseed.file` / `reseed.zipfile` **[TV]**), (c) reseed through a user-configured proxy. State this in onboarding.
- Disable address-book subscriptions and every feature unrelated to INIM's Destination (F-7) and verify by traffic audit (E-9): the only non-router-link traffic the fork may originate is INIM's.
- The router's link-layer transports (NTCP2/SSU2) are visible to the local ISP as I2P-like traffic; document this in the threat model.

### 7.9 Authorization lifecycle and revocation

Two separate operations, as in v0.4:

**A. Group removal** is MLS-only (§6.5 of v0.4, retained): admin commit → new epoch → removed member cannot decrypt new epochs. It never touches transport authorization of anyone, in any conversation.

**B. Revoking a contact's access to my Destination:**

1. Identify the credential and the Destination bound to that contact.
2. Remove the client entry via the fork's runtime update (F-2); the router republishes the LeaseSet and **confirms** it.
3. Remove the contact's Destination from the allowlist (F-4) and close its active sessions (F-4). Removing a key does not terminate existing sessions or cached LeaseSets.
4. Delete the revoked credential material (the key ring entry for *my* access to them, and the pending state), clear transient copies.
5. Persist the revocation in `revocations` so a restore or restart never resurrects it.
6. Verify (integration test) that a client using the old credential cannot establish a useful connection.
7. Report success only after router confirmation; return a typed result (`applied`, `sessions_closed`, `router_confirmed`, `pending`).

Revocation prevents future access only: it cannot erase received data or MLS secrets already held. One owner cannot revoke another owner's Destination. Do not rotate the permanent Destination merely to revoke one client unless E-5 proves selective revocation impossible; if so, document impact and re-invitation in an ADR.

### 7.10 `I2pTransport` contract

```rust
#[async_trait]
pub trait I2pTransport: Send + Sync + 'static {
    async fn start(&self, cfg: &RouterConfig) -> Result<()>;
    async fn stop(&self) -> Result<()>;

    async fn ensure_destination(&self) -> Result<LocalDestination>;   // persistent keys; b33 + flags

    // Owner side (my Destination)
    async fn authorize_client(&self, label: &ClientLabel, client_pub: &X25519Pub,
                              expires: Option<SystemTime>) -> Result<AuthChange>;
    async fn revoke_client(&self, label: &ClientLabel) -> Result<RevocationResult>;
    async fn set_peer_allowlist(&self, dests: &[DestHash]) -> Result<()>;
    async fn close_peer_sessions(&self, dest: &DestHash) -> Result<()>;

    // Client side (credentials I hold for others' Destinations)
    async fn set_remote_credential(&self, remote: &RemoteDest, priv_key: SecretKey) -> Result<()>;
    async fn clear_remote_credential(&self, remote: &RemoteDest) -> Result<()>;

    // Data plane (shape fixed by ADR-002)
    async fn send(&self, remote: &RemoteDest, unit: Bytes, opts: SendOpts) -> Result<SendReceipt>;
    fn incoming(&self) -> BoxStream<'static, Incoming>;   // Incoming carries the authenticated DestHash

    async fn set_transit_policy(&self, p: &TransitPolicy) -> Result<TransitApplied>;
    async fn status(&self) -> Result<TransportStatus>;
}
```

Result types MUST distinguish "requested", "router-confirmed" and "failed". A pure-Rust router may replace the fork only if it satisfies this contract and the Phase 1 test suite.

---

## 8. Delivery, inbox and outbox

### 8.1 Model

Direct peer-to-peer delivery. No offline delivery promise without a relay (§19). The outbox is durable; messages stay queued while the peer is unreachable.

### 8.2 States

| State | Meaning |
|---|---|
| CREATED | Built by the core |
| QUEUED | Persisted in outbox (final ciphertext stored) |
| SENT | Handed to the transport |
| RECEIVED | Peer core accepted the frame (transport-level ACK) |
| DELIVERED | Peer core persisted the message durably and ACKed |
| READ | Application-level read receipt, optional, carried **inside MLS** |
| FAILED | Terminal, with diagnostic reason |

Do not equate RECEIVED, DELIVERED and READ. Read receipts are not themselves acknowledged (no ACK recursion). ACK frames are authenticated by the sender Destination and associated with a frame id; `RECEIVED`/`DELIVERED` need no extra MLS layer.

### 8.3 ACK, retry, deduplication

- Every logical frame has a stable id; retries reuse it with bounded exponential backoff and jitter.
- The receiver persists before sending `DELIVERED`. The sender keeps the outbox record until `DELIVERED`.
- Duplicate frames and duplicate MLS ciphertexts (OpenMLS rejects reused generations) are recognized by id and **are not errors**: they are re-ACKed and produce no visible message or side effect.
- Retention and expiry policies are explicit; pending messages are never silently dropped.

### 8.4 Ordering and state integrity

- MLS epoch/ordering follows MDK/OpenMLS and §6.7. Late or out-of-order messages are displayed by the documented rule (sender timestamp inside MLS payload for display; receive order for processing).
- MLS state transitions and the corresponding message-processing result commit in **one** database transaction. A transition is never applied twice after retry or restart. Failed validation = fail closed.
- A conversation is *established* only after Welcome processing and persistence succeed.

### 8.5 Groups

Sender fan-out to each reachable member, independent per-member state, gossip/sync for the rest (§6.8). Success for one member says nothing about others.

---

## 9. Storage and key safety

### 9.1 Database

SQLCipher via `rusqlite`. Tables (at least): `identity`, `contacts`, `peer_auth` (npub ↔ Destination ↔ credential labels), `key_ring` (credentials I hold for others; encrypted), `invitations`, `conversations`, `messages`, `mls_state` (through MDK storage traits), `key_packages`, `outbox`, `inbox`, `group_event_log`, `revocations`, `settings`, `transit_policy`, `agent_permissions`, `approvals`, `audit_log`, `schema_migrations`. The schema supports multiple participants and future devices. Migrations are transactional and tested on existing profiles.

### 9.2 MLS state integrity

- Rust core only; atomic with message metadata; verify on load; stop on corruption; never roll back an epoch silently.
- Follow OpenMLS rules for deleting obsolete secrets; document the limits of real deletion on flash storage and in backups.
- Crash-injection tests around commit, message persistence, ACK and revocation.
- Run blocking DB access on dedicated threads; serialize mutations per group in the core.

### 9.3 Key management

- Random database key, wrapped by Android Keystore. Optional passphrase (Argon2id) unlock. Biometrics only authorize use of a protected key; they are not the key and not a backup mechanism.
- Lock timeout and explicit lock; best-effort memory clearing; documented behavior after reboot, biometric changes, reinstall, Keystore invalidation.
- **Headless/agent profiles:** unattended unlock is allowed from a key file (mode 0600), an inherited file descriptor, or an OS keyring; env-var secrets are discouraged. The mode is explicit in the profile and shown in `info`.
- Credentials in `key_ring` and invitation secrets are encrypted at rest inside the database and never logged.

### 9.4 Process ownership

One owner per profile (§3). The owner serializes all mutations; frontends are clients; events are published after commit. Detect stale locks and recover after crashes. Tests: simultaneous send/receive/commit/restart.

### 9.5 Backup and recovery

- Encrypted backup/export. Recovering the `nsec` alone does not restore conversations, MLS state or transport credentials; say so in the UI.
- Restoring an old backup must not resurrect revoked credentials or an obsolete MLS epoch: restore detects rollback via epoch/revocation checks and forces re-establishment where required.
- Lost device: new device/profile reconnects through Destination migration (§6.5) or fresh invitations. Document which history and forward-secrecy properties are lost when old backups hold old secrets.

---

## 10. Frontends and the agent interface

### 10.1 Android

- Kotlin + Compose; core embedded in-process; i2pd fork embedded as a native library (no externally reachable I2CP port, no dependency on a separate i2pd app) (ADR-008).
- Onboarding (identity create/import, reseed, transit option), contacts with the three states of §5.3, QR create/scan of **Invitations** (with the credential warning), chat, groups, transport status, delivery states, notifications, lock.
- Foreground service: declare the proper foreground-service type. Android 15 limits `dataSync` foreground services in time **[TV]**; because Google Play is not a target, evaluate `specialUse` and a battery-optimization exemption request (both subject to Play policy review, which does not apply to sideloaded builds) in ADR-008.
- **Distribution:** GitHub Releases are the primary channel: signed APKs, published checksums and signing-key fingerprint, **reproducible builds** so that anyone can verify an APK against the source. F-Droid is opportunistic: keep the app free of Google Play Services/FCM and proprietary blobs so inclusion stays possible. No Google dependency of any kind.
- **Updates:** the app never contacts GitHub or any clearnet host. Update notices and artifacts are delivered by manual download or, later, over I2P (signed release manifest verified against the pinned release key, ADR-008). A compromised update channel is a threat; releases are verified before installation.
- **Release-key custody:** (1) the Android APK signing key lives on a hardware token or an offline machine, never as a plain file in CI or on a developer laptop; (2) at least two encrypted offline backups in separate places, because Android only accepts updates signed by the same key and a lost key forces every user to reinstall; (3) use Android's APK signature scheme with key-rotation lineage so a replaced key stays trusted; (4) a separate signing key (minisign or PGP) signs the release manifest and checksums, with the same custody; (5) the key fingerprint is published in several independent places (repository, release notes, project site, later an I2P site) so a substituted key is noticeable; (6) reproducible builds let anyone check that a published APK matches the source, which limits what a compromised signer can hide. CI may build; signing is a deliberate human step with the token. (7) Keys are generated on the owner's own machine, never in an assistant session, a shared chat, CI, or any machine the owner does not control. The backup copy is encrypted (passphrase) **before** it is moved to the owner's server; the passphrase is not stored next to it. `tools/gen-release-keys.sh` automates generation, fingerprint printing and the encrypted backup. A hardware token is the recommended upgrade once releases begin.
- Battery: reconnect backoff, transit off by default, tunnel quantities tuned (E-8).
- No clearnet push: no FCM, no UnifiedPush distributor reached over the clearnet. Be explicit: without a push service, timely notifications depend on the service staying alive; no guarantees under force-stop or OS restrictions.
- **Optional wake-up service inside I2P (ADR-017):** an ntfy/UnifiedPush-style service hosted as an I2P Secret-LeaseSet service is allowed as a later option. Limits to state in the ADR: it carries content-free wake-ups only; the phone still needs a live router and a persistent connection to it, so it does not by itself remove the foreground-service requirement or the battery cost; it adds a metadata observer (the wake-up host sees when a profile is woken). **It is on by default** (owner decision): onboarding shows this disclosure, lets the user pick the host (their own server or a volunteer-run one), and settings let them turn it off at any time. Failure or absence of a wake-up host never affects message delivery; the foreground service stays the primary path.
- Handle process death, router restart, network changes and reboot without regenerating Destination keys.

### 10.2 CLI (`inim`)

Thin client of the owner daemon. Illustrative grammar (freeze in the API reference):

```text
inim daemon start|stop|status
inim unlock | lock
inim info                                  # app, identity, storage, transport, transit, groups
inim identity show | import | export       # export needs explicit confirmation
inim invite create [--ttl 10m] | list | revoke <id>
inim invite accept <inim://i/...>
inim contacts list | show <npub> | revoke <npub>
inim send --to <npub|conv> (--text "…" | --stdin) [--idempotency-key K]
inim messages <conv> [--since CURSOR]
inim events --follow [--since CURSOR]
inim group create|add|remove|leave …
inim transit show|set --enabled --share 20
inim --format json <any command>
```

### 10.3 Agent API (first-class)

Goal: an AI agent or script can run the whole messenger lifecycle reliably, unattended, without a human screen.

- **Protocol:** JSON-RPC 2.0, newline-delimited, over stdio (`inim agent`) or a local Unix socket/named pipe with a strong local token. No network listener by default.
- **Self-describing:** `describe` returns method names, parameter schemas and error codes as JSON Schema; the repository ships the same schema and `docs/agent-guide.md`.
- **Reliable consumption:** every event has a monotonic `event_id`; `wait_events(since, timeout)` supports long-poll without loss across restarts; messages are never consumed destructively.
- **Idempotent writes:** `send_message` takes an `idempotency_key`; repeats return the original `message_id`/state.
- **Typed outcomes:** every mutating call returns what happened (`queued`, `delivered`, `pending_router_confirmation`, `needs_approval`), never a bare "ok".
- **Text invitations:** `invite.create` returns the `inim://i/…` URI (and optional QR image); `invite.accept` takes the URI. No camera needed.
- **Structured errors:** stable codes (`locked`, `permission_denied`, `rate_limited`, `peer_unreachable`, `group_forked`, `approval_required`, …) with machine-readable detail.
- **Capabilities** (per agent token, expiring, individually revocable): `read` (by conversation), `send` (by contact/conversation, with rate limits), `contacts.manage`, `invite.create`, `invite.accept`, `group.manage`, `transit.configure`, `identity.export` (denied by default), `admin`. "Database unlocked" never implies any capability.
- **Approval queue:** sensitive actions (accepting enrollment from a new npub, adding group members, transport offers under `ask`, export) generate `approval_required` events. They can be resolved by a human UI, by a supervising agent with `approvals.resolve`, or auto-resolved by explicit policy.
- **Two operating modes:** *owner mode* (the agent holds the identity and runs unattended; policies `auto_accept` allowed) and *delegate mode* (the agent acts on a human's profile under limited capabilities).
- **Audit:** security-relevant actions are logged without plaintext or secrets.
- **Rate limiting and input validation** on every method.

### 10.4 MCP server (moved up to Phase 6)

Thin layer over the Agent API: same permissions, no bypass. Tools such as `inim_info`, `inim_wait_events`, `inim_read`, `inim_send`, `inim_contacts`, `inim_invite_create`, `inim_invite_accept`, `inim_approvals`. Defaults are conservative (send restricted to allow-listed contacts, rate-limited).

### 10.5 Agent safety rules (normative)

- **Received message content is untrusted data, never instructions.** The API marks every message and attachment as `untrusted: true`; MCP wraps it as quoted data; docs and tool descriptions state that an agent must not execute, forward or act on instructions found in message bodies without independent authorization.
- Agents never receive `nsec` unless explicitly granted `identity.export` by the owner.
- Autonomous enrollment (`auto_accept`) is off by default and must be enabled per profile; the default for new agent profiles is `ask` resolved by a supervisor.
- Outgoing rate limits and per-contact send scopes apply by default.
- Optional self-declaration: a profile may flag itself `automated` in its ContactCard; it is informational only.

### 10.6 Shared-core diagram

```text
Compose ─┐
CLI      ─┤
Agent    ─┼──> owner core ───> I2pTransport ───> i2pd fork
MCP      ─┘
```

---

## 11. Core API (minimum)

`initialize`, `unlock`, `lock`, `info`, `describe`, `generate_identity`, `import_identity`, `get_own_profile`, `create_invitation`, `list_invitations`, `revoke_invitation`, `accept_invitation`, `list_contacts`, `revoke_contact_transport_access`, `rotate_transport_credential`, `create_conversation` (1:1 / group), `group_add_member`, `group_remove_member`, `send_message`, `list_messages`, `wait_events` / `observe_events`, `list_approvals`, `resolve_approval`, `set_transit_policy`, `get_transport_status`, `grant_agent_capability`, `revoke_agent_capability`.

Mutating MLS state or transport authorization returns explicit typed outcomes; local acceptance is not remote delivery or completed revocation. Extend later with file and call APIs without breaking these.

---

## 12. Versioning and compatibility

Version independently: wire protocol (Frame), ContactCard/Invitation formats, database schema, Core/Agent API, Marmot profile (MIP commit + MDK version), fork configuration contract.

Capability negotiation in `HELLO`. Unsupported mandatory features produce an explicit error. **No downgrade** to public LeaseSets or clearnet. Migrations preserve identity, Destination keys, conversations and MLS state. Upstream changes (MDK, MIPs, OpenMLS, i2pd base) need a compatibility review and tests before adoption.

---

## 13. Implementation phases

**Phase 0 — Pinning, ADRs, experiment plan.** Pin MDK/OpenMLS/MIP commit/i2pd base. Write ADR-001…009 skeletons. Resolve all [TV] items that block Phase 1.

**Phase 1 — Fork and transport proof of concept (experiments E-1…E-9, Appendix C).** Two independent routers, Encrypted LeaseSet with per-client DH auth, key ring, runtime authorize/revoke, datagram vs streaming, reply path, LeaseSet capacity, restart, traffic audit. *Gate: ADR-002 decided; Appendix B filled with verified behavior.*

**Phase 2 — Core skeleton, identity, storage, daemon + minimal CLI.** `inimd`, `inim info`, identity import/export, SQLCipher, Keystore abstraction, migrations, lock/unlock.

**Phase 3 — Marmot engine over a simulated transport.** MDK integration, KeyPackage pool, 1:1 and group creation, Welcome/commit/application messages, persistence, MLS+message transactions, CR-1…CR-4 under injected delay/duplication/partition, byte-level interoperability vectors against MDK/WhiteNoise events (credentials, KeyPackages, Welcome, kind-445).

**Phase 4 — Enrollment and real I2P transport.** ContactCard, Invitation, Enrollment, credential rotation, allowlist, `transport.offer`; two real routers.

**Phase 5 — Messaging reliability.** Frames, fragmentation, outbox/inbox, ACK levels, dedup, retry, sync; restart, offline, lost-ACK, duplicate tests. *Gate: the MVP acceptance criteria that do not need Android (§15.3).*

**Phase 6 — Agent API and MCP.** JSON-RPC, schema, events/cursors, idempotency, capabilities, approvals, audit, agent guide. Agents become the e2e test driver from here on.

**Phase 7 — Android MVP.** Onboarding, Invitation QR, contacts, chat, status, notifications, lifecycle, transit option, recovery.

**Phase 8 — Private groups hardening.** Mesh enrollment, gossip, sync from members, admin commits and failover, member removal and its isolation tests, fork recovery.

**Phase 9 — Files and voice messages** (ADR-010).

**Phase 10 — Real-time calls** (feasibility experiment first; ADR-011).

**Phase 11 — Security hardening.** Threat-model review, fuzzing, crash recovery, backup/restore, revocation audits, external review.

**Phase 12 — I2P-hosted relays and group hubs (§19), Tier B groups.** Experiments E-11/E-12 run earlier (they can start in Phase 3) so that ADR-016 is ready before this phase.

**Phase 13+ — Tier C community groups (ADR-016), public groups and discovery, multi-device, pure-Rust router, external signer.** Each through its own specification/ADR without weakening existing guarantees.

---

## 14. Security requirements and threat model

### 14.1 Required protections

- Transport only through authorized Encrypted LeaseSets; fail closed.
- MLS/Marmot protection for content; keys, MLS state and credentials encrypted at rest.
- Contact identity ↔ MLS credential binding per upstream; INIM Card/Invitation/Enrollment signatures validated.
- Per-contact credentials secret and never logged; bootstrap credentials short-lived and rotated.
- Allowlist of Destinations bound to contacts.
- Agent capabilities explicit; approvals auditable; `nsec` only via explicit export.
- No plaintext, secrets or invitations in logs, crash reports or analytics (there is no analytics).
- Group removal and transport revocation remain separate.

### 14.2 Threats

| Threat | Mitigation / limitation |
|---|---|
| Malicious or curious I2P router/peers on path | MLS end-to-end; I2P layers; metadata minimized |
| Unauthorized I2P client | Encrypted LeaseSet + per-client auth + Destination allowlist |
| Invitation intercepted (photo of QR, link leak) | Short TTL, single use, first confirmed npub wins, `ask` policy, SAS for remote invites, bootstrap rotation |
| Contact/bundle substitution | Signed cards/invitations, npub in KeyPackage credential, explicit confirmation |
| Hostile group member learns Destinations | Disclosed at join; `ask`/`never` policies; cannot connect without approval |
| LeaseSet client-count leak | Padding buckets (F-3); published capacity limit |
| Another Android app reaching I2CP | Embedded router / Unix socket; no open TCP port (F-8) |
| Stolen device/database | SQLCipher, Keystore-wrapped key, lock |
| MLS state corruption / rollback | Transactions, integrity checks, fail closed, rollback detection |
| Commit race / group fork | CR-1…CR-4, epoch authenticator in ACKs, `FORKED` state |
| Compromised Agent API client | Capabilities, expiry, rate limits, approvals, audit |
| **Prompt injection through message content** | `untrusted` marking, quoting in MCP, no auto-execution, send scopes |
| Replay/duplicate | Frame ids, Datagram2 replay prevention, dedup, idempotency keys |
| Removed member | MLS commit and new epoch |
| Revoked client | Runtime removal, allowlist, session close, verified by test |
| Nostr identity linkage (imported key) | Disclosed; I2P hides location, not identity |
| Traffic analysis | Minimize metadata; residual timing/volume leakage documented |
| ISP sees I2P usage | Documented; router transports are I2P-typical |
| Group hub learns metadata (Tier B/C) | Sees member Destinations, timing, sizes, group tag; no content; creator-run hubs; documented |
| Tier C weaker guarantees misunderstood | Plain-language UI/docs statement per tier |
| Compromised update channel | Signed releases, reproducible builds, verification before install |

### 14.3 Explicit limitations

No protection against compromised endpoints or malware on an unlocked device; participants who copy content; all traffic-correlation analysis; retroactive erasure; guaranteed Android background delivery; the public `npub` linkage of an imported identity.

---

## 15. Testing and acceptance

### 15.1 Required tests

| Test | Expected |
|---|---|
| Valid / tampered / expired ContactCard and Invitation | Accepted / rejected / rejected |
| Invitation reuse after consumption | Rejected |
| Enrollment replay and concurrent claims | First confirmed npub wins; others fail |
| Interrupted enrollment at each step, restart | Resumes idempotently |
| Bootstrap credential expiry/rotation | Revoked on time; only rotated keys remain |
| Authorized / unauthorized / revoked client | Connects / no useful access / no new access |
| Revoke with active session | Sessions closed; documented semantics |
| Other contacts after revoke | Still authorized |
| Key ring with N peers | Correct credential per peer, no cross-use |
| Destination allowlist | Unknown Destination dropped; migration path limited to MLS `EVENT` |
| i2pd restart / core restart | Destination, auth, MLS, outbox recover |
| Corrupted MLS state | Detected; processing stops |
| Duplicate frame / duplicate MLS ciphertext | No visible duplicate; re-ACK |
| Lost ACK | Retry with identical bytes; dedup |
| Offline recipient, reconnect | Queued, then delivered |
| Commit conflict (CR-3) and hold (CR-2) | Deterministic winner; no fork |
| Fork detection (CR-4) | `FORKED`, sending halts, recovery works |
| Catch-up from another member | Missing epochs recovered via MLS rules |
| Group removal | Removed member cannot decrypt new epoch |
| Group removal isolation | Other conversations and Destinations unaffected |
| Transport offer under `ask`/`never` | No authorization without approval |
| Marmot byte vectors | MDK/WhiteNoise-produced KeyPackages, Welcomes, 445 events verified |
| No relay list leakage | Group data contains no dialable relay |
| Concurrent clients on one profile | No MLS race or DB corruption |
| Agent permission denial; approval flow; idempotent send | Rejected / queued / one message |
| Prompt-injection tagging | Every message `untrusted`; MCP output quoted |
| Transit settings | Applied/confirmed, persisted, restart semantics correct |
| Traffic audit | No non-I2P traffic from INIM processes beyond router links and reseed |
| Protocol mismatch | Explicit error, no downgrade |
| Database restore / rollback | Detected per policy |

### 15.2 Categories

Unit, transport integration (≥ 2 independent routers), Marmot integration, end-to-end (≥ 3 clients), agent API, property-based, fuzzing (frames, cards, invitations, JSON-RPC), crash injection (commit, persistence, ACK, revocation, rotation), load (fan-out, concurrent sessions, Android resources).

### 15.3 MVP acceptance gate

1. Two independent clients enroll via Invitation (QR or URI).
2. Both establish the Marmot 1:1 conversation.
3. Text travels only through authorized Encrypted LeaseSets and is MLS-protected.
4. Unauthorized clients get no useful access; revocation is verified.
5. Outbox, ACK, retry and dedup survive disconnects and restarts.
6. Identity, Destination, credentials and MLS state survive normal restarts.
7. No clearnet or public-LeaseSet fallback exists (traffic audit passes).
8. Security-relevant failures fail closed and are visible.
9. An agent can perform steps 1–5 through the Agent API unattended.
10. Transit option works as specified.

---

## 16. Documentation deliverables

This specification; `DEPENDENCIES.md` with exact pins and provenance; Marmot-over-I2P profile (frames, CR rules); ContactCard/Invitation/Enrollment formats and state machines; i2pd fork change list and Appendix B verified mapping; authorization creation/rotation/revocation procedure; wire/ACK protocol; CLI and Agent API reference with JSON Schema and agent guide; key management/backup/recovery guide; threat model; two-router dev guide; ADRs (Appendix D).

---

## 17. Roadmap

| Item | Priority |
|---|---|
| Private groups | High (right after 1:1) |
| Files, voice messages | High |
| I2P-hosted relays (§19) | Medium–high once the user base grows |
| Real-time calls | Medium (experiment-gated) |
| Public groups + discovery | Medium |
| Multi-device (extra MLS leaves) | Medium |
| External signer (NIP-55-style) | Medium |
| Pure-Rust I2P router | When viable |
| Desktop UI | As needed |

---

## 18. Decisions summary

| Topic | Decision |
|---|---|
| Identity | Nostr secp256k1; import supported deliberately |
| MLS/Marmot | MDK on OpenMLS; MIP-00..03 pinned; content-compatible, not relay-wire-compatible |
| Relays | None required; I2P-hosted relays later |
| Transport | Encrypted LeaseSets + per-client DH auth only |
| Router | INIM i2pd fork via I2CP; replaceable behind `I2pTransport` |
| Data plane | Datagram-first (proposed); streaming fallback; ADR-002 |
| Destination | One persistent per profile |
| Authorization | Per-peer, client-generated keys; bootstrap creds short-lived and rotated |
| Group transport | MLS-carried `transport.offer`; policy `ask`/`auto`/`never` |
| Commit ordering | CR-1…CR-4 |
| Revocation vs group removal | Separate operations |
| Storage | `rusqlite` + SQLCipher; single owner daemon |
| Transit | User option (on/off, share %) |
| Agents | First-class; JSON-RPC + MCP; untrusted-content rule |
| Android | Embedded core and router; no open I2CP port |
| Clearnet | None at the messaging layer; reseed/link layer disclosed |
| Large groups | Tiers A mesh / B hub-hosted MLS / C community mode (ADR-016); no per-member MLS promise at 10⁴+ |
| Bridges to Nostr/WhiteNoise | None |
| Android distribution | GitHub Releases (signed, reproducible); F-Droid opportunistic; no Google dependency; no clearnet self-update |

---

## 19. Relay readiness (future I2P-hosted relays)

Not built in v0.5, but the design MUST NOT preclude it:

- The outbox targets a `DeliveryTarget` (`Peer` | `Relay`) abstraction; today only `Peer` exists.
- Reserve frame types `MAILBOX_PUT`, `MAILBOX_GET`, `MAILBOX_ACK`, and a `KP_PUBLISH/KP_LOOKUP` pair (the relay analogue of Marmot's KeyPackage publication).
- A relay is itself a Secret-LeaseSet service. Depositors and fetchers are individually authorized clients; it stores only opaque frames (already MLS-encrypted); it never holds MLS secrets or file keys.
- Open questions for ADR-012: authorization and abuse control, quotas and retention, deletion, who a relay learns about (depositor/fetcher Destinations), and incentives for volunteers.
- Member-as-relay (§6.8) is the interim mechanism and its frames are designed to be reused by relays.
- **Group hub role (Tier B/C, §6.6):** a hub is a relay bound to one or more groups. Reserve frame types `HUB_JOIN`, `HUB_EVENT`, `HUB_SYNC`. Members hold a client credential for the hub only. The hub fans out opaque frames, keeps the event log for catch-up, and may be run by the group creator on a headless node. Hubs can be replicated; ADR-016 decides how members choose among hubs and how a hub's disappearance is survived (members must be able to re-home to another hub using their own event log).
- **Volunteer hubs** are expected once hub code exists. A hub operator can observe member Destinations, timing and frame sizes, so the creator-run hub is the default and any other hub is chosen per group by its admins, shown to members, and replaceable (members re-home using their own event log). No hub is trusted with content, keys or membership decisions.
- Hub fan-out for very large groups needs a distribution structure (e.g., a tree of hubs); ADR-016 specifies it after E-12.

---

## Appendix A — i2pd fork requirements

| ID | Requirement | Why |
|---|---|---|
| F-1 | **Key ring:** register client-auth private keys per remote Destination (b33/hash) at runtime; the router picks the key when resolving that Destination's Encrypted LeaseSet | Stock `i2cp.leaseSetPrivKey` is a session-wide single key; per-contact credentials need N keys without N sessions |
| F-2 | Add/remove/replace authorized client entries at runtime; republish the LeaseSet; emit a **confirmation event** | Revocation must be provable, not assumed |
| F-3 | Pad the client list with dummy entries in size buckets | Hide the real contact count |
| F-4 | Router-level allowlist of remote Destinations; drop others; `close sessions of Destination X` | Instant refusal; stale cached LeaseSets |
| F-5 | Events over I2CP: tunnel readiness, LeaseSet published, peer connect/drop, auth failure counters | Visible status, no polling the web console |
| F-6 | Runtime transit policy (enable, share %, max tunnels) | §7.7 |
| F-7 | Strip everything not needed: proxies, SAM/BOB, address-book subscriptions, web console beyond a local diagnostic socket, tunnels.conf defaults | Only INIM traffic |
| F-8 | I2CP over Unix socket / in-process pipe; no TCP listener by default | Other apps must not reach I2CP (it has no authentication) |
| F-9 | Datagram2 (protocol 19) and Datagram3 (20) over I2CP, if not present **[TV]** | ADR-002 |
| F-10 | Reproducible builds, Android JNI library target, pinned upstream base, patch series kept rebased | Maintenance |

---

## Appendix B — Secret LeaseSet ↔ I2CP option map (to be completed in Phase 1)

| Option | Side | Seen in i2pd source 2.58 | Direction / lifecycle to verify |
|---|---|---|---|
| `i2cp.leaseSetType` (5 = encrypted) | Owner session | [V] | Mandatory; reject sessions without it |
| `i2cp.leaseSetEncType` | Both | [V] | ECIES-X25519 (4) default |
| `i2cp.leaseSetAuthType` (1 = DH) | Owner session | [V] | Mandatory 1 |
| `i2cp.leaseSetClient.dh.nnn` | Owner session | [V] | Runtime update? Republish timing? Slot reuse? |
| `i2cp.leaseSetClient.psk.nnn` | Owner session | [V] | Not used |
| `i2cp.leaseSetPrivKey` | Client side | [V] | One key per session; replaced by F-1 |
| `i2cp.leaseSetSecret` | Both | [TV] in i2pd | Blinding secret; useful as additional layer |

Each row requires: observed behavior on the pinned fork, a two-router test, and log evidence that does not expose secrets.

---

## Appendix C — Phase 1 experiments

| ID | Question | Pass criterion |
|---|---|---|
| E-1 | Secret LeaseSet with DH auth between two independent routers works end-to-end | Authorized connects; unauthorized fails |
| E-2 | Key ring (F-1) with ≥ 20 remote Destinations on one session | Correct key per peer |
| E-3 | Datagram2/3 vs streaming: latency (cold/warm), delivery rate, throughput, MTU | Decides ADR-002 |
| E-4 | Can a server reply to a client whose LeaseSet it cannot decrypt? | Documented; Enrollment works either way |
| E-5 | Runtime revoke: time to effect, cached LeaseSet, active sessions | Matches §7.9 claims or the claims are corrected |
| E-6 | Maximum client entries per Encrypted LeaseSet; padding behavior | Capacity published |
| E-7 | Router/core restart persistence of Destination and authorization | No key regeneration |
| E-8 | Android resource use: tunnel quantities, transit on/off, battery | Defaults chosen |
| E-9 | Traffic audit | Only router links, reseed, INIM data |
| E-10 | Does a Datagram path accept ≥ 8 KB reliably; fragmentation thresholds | MTU fixed |
| E-11 | OpenMLS/MDK cost at 100 / 1 000 / 5 000 / 10 000 members on a mid-range phone and a desktop: tree memory, Welcome size, commit creation/processing time, batched-commit behavior | Tier B cap and commit-window defaults chosen |
| E-12 | Hub fan-out over I2P: throughput and latency for one hub serving N connected members, and for a tree of hubs; behavior when a hub disappears | Tier B/C distribution design chosen |

---

## Appendix D — ADR index

001 Upstream pinning · 002 Data plane (datagram vs streaming) · 003 Serialization and INIM application kind registry · 004 Commit ordering and fork recovery · 005 Card/Invitation/Enrollment formats, state machine, migration · 006 Group mesh and gossip bounds · 007 Storage provider and key management · 008 Router embedding, I2CP access control, Android service type · 009 Transit policy · 010 File transfer (MIP-04 crypto reuse without Blossom) · 011 Calls · 012 I2P relays · 013 Public group discovery · 014 Multi-device · 015 Agent API, approvals, MCP · 016 Large groups (upstream-first; Tier B hubs, Tier C community mode, Light MLS vs epoch-keyed channels as fallback) · 017 Optional wake-up service hosted inside I2P.

---

## Appendix E — Open questions for the project owner

**Decided by the owner (v0.6):** desktop/headless transit on at 50 %, Android off by default; no bridges to Nostr/WhiteNoise; Android distribution via GitHub Releases, F-Droid if it works out, no Google Play; group size must not be architecturally capped (tiers in §6.6).

**Open:**

**Also decided (v0.7):** very large communities follow whatever Marmot/WhiteNoise specify (ADR-016 upstream-first); volunteer hubs are welcome, creator-run is the default; push only through a wake-up service hosted inside I2P (ADR-017), enabled by default and switchable by the user, never FCM or clearnet; release keys live on the owner's computer with an encrypted backup on the owner's server.

**Open:**

1. Whether and when to move the release keys to a hardware token (§10.1 sets the rules; the owner holds the keys on their own computer for now).
2. If Marmot/WhiteNoise still have no large-group design when Phase 12 starts: choose between Light MLS and epoch-keyed channels (ADR-016), including which guarantees are acceptable for communities of 10⁴+ members.

---

## Appendix F — Sources used for [V] statements (checked 2026-11-13)

- Marmot "Build with Marmot": https://whitenoise-web.vercel.app/build (event kinds, ciphersuite, identity model, MIP status, Welcome size note)
- MDK constants: https://docs.rs/crate/mdk-core/latest/source/src/constant.rs (kind 30443, legacy 443, extension 0xF2EE, default ciphersuite)
- MDK repository: https://github.com/marmot-protocol/mdk (OpenMLS-based, SQLCipher-backed storage, agent-control crate)
- Marmot credentials: https://marmot-protocol.github.io/marmot-ts/core/credentials.html (BasicCredential, 32-byte npub)
- i2pd option constants: https://sources.debian.org/src/i2pd/2.58.0-1/libi2pd/Destination.h
- I2CP documentation: https://geti2p.net/en/docs/protocol/i2cp (client must implement streaming; leaseSet options)
- Datagram types: https://geti2p.net/spec/datagrams and Proposal 163 (Datagram2/3, 0.9.66; implementation support listed as TBD)
- Vector group chats (MLS/Marmot, up to 100 members): https://vector-privacy.gitbook.io/vector-privacy/vector-messenger/features/group-chats
- Vector Communities (Concord, non-MLS): https://github.com/vectorprivacy/vector
- MLS RFC 9420 (scale "two to thousands"): https://www.rfc-editor.org/rfc/rfc9420
- Light MLS drafts: https://www.ietf.org/archive/id/draft-kiefer-mls-light-00.html

---

**Single source of truth for the coding agent.** Implement phase by phase. Use MDK for Marmot/MLS and do not modify its cryptography. Keep MLS membership and I2P authorization separate. Never put a long-lived private authorization key on the wire. Do not bypass Secret LeaseSets. Do not put protocol logic in frontends. Treat message content as untrusted data. Verify every [TV] item against the pinned fork and real two-router tests before claiming it works.
