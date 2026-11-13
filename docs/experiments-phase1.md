# Phase 1 experiment plan (Appendix C of the specification)

All experiments run against the pinned i2pd fork (two independent routers) and produce log evidence without secrets.

| ID | Question | Pass criterion | Status |
|---|---|---|---|
| E-1 | Secret LeaseSet + DH auth between two independent routers works end-to-end | Authorized connects; unauthorized fails | planned |
| E-2 | Key ring (F-1) with >= 20 remote Destinations on one session | Correct key per peer; no cross-use | planned |
| E-3 | Datagram2/3 vs streaming: latency (cold/warm), delivery rate, throughput, MTU | Decides ADR-002 | planned |
| E-4 | Can a server reply to a client whose LeaseSet it cannot decrypt? | Documented; enrollment works either way | planned |
| E-5 | Runtime revoke: time to effect, cached LeaseSet, active sessions | Matches 7.9 claims or the claims are corrected | planned |
| E-6 | Maximum client entries per Encrypted LeaseSet; padding behavior | Capacity published | planned |
| E-7 | Router/core restart persistence of Destination + authorization | No key regeneration | planned |
| E-8 | Android resource use: tunnel quantities, transit on/off, battery | Defaults chosen | planned |
| E-9 | Traffic audit | Only router link-layer traffic, reseed, INIM data | planned |
| E-10 | Does a Datagram path accept >= 8 KB reliably; fragmentation thresholds | MTU fixed | planned |
| E-11 | OpenMLS/MDK cost at 100/1000/5000/10000 members on mid-range phone + desktop | Tier B cap + commit-window defaults chosen | planned |
| E-12 | Hub fan-out over I2P (single hub + tree; hub disappearance) | Tier B/C distribution design chosen | planned |

each row updates ADR-002 (data plane) or Appendix B (leaseSet/I2CP map) upon completion.
