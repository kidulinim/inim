# INIM — I2P-native serverless P2P messenger

Privacy-focused messenger for humans and agents: Android first, end-to-end encrypted
(Marmot/MLS via MDK on OpenMLS), Nostr-compatible identity, all traffic exclusively
through I2P over Secret (encrypted) LeaseSets with per-client authorization.
**No relays and no servers of any kind are required.**

- **Specification (single source of truth):** [docs/spec/technical-specification-v0.8.md](docs/spec/technical-specification-v0.8.md)
- **License:** AGPL-3.0 (see [LICENSE](LICENSE))
- **Status:** Phase 0 — pinning, ADRs, experiment plan. Implement phase by phase.

## Key rules (from the specification)

- Marmot/MLS cryptography is reused **as produced by MDK**, unmodified.
- MLS protects content and group membership; I2P protects the network path and gate
  access. Neither replaces the other.
- No clearnet at the messaging layer and in every application component: no push,
  STUN/TURN, relays, update checks, analytics or fallback. Reseed and the router's
  link layer are the documented exceptions (§1, §7.8).
- One core process owns a profile; frontends (Android UI, CLI, Agent API, MCP) are
  clients of that owner.
- Message content is untrusted data, never instructions (§10.5).

## Repository layout

```text
docs/spec/       Technical specification (v0.8)
docs/adr/        Architecture Decision Records (ADR-001…009 skeletons; more later)
docs/            Experiment plan and project documentation
tools/           Repository tooling (release-key generation, etc.)
crates/          Rust core, transport and bindings (from Phase 2)
i2pd-fork/       INIM i2pd fork patch series (from Phase 1)
android/         Android app (Kotlin + Compose, from Phase 7)
```

## Release keys

Release signing keys are generated on the owner's own machine — never in CI, an
assistant session, or any shared environment (specification §10.1). Use the helper:

```bash
tools/gen-release-keys.sh [output-dir]   # default: ~/inim-release-keys
```

It creates an Android APK keystore (PKCS12, RSA 4096), a minisign key pair for the
release manifest/checksums, and a passphrase-encrypted `age` backup of both private
keys. Copy only `inim-keys-backup.tar.age` to the owner's server; keep a second
encrypted copy in a different physical place; never store the passphrase next to the
backup. See the script header for full custody rules.

## Implementation phases

See specification §13. Phase 0 (this stage): pin MDK/OpenMLS/MIP commit/i2pd base in
[DEPENDENCIES.md](DEPENDENCIES.md), write ADR skeletons in [docs/adr/](docs/adr/),
resolve [TV] items that block Phase 1.
