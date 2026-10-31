# C2 — Python/Godot combat parity

Snapshot: `6c65ef4814973b294aadecee5bd44d404d3f1c74`. Engine `4.7.2.stable.arch_linux.ed1daf0bf`. Python `3.14.7`.

**Parity is partial.** 136 cases: 99 combat cases, 36 expected compile rejections, and one incompatible-graft check. The original Python suite passes **121/121**. All 188 successful compiler comparisons across both runs match (canonical recipe, ops serialized at the source compiler’s 3-decimal precision, and rejected families). All 198 Godot combat runs finish finite, max generation ≤2 and ≤16 payload applications per root budget. **Three isolated bugs** are documented below, including one in the reference.

Total-damage equality within numerical tolerance: grid **42/99**, reference-event replay **67/99**. All compared metric equality: grid **35/99**, replay **57/99**. These are diagnostic counts, not an acceptance claim for the full game.

## Re-run

From the parent project:

```sh
godot --headless --path asset-work/codex-mvp/parity/harness --script run_parity.gd
```

The entry point prepares fresh byte-identical source copies, runs the Python suite and reference, runs Godot grid and replay modes, then regenerates this report. To confine even Godot engine startup directories to this project, use `asset-work/codex-mvp/parity/run.sh` (same command, local XDG directories). No network is used by the harness after the initial clone. A nonzero exit indicates a harness/invariant failure; documented gameplay parity differences are findings, not harness failures.

Python side only: `python3 asset-work/codex-mvp/parity/python_runner.py prepare`; regenerate the report from saved results: `python3 asset-work/codex-mvp/parity/python_runner.py report`.

## Method and limits

- Inputs: every scenario with `towers` or `recipe`, the incompatible graft, every one of 13 runes at G1/G3/G5, scenario comparison baselines, all six sibling donor permutations, graft depth 3/4, every receiver ability just below its unlock grade, and direct combat probes.
- Default wave is exactly the reference: 6 enemies, 120 HP, spacing 0.6 tile, armor 10%, speed 1 tile/s, duration 14 s, dt=0.05 s, tower at (6,2), range 4. Per-rune attack periods and summon lifetime/cadence come from the identical JSON spec. Tower overlap is intentional for multi-tower tests.
- The row is X, Y-up game coordinates use world X=2×tile X and Z=0. Towers sit at cell (6,-2). Enemy path distance is offset by +64 tiles to preserve the reference negative start positions without hitting the game path-start clamp; rendered position subtracts that origin. This offset can shift exact floating-point ties by an ulp. Direct probes start at X=6 with configurable spacing; their full actions are persisted in `harness/cases.json`.
- Grid mode uses unchanged `tower.gd` attack/summon methods, unchanged `enemy.gd` status access and speed, and unchanged `combat.gd`/`rune_lib.gd`. Scene/GLB setup and enemy visuals are bypassed; no art is loaded. A stub board chooses a deterministic adjacent free cell for summons. The enemy visual adapter publishes the straight-row position at the same point in the frame as game.gd; tile_pos remains the native global-position lookup in grid mode.
- All combat overrides in `observed_combat.gd` call super with unchanged arguments. Extra budget IDs/counters observe applications; no op, budget-left value or combat decision is patched. Python wrappers similarly observe the original classes; every normal run is cross-checked against unwrapped `sim.simulate` metrics during preparation.
- VFX methods are no-ops except observation and required gameplay callbacks. Projectiles hit immediately to match the reference; meteor and lava callbacks use a deterministic simulated-time queue. The real VFX projectile travel duration is intentionally excluded. There is no rendering, physical play, curved-map/topology or real VFX lifecycle acceptance in this evidence.
- Replay feeds the Python tower/timer root events (raw ops, target IDs, time and position) into unchanged Godot combat; status ticks, movement and fields still execute in Godot. Replay reads enemy position directly from path distance to isolate the stale transform issue. It bypasses Godot host targeting/summon loops; it does **not** remove one-cell fields, Godot Vector2 precision or the trail-initialization bug. Compiler equality is checked separately before this replay is interpreted.
- Mana means combat-earned mana only: siphon + marks + 2 per kill. Passive +3/s and starting balances are excluded on both sides because the reference omits them. Stones include one per normal enemy plus mark crystal bonuses. Damage is uncapped dealt damage, with capped damage also shown. Status counts count apply_status calls, including refreshes; freezes count freeze calls, including novas. Hops count selected targets, even if their payload budget is exhausted, matching the reference.
- Root application distributions and individual records are saved. “Application” means a successful apply_payload budget decrement; direct deal/freeze/status calls do not consume that budget in either engine. The generation ceiling is for propagation; max_status_gen separately records the generation used by apply_status. Finite means bounded simulated steps, finite reported values and no event-watchdog overflow, not a proof for arbitrary future recipes.
- Relative difference is `(Godot − Python) / |Python|`; a zero reference with a nonzero result is “new”. Only absolute ≤1e-6 plus relative ≤1e-9 is numerical tolerance. Discrete count changes are never silently accepted as a percentage tolerance. Source hashes and spec identity are in `results/provenance.json`; raw full-precision results are in `results/python.json` and `results/godot.json`.

## Difference classification

| ID | Class | Evidence / meaning |
|---|---|---|
| E1 | Expected structural difference | Grid range membership vs continuous radius: `repo/scripts/tower.gd:109`; Python `sim.py:569`. Cell-edge target timing can add/remove a whole attack. |
| E2 | Expected structural difference | One-cell fields, refresh/merge and cell-crossing trail placement vs Python radius fields and distance-threshold trail drops: `repo/scripts/combat.gd:347`, `:389`, `:405`; `sim.py:436`, `:461`. This can change damage, slow duration, deaths, marks and subsequent budgets even in replay. B2 is an additional isolated implementation defect. |
| E3 | Expected structural / numeric boundary difference | Godot Vector2 spatial comparisons and transformed positions vs Python scalar binary64. At exact spacing/range boundaries, a different tied neighbour or one-step exposure can change downstream discrete events. This is distinguished from harmless arithmetic tolerance. Direct `boundary-pierce` fixes targets at 6.2 and 7.1 to exercise the 0.9-tile pierce boundary. |
| E4 | Expected structural difference | Snapped meteor landings, actual slowed target lead, 2D multi-impact offsets and adjacent-cell summons, volcano initial 0.6 vs 0.5 s, golem/beetle approach and reach differ: `repo/scripts/tower.gd:173`, `:187`, `:192`, `:226`, `:271`; `repo/scripts/combat.gd:476`. Replay removes the host portion. |
| B1/B2/B3 | BUG | Isolated reproductions below establish defects; B3 is in Python. “exposure” in an aggregate row means the recipe can exercise the defect; it is not a claim that every downstream numeric delta has been individually attributed. |

Aggregate rows can mix E1–E4 and a bug exposure. These classifications identify concrete code-path differences, not an additive causal decomposition of each element/status count. Reference-event replay is an isolation tool, not a promise of bitwise geometric parity.

## Prioritised bugs and minimal reproductions

| Priority | ID | Location | Impact |
|---|---|---|---|
| P1 | B1 | Godot `combat.gd:329`, `enemy.gd:107` | Propagation uses a pre-push transform; the direct reproduction adds two unintended hops. |
| P1 reference | B3 | Python `sim.py:194` | Lethal-hit siphon payout is omitted from the reference oracle. |
| P2 | B2 | Godot `combat.gd:192`, `:349` | Fractional burn start creates an extra trail without a cell crossing. |

### B1 — P1 — forced move uses a stale enemy transform for propagation

`repo/scripts/combat.gd:329` updates only `e.s`; `repo/scripts/enemy.gd:107` reads `global_position` in tile_pos. game.gd refreshes the transform after ordinary movement (`:344`), before tower attacks; a push during a tower event has no refresh before follow-on propagation (`combat.gd:364` and `:438`). Thus chain range and follow-on fields use the pre-push position.

**Repro:** `push-chain-stale-position`: HP 10000, enemies at X=6,8,10,…; one `water3{water_hit:[electric3]}` hit on enemy 0. Wet extends chain reach to 2.25 tiles. Push moves victim to 5.65, so the next enemy is 2.35 away and Python produces zero hops. Grid Godot uses X=6, finds distance 2, and produces two hops. Python damage **18**, Godot grid **29.91645** (+66.2025%); replay using authoritative path position returns to **18**. No game code was fixed.

### B2 — P2 — new burn instance drops a trail without crossing a cell

`repo/scripts/combat.gd:192` stores an unsnapped `last_drop = e.tile_pos()`, but `:349` compares it with a snapped cell coordinate. A burn applied at a fractional position necessarily fails that equality on the next movement, even in the same cell. The intended grid-crossing condition is therefore not respected for the first drop.

**Repro:** `trail-spurious-cell-drop`: enemy at X=6.25; apply native `fire3` burn; move forward 0.01 tile, still in cell 6. Python creates **0** trail fields, Godot creates **1** in both grid/replay. This is distinct from the intentional one-cell-vs-radius rule. Subsequent drops use snapped last_drop, so the defect is first-drop specific.

### B3 — P1 reference correctness — lethal hit skips mana siphon in Python

`repo/design/rune_mechanics/mechanics/sim.py:194` returns from apply_payload after the target dies, before reaching the siphon aggregation at `:205`. Godot `repo/scripts/combat.gd:79` breaks the op loop and reaches the payout at `:90`. The rule “damage in this event converts to mana” includes a lethal hit; Godot matches that rule here.

**Repro:** `siphon-lethal-mana1`: HP=1, armor=10%, direct `mana1` hit deals 4.05 uncapped damage. Python total mana **2**, siphon **0**; Godot total mana **4.43**, siphon **2.43**. `mana3` repeats it: damage **9**, Python total **2**, Godot **8.75**. Both get one kill and one stone. This is not a reason to alter Godot to reproduce the reference defect.

## Targeted probe results

| Probe | Python | Godot grid | Godot replay | Interpretation |
|---|---|---|---|---|
| summon-loop-volcano: root attack events | 8 | 8 | 8 | Repeated attacks execute; fixed 30 s cap, pack exits earlier. Actual elapsed times below. |
| summon-loop-golem: root attack events | 18 | 17 | 18 | Repeated attacks execute; fixed 30 s cap, pack exits earlier. Actual elapsed times below. |
| summon-loop-hive: root attack events | 62 | 61 | 62 | Repeated attacks execute; fixed 30 s cap, pack exits earlier. Actual elapsed times below. |
| same-status-two-towers: status_instances | 1 | 1 | 1 | See case table / raw state. |
| forced-move-bleed: bleed_forced | 1.225 | 1.1025 | 1.1025 | See case table / raw state. |
| frozen-death-shards: shards | 1 | 1 | 1 | See case table / raw state. |
| siphon-tick: mana_siphon | 1.550745 | 1.550745 | 1.550745 | See case table / raw state. |
| mark-economics: mana_mark | 11.91 | 11.91 | 11.91 | See case table / raw state. |
| mark-economics: stones | 3 | 3 | 3 | See case table / raw state. |
| budget-dense-64: max_budget_used | 16 | 16 | 16 | See case table / raw state. |

All six sibling permutations produce identical metrics within each implementation. Depth-3/4 grafts compile and terminate; the table shows their differing combat outcomes. Receiver grade locks are rejected with `locked_on_receiver` in both implementations. The dense 64-enemy stress probe reaches 16 applications, so the cap is exercised rather than merely unchallenged.

Two identical fire3 burns from tower IDs 0 and 1 produce two application calls but one stored status instance and one 2.7-damage tick, attributed to the first tower in both engines. Both key statuses by op UID without tower ID (`combat.gd:174`; `sim.py:283`); a refresh neither changes ownership nor resets the spread-once flag. This is shared behavior, **not a parity bug**. Whether independently sourced burns should stack or own separate first-spread opportunities requires a design decision.

Forced bleed counters differ in definition: Python records nominal pre-armor movement damage, while the Godot observer records actual blood damage during move (including descendants). Their existence is verified, but their magnitudes are not presented as directly comparable metrics. Element damage remains comparable.

Verification: **1082/1082 checks passed**. Full check records: `results/verification.json`.

## Scenario tables

Each table contains every requested metric, each nonzero element and status/hop kind, and per-root application histograms. Missing dictionary entries are zero. Grid is the actual runtime host on the straight lane; replay is the reference root-event stream through Godot combat. Compile-only cases have no invented damage numbers.

### v4-01 (scenario)

Recipes: `fire3{burn:[electric1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 174.483 | 161.883 | -7.221% | 160.083 | -8.253% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 174.483 | 161.883 | -7.221% | 160.083 | -8.253% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 134.1 | -8.589% | 132.3 | -9.816% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 27.783 | 27.783 | 0% | 27.783 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 15 | -60.526% | 14 | -63.158% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### v4-02 (scenario)

Recipes: `fire3{fire_hit:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 378.944392 | 335.744392 | -11.400% | 335.744393 | -11.400% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 378.944392 | 335.744392 | -11.400% | 335.744393 | -11.400% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 165 | 115 | -30.303% | 115 | -30.303% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 14 | 14 | 0% | 14 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 14 | 14 | 0% | 14 | 0% | equal |
| by_element.fire | 305.64909 | 262.44909 | -14.134% | 262.44909 | -14.134% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 73.295302 | 73.295303 | 0% | 73.295303 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 21 | 21 | 0% | 21 | 0% | equal |
| hops.mermi sekerek | 14 | 14 | 0% | 14 | 0% | equal |
| fields.fire_trail | 98 | 15 | -84.694% | 14 | -85.714% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 137 | 87 | -36.496% | 87 | -36.496% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 130 | 80 | -38.462% | 80 | -38.462% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_5_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-03 (scenario)

Recipes: `fire3{burn:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 331.853121 | 300.353121 | -9.492% | 301.253121 | -9.221% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 331.853121 | 300.353121 | -9.492% | 301.253121 | -9.221% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 155 | 120 | -22.581% | 121 | -21.935% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 16 | 16 | 0% | 16 | 0% | equal |
| status_instances | 4 | 3 | -25.000% | 4 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.fire | 243 | 211.5 | -12.963% | 212.4 | -12.593% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 88.853121 | 88.853121 | 0% | 88.853121 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 23 | 23 | 0% | 23 | 0% | equal |
| hops.durum yandakine atlayarak | 16 | 16 | 0% | 16 | 0% | equal |
| fields.fire_trail | 89 | 13 | -85.393% | 13 | -85.393% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 123 | 88 | -28.455% | 89 | -27.642% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 115 | 80 | -30.435% | 81 | -29.565% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |

### v4-04 (scenario)

Recipes: `fire3{burn:[electric3{chain:[ice2]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 321.965492 | 311.165492 | -3.354% | 315.665492 | -1.957% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 321.965492 | 311.165492 | -3.354% | 315.665492 | -1.957% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 130 | 118 | -9.231% | 123 | -5.385% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 32 | 32 | 0% | 32 | 0% | equal |
| status_instances | 7 | 6 | -14.286% | 7 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.fire | 220.5 | 209.7 | -4.898% | 214.2 | -2.857% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 88.853121 | 88.853121 | 0% | 88.853121 | 0% | tolerance (floating arithmetic) |
| by_element.ice | 12.612371 | 12.612371 | 0% | 12.612371 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 23 | 23 | 0% | 23 | 0% | equal |
| statuses.slow | 16 | 16 | 0% | 16 | 0% | equal |
| hops.durum yandakine atlayarak | 16 | 16 | 0% | 16 | 0% | equal |
| fields.fire_trail | 82 | 15 | -81.707% | 14 | -82.927% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 98 | 86 | -12.245% | 91 | -7.143% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 90 | 78 | -13.333% | 83 | -7.778% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |

### v4-05 (scenario)

Recipes: `fire5{burn:[electric3,poison2,blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 651.186795 | 693.568591 | +6.508% | 680.251326 | +4.463% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 621.6 | 664.15399 | +6.846% | 663.99649 | +6.821% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 5 | 5 | 0% | 5 | 0% | equal |
| mana | 10 | 10 | 0% | 10 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 5 | 0% | 5 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 134 | 137 | +2.239% | 132 | -1.493% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 58 | 88 | +51.724% | 80 | +37.931% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| status_instances | 11 | 18 | +63.636% | 18 | +63.636% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 12 | +100.000% | 10 | +66.667% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.fire | 319.05 | 305.55 | -4.231% | 303.3 | -4.937% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 50.684295 | 70.498591 | +39.094% | 66.833826 | +31.863% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.blood | 96.075 | 109.62 | +14.098% | 109.1475 | +13.607% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.poison | 185.3775 | 207.9 | +12.150% | 200.97 | +8.411% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 11 | 16 | +45.455% | 14 | +27.273% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.poison | 27 | 40 | +48.148% | 37 | +37.037% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.bleed | 27 | 40 | +48.148% | 37 | +37.037% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| hops.durum yandakine atlayarak | 6 | 12 | +100.000% | 10 | +66.667% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| fields.fire_trail | 56 | 11 | -80.357% | 10 | -82.143% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 122 | 113 | -7.377% | 112 | -8.197% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 119 | 107 | -10.084% | 107 | -10.084% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_5_applications | 3 | 6 | +100.000% | 5 | +66.667% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### v4-06 (scenario)

Recipes: `ice4{ice_shards:[electric3]}`, `stone3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 318.2 | 318.2 | 0% | 318.2 | 0% | equal |
| damage_capped | 304.2 | 304.2 | 0% | 304.2 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 1 | 1 | 0% | 1 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 30 | 30 | 0% | 30 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 9 | 9 | 0% | 9 | 0% | equal |
| status_instances | 8 | 8 | 0% | 8 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 12 | 12 | 0% | 12 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 9 | 9 | 0% | 9 | 0% | equal |
| by_element.ice | 122.4 | 122.4 | 0% | 122.4 | 0% | equal |
| by_element.physical | 195.8 | 195.8 | 0% | 195.8 | 0% | tolerance (floating arithmetic) |
| statuses.slow | 6 | 6 | 0% | 6 | 0% | equal |
| statuses.cold | 6 | 6 | 0% | 6 | 0% | equal |
| statuses.shred | 14 | 14 | 0% | 14 | 0% | equal |
| hops.parça | 9 | 9 | 0% | 9 | 0% | equal |
| roots.with_applications | 12 | 12 | 0% | 12 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_3_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_5_applications | 4 | 4 | 0% | 4 | 0% | equal |

### v4-07 (scenario)

Recipes: `water3{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 120.015 | 120.015 | 0% | 120.015 | 0% | tolerance (floating arithmetic) |
| damage_capped | 120 | 120 | 0% | 120 | 0% | tolerance (floating arithmetic) |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 2.45 | 2.45 | 0% | 2.45 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 81.9 | 81.9 | 0% | 81.9 | 0% | equal |
| by_element.blood | 38.115 | 38.115 | 0% | 38.115 | 0% | tolerance (floating arithmetic) |
| statuses.wet | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-08 (scenario)

Recipes: `blood1{bleed:[water3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 110.889 | 111.114 | +0.203% | 110.889 | 0% | BUG exposure / structural mixture: E1, E3, B1 exposure; tolerance (floating arithmetic) |
| damage_capped | 110.889 | 111.114 | +0.203% | 110.889 | 0% | BUG exposure / structural mixture: E1, E3, B1 exposure; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 21 | 21 | 0% | 21 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 4 | 4 | 0% | 4 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | BUG exposure / structural mixture: E1, E3, B1 exposure; tolerance (floating arithmetic) |
| by_element.water | 45.864 | 45.864 | 0% | 45.864 | 0% | tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.wet | 14 | 14 | 0% | 14 | 0% | equal |
| roots.with_applications | 21 | 21 | 0% | 21 | 0% | equal |
| roots.using_1_applications | 21 | 21 | 0% | 21 | 0% | equal |

### v4-09 (scenario)

Recipes: `fire3`, `water4{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 278.89875 | 301.96125 | +8.269% | 265.66875 | -4.744% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 258 | 300.40125 | +16.435% | 249.9 | -3.140% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 2 | 2 | 0% | 2 | 0% | equal |
| mana | 4 | 4 | 0% | 4 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 2 | 2 | 0% | 2 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 43 | 50 | +16.279% | 40 | -6.977% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 4 | 9 | +125.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 3.825 | 4.725 | +23.529% | 3.825 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 14 | 0% | 14 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 112.5 | 126.9 | +12.800% | 99.9 | -11.200% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.water | 126 | 126 | 0% | 126 | 0% | equal |
| by_element.blood | 40.39875 | 49.06125 | +21.442% | 39.76875 | -1.559% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 6 | 7 | +16.667% | 6 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.wet | 6 | 7 | +16.667% | 6 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.bleed | 6 | 7 | +16.667% | 6 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| fields.fire_trail | 20 | 12 | -40.000% | 7 | -65.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 43 | 50 | +16.279% | 40 | -6.977% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 43 | 50 | +16.279% | 40 | -6.977% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### v4-09-alone (comparison)

Recipes: `water4{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 176.085 | 176.2425 | +0.089% | 176.085 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 176.0025 | 176.16 | +0.089% | 176.0025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 4 | 4 | 0% | 4 | 0% | equal |
| pushed_tiles | 3.15 | 3.15 | 0% | 3.15 | 0% | tolerance (floating arithmetic) |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 126 | 126 | 0% | 126 | 0% | equal |
| by_element.blood | 50.085 | 50.2425 | +0.314% | 50.085 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| statuses.wet | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-10 (scenario)

Recipes: `ice2`, `blood1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 96.13125 | 96.35625 | +0.234% | 96.13125 | 0% | expected structural difference: E1, E3 |
| damage_capped | 96.13125 | 96.35625 | +0.234% | 96.13125 | 0% | expected structural difference: E1, E3 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 14 | 14 | 0% | 14 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 14 | 0% | 14 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.ice | 56.7 | 56.7 | 0% | 56.7 | 0% | equal |
| by_element.blood | 39.43125 | 39.65625 | +0.571% | 39.43125 | 0% | expected structural difference: E1, E3 |
| statuses.slow | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 14 | 14 | 0% | 14 | 0% | equal |
| roots.using_1_applications | 14 | 14 | 0% | 14 | 0% | equal |

### v4-10-alone (comparison)

Recipes: `blood1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-11 (scenario)

Recipes: `volcano3{lava_blob:[electric3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 466.827347 | 493.192854 | +5.648% | 466.827347 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 466.827347 | 493.192854 | +5.648% | 466.827347 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 8 | 8 | 0% | 8 | 0% | equal |
| applications | 50 | 54 | +8.000% | 50 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 17 | 19 | +11.765% | 17 | 0% | expected structural difference: E1, E3, E4 |
| status_instances | 5 | 4 | -20.000% | 5 | 0% | expected structural difference: E1, E3, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 16 | +6.667% | 15 | 0% | expected structural difference: E1, E3, E4 |
| by_element.lava | 295.785922 | 312.49134 | +5.648% | 295.785923 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| by_element.ice | 81.019622 | 85.595454 | +5.648% | 81.019622 | 0% | expected structural difference: E1, E3, E4 |
| by_element.electric | 90.021802 | 95.10606 | +5.648% | 90.021803 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| statuses.slow | 25 | 27 | +8.000% | 25 | 0% | expected structural difference: E1, E3, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 16 | +6.667% | 15 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_4_applications | 1 | 0 | -100.000% | 1 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_6_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_8_applications | 2 | 3 | +50.000% | 2 | 0% | expected structural difference: E1, E3, E4 |

### v4-12 (scenario)

Recipes: `volcano3{lava_blob:[electric3{chain:[fire3{burn:[ice2]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 468.820403 | 445.456614 | -4.984% | 480.811449 | +2.558% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 468.813379 | 445.456614 | -4.982% | 480.811449 | +2.559% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 2 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 8 | 6 | -25.000% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| applications | 124 | 105 | -15.323% | 121 | -2.419% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 41 | 40 | -2.439% | 47 | +14.634% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 5 | 6 | +20.000% | 6 | +20.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 16 | +6.667% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 283.365922 | 275.23134 | -2.871% | 287.65134 | +1.512% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 86.241802 | 83.76606 | -2.871% | 87.54606 | +1.512% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 73.930148 | 63.121494 | -14.620% | 75.469494 | +2.082% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 25.28253 | 23.33772 | -7.692% | 30.144555 | +19.231% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 15 | 16 | +6.667% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 26 | 24 | -7.692% | 31 | +19.231% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 16 | +6.667% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 61 | 10 | -83.607% | 16 | -73.770% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 84 | 65 | -22.619% | 79 | -5.952% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 76 | 57 | -25.000% | 71 | -6.579% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 6 | 8 | +33.333% | 7 | +16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_8_applications | 1 | 0 | -100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### v4-13 (scenario)

Recipes: `meteor2{meteor_area:[poison1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 125.1 | 195.57 | +56.331% | 125.1 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 125.1 | 195.57 | +56.331% | 125.1 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 2 | 4 | +100.000% | 2 | 0% | expected structural difference: E1, E3, E4 |
| applications | 18 | 33 | +83.333% | 18 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 4 | 7 | +75.000% | 4 | 0% | expected structural difference: E1, E3, E4 |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.impact | 93.6 | 135.72 | +45.000% | 93.6 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| by_element.poison | 31.5 | 59.85 | +90.000% | 31.5 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| statuses.poison | 4 | 7 | +75.000% | 4 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 14 | 23 | +64.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 10 | 19 | +90.000% | 10 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_2_applications | 4 | 1 | -75.000% | 4 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_4_applications | 0 | 3 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |

### v4-14 (scenario)

Recipes: `meteor3{meteor_fragments:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 179.506136 | 272.089818 | +51.577% | 179.506136 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 179.506136 | 272.089818 | +51.577% | 179.506136 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 14 | 16 | +14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| applications | 38 | 62 | +63.158% | 38 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 24 | +60.000% | 15 | 0% | expected structural difference: E1, E3, E4 |
| by_element.impact | 163.8 | 246.96 | +50.769% | 163.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| by_element.electric | 15.706136 | 25.129818 | +60.000% | 15.706136 | 0% | expected structural difference: E1, E3, E4 |
| hops.parça sekerek | 10 | 16 | +60.000% | 10 | 0% | expected structural difference: E1, E3, E4 |
| hops.parça | 5 | 8 | +60.000% | 5 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 3 | 0 | -100.000% | 3 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_14_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_16_applications | 0 | 3 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |

### v4-15 (scenario)

Recipes: `golem3{golem_punch:[fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 234.36 | 184.32 | -21.352% | 223.02 | -4.839% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 234.03 | 182.1 | -22.189% | 220.8 | -5.653% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 49 | 30 | -38.776% | 34 | -30.612% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 138.6 | 118.8 | -14.286% | 138.6 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| by_element.fire | 95.76 | 65.52 | -31.579% | 84.42 | -11.842% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 8 | 5 | -37.500% | 7 | -12.500% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 27 | 9 | -66.667% | 11 | -59.259% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 49 | 30 | -38.776% | 34 | -30.612% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 49 | 30 | -38.776% | 34 | -30.612% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### v4-16 (scenario)

Recipes: `golem3{ground_slam:[ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 185.616 | 165.816 | -10.667% | 185.616 | 0% | expected structural difference: E1, E3, E4 |
| damage_capped | 185.616 | 165.816 | -10.667% | 185.616 | 0% | expected structural difference: E1, E3, E4 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 16 | 14 | -12.500% | 16 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 3 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 16 | 14 | -12.500% | 16 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 158.4 | 138.6 | -12.500% | 158.4 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| by_element.ice | 27.216 | 27.216 | 0% | 27.216 | 0% | equal |
| statuses.slow | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 16 | 14 | -12.500% | 16 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 16 | 14 | -12.500% | 16 | 0% | expected structural difference: E1, E3, E4 |

### v4-17 (scenario)

Recipes: `hive3{beetle_bite:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 169.65 | 164.205 | -3.210% | 169.65 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 169.635 | 164.19 | -3.210% | 169.635 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 135 | 130.5 | -3.333% | 135 | 0% | expected structural difference: E1, E3, E4 |
| by_element.blood | 34.65 | 33.705 | -2.727% | 34.65 | 0% | expected structural difference: E1, E3, E4 |
| statuses.bleed | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |

### v4-18 (scenario)

Recipes: `hive3{beetle_bite:[poison2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 207.765 | 196.335 | -5.501% | 207.765 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 206.22 | 194.79 | -5.543% | 206.22 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 40 | 38 | -5.000% | 40 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 135 | 130.5 | -3.333% | 135 | 0% | expected structural difference: E1, E3, E4 |
| by_element.poison | 72.765 | 65.835 | -9.524% | 72.765 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| statuses.poison | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 40 | 38 | -5.000% | 40 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 40 | 38 | -5.000% | 40 | 0% | expected structural difference: E1, E3, E4 |

### v4-19 (scenario)

Recipes: `light3{pierce:[poison1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 212.58 | 218.88 | +2.964% | 215.73 | +1.482% | expected structural difference: E1, E3 |
| damage_capped | 212.58 | 218.88 | +2.964% | 215.73 | +1.482% | expected structural difference: E1, E3 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 3 | 3 | 0% | 3 | 0% | equal |
| applications | 41 | 43 | +4.878% | 42 | +2.439% | expected structural difference: E1, E3 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 18 | 18 | 0% | 18 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 9 | 0% | 9 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 9 | 9 | 0% | 9 | 0% | equal |
| by_element.light | 168.48 | 168.48 | 0% | 168.48 | 0% | equal |
| by_element.poison | 44.1 | 50.4 | +14.286% | 47.25 | +7.143% | expected structural difference: E1, E3 |
| statuses.blind | 18 | 18 | 0% | 18 | 0% | equal |
| statuses.poison | 9 | 9 | 0% | 9 | 0% | equal |
| hops.ışın deler | 9 | 9 | 0% | 9 | 0% | equal |
| roots.with_applications | 23 | 25 | +8.696% | 24 | +4.348% | expected structural difference: E1, E3 |
| roots.using_1_applications | 14 | 16 | +14.286% | 15 | +7.143% | expected structural difference: E1, E3 |
| roots.using_3_applications | 9 | 9 | 0% | 9 | 0% | equal |

### v4-20 (scenario)

Recipes: `stone3{fragments:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 188.685414 | 188.833039 | +0.078% | 188.928589 | +0.129% | expected structural difference: E1, E3 |
| damage_capped | 188.685414 | 188.833039 | +0.078% | 188.928589 | +0.129% | expected structural difference: E1, E3 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 13 | 13 | 0% | 13 | 0% | equal |
| applications | 41 | 41 | 0% | 41 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 6 | 6 | 0% | 6 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 5 | 5 | 0% | 5 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 18 | 18 | 0% | 18 | 0% | equal |
| by_element.physical | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| by_element.electric | 20.385414 | 20.533039 | +0.724% | 20.628589 | +1.193% | expected structural difference: E1, E3 |
| statuses.shred | 11 | 11 | 0% | 11 | 0% | equal |
| hops.parça sekerek | 12 | 12 | 0% | 12 | 0% | equal |
| hops.parça | 6 | 6 | 0% | 6 | 0% | equal |
| roots.with_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_7_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_13_applications | 1 | 1 | 0% | 1 | 0% | equal |

### v4-21 (scenario)

Recipes: `fire5{fire_trail:[poison1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 399.6 | 316.35 | -20.833% | 307.35 | -23.086% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 399.6 | 309 | -22.673% | 300 | -24.925% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana | 0 | 2 | new (ref=0) | 2 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 129 | 85 | -34.109% | 82 | -36.434% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 6 | 9 | +50.000% | 9 | +50.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 308.25 | 218.7 | -29.051% | 212.85 | -30.949% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.poison | 91.35 | 97.65 | +6.897% | 94.5 | +3.448% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 7 | 6 | -14.286% | 6 | -14.286% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.poison | 78 | 35 | -55.128% | 34 | -56.410% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| fields.fire_trail | 44 | 11 | -75.000% | 12 | -72.727% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 129 | 85 | -34.109% | 82 | -36.434% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 129 | 85 | -34.109% | 82 | -36.434% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### v4-22 (scenario)

Recipes: `volcano5{lava_blob:[fire3,electric3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### v4-23 (scenario)

Recipes: `water1{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 83.3175 | 83.475 | +0.189% | 83.3175 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 83.3175 | 83.475 | +0.189% | 83.3175 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| by_element.blood | 45.5175 | 45.675 | +0.346% | 45.5175 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-24 (scenario)

Recipes: `light2{dazzle:[electric1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 122.715 | 122.715 | 0% | 122.715 | 0% | tolerance (floating arithmetic) |
| damage_capped | 122.715 | 122.715 | 0% | 122.715 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 2 | 2 | 0% | 2 | 0% | equal |
| applications | 18 | 18 | 0% | 18 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 9 | 0% | 9 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.light | 97.2 | 97.2 | 0% | 97.2 | 0% | tolerance (floating arithmetic) |
| by_element.electric | 25.515 | 25.515 | 0% | 25.515 | 0% | tolerance (floating arithmetic) |
| statuses.blind | 9 | 9 | 0% | 9 | 0% | equal |
| roots.with_applications | 9 | 9 | 0% | 9 | 0% | equal |
| roots.using_2_applications | 9 | 9 | 0% | 9 | 0% | equal |

### user-trail-ice (scenario)

Recipes: `fire3{fire_trail:[ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 129.672 | 160.884 | +24.070% | 184.59 | +42.351% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 129.672 | 160.884 | +24.070% | 184.59 | +42.351% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 29 | 45 | +55.172% | 56 | +93.103% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 5 | +150.000% | 7 | +250.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 120.6 | 131.4 | +8.955% | 144.9 | +20.149% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.ice | 9.072 | 29.484 | +225.000% | 39.69 | +337.500% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.slow | 8 | 26 | +225.000% | 35 | +337.500% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| fields.fire_trail | 38 | 10 | -73.684% | 11 | -71.053% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 29 | 45 | +55.172% | 56 | +93.103% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 29 | 45 | +55.172% | 56 | +93.103% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### user-lava-hop (scenario)

Recipes: `volcano3{lava_blob:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 358.9974 | 358.9974 | 0% | 358.9974 | 0% | tolerance (floating arithmetic) |
| damage_capped | 358.9974 | 358.9974 | 0% | 358.9974 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 6 | 6 | 0% | 6 | 0% | equal |
| applications | 48 | 48 | 0% | 48 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.lava | 275.23134 | 275.23134 | 0% | 275.23134 | 0% | tolerance (floating arithmetic) |
| by_element.electric | 83.76606 | 83.76606 | 0% | 83.76606 | 0% | equal |
| hops.lav topu düşmandan düşmana zıplayarak | 16 | 16 | 0% | 16 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_6_applications | 8 | 8 | 0% | 8 | 0% | equal |

### mana-graft (scenario)

Recipes: `fire3{burn:[mana1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 160.5915 | 147.9915 | -7.846% | 146.1915 | -8.967% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 160.5915 | 147.9915 | -7.846% | 146.1915 | -8.967% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 21.71043 | 21.71043 | 0% | 21.71043 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 21.71043 | 21.71043 | 0% | 21.71043 | 0% | tolerance (floating arithmetic) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 134.1 | -8.589% | 132.3 | -9.816% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.arcane | 13.8915 | 13.8915 | 0% | 13.8915 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 15 | -60.526% | 14 | -63.158% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### mana-mark (scenario)

Recipes: `mana3`, `stone3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 246.3 | 246.3 | 0% | 246.3 | 0% | equal |
| damage_capped | 231.5 | 231.5 | 0% | 231.5 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 97.98 | 97.98 | 0% | 97.98 | 0% | equal |
| mana_siphon | 58.5 | 58.5 | 0% | 58.5 | 0% | equal |
| mana_mark | 37.48 | 37.48 | 0% | 37.48 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 25 | 25 | 0% | 25 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 6 | 6 | 0% | 6 | 0% | equal |
| status_instances | 7 | 7 | 0% | 7 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 13 | 13 | 0% | 13 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 6 | 0% | 6 | 0% | equal |
| by_element.arcane | 78 | 78 | 0% | 78 | 0% | equal |
| by_element.physical | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| statuses.mana_mark | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.shred | 10 | 10 | 0% | 10 | 0% | equal |
| hops.parça | 6 | 6 | 0% | 6 | 0% | equal |
| roots.with_applications | 13 | 13 | 0% | 13 | 0% | equal |
| roots.using_1_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_3_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_5_applications | 1 | 1 | 0% | 1 | 0% | equal |

### mana-mark-alone (comparison)

Recipes: `stone3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| damage_capped | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 17 | 17 | 0% | 17 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 6 | 6 | 0% | 6 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 5 | 5 | 0% | 5 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 6 | 0% | 6 | 0% | equal |
| by_element.physical | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| statuses.shred | 11 | 11 | 0% | 11 | 0% | equal |
| hops.parça | 6 | 6 | 0% | 6 | 0% | equal |
| roots.with_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_3_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_5_applications | 1 | 1 | 0% | 1 | 0% | equal |

### mana-crystal (scenario)

Recipes: `mana5`, `fire5`, `stone5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 742.2 | 715.9 | -3.544% | 713.4 | -3.880% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 666.4 | 650.7 | -2.356% | 644.4 | -3.301% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 4 | 4 | 0% | 4 | 0% | equal |
| mana | 306.81 | 303.54 | -1.066% | 301.05 | -1.877% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana_siphon | 173.8 | 173.8 | 0% | 173.8 | 0% | equal |
| mana_mark | 125.01 | 121.74 | -2.616% | 119.25 | -4.608% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| stones | 12 | 12 | 0% | 12 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 99 | 84 | -15.152% | 84 | -15.152% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 22 | 22 | 0% | 22 | 0% | equal |
| status_instances | 17 | 17 | 0% | 17 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 21 | 21 | 0% | 21 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 11 | 11 | 0% | 11 | 0% | equal |
| by_element.arcane | 173.8 | 173.8 | 0% | 173.8 | 0% | equal |
| by_element.fire | 263.9 | 237.6 | -9.966% | 235.1 | -10.913% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.physical | 304.5 | 304.5 | 0% | 304.5 | 0% | equal |
| statuses.mana_mark | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.burn | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.shred | 12 | 12 | 0% | 12 | 0% | equal |
| statuses.stun | 12 | 12 | 0% | 12 | 0% | equal |
| hops.parça | 11 | 11 | 0% | 11 | 0% | equal |
| fields.fire_trail | 22 | 8 | -63.636% | 9 | -59.091% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 77 | 62 | -19.481% | 62 | -19.481% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 72 | 57 | -20.833% | 57 | -20.833% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_3_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_5_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 2 | 2 | 0% | 2 | 0% | equal |

### wet-electric (scenario)

Recipes: `water2`, `electric3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 243.27 | 243.27 | 0% | 243.27 | 0% | equal |
| damage_capped | 241.77 | 241.77 | 0% | 241.77 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 47 | 47 | 0% | 47 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 15 | 15 | 0% | 15 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.water | 56.7 | 56.7 | 0% | 56.7 | 0% | equal |
| by_element.electric | 186.57 | 186.57 | 0% | 186.57 | 0% | tolerance (floating arithmetic) |
| statuses.wet | 7 | 7 | 0% | 7 | 0% | equal |
| hops.seker | 16 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3 |
| roots.with_applications | 15 | 15 | 0% | 15 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 16 | new (ref=0) | 16 | new (ref=0) | expected structural difference: E1, E3 |

### wet-electric-alone (comparison)

Recipes: `electric3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 149.22 | 149.22 | 0% | 149.22 | 0% | tolerance (floating arithmetic) |
| damage_capped | 149.22 | 149.22 | 0% | 149.22 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 40 | 40 | 0% | 40 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.electric | 149.22 | 149.22 | 0% | 149.22 | 0% | tolerance (floating arithmetic) |
| hops.seker | 16 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 16 | new (ref=0) | 16 | new (ref=0) | expected structural difference: E1, E3 |

### rej-locked-shards (scenario)

Recipes: `ice3{ice_shards:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### rej-locked-push (scenario)

Recipes: `water2{push:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### rej-armor-chain (scenario)

Graft check: `['golem2', 'stone_skin', 'electric3']`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| graft accepted | false | false | 0 | false | 0 | equal |

### rej-summon (scenario)

Recipes: `fire3{burn:[volcano3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 217.701 | 194.6295 | -10.598% | 192.8295 | -11.425% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 213.7575 | 191.2575 | -10.526% | 189.4575 | -11.368% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 58 | 40 | -31.034% | 38 | -34.483% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 128.7 | -12.270% | 126.9 | -13.497% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 71.001 | 65.9295 | -7.143% | 65.9295 | -7.143% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 15 | -60.526% | 14 | -63.158% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 58 | 40 | -31.034% | 38 | -34.483% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 58 | 40 | -31.034% | 38 | -34.483% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### rej-pierce-tick (scenario)

Recipes: `fire3{burn:[light3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 186.831 | 174.231 | -6.744% | 172.431 | -7.708% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 186.831 | 174.231 | -6.744% | 172.431 | -7.708% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 11 | 11 | 0% | 11 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 134.1 | -8.589% | 132.3 | -9.816% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.light | 40.131 | 40.131 | 0% | 40.131 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.blind | 14 | 14 | 0% | 14 | 0% | equal |
| fields.fire_trail | 38 | 15 | -60.526% | 14 | -63.158% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### stress-24 (scenario)

Recipes: `fire5{fire_hit:[electric5{chain:[ice5{chill:[poison5,blood5]},stone3]},meteor3],burn:[electric3{chain:[ice2,water3]},poison4{poison_tick:[blood2]}],fire_trail:[ice3{freeze:[light3]},hive1,golem1,volcano2{lava_blob:[fire2,water2{wet:[electric2,poison1]}]},stone2{armor_shred:[light2]},blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 739.359243 | 727.157071 | -1.650% | 737.309101 | -0.277% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| damage_capped | 720 | 720 | 0% | 720 | 0% | tolerance (floating arithmetic) |
| kills | 6 | 6 | 0% | 6 | 0% | equal |
| mana | 12 | 12 | 0% | 12 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 6 | 6 | 0% | 6 | 0% | equal |
| frozen | 5 | 4 | -20.000% | 6 | +20.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 13 | 13 | 0% | 13 | 0% | equal |
| applications | 142 | 139 | -2.113% | 154 | +8.451% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 216 | 192 | -11.111% | 199 | -7.870% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| status_instances | 78 | 100 | +28.205% | 92 | +17.949% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| pushed_tiles | 1.004457 | 1.090751 | +8.591% | 1.004457 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| seconds | 5.65 | 5.95 | +5.310% | 6.5 | +15.044% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| host_attacks | 3 | 3 | 0% | 3 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 24 | 27 | +12.500% | 30 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.fire | 175.141431 | 171.365537 | -2.156% | 163.699052 | -6.533% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.electric | 114.162571 | 124.072838 | +8.681% | 118.619273 | +3.904% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.impact | 77.115924 | 108.055544 | +40.121% | 64.512879 | -16.343% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.ice | 44.940139 | 41.255708 | -8.199% | 43.285894 | -3.681% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.physical | 61.310592 | 51.973572 | -15.229% | 58.634202 | -4.365% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.blood | 44.484046 | 49.179118 | +10.555% | 46.307748 | +4.100% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.lava | 42.547974 | 34.186614 | -19.652% | 39.784374 | -6.495% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.water | 21.950686 | 22.035064 | +0.384% | 21.975382 | +0.113% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.light | 71.05 | 60.17984 | -15.299% | 78.10992 | +9.937% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| by_element.poison | 86.655879 | 64.853236 | -25.160% | 102.380376 | +18.146% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.burn | 30 | 29 | -3.333% | 30 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.charge | 9 | 9 | 0% | 8 | -11.111% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.slow | 28 | 27 | -3.571% | 28 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.poison | 52 | 50 | -3.846% | 56 | +7.692% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.bleed | 24 | 19 | -20.833% | 24 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.cold | 20 | 18 | -10.000% | 20 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.shred | 20 | 18 | -10.000% | 20 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.blind | 18 | 15 | -16.667% | 20 | +11.111% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| statuses.wet | 21 | 20 | -4.762% | 22 | +4.762% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| hops.mermi sekerek | 6 | 7 | +16.667% | 8 | +33.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| hops.parça | 1 | 1 | 0% | 1 | 0% | equal |
| hops.durum yandakine geçerek | 9 | 10 | +11.111% | 13 | +44.444% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| hops.durum yandakine atlayarak | 8 | 9 | +12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| fields.fire_trail | 16 | 5 | -68.750% | 5 | -68.750% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.with_applications | 51 | 47 | -7.843% | 53 | +3.922% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_1_applications | 28 | 23 | -17.857% | 29 | +3.571% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_2_applications | 3 | 4 | +33.333% | 3 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_3_applications | 3 | 3 | 0% | 1 | -66.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_4_applications | 2 | 0 | -100.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_5_applications | 11 | 12 | +9.091% | 11 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_6_applications | 2 | 3 | +50.000% | 6 | +200.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_11_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |
| roots.using_13_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_8_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B1 exposure, B2 exposure |

### plain-fire1 (plain)

Recipes: `fire1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 63 | 63 | 0% | 63 | 0% | equal |
| damage_capped | 63 | 63 | 0% | 63 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 63 | 63 | 0% | 63 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-fire3 (plain)

Recipes: `fire3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 146.7 | 134.1 | -8.589% | 132.3 | -9.816% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 146.7 | 134.1 | -8.589% | 132.3 | -9.816% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 134.1 | -8.589% | 132.3 | -9.816% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 15 | -60.526% | 14 | -63.158% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 58 | 44 | -24.138% | 42 | -27.586% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### plain-fire5 (plain)

Recipes: `fire5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 308.25 | 232.2 | -24.672% | 226.35 | -26.569% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 308.25 | 228.9 | -25.742% | 223.05 | -27.640% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana | 0 | 2 | new (ref=0) | 2 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 100 | 58 | -42.000% | 56 | -44.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 3 | +50.000% | 3 | +50.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 308.25 | 232.2 | -24.672% | 226.35 | -26.569% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 44 | 11 | -75.000% | 12 | -72.727% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 100 | 58 | -42.000% | 56 | -44.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 100 | 58 | -42.000% | 56 | -44.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### plain-ice1 (plain)

Recipes: `ice1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| damage_capped | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.ice | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-ice3 (plain)

Recipes: `ice3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 86.4 | 86.4 | 0% | 86.4 | 0% | tolerance (floating arithmetic) |
| damage_capped | 86.4 | 86.4 | 0% | 86.4 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 2 | 2 | 0% | 2 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 8 | 8 | 0% | 8 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.ice | 86.4 | 86.4 | 0% | 86.4 | 0% | tolerance (floating arithmetic) |
| statuses.slow | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.cold | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_1_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-ice5 (plain)

Recipes: `ice5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 163.8 | 163.8 | 0% | 163.8 | 0% | equal |
| damage_capped | 143.4 | 143.4 | 0% | 143.4 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 4 | 4 | 0% | 4 | 0% | equal |
| nova_frozen | 3 | 3 | 0% | 3 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 4 | 4 | 0% | 4 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.ice | 163.8 | 163.8 | 0% | 163.8 | 0% | equal |
| statuses.slow | 6 | 6 | 0% | 6 | 0% | equal |
| statuses.cold | 6 | 6 | 0% | 6 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-electric1 (plain)

Recipes: `electric1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 64.8 | 64.8 | 0% | 64.8 | 0% | equal |
| damage_capped | 64.8 | 64.8 | 0% | 64.8 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 8 | 8 | 0% | 8 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.electric | 64.8 | 64.8 | 0% | 64.8 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_1_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-electric3 (plain)

Recipes: `electric3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 149.22 | 149.22 | 0% | 149.22 | 0% | tolerance (floating arithmetic) |
| damage_capped | 149.22 | 149.22 | 0% | 149.22 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 40 | 40 | 0% | 40 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.electric | 149.22 | 149.22 | 0% | 149.22 | 0% | tolerance (floating arithmetic) |
| hops.seker | 16 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 16 | new (ref=0) | 16 | new (ref=0) | expected structural difference: E1, E3 |

### plain-electric5 (plain)

Recipes: `electric5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 322.65 | 322.65 | 0% | 322.65 | 0% | tolerance (floating arithmetic) |
| damage_capped | 322.65 | 322.65 | 0% | 322.65 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 56 | 56 | 0% | 56 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 24 | 24 | 0% | 24 | 0% | equal |
| status_instances | 5 | 5 | 0% | 6 | +20.000% | expected structural difference: E1, E3 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 24 | 24 | 0% | 24 | 0% | equal |
| by_element.electric | 322.65 | 322.65 | 0% | 322.65 | 0% | tolerance (floating arithmetic) |
| statuses.charge | 32 | 32 | 0% | 32 | 0% | equal |
| hops.seker | 24 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_7_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 24 | new (ref=0) | 24 | new (ref=0) | expected structural difference: E1, E3 |

### plain-poison1 (plain)

Recipes: `poison1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 63 | 63 | 0% | 63 | 0% | equal |
| damage_capped | 63 | 63 | 0% | 63 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 21 | 21 | 0% | 21 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.poison | 63 | 63 | 0% | 63 | 0% | equal |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 21 | 21 | 0% | 21 | 0% | equal |
| roots.using_1_applications | 21 | 21 | 0% | 21 | 0% | equal |

### plain-poison3 (plain)

Recipes: `poison3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 144.9 | 151.2 | +4.348% | 144.9 | 0% | expected structural difference: E1, E3 |
| damage_capped | 144.9 | 151.2 | +4.348% | 144.9 | 0% | expected structural difference: E1, E3 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 22 | 23 | +4.545% | 22 | 0% | expected structural difference: E1, E3 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.poison | 144.9 | 151.2 | +4.348% | 144.9 | 0% | expected structural difference: E1, E3 |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 22 | 23 | +4.545% | 22 | 0% | expected structural difference: E1, E3 |
| roots.using_1_applications | 22 | 23 | +4.545% | 22 | 0% | expected structural difference: E1, E3 |

### plain-poison5 (plain)

Recipes: `poison5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 257.4 | 257.4 | 0% | 257.4 | 0% | equal |
| damage_capped | 238.8 | 238.8 | 0% | 238.8 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 20 | 20 | 0% | 20 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 1 | 1 | 0% | 1 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.poison | 257.4 | 257.4 | 0% | 257.4 | 0% | equal |
| statuses.poison | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 20 | 20 | 0% | 20 | 0% | equal |
| roots.using_1_applications | 20 | 20 | 0% | 20 | 0% | equal |

### plain-water1 (plain)

Recipes: `water1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| damage_capped | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 37.8 | 37.8 | 0% | 37.8 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-water3 (plain)

Recipes: `water3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 81.9 | 81.9 | 0% | 81.9 | 0% | equal |
| damage_capped | 81.9 | 81.9 | 0% | 81.9 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 2.45 | 2.45 | 0% | 2.45 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 81.9 | 81.9 | 0% | 81.9 | 0% | equal |
| statuses.wet | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-water5 (plain)

Recipes: `water5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 188.1 | 188.1 | 0% | 188.1 | 0% | equal |
| damage_capped | 169.5 | 169.5 | 0% | 169.5 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 6 | 6 | 0% | 6 | 0% | equal |
| applications | 33 | 33 | 0% | 33 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 10 | 10 | 0% | 10 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 4.675 | 4.675 | 0% | 4.675 | 0% | tolerance (floating arithmetic) |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 188.1 | 188.1 | 0% | 188.1 | 0% | equal |
| statuses.wet | 16 | 16 | 0% | 16 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_2_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_4_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_6_applications | 4 | 4 | 0% | 4 | 0% | equal |

### plain-stone1 (plain)

Recipes: `stone1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 63 | 63 | 0% | 63 | 0% | equal |
| damage_capped | 63 | 63 | 0% | 63 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 5 | 5 | 0% | 5 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 5 | 5 | 0% | 5 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 63 | 63 | 0% | 63 | 0% | equal |
| roots.with_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_1_applications | 5 | 5 | 0% | 5 | 0% | equal |

### plain-stone3 (plain)

Recipes: `stone3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| damage_capped | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 17 | 17 | 0% | 17 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 6 | 6 | 0% | 6 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 5 | 5 | 0% | 5 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 6 | 0% | 6 | 0% | equal |
| by_element.physical | 168.3 | 168.3 | 0% | 168.3 | 0% | equal |
| statuses.shred | 11 | 11 | 0% | 11 | 0% | equal |
| hops.parça | 6 | 6 | 0% | 6 | 0% | equal |
| roots.with_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_3_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_5_applications | 1 | 1 | 0% | 1 | 0% | equal |

### plain-stone5 (plain)

Recipes: `stone5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 321 | 321 | 0% | 321 | 0% | equal |
| damage_capped | 321 | 321 | 0% | 321 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 29 | 29 | 0% | 29 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 24 | 24 | 0% | 24 | 0% | equal |
| status_instances | 4 | 4 | 0% | 4 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 5 | 5 | 0% | 5 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 12 | 12 | 0% | 12 | 0% | equal |
| by_element.physical | 321 | 321 | 0% | 321 | 0% | equal |
| statuses.shred | 17 | 17 | 0% | 17 | 0% | equal |
| statuses.stun | 17 | 17 | 0% | 17 | 0% | equal |
| hops.parça | 12 | 12 | 0% | 12 | 0% | equal |
| roots.with_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_3_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_5_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_7_applications | 3 | 3 | 0% | 3 | 0% | equal |

### plain-light1 (plain)

Recipes: `light1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 64.8 | 64.8 | 0% | 64.8 | 0% | tolerance (floating arithmetic) |
| damage_capped | 64.8 | 64.8 | 0% | 64.8 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 9 | 9 | 0% | 9 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 9 | 0% | 9 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.light | 64.8 | 64.8 | 0% | 64.8 | 0% | tolerance (floating arithmetic) |
| roots.with_applications | 9 | 9 | 0% | 9 | 0% | equal |
| roots.using_1_applications | 9 | 9 | 0% | 9 | 0% | equal |

### plain-light3 (plain)

Recipes: `light3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 168.48 | 168.48 | 0% | 168.48 | 0% | equal |
| damage_capped | 168.48 | 168.48 | 0% | 168.48 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 3 | 3 | 0% | 3 | 0% | equal |
| applications | 27 | 27 | 0% | 27 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 9 | 9 | 0% | 9 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 9 | 0% | 9 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 9 | 9 | 0% | 9 | 0% | equal |
| by_element.light | 168.48 | 168.48 | 0% | 168.48 | 0% | equal |
| statuses.blind | 18 | 18 | 0% | 18 | 0% | equal |
| hops.ışın deler | 9 | 9 | 0% | 9 | 0% | equal |
| roots.with_applications | 9 | 9 | 0% | 9 | 0% | equal |
| roots.using_3_applications | 9 | 9 | 0% | 9 | 0% | equal |

### plain-light5 (plain)

Recipes: `light5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 307.881 | 307.881 | 0% | 307.2006 | -0.221% | expected structural difference: E1, E3 |
| damage_capped | 300.306 | 300.306 | 0% | 299.6256 | -0.227% | tolerance (floating arithmetic); expected structural difference: E1, E3 |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 5 | 5 | 0% | 5 | 0% | equal |
| applications | 29 | 29 | 0% | 29 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 20 | 20 | 0% | 20 | 0% | equal |
| status_instances | 6 | 6 | 0% | 6 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 9 | 0% | 9 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 10 | 10 | 0% | 10 | 0% | equal |
| by_element.light | 307.881 | 307.881 | 0% | 307.2006 | -0.221% | expected structural difference: E1, E3 |
| statuses.blind | 18 | 18 | 0% | 18 | 0% | equal |
| statuses.lit | 18 | 18 | 0% | 18 | 0% | equal |
| hops.ışın deler | 10 | 10 | 0% | 10 | 0% | equal |
| roots.with_applications | 9 | 9 | 0% | 9 | 0% | equal |
| roots.using_3_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_5_applications | 1 | 1 | 0% | 1 | 0% | equal |

### plain-blood1 (plain)

Recipes: `blood1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-blood3 (plain)

Recipes: `blood3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 136.85625 | 137.53125 | +0.493% | 136.85625 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 136.85625 | 137.53125 | +0.493% | 136.85625 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.blood | 136.85625 | 137.53125 | +0.493% | 136.85625 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-blood5 (plain)

Recipes: `blood5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 248.04 | 249.66 | +0.653% | 248.04 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 247.98 | 249.6 | +0.653% | 247.98 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 7 | 7 | 0% | 7 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.blood | 248.04 | 249.66 | +0.653% | 248.04 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-meteor1 (plain)

Recipes: `meteor1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 64.8 | 64.8 | 0% | 64.8 | 0% | equal |
| damage_capped | 64.8 | 64.8 | 0% | 64.8 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 4 | 4 | 0% | 4 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.impact | 64.8 | 64.8 | 0% | 64.8 | 0% | equal |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_1_applications | 4 | 4 | 0% | 4 | 0% | equal |

### plain-meteor3 (plain)

Recipes: `meteor3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 163.8 | 246.96 | +50.769% | 163.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 163.8 | 246.96 | +50.769% | 163.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 6 | 8 | +33.333% | 6 | 0% | expected structural difference: E1, E3, E4 |
| applications | 18 | 30 | +66.667% | 18 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 5 | 8 | +60.000% | 5 | 0% | expected structural difference: E1, E3, E4 |
| by_element.impact | 163.8 | 246.96 | +50.769% | 163.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| hops.parça | 5 | 8 | +60.000% | 5 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_4_applications | 3 | 0 | -100.000% | 3 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_6_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_8_applications | 0 | 3 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |

### plain-meteor5 (plain)

Recipes: `meteor5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 288 | 302.4 | +5.000% | 288 | 0% | expected structural difference: E1, E3, E4 |
| damage_capped | 278.4 | 292.8 | +5.172% | 278.4 | 0% | expected structural difference: E1, E3, E4 |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 8 | 13 | +62.500% | 8 | 0% | expected structural difference: E1, E3, E4 |
| applications | 31 | 33 | +6.452% | 31 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 4 | 5 | +25.000% | 4 | 0% | expected structural difference: E1, E3, E4 |
| by_element.impact | 288 | 302.4 | +5.000% | 288 | 0% | expected structural difference: E1, E3, E4 |
| hops.parça | 4 | 5 | +25.000% | 4 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_7_applications | 1 | 0 | -100.000% | 1 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_8_applications | 3 | 1 | -66.667% | 3 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_2_applications | 0 | 1 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_10_applications | 0 | 1 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_13_applications | 0 | 1 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E4 |

### plain-volcano1 (plain)

Recipes: `volcano1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 61.2 | 61.2 | 0% | 61.2 | 0% | equal |
| damage_capped | 61.2 | 61.2 | 0% | 61.2 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 4 | 4 | 0% | 4 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.lava | 61.2 | 61.2 | 0% | 61.2 | 0% | equal |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_1_applications | 4 | 4 | 0% | 4 | 0% | equal |

### plain-volcano3 (plain)

Recipes: `volcano3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 165.6 | 165.6 | 0% | 165.6 | 0% | equal |
| damage_capped | 165.6 | 165.6 | 0% | 165.6 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 2 | 2 | 0% | 2 | 0% | equal |
| applications | 16 | 16 | 0% | 16 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.lava | 165.6 | 165.6 | 0% | 165.6 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_2_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-volcano5 (plain)

Recipes: `volcano5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | expected structural difference: E1, E3, E2, E4 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 2 | 2 | 0% | 2 | 0% | equal |
| applications | 27 | 31 | +14.815% | 30 | +11.111% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.lava | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 8 | 5 | -37.500% | 6 | -25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 19 | 23 | +21.053% | 22 | +15.789% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 11 | 15 | +36.364% | 14 | +27.273% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-golem1 (plain)

Recipes: `golem1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 64.8 | 57.6 | -11.111% | 64.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 64.8 | 57.6 | -11.111% | 64.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 9 | 8 | -11.111% | 9 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 8 | -11.111% | 9 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 64.8 | 57.6 | -11.111% | 64.8 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| roots.with_applications | 9 | 8 | -11.111% | 9 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 9 | 8 | -11.111% | 9 | 0% | expected structural difference: E1, E3, E4 |

### plain-golem3 (plain)

Recipes: `golem3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 138.6 | 118.8 | -14.286% | 138.6 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 138.6 | 118.8 | -14.286% | 138.6 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 138.6 | 118.8 | -14.286% | 138.6 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| roots.with_applications | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |

### plain-golem5 (plain)

Recipes: `golem5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 315 | 270 | -14.286% | 315 | 0% | expected structural difference: E1, E3, E4 |
| damage_capped | 285 | 255 | -10.526% | 285 | 0% | expected structural difference: E1, E3, E4 |
| kills | 2 | 1 | -50.000% | 2 | 0% | expected structural difference: E1, E3, E4 |
| mana | 4 | 2 | -50.000% | 4 | 0% | expected structural difference: E1, E3, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 2 | 1 | -50.000% | 2 | 0% | expected structural difference: E1, E3, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 315 | 270 | -14.286% | 315 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E4 |

### plain-hive1 (plain)

Recipes: `hive1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 59.85 | 59.85 | 0% | 59.85 | 0% | tolerance (floating arithmetic) |
| damage_capped | 59.85 | 59.85 | 0% | 59.85 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 19 | 19 | 0% | 19 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 19 | 19 | 0% | 19 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 59.85 | 59.85 | 0% | 59.85 | 0% | tolerance (floating arithmetic) |
| roots.with_applications | 19 | 19 | 0% | 19 | 0% | equal |
| roots.using_1_applications | 19 | 19 | 0% | 19 | 0% | equal |

### plain-hive3 (plain)

Recipes: `hive3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 135 | 130.5 | -3.333% | 135 | 0% | expected structural difference: E1, E3, E4 |
| damage_capped | 133.5 | 129 | -3.371% | 133.5 | 0% | expected structural difference: E1, E3, E4 |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 135 | 130.5 | -3.333% | 135 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 30 | 29 | -3.333% | 30 | 0% | expected structural difference: E1, E3, E4 |

### plain-hive5 (plain)

Recipes: `hive5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 356.4 | 340.2 | -4.545% | 356.4 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 353.4 | 337.2 | -4.584% | 353.4 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 2 | 2 | 0% | 2 | 0% | equal |
| mana | 4 | 4 | 0% | 4 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 2 | 2 | 0% | 2 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 44 | 42 | -4.545% | 44 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 45 | 43 | -4.444% | 45 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 356.4 | 340.2 | -4.545% | 356.4 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| roots.with_applications | 44 | 42 | -4.545% | 44 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 44 | 42 | -4.545% | 44 | 0% | expected structural difference: E1, E3, E4 |

### plain-mana1 (plain)

Recipes: `mana1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 32.4 | 32.4 | 0% | 32.4 | 0% | equal |
| damage_capped | 32.4 | 32.4 | 0% | 32.4 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 19.44 | 19.44 | 0% | 19.44 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 19.44 | 19.44 | 0% | 19.44 | 0% | tolerance (floating arithmetic) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 8 | 8 | 0% | 8 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 32.4 | 32.4 | 0% | 32.4 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_1_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-mana3 (plain)

Recipes: `mana3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 72 | 72 | 0% | 72 | 0% | equal |
| damage_capped | 72 | 72 | 0% | 72 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 63 | 63 | 0% | 63 | 0% | equal |
| mana_siphon | 54 | 54 | 0% | 54 | 0% | equal |
| mana_mark | 9 | 9 | 0% | 9 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 8 | 8 | 0% | 8 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 72 | 72 | 0% | 72 | 0% | equal |
| statuses.mana_mark | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_1_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-mana5 (plain)

Recipes: `mana5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 158.4 | 158.4 | 0% | 158.4 | 0% | equal |
| damage_capped | 158.4 | 158.4 | 0% | 158.4 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 199.98 | 199.98 | 0% | 199.98 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 158.4 | 158.4 | 0% | 158.4 | 0% | equal |
| mana_mark | 41.58 | 41.58 | 0% | 41.58 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 8 | 8 | 0% | 8 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 158.4 | 158.4 | 0% | 158.4 | 0% | equal |
| statuses.mana_mark | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_1_applications | 8 | 8 | 0% | 8 | 0% | equal |

### shuffle-0 (probe)

Recipes: `volcano5{lava_blob:[fire3,electric3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### shuffle-1 (probe)

Recipes: `volcano5{lava_blob:[fire3,ice2,electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### shuffle-2 (probe)

Recipes: `volcano5{lava_blob:[electric3,fire3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### shuffle-3 (probe)

Recipes: `volcano5{lava_blob:[electric3,ice2,fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### shuffle-4 (probe)

Recipes: `volcano5{lava_blob:[ice2,fire3,electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### shuffle-5 (probe)

Recipes: `volcano5{lava_blob:[ice2,electric3,fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 742.832554 | -2.354% | 784.020058 | +3.060% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| kills | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana | 10 | 12 | +20.000% | 10 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 80 | -11.111% | 93 | +3.333% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| status_instances | 10 | 10 | 0% | 10 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.9 | -22.143% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.fire | 126.205254 | 123.861654 | -1.857% | 127.140363 | +0.741% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| fields.fire_trail | 36 | 6 | -83.333% | 10 | -72.222% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.with_applications | 55 | 46 | -16.364% | 55 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_1_applications | 47 | 39 | -17.021% | 47 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, E4, B2 exposure |

### deep3 (probe)

Recipes: `fire5{burn:[electric5{chain:[ice5{freeze:[poison4]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 718.232006 | 751.242373 | +4.596% | 704.760806 | -1.876% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 693.09294 | 720 | +3.882% | 691.725635 | -0.197% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 5 | 6 | +20.000% | 4 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana | 10 | 12 | +20.000% | 8 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 4 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| frozen | 15 | 15 | 0% | 15 | 0% | equal |
| nova_frozen | 10 | 10 | 0% | 10 | 0% | equal |
| shards | 2 | 2 | 0% | 2 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 9 | 9 | 0% | 9 | 0% | equal |
| applications | 156 | 164 | +5.128% | 162 | +3.846% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 137 | 132 | -3.650% | 134 | -2.190% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| status_instances | 23 | 21 | -8.696% | 23 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 13.4 | -4.286% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 27 | 25 | -7.407% | 27 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.fire | 350.1 | 376.65 | +7.584% | 345.6 | -1.285% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 257.991391 | 268.724937 | +4.160% | 247.785391 | -3.956% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.ice | 78.035815 | 72.527836 | -7.058% | 78.035815 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure; tolerance (floating arithmetic) |
| by_element.poison | 32.1048 | 33.3396 | +3.846% | 33.3396 | +3.846% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 30 | 28 | -6.667% | 30 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.charge | 61 | 61 | 0% | 60 | -1.639% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.slow | 24 | 22 | -8.333% | 23 | -4.167% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.cold | 24 | 22 | -8.333% | 23 | -4.167% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| hops.durum yandakine atlayarak | 24 | 22 | -8.333% | 24 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| hops.buz parçası düşer | 3 | 3 | 0% | 3 | 0% | equal |
| fields.fire_trail | 62 | 14 | -77.419% | 16 | -74.194% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 101 | 112 | +10.891% | 106 | +4.950% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 90 | 102 | +13.333% | 95 | +5.556% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_2_applications | 2 | 1 | -50.000% | 1 | -50.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_5_applications | 1 | 0 | -100.000% | 1 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_6_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_9_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### deep4 (probe)

Recipes: `fire5{burn:[electric5{chain:[ice5{freeze:[poison4{poison_tick:[blood2]}]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 720.427958 | 749.61267 | +4.051% | 709.892995 | -1.462% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| damage_capped | 693.09294 | 720 | +3.882% | 693.699828 | +0.088% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| kills | 5 | 6 | +20.000% | 4 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana | 10 | 12 | +20.000% | 8 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 4 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| frozen | 15 | 12 | -20.000% | 12 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| nova_frozen | 10 | 8 | -20.000% | 8 | -20.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| shards | 2 | 2 | 0% | 2 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 9 | 8 | -11.111% | 8 | -11.111% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| applications | 151 | 160 | +5.960% | 155 | +2.649% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 141 | 139 | -1.418% | 137 | -2.837% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| status_instances | 26 | 23 | -11.538% | 25 | -3.846% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 13.4 | -4.286% | 14 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure; tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 26 | 25 | -3.846% | 26 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.fire | 346.05 | 370.8 | +7.152% | 339.75 | -1.821% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.electric | 251.970087 | 261.164937 | +3.649% | 247.056087 | -1.950% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.ice | 72.527836 | 70.631646 | -2.614% | 70.631646 | -2.614% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.poison | 32.1048 | 33.3396 | +3.846% | 34.5744 | +7.692% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| by_element.blood | 17.775235 | 13.676487 | -23.059% | 17.880863 | +0.594% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.burn | 28 | 27 | -3.571% | 27 | -3.571% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.charge | 59 | 60 | +1.695% | 59 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.slow | 22 | 21 | -4.545% | 21 | -4.545% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.cold | 22 | 21 | -4.545% | 21 | -4.545% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.poison | 7 | 5 | -28.571% | 5 | -28.571% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| statuses.bleed | 12 | 13 | +8.333% | 13 | +8.333% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| hops.durum yandakine atlayarak | 23 | 22 | -4.348% | 23 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| hops.buz parçası düşer | 3 | 3 | 0% | 3 | 0% | equal |
| fields.fire_trail | 62 | 14 | -77.419% | 16 | -74.194% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.with_applications | 99 | 111 | +12.121% | 105 | +6.061% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_1_applications | 88 | 101 | +14.773% | 94 | +6.818% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_2_applications | 3 | 2 | -33.333% | 3 | 0% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_6_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 4 | 5 | +25.000% | 5 | +25.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |
| roots.using_8_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_9_applications | 1 | 0 | -100.000% | 0 | -100.000% | BUG exposure / structural mixture: E1, E3, E2, B2 exposure |

### summon-loop-volcano (probe)

Recipes: `volcano5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | expected structural difference: E1, E3, E2, E4 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 2 | 2 | 0% | 2 | 0% | equal |
| applications | 27 | 31 | +14.815% | 30 | +11.111% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 21 | 21.05 | +0.238% | 21.05 | +0.238% | expected structural difference: E1, E3, E2, E4 |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.lava | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 8 | 5 | -37.500% | 6 | -25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 19 | 23 | +21.053% | 22 | +15.789% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 11 | 15 | +36.364% | 14 | +27.273% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 8 | 8 | 0% | 8 | 0% | equal |

### summon-loop-golem (probe)

Recipes: `golem5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 405 | 382.5 | -5.556% | 405 | 0% | expected structural difference: E1, E3, E4 |
| damage_capped | 405 | 382.5 | -5.556% | 405 | 0% | expected structural difference: E1, E3, E4 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 18 | 17 | -5.556% | 18 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 21 | 21.05 | +0.238% | 21.05 | +0.238% | expected structural difference: E1, E3, E4 |
| host_attacks | 18 | 17 | -5.556% | 18 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 405 | 382.5 | -5.556% | 405 | 0% | expected structural difference: E1, E3, E4 |
| roots.with_applications | 18 | 17 | -5.556% | 18 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 18 | 17 | -5.556% | 18 | 0% | expected structural difference: E1, E3, E4 |

### summon-loop-hive (probe)

Recipes: `hive5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 502.2 | 494.1 | -1.613% | 502.2 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| damage_capped | 502.2 | 494.1 | -1.613% | 502.2 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 62 | 61 | -1.613% | 62 | 0% | expected structural difference: E1, E3, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 21 | 21.05 | +0.238% | 21.05 | +0.238% | expected structural difference: E1, E3, E4 |
| host_attacks | 62 | 61 | -1.613% | 62 | 0% | expected structural difference: E1, E3, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 502.2 | 494.1 | -1.613% | 502.2 | 0% | expected structural difference: E1, E3, E4; tolerance (floating arithmetic) |
| roots.with_applications | 62 | 61 | -1.613% | 62 | 0% | expected structural difference: E1, E3, E4 |
| roots.using_1_applications | 62 | 61 | -1.613% | 62 | 0% | expected structural difference: E1, E3, E4 |

### same-status-two-towers (direct)

Actions: `[{"kind":"status","recipe":"fire3","status":"burn","tower":0,"repeat":1,"target":0},{"kind":"status","recipe":"fire3","status":"burn","tower":1,"repeat":1,"target":0},{"kind":"tick","dt":1}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 2.7 | 2.7 | 0% | 2.7 | 0% | equal |
| damage_capped | 2.7 | 2.7 | 0% | 2.7 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 1 | 1 | 0% | 1 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 1 | 1 | 0% | 1 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 2.7 | 2.7 | 0% | 2.7 | 0% | equal |
| statuses.burn | 2 | 2 | 0% | 2 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

### forced-move-bleed (direct)

Actions: `[{"kind":"event","recipe":"water3{water_hit:[blood1]}","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 12.8025 | 12.8025 | 0% | 12.8025 | 0% | equal |
| damage_capped | 12.8025 | 12.8025 | 0% | 12.8025 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 1 | 1 | 0% | 1 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0.35 | 0.35 | 0% | 0.35 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 11.7 | 11.7 | 0% | 11.7 | 0% | tolerance (floating arithmetic) |
| by_element.blood | 1.1025 | 1.1025 | 0% | 1.1025 | 0% | tolerance (floating arithmetic) |
| statuses.wet | 1 | 1 | 0% | 1 | 0% | equal |
| statuses.bleed | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

### forced-move-origin (direct)

Actions: `[{"kind":"event","recipe":"water3{push:[electric3]}","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 21.15 | 21.15 | 0% | 21.15 | 0% | equal |
| damage_capped | 21.15 | 21.15 | 0% | 21.15 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 2 | 2 | 0% | 2 | 0% | equal |
| applications | 2 | 2 | 0% | 2 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0.35 | 0.35 | 0% | 0.35 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 11.7 | 11.7 | 0% | 11.7 | 0% | tolerance (floating arithmetic) |
| by_element.electric | 9.45 | 9.45 | 0% | 9.45 | 0% | equal |
| statuses.wet | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_2_applications | 1 | 1 | 0% | 1 | 0% | equal |

### push-chain-stale-position (direct)

Actions: `[{"kind":"event","recipe":"water3{water_hit:[electric3]}","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 18 | 29.91645 | +66.203% | 18 | 0% | BUG B1 |
| damage_capped | 18 | 29.91645 | +66.203% | 18 | 0% | BUG B1 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 1 | new (ref=0) | 0 | 0% | BUG B1 |
| max_status_gen | 0 | 1 | new (ref=0) | 0 | 0% | BUG B1 |
| max_budget_used | 1 | 5 | +400.000% | 1 | 0% | BUG B1 |
| applications | 1 | 5 | +400.000% | 1 | 0% | BUG B1 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 2 | new (ref=0) | 0 | 0% | BUG B1 |
| status_instances | 1 | 3 | +200.000% | 1 | 0% | BUG B1 |
| pushed_tiles | 0.35 | 0.581709 | +66.203% | 0.35 | 0% | BUG B1 |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 2 | new (ref=0) | 0 | 0% | BUG B1 |
| by_element.water | 11.7 | 19.445692 | +66.202% | 11.7 | 0% | BUG B1; tolerance (floating arithmetic) |
| by_element.electric | 6.3 | 10.470757 | +66.203% | 6.3 | 0% | BUG B1 |
| statuses.wet | 1 | 3 | +200.000% | 1 | 0% | BUG B1 |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 0 | -100.000% | 1 | 0% | BUG B1 |
| hops.mermi sekerek | 0 | 2 | new (ref=0) | 0 | 0% | BUG B1 |
| roots.using_5_applications | 0 | 1 | new (ref=0) | 0 | 0% | BUG B1 |

### boundary-pierce (direct)

Actions: `[{"kind":"position","target":0,"value":6.2},{"kind":"position","target":1,"value":7.1},{"kind":"event","recipe":"light3","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 18.72 | 11.7 | -37.500% | 11.7 | -37.500% | expected structural difference: E3 |
| damage_capped | 18.72 | 11.7 | -37.500% | 11.7 | -37.500% | expected structural difference: E3 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E3 |
| max_status_gen | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E3 |
| max_budget_used | 3 | 1 | -66.667% | 1 | -66.667% | expected structural difference: E3 |
| applications | 3 | 1 | -66.667% | 1 | -66.667% | expected structural difference: E3 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E3 |
| status_instances | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E3 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E3 |
| by_element.light | 18.72 | 11.7 | -37.500% | 11.7 | -37.500% | expected structural difference: E3 |
| statuses.blind | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E3 |
| hops.ışın deler | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E3 |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E3 |
| roots.using_1_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E3 |

### trail-spurious-cell-drop (direct)

Actions: `[{"kind":"position","target":0,"value":6.25},{"kind":"status","recipe":"fire3","status":"burn","tower":0,"repeat":1,"target":0},{"kind":"move","target":0,"dist":0.01,"forced":false}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 0 | 0 | 0% | 0 | 0% | equal |
| damage_capped | 0 | 0 | 0% | 0 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 0 | 0 | 0% | 0 | 0% | equal |
| applications | 0 | 0 | 0% | 0 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| statuses.burn | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 0 | 0 | 0% | 0 | 0% | equal |
| fields.fire_trail | 0 | 1 | new (ref=0) | 1 | new (ref=0) | BUG B2 |

### frozen-death-shards (direct)

Actions: `[{"kind":"status","recipe":"ice4{ice_shards:[electric3]}","status":"cold","tower":0,"repeat":3,"target":0},{"kind":"hp","target":0,"value":1},{"kind":"damage","target":0,"amount":1000,"element":"physical"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 930.564909 | 930.564909 | 0% | 930.564909 | 0% | equal |
| damage_capped | 31.564909 | 31.564909 | 0% | 31.564909 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 2 | 0% | 2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 1 | 1 | 0% | 1 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 1 | 1 | 0% | 1 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 10 | 10 | 0% | 10 | 0% | equal |
| applications | 10 | 10 | 0% | 10 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 6 | 0% | 6 | 0% | equal |
| by_element.physical | 900 | 900 | 0% | 900 | 0% | equal |
| by_element.ice | 18 | 18 | 0% | 18 | 0% | equal |
| by_element.electric | 12.564909 | 12.564909 | 0% | 12.564909 | 0% | equal |
| statuses.cold | 3 | 3 | 0% | 3 | 0% | equal |
| hops.parça sekerek | 4 | 4 | 0% | 4 | 0% | equal |
| hops.buz parçası hedef arayıp seker | 2 | 2 | 0% | 2 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_10_applications | 1 | 1 | 0% | 1 | 0% | equal |

### siphon-lethal-mana1 (direct)

Actions: `[{"kind":"event","recipe":"mana1","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 4.05 | 4.05 | 0% | 4.05 | 0% | equal |
| damage_capped | 1 | 1 | 0% | 1 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 4.43 | +121.500% | 4.43 | +121.500% | BUG B3 (Python reference) |
| mana_siphon | 0 | 2.43 | new (ref=0) | 2.43 | new (ref=0) | BUG B3 (Python reference) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 1 | 1 | 0% | 1 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 4.05 | 4.05 | 0% | 4.05 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

### siphon-lethal-mana3 (direct)

Actions: `[{"kind":"event","recipe":"mana3","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 9 | 9 | 0% | 9 | 0% | equal |
| damage_capped | 1 | 1 | 0% | 1 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2 | 8.75 | +337.500% | 8.75 | +337.500% | BUG B3 (Python reference) |
| mana_siphon | 0 | 6.75 | new (ref=0) | 6.75 | new (ref=0) | BUG B3 (Python reference) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 1 | 0% | 1 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 1 | 1 | 0% | 1 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 9 | 9 | 0% | 9 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

### siphon-tick (direct)

Actions: `[{"kind":"status","recipe":"fire3{burn:[mana1]}","status":"burn","tower":0,"repeat":1,"target":0},{"kind":"tick","dt":1}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 3.69225 | 3.69225 | 0% | 3.69225 | 0% | equal |
| damage_capped | 3.69225 | 3.69225 | 0% | 3.69225 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 1.550745 | 1.550745 | 0% | 1.550745 | 0% | equal |
| mana_siphon | 1.550745 | 1.550745 | 0% | 1.550745 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 1 | 1 | 0% | 1 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 1 | 1 | 0% | 1 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 2.7 | 2.7 | 0% | 2.7 | 0% | equal |
| by_element.arcane | 0.99225 | 0.99225 | 0% | 0.99225 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

### mark-economics (direct)

Actions: `[{"kind":"status","recipe":"mana5","status":"mana_mark","tower":0,"repeat":1,"target":0},{"kind":"event","recipe":"stone3","tower":0,"target":0},{"kind":"hp","target":0,"value":1},{"kind":"damage","target":0,"amount":10,"element":"fire"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 39.7 | 39.7 | 0% | 39.7 | 0% | equal |
| damage_capped | 30.7 | 30.7 | 0% | 30.7 | 0% | tolerance (floating arithmetic) |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 13.91 | 13.91 | 0% | 13.91 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 11.91 | 11.91 | 0% | 11.91 | 0% | equal |
| stones | 3 | 3 | 0% | 3 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 3 | 3 | 0% | 3 | 0% | equal |
| applications | 3 | 3 | 0% | 3 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 1 | 1 | 0% | 1 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 1 | 1 | 0% | 1 | 0% | equal |
| by_element.physical | 29.7 | 29.7 | 0% | 29.7 | 0% | tolerance (floating arithmetic) |
| by_element.fire | 10 | 10 | 0% | 10 | 0% | equal |
| statuses.mana_mark | 1 | 1 | 0% | 1 | 0% | equal |
| statuses.shred | 2 | 2 | 0% | 2 | 0% | equal |
| hops.parça | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 1 | 1 | 0% | 1 | 0% | equal |

### budget-dense-64 (direct)

Actions: `[{"kind":"event","recipe":"fire5{fire_hit:[electric5{chain:[ice5{chill:[poison5,blood5]},stone3]},meteor3],burn:[electric3{chain:[ice2,water3]},poison4{poison_tick:[blood2]}],fire_trail:[ice3{freeze:[light3]},hive1,golem1,volcano2{lava_blob:[fire2,water2{wet:[electric2,poison1]}]},stone2{armor_shred:[light2]},blood1]}","tower":0,"target":0},{"kind":"tick","dt":1},{"kind":"tick","dt":1},{"kind":"tick","dt":1},{"kind":"tick","dt":1}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 505.658879 | 518.70664 | +2.580% | 505.658879 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| damage_capped | 505.658879 | 518.70664 | +2.580% | 505.658879 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 16 | 16 | 0% | 16 | 0% | equal |
| applications | 74 | 75 | +1.351% | 74 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| rejected_events | 21 | 19 | -9.524% | 19 | -9.524% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| spread_status | 87 | 88 | +1.149% | 87 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| status_instances | 15 | 14 | -6.667% | 15 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| pushed_tiles | 1.004457 | 1.004457 | 0% | 1.004457 | 0% | tolerance (floating arithmetic) |
| seconds | 4 | 4 | 0% | 4 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 13 | 13 | 0% | 13 | 0% | equal |
| by_element.fire | 119.209984 | 119.209984 | 0% | 119.209984 | 0% | equal |
| by_element.electric | 83.548363 | 83.976924 | +0.513% | 83.548363 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| by_element.impact | 58.683131 | 58.683131 | 0% | 58.683131 | 0% | tolerance (floating arithmetic) |
| by_element.ice | 13.322174 | 13.417161 | +0.713% | 13.322174 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| by_element.physical | 5.502944 | 5.502944 | 0% | 5.502944 | 0% | tolerance (floating arithmetic) |
| by_element.water | 9.849226 | 9.986428 | +1.393% | 9.849226 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| by_element.blood | 5.715385 | 6.565835 | +14.880% | 5.715385 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| by_element.poison | 209.827672 | 221.364232 | +5.498% | 209.827672 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure; tolerance (floating arithmetic) |
| statuses.burn | 15 | 15 | 0% | 15 | 0% | equal |
| statuses.charge | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.slow | 11 | 11 | 0% | 11 | 0% | equal |
| statuses.poison | 27 | 27 | 0% | 27 | 0% | equal |
| statuses.bleed | 17 | 18 | +5.882% | 17 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| statuses.cold | 3 | 3 | 0% | 3 | 0% | equal |
| statuses.shred | 3 | 3 | 0% | 3 | 0% | equal |
| statuses.wet | 8 | 8 | 0% | 8 | 0% | equal |
| hops.mermi sekerek | 3 | 3 | 0% | 3 | 0% | equal |
| hops.parça | 2 | 2 | 0% | 2 | 0% | equal |
| hops.durum yandakine atlayarak | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 43 | 44 | +2.326% | 43 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| roots.using_1_applications | 38 | 39 | +2.632% | 38 | 0% | BUG exposure / structural mixture: E2, E4, B1 exposure, B2 exposure |
| roots.using_5_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_16_applications | 1 | 1 | 0% | 1 | 0% | equal |

### lock-fire-burn (lock)

Recipes: `fire1{burn:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-fire-fire_trail (lock)

Recipes: `fire2{fire_trail:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-ice-chill (lock)

Recipes: `ice1{chill:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-ice-freeze (lock)

Recipes: `ice2{freeze:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-ice-ice_shards (lock)

Recipes: `ice3{ice_shards:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-ice-frost_nova (lock)

Recipes: `ice4{frost_nova:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-electric-chain (lock)

Recipes: `electric1{chain:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-electric-overload (lock)

Recipes: `electric3{overload:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-poison-toxic_stack (lock)

Recipes: `poison1{toxic_stack:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-poison-heal_suppression (lock)

Recipes: `poison2{heal_suppression:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-poison-contagion (lock)

Recipes: `poison3{contagion:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-water-wet (lock)

Recipes: `water1{wet:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-water-push (lock)

Recipes: `water2{push:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-water-wave (lock)

Recipes: `water4{wave:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-stone-armor_shred (lock)

Recipes: `stone1{armor_shred:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-stone-fragments (lock)

Recipes: `stone2{fragments:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-stone-concussion (lock)

Recipes: `stone4{concussion:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-light-dazzle (lock)

Recipes: `light1{dazzle:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-light-pierce (lock)

Recipes: `light2{pierce:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-light-illuminate (lock)

Recipes: `light4{illuminate:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-blood-intensity (lock)

Recipes: `blood1{intensity:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-blood-rupture (lock)

Recipes: `blood3{rupture:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-meteor-meteor_area (lock)

Recipes: `meteor1{meteor_area:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-meteor-meteor_fragments (lock)

Recipes: `meteor2{meteor_fragments:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-meteor-meteor_shower (lock)

Recipes: `meteor4{meteor_shower:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-volcano-splash (lock)

Recipes: `volcano1{splash:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-volcano-wide_eruption (lock)

Recipes: `volcano2{wide_eruption:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-volcano-lava_pool (lock)

Recipes: `volcano3{lava_pool:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-golem-stone_skin (lock)

Recipes: `golem1{stone_skin:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-golem-ground_slam (lock)

Recipes: `golem2{ground_slam:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-hive-brood (lock)

Recipes: `hive1{brood:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-hive-swarm_focus (lock)

Recipes: `hive2{swarm_focus:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-mana-mana_mark (lock)

Recipes: `mana2{mana_mark:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

### lock-mana-crystallize (lock)

Recipes: `mana4{crystallize:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| compile error | locked_on_receiver | locked_on_receiver | — | locked_on_receiver | — | equal |

