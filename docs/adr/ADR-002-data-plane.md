# ADR-002: Data plane — datagram vs streaming

Status: draft (Phase 0) — decided by experiment E-3 (Phase 1)

## Context
I2CP is a message interface; TCP-style streaming is a library a non-Java client must implement itself [V]. i2pd's streaming code is internal to the router (spec §7.4).

## Options
- A. Datagram-first (proposed default): one datagram out, one ACK back. Needs frame reliability (required anyway, §8). Datagram2 (proto 19) gives authenticated + replay prevention [V]; Datagram3 (20) is repliable/unauthenticated. i2pd support for 19/20 is [TV] (fork requirement F-9).
- B. Streaming over I2CP: implement the streaming protocol in Rust. Fallback only.
- C. Fork-provided stream endpoint: lock-in risk; rejected unless E-3 forces it.

## Decision criteria (E-3)
Cold/warm first-message latency, p50/p95 delivery, loss, throughput, MTU (E-10: is >= 8 KB reliable?), behavior with revoked credentials.

## Invariants
- The sender of every inbound unit is an authenticated Destination mapped to an authorized contact (§7.6). Datagram3 alone is insufficient for control frames.
- The I2pTransport contract (§7.10) stays valid for either choice.
