# C2 parity rerun — d2d3af1

Baseline 5065a12 preserved; clone pinned to d2d3af1d0045075af326c3aa618d50df1fee42ef. Game sources unchanged.

| Equality (110 combat) | 5065a12 → d2d3af1 |
|---|---:|
| grid damage | 55 → 55 / 110 |
| grid all_metrics | 49 → 53 / 110 |
| replay damage | 78 → 78 / 110 |
| replay all_metrics | 70 → 73 / 110 |

**R1/R2 fixed:** empty chain labels now seker (14.85 damage / one hop); poison1 at dt=.99995 now 0 damage, dt=1 gives 4.5 in Python/grid/replay.

**Stacking/ownership core probes identical:** two fire3 towers → 2 instances / 5.4 total / 2.7 each; contagion owner 2 gets 10.035; shard owner 3 gets 10.701 and frozen_tower=3; crystal owner 4 gets 2.835. Killer 9 gets exactly 90 in all credit probes. Same-tower burn stays 2.7; poison/bleed two-owner ticks/movement give 9; utility wet remains one instance.

**New real difference R3:** Godot repo/scripts/combat.gd:165–168 creates a separate 16-application death budget per poison owner; Python repo/design/rune_mechanics/mechanics/sim.py:274,299–300 shares one budget. Minimal saved case death-budget-2-owners: 4 enemies all X=6, poison4{contagion:[meteor3]} from towers 0/1, victim HP=90, 100 physical kill from tower 9. Python damage **167.2632**, applications **16**, rejects **4**; grid/replay **179.6112**, applications **20**, rejects **0**. Single-owner control matches. Individual roots respect cap 16 in both; shared-versus-owner contract requires a decision. No game fixes.

Validation: **136/136 Python tests**, **1242/1242 harness checks**, **16/16 native probes**, **49 isolation cases per engine / 223/223 isolation checks** (R3 asserted as an expected reproduced difference). Main suite remains 147 cases / 110 combat; no new mismatching cells or whole-case regressions there. Headless evidence only; no rendered/full-game acceptance.

Material delta: Python 1 cases / 7 metric cells; grid 8 / 25; replay 8 / 24. Only intentional same-status-two-towers damage changes; other material changes are R1 labels and Godot death-root histograms. Residuals and sources: REPORT.md; raw/classified inventories: results/ and validation/isolation-verification.json.

Repeat/source/adapter/baseline receipts: validation/repeat-verification.json and validation/repeat-run.log. Supplemental lint: validation/lint-d2d3af1.json (isolated UI dependency/path limitations remain). Baseline: results_5065a12/, REPORT_5065a12.md, validation/harness_5065a12/ and validation/baseline_5065a12_sha256.json. All artifacts remain in parity; no commits/pushes.
