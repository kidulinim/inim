# ADR-007: Storage provider and key management

Status: draft (Phase 0) — decide before Phase 2

## Context
OpenMLS/MDK storage is synchronous; atomic MLS+message transactions are required (spec 4, 9).

## Decisions (to confirm)
- `rusqlite` + `bundled-sqlcipher` (sqlx dropped). One DB, one transaction across MLS state + inbox/outbox + app tables.
- If `mdk-sqlite-storage` runs on SQLCipher, use it [TV]; otherwise implement `mdk-storage-traits` on our DB.
- DB key: random, wrapped by Android Keystore; optional passphrase (Argon2id) unlock; headless profiles: key file (0600) / inherited fd / OS keyring; env-var secrets discouraged.
- Tables (9.1): identity, contacts, peer_auth, key_ring, invitations, conversations, messages, mls_state, key_packages, outbox, inbox, group_event_log, revocations, settings, transit_policy, agent_permissions, approvals, audit_log, schema_migrations.
- Migrations transactional and tested on existing profiles.

## Verification
Crash-injection tests around commit, message persistence, ACK, revocation (9.2). Blocking DB access on dedicated threads; per-group mutation serialization.
