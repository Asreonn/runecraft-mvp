# C2 parity rerun — 94a1c1a

**B1, B2 and B3 are fixed.** Game/reference logic was left unchanged; adapters load the real economy and accept the new summon owner signature.

| Probe | Exact before → after | Status |
|---|---|---|
| B1 stale forced-move transform | Grid damage 29.91645 → 18; hops 2 → 0. Python/replay remain damage 18, hops 0. | fixed |
| B2 first trail | Grid/replay fields 1 → 0; Python remains 0 for X=6.25→6.26. | fixed |
| B3 lethal siphon G1 | Python siphon 0 → 0.6, total mana 2 → 2.6; grid/replay siphon 2.43 → 0.6, total 4.43 → 2.6. | fixed |
| B3 lethal siphon G3 | Python siphon 0 → 0.75, total 2 → 2.75; grid/replay siphon 6.75 → 0.75, total 8.75 → 2.75. | fixed |

Changed old-case metrics:

- Python: 8/99 cases, 18 material metric changes.
- grid: 51/99 cases, 353 material metric changes.
- replay: 49/99 cases, 305 material metric changes.

No previously matching original case loses damage or whole-case metric equality. New individual discrepancies occur within already divergent cases: 16 grid and 26 replay cells (all enumerated in REPORT.md and results/parity-transitions.json). Grid damage equality improves 42→44/99; replay stays 67/99. All-metric equality improves grid 35→39/99 and replay 57→60/99.

Mana changes follow lethal payout, overkill exclusion and soft caps. Grid/replay combat changes follow immediate movement synchronization and corrected trail initialization; these cascade through fields, targets and budgets. Godot per-tower damage now records HP removed; Python retains uncapped per-tower totals. Every changed metric and reason is in [REPORT.md](REPORT.md#commit-delta-6c65ef4--94a1c1a), with exact values in results/commit-deltas.json and all raw-state/trace changes in results/raw-commit-deltas.json.

New findings (all P2; shared by Godot and Python):

- **N1:** combat.gd:128 / sim.py:249 omit tower identity from mark cap keys. Two disjoint mana3 mark owners earn **6.3**, expected **7.2**. Repro: mark-cap-distinct-towers; enemies X=6/16, mark each from a different tower, deal 20 physical to each at t=0.
- **N2:** combat.gd:92–102 / sim.py:206–211 combine all siphon producers under the first UID/grade. One fire1{fire_hit:[mana1,mana1]} hit earns **4.658025**, expected **6.533025** with two independent G1 caps. Repro: siphon-two-nodes, HP 10000, X=6.
- **N3:** combat.gd:102,128 / sim.py:211,249 split one node across siphon and mark buckets. Two mana3 hits at t=0 earn **9.675**, expected **8.325** for the combined producing-node cap. Repro: cap-shared-node-channels, HP 10000, X=6.

Validation: **127/127 Python tests**, **1233/1233 harness/invariant checks** over 147 cases (110 combat), including **16/16 native field/tower probes**. The three failing economy contracts are saved separately in results/contract-findings.json; passing harness checks do not imply those rules pass. Repeat receipts are in validation/repeat-verification.json. This is headless combat/compiler/economy and native field/tower state evidence; rendered visuals, actual summon visual lifecycle, inventory and save/load are outside this harness.
