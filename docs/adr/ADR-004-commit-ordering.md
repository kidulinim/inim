# ADR-004: Commit ordering and fork recovery

Status: draft (Phase 0) — formalize + model-check before Phase 3

## Context
MLS needs one agreed commit order per epoch. Marmot uses relays; INIM has no delivery service (spec §6.7).

## Rules (to formalize)
- CR-1: only admins commit; non-admins send proposals. 1:1: both admins, creator is tie-break. Confirm admin semantics in MIP-01 [TV].
- CR-2: hold before merge — stage (OpenMLS pending commit), deliver, merge after ACK from every reachable member or commit_hold (default 30s), whichever is later.
- CR-3: same-parent conflict -> lowest SHA-256(commit bytes) wins; loser clears pending, processes winner, re-submits proposals.
- CR-4: ACK carries (epoch, truncated epoch_authenticator); mismatch -> FORKED: sending stops, user/agent notified, recovery by re-adding diverged member from majority branch. Never roll back silently.
- OpenMLS params (max_past_epochs, out-of-order tolerance, forward distance) pinned here and in DEPENDENCIES.md.
- Outbox stores final ciphertext; retries resend identical bytes.

## Verification
Model-check CR-1..CR-4 state machine; Phase 3 tests inject delay/duplication/partition (§15.1).
