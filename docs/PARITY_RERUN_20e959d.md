# C2 parity rerun — 20e959d

Baseline d2d3af1 preserved in results_d2d3af1/, REPORT_d2d3af1.md and validation/harness_d2d3af1/ (72 SHA256 entries). Clone pinned to 20e959d28d1cca8c10d620188dc334c308afde27. One intervening commit changes scripts/combat.gd and docs/PARITY_REPORT.md; no other runtime/reference source changes. No game edits.

**R3 fixed in Python/grid/replay:** death-budget-2-owners now gives **167.2632 damage / 16 applications / 16 max budget / 4 rejected events**, equal in all three. Godot was 179.6112 / 20 / 10 / 0. Credit stays with owners: tower 0=44.8056, tower 1=32.4576, killer 9=90. Single-owner and all existing core credit/stacking controls remain equal.

Minimal repro: four enemies at X=6, poison4{contagion:[meteor3]} on enemy 0 from towers 0/1, victim HP=90, physical kill 100 from tower 9, t=0. Saved actions: validation/reclassification-cases.json. Godot repo/scripts/combat.gd:143,147,167 shares death_budget; Python repo/design/rune_mechanics/mechanics/sim.py:274,287–289,299–300 shares root.budget. R1/R2 and B1–B3/N1–N3 remain passing.

| Equality / 110 combat | d2d3af1 → 20e959d |
|---|---:|
| grid damage | 55 → 55 / 110 |
| grid all_metrics | 53 → 53 / 110 |
| replay damage | 78 → 78 / 110 |
| replay all_metrics | 73 → 73 / 110 |

Validation: **136/136 Python tests; 1242/1242 harness checks; 16/16 native probes; 49 isolation cases per engine; 231/231 isolation checks**. Isolation equality in each Godot mode: damage 48/49, all compared metrics 43/49. R3 is now asserted equal, not expected to differ.

## Commit delta: d2d3af1 → 20e959d

| Suite / stream | Materially changed cases | Metric cells | Raw changed cases | Raw leaf changes |
|---|---:|---:|---:|---:|
| main/Python | 0 | 0 | 0 | 0 |
| main/grid | 3 | 10 | 38 | 1509 |
| main/replay | 3 | 9 | 38 | 1555 |
| isolation/Python | 0 | 0 | 0 | 0 |
| isolation/grid | 1 | 9 | 5 | 18 |
| isolation/replay | 1 | 9 | 5 | 18 |

New mismatching cells: 4; repaired cells: 18. Raw metadata changes (including empty roots and first-registration tower labels) are retained in results/raw-commit-deltas.json; per-tower damage is checked separately.

All temporal/raw changes and parity transitions are enumerated in results/commit-deltas.json, raw-commit-deltas.json and parity-transitions.json. REPORT.md includes source locations, minimal residual controls and every case table. Existing E1–E5 model/numeric/diagnostic residuals remain explicit. Root records are budget observations; their tower metadata is not per-owner damage credit.

**Observed change beyond the targeted repro:** main Godot deep3/deep4/stress-24 have 10 grid / 9 replay changed histogram cells; four previously equal histogram cells now differ. Main damage, credit, enemy state and every other non-root raw field are unchanged. There are 38/147 main raw cases changed per mode, all solely root metadata/arrays. Isolation changes only the two-owner repro numerically; four further cases change root metadata (5 raw cases total per mode). No Python raw result changes.

**Mixed shard/poison check:** 5 supplemental cases pass; saturated mixed-owner death gives 218.6064 damage / 16 applications / 7 rejected in all engines, including correct owners 3/0/1/9. Separate root-histogram controls reproduce the existing field/tick-associated histogram residual with the deep3 recipe; trimming its outer fire restores equality. All details and both engine file:line sites are in REPORT.md.

Repeat and integrity: validation/repeat-verification.json / repeat-run.log; final scope audit: validation/final-audit.json. Execution adapters unchanged; source copies byte-identical. All artifacts inside parity; no commits/pushes. Evidence is headless only, with immediate projectile stubs and simulated timers; no rendered/full-game acceptance. No fresh lint claim.
