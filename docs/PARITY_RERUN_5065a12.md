# C2 parity rerun — 5065a12

**N1, N2 and N3 are fixed in Python, Godot grid and Godot replay.** No gameplay/reference logic or existing adapters were edited. Source copies are refreshed byte for byte.

| Equality (same 110 combat cases) | 94a1c1a → 5065a12 |
|---|---:|
| grid damage | 55 → 55 / 110 |
| grid all compared metrics | 49 → 49 / 110 |
| replay damage | 78 → 78 / 110 |
| replay all compared metrics | 70 → 70 / 110 |

| Contract | Before → after (identical in Python/grid/replay) | Expected / status |
|---|---:|---|
| N1 / mark-cap-distinct-towers | 6.3 → 7.2 | 7.2 / pass in all three |
| N2 / siphon-two-nodes | 4.658025 → 6.533025 | 6.533025 / pass in all three |
| N3 / cap-shared-node-channels | 9.675 → 8.325 | 8.325 / pass in all three |

Material changes: Python **7/110 cases, 16 metrics**; grid **7/110, 16**; replay **7/110, 16**. All are mana metrics. Python also adds mark-owner metadata. Damage and non-economy behavior are unchanged; no new mismatching metric cells or whole-case regressions.

**Residual classification:** expected grid/radius targeting, one-cell fields/merging/trails, summon geometry/timing, spatial precision boundaries and diagnostic accounting remain. Every material cell is classified in results/divergence-classification.json and REPORT.md. Coupled scenario descendants have source-based association, not individual causal proof.

**Newly reported pre-existing implementation differences (no game fixes):** R1 emits empty chain labels in Godot versus Python "seker" (minimal electric3 probe: damage 14.85, one hop in all engines; expected common label "seker"). R2 uses DoT tick tolerance 0.0001 versus 1e-9 (poison1 at dt=0.99995: Python 0, grid/replay 4.5 damage; expected 0 before 1 s). Both engine file:line locations, minimal reproductions and expected values are in REPORT.md. R2 is a separate isolation probe, not a claimed cause of fixed-dt scenario residuals.

Validation: **130/130 Python tests**, **1242/1242 harness/invariant checks** over **147 cases (110 combat)**, including **16/16 native field/tower probes**, plus **39 isolation cases per engine**. B1/B2/B3 remain fixed. Repeat/source-integrity receipts: validation/repeat-verification.json and validation/repeat-run.log. Static lint remains non-clean for isolated-harness dependency/path limitations detailed in REPORT.md; headless logs contain no engine errors. No rendered, inventory or save/load acceptance is claimed.

Preserved baseline: results_94a1c1a/, REPORT_94a1c1a.md, RERUN_SUMMARY_94a1c1a.md and validation/harness_94a1c1a/. Current report: REPORT.md; entry point: README.md. No tracked clone files changed, no commit or push.
