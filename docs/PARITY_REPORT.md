# C2 — Python/Godot combat parity

Snapshot: `94a1c1aa9f8effb978078a058100c8ea87b2ccc7`. Engine `4.7.2.stable.arch_linux.ed1daf0bf`. Python `3.14.7`.

**Parity is partial.** 147 cases: 110 combat cases, 36 expected compile rejections, and one incompatible-graft check. Python suite: **127/127**. All 188 successful compiler comparisons match. All 220 Godot combat runs finish finite, generation ≤2 and ≤16 payload applications per root budget.

**B1, B2 and B3 are fixed.** Three newly isolated income-cap defects are shared by Godot and Python; see minimal reproductions below. Matching the reference alone does not establish conformance to the per-node economy rule.

Total-damage equality: grid **55/110**, replay **78/110**. All compared metric equality: grid **49/110**, replay **70/110**. Original-case counts and every changed metric are in the final commit-delta section.

## Re-run

From the parent project:

```sh
asset-work/codex-mvp/parity/run.sh
python3 asset-work/codex-mvp/parity/validation/verify_repeat.py
```

The equivalent core command remains `godot --headless --path asset-work/codex-mvp/parity/harness --script run_parity.gd`. The wrapper also keeps engine startup data/config/cache under this directory. Preparation copies sources byte for byte, executes the native Python suite and reference, and runs Godot grid and reference-event replay. The report is regenerated from raw results. No game or reference logic is patched. Nonzero exits indicate harness/invariant failures; documented parity and contract findings are not silently converted into implementation acceptance.

Python only: `python3 asset-work/codex-mvp/parity/python_runner.py prepare`; report only: same script with `report`.

## Method and limits

- Original coverage is retained: every scenario with towers/recipe, incompatible graft, all 13 runes at G1/G3/G5, comparison baselines, six sibling permutations, depth 3/4, receiver grade locks, all original direct probes. Added direct cases cover same-node caps, independent towers, second rollover, separate mark owners, multiple siphon donors, overkill marks, single crystallization and a real trail cell crossing.
- Default wave: six enemies, 120 HP, 0.6-tile spacing, 10% armor, speed 1 tile/s, duration 14 s, dt 0.05 s, tower (6,2), range 4. Periods/lifetimes come from the identical runtime/reference JSON spec. Tower overlap is intentional.
- Straight lane: world X=2×tile X, world Z=0; tower cell (6,-2). Path distance has +64-tile origin to avoid the native start clamp. Direct probes start at tile X=6. The offset can shift exact floating ties. Native enemy.sync_position() now calls the adapter world_pos() immediately; grid tile_pos remains the native transform read. No adapter recreates the B1 fix.
- Unchanged tower attack/summon methods, combat handlers, compiler, enemy statuses/speed and the real scripts/economy.gd run in the harness. Board/path/visual adapters replace the scene and art. The summon VFX stub accepts the new owner argument and records group/meta, but this is not acceptance evidence for real VFX ownership or cleanup.
- Observer overrides delegate unchanged arguments to super. Python normal runs are cross-checked against unwrapped sim.simulate; all source copies and spec hashes are recorded in results/provenance.json.
- Projectiles hit immediately to match the reference. Lava/meteor callbacks use deterministic simulated-time scheduling. Replay supplies Python tower/timer root events while Godot retains status/movement/field execution; it bypasses host targeting/summon loops. Grid fields vs radius fields and floating-point boundaries remain.
- Mana includes siphon, marks and 2 per kill; passive regen/starting balances are excluded. Soft caps use the real economy implementation, reset at integer simulated seconds, and exclude overkill. Stones include normal drops plus one best crystal bonus. Diagnostic damage and element totals remain uncapped; damage_capped removes overkill. Godot by_tower now records capped HP damage because the production callback changed, while Python by_tower remains uncapped; this is explicitly excluded from direct cross-engine equality.
- Status counts include refresh calls. Hops include selected targets even with exhausted payload budgets. Root application records and distributions are saved; direct damage/status calls do not consume application budgets. Finite means bounded steps, finite values and no event watchdog overflow.
- Numeric tolerance is abs≤1e-6 plus rel≤1e-9. Discrete counts require equality. Bleed counters differ in definition: Python nominal pre-armor movement damage vs observed Godot actual blood damage including descendants. Element totals are comparable.
- Native field VFX registration/lookup/merge/eviction/expiry is additionally exercised headlessly with unmodified vfx.gd; meteor/lava stale-callback cancellation uses native tower.set_rune(null) with the deterministic VFX timer stub. No rendered appearance, physical play, curved topology, real projectile/summon visual lifecycle, inventory transactions or save/load acceptance is claimed. rune_store.gd, save_system.gd and DECISIONS.md are reviewed/hashed context; their separate invariant suite is outside the original parity coverage.

## Difference classification

| ID | Class | Evidence / meaning |
|---|---|---|
| E1 | Expected structural | Cell-centre range membership vs continuous radius: tower.gd:124; sim.py:600. A boundary can add/remove a whole attack. |
| E2 | Expected structural | One-cell field merge/refresh and cell-crossing trails vs radius fields and distance drops: combat.gd:338,385,400,418; sim.py:441,483. B2 is repaired; this deliberate structural difference remains. |
| E3 | Spatial numeric boundary | Godot Vector2 vs Python binary64 can choose a different tied neighbour or exposure step. boundary-pierce still selects one Python hop vs zero Godot hops at 6.2/7.1. Discrete consequences are not treated as arithmetic tolerance. |
| E4 | Expected structural | Snapped meteor landings, slowed lead, 2D offsets, adjacent summons, volcano initial 0.6 vs 0.5 s, summon approach/reach: tower.gd:188,210,245,290. Replay removes host differences. |
| N1/N2/N3 | New shared economy defects | Native runtime and reference agree numerically but violate the new per-producing-node cap. Independently tested below; not a new Godot-only parity divergence. |

Aggregate scenario differences can mix E1–E4. Commit deltas caused by B1/B2 repairs can cascade through targets, fields, deaths, status calls, budgets and mana. Path exposure is reported without claiming an additive attribution of every downstream number.

## Prioritised bugs and minimal reproductions

| Priority | ID | Location | Finding |
|---|---|---|---|
| P2 | N1 | repo/scripts/combat.gd:128; repo/design/rune_mechanics/mechanics/sim.py:249 | Mark income source omits tower identity, so identical Mana nodes on separate towers share a cap even in disjoint areas. |
| P2 | N2 | repo/scripts/combat.gd:92–102; repo/design/rune_mechanics/mechanics/sim.py:206–211 | Multiple siphon nodes are summed and charged to the first node's cap/grade; the other nodes' independent caps disappear. |
| P2 | N3 | repo/scripts/combat.gd:102,128; repo/design/rune_mechanics/mechanics/sim.py:211,249 | One Mana node gets separate siphon and mark caps instead of one combined node cap. |

### N1 — separate mark owners incorrectly share an income bucket

**Minimal reproduction:** `mark-cap-distinct-towers`: two enemies, HP 10000, tile X=6 and 16. Apply mana3 mark to enemy 0 from tower 0 and enemy 1 from tower 1. At t=0 deal 20 physical damage to each. Each takes 18 HP damage and generates 3.6 mana, below its G3 cap of 6. Expected independent-node income **7.2**. Python, Godot grid and replay each return **6.3**. The second source sees only 2.4 room, yielding 2.4+1.2×0.25=2.7. Same-tower control correctly returns 6.3. The runtime key is mark|op.uid; reference key is (mark, op.uid). Compiler UIDs repeat across identical tower recipes. This is separate from the pre-existing same-status-on-one-enemy design question: these marks are on different enemies ten tiles apart.

### N2 — multiple siphon producers collapse into the first producer

**Minimal reproduction:** `siphon-two-nodes`: one HP-10000 enemy at X=6; hit once with `fire1{fire_hit:[mana1,mana1]}`. Resolved HP damage is **13.2525**. Each distinct donor UID has siphon 0.42, so raw income is **5.56605 per node**. Independent G1 caps yield 2×(2.5+(5.56605−2.5)×0.25)=**6.533025**. All implementations return **4.658025**, applying one cap to combined raw 11.1321. Source code selects the first siphon's UID/grade. No proposed correction is applied by this harness.

### N3 — one Mana producer has independent siphon and mark caps

**Minimal reproduction:** `cap-shared-node-channels`: one HP-10000 enemy at X=6, two native mana3 hits from tower 0 at t=0. Each hit removes 9 HP. Siphon raw is 13.5 total; the mark applied by the first hit adds 1.8 on the second. One producing G3 node should cap combined raw 15.3 at 6 + (15.3−6)×0.25 = **8.325**. All implementations instead pay siphon **7.875** plus mark **1.8**, total **9.675**. Siphon and mark use distinct ability/channel keys, so they never consume one shared node bucket. This is a rule violation against DECISIONS.md per-producing-Mana-node cap, not a claim of Godot/Python disagreement.

### Repaired B1 / B2 / B3 — exact original probes

| Probe / metric | Python before → after | Godot grid before → after | Godot replay before → after | Status |
|---|---|---|---|---|
| push-chain-stale-position / damage | 18 → 18 | 29.91645 → 18 | 18 → 18 | fixed |
| push-chain-stale-position / hops | 0 → 0 | 2 → 0 | 0 → 0 | fixed |
| trail-spurious-cell-drop / fields | 0 → 0 | 1 → 0 | 1 → 0 | fixed |
| siphon-lethal-mana1 / mana_siphon | 0 → 0.6 | 2.43 → 0.6 | 2.43 → 0.6 | fixed |
| siphon-lethal-mana1 / mana | 2 → 2.6 | 4.43 → 2.6 | 4.43 → 2.6 | fixed |
| siphon-lethal-mana3 / mana_siphon | 0 → 0.75 | 6.75 → 0.75 | 6.75 → 0.75 | fixed |
| siphon-lethal-mana3 / mana | 2 → 2.75 | 8.75 → 2.75 | 8.75 → 2.75 | fixed |

B1: native combat.gd:341 calls enemy.gd:108 sync_position immediately after movement; the original 2.35-tile post-push gap now yields zero unintended hops. B2: combat.gd:202 initializes last_drop with _cellv; moving 6.25→6.26 stays in cell 6 and creates no trail. Control 6.49→6.51 still creates one grid trail. B3: sim.py:195 now breaks instead of returning before payout. Lethal mana1/mana3 pay 0.6/0.75 for the one HP actually removed; old Godot payouts 2.43/6.75 included overkill. All retain one kill and one stone.

## Targeted probe results

Native field/tower probes: **16/16** (results/feature-probes.json). Field cap 8; first fid 1 survives dictionary mutation and merge; eviction and expiry clear real VFX lookups. One meteor callback deals 14.4 in its unchanged control and 0 after native rune clear; two lava callbacks deal 70.2 in control and 0 after clear. Generation increases and summon state clears. These are process/state checks, not rendered acceptance.

| Probe / metric | Python | Godot grid | Godot replay | Interpretation |
|---|---:|---:|---:|---|
| summon-loop-volcano / host_attacks | 8 | 8 | 8 | Repeated native host attacks |
| summon-loop-golem / host_attacks | 18 | 17 | 18 | Repeated native host attacks |
| summon-loop-hive / host_attacks | 62 | 61 | 62 | Repeated native host attacks |
| same-status-two-towers / status_instances | 1 | 1 | 1 | Shared refresh, not independent stacking |
| forced-move-bleed / bleed_forced | 1.225 | 1.1025 | 1.1025 | Counter definitions differ; see limits |
| frozen-death-shards / shards | 1 | 1 | 1 | Death propagation |
| siphon-tick / mana_siphon | 1.550745 | 1.550745 | 1.550745 | Tick income unchanged |
| mark-economics / mana_mark | 9.21 | 9.21 | 9.21 | Overkill excluded |
| mark-economics / stones | 3 | 3 | 3 | One crystal bonus |
| budget-dense-64 / max_budget_used | 16 | 16 | 16 | Application cap exercised |
| cap-same-node / mana_siphon | 3.09 | 3.09 | 3.09 | 2.5 cap, excess ×0.25 |
| cap-distinct-towers / mana_siphon | 4.86 | 4.86 | 4.86 | Independent siphon owners |
| cap-next-second / mana_siphon | 4.86 | 4.86 | 4.86 | Integer-second reset |
| mark-cap-distinct-towers / mana_mark | 6.3 | 6.3 | 6.3 | N1: expected 7.2 |
| mark-cap-same-tower / mana_mark | 6.3 | 6.3 | 6.3 | Control: expected 6.3 |
| siphon-two-nodes / mana_siphon | 4.658025 | 4.658025 | 4.658025 | N2: expected 6.533025 |
| cap-shared-node-channels / mana | 9.675 | 9.675 | 9.675 | N3: expected 8.325 |
| mark-overkill / mana_mark | 0.3 | 0.3 | 0.3 | Only 1 HP converted |
| crystal-single-mark / stones | 3 | 3 | 3 | 1 normal + 2 crystal |
| crystal-two-marks / stones | 3 | 3 | 3 | 1 normal + 2 crystal, not 5 |

All six sibling permutations remain identical within each implementation. Depth-3/4 grafts terminate. Receiver locks reject with locked_on_receiver. Two identical fire3 burns from different towers still store one instance and one 2.7-damage tick owned by the first tower (combat.gd:184; sim.py:306). This pre-existing shared behavior remains an open design decision in DECISIONS.md.

Verification: **1233/1233 checks passed**. Full records: results/verification.json. Known N1/N2/N3 contract probes are reported findings, not claims that their intended values pass. Repeat determinism and unchanged clone/source-copy receipts are in validation/repeat-verification.json.

## Scenario tables

Every original case and added control follows. Absent dictionary entries are zero. Per-root histograms exclude empty roots. Full raw state and root records are retained in results/python.json and results/godot.json.

### v4-01 (scenario)

Recipes: `fire3{burn:[electric1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 174.483 | 158.283 | -9.285% | 158.283 | -9.285% | expected structural difference: E1, E3, E2 |
| damage_capped | 174.483 | 158.283 | -9.285% | 158.283 | -9.285% | expected structural difference: E1, E3, E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | expected structural difference: E1, E3, E2 |
| by_element.electric | 27.783 | 27.783 | 0% | 27.783 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |

### v4-02 (scenario)

Recipes: `fire3{fire_hit:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 378.944392 | 334.844393 | -11.638% | 333.044393 | -12.113% | expected structural difference: E1, E3, E2 |
| damage_capped | 378.944392 | 334.844393 | -11.638% | 333.044393 | -12.113% | expected structural difference: E1, E3, E2 |
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
| applications | 165 | 114 | -30.909% | 112 | -32.121% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 14 | 14 | 0% | 14 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 14 | 14 | 0% | 14 | 0% | equal |
| by_element.fire | 305.64909 | 261.54909 | -14.428% | 259.74909 | -15.017% | expected structural difference: E1, E3, E2 |
| by_element.electric | 73.295302 | 73.295303 | 0% | 73.295303 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 21 | 21 | 0% | 21 | 0% | equal |
| hops.mermi sekerek | 14 | 14 | 0% | 14 | 0% | equal |
| fields.fire_trail | 98 | 12 | -87.755% | 11 | -88.776% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 137 | 86 | -37.226% | 84 | -38.686% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 130 | 79 | -39.231% | 77 | -40.769% | expected structural difference: E1, E3, E2 |
| roots.using_5_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-03 (scenario)

Recipes: `fire3{burn:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 331.853121 | 296.753121 | -10.577% | 296.753121 | -10.577% | expected structural difference: E1, E3, E2 |
| damage_capped | 331.853121 | 296.753121 | -10.577% | 296.753121 | -10.577% | expected structural difference: E1, E3, E2 |
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
| applications | 155 | 116 | -25.161% | 116 | -25.161% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 16 | 16 | 0% | 16 | 0% | equal |
| status_instances | 4 | 3 | -25.000% | 4 | 0% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.fire | 243 | 207.9 | -14.444% | 207.9 | -14.444% | expected structural difference: E1, E3, E2 |
| by_element.electric | 88.853121 | 88.853121 | 0% | 88.853121 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 23 | 23 | 0% | 23 | 0% | equal |
| hops.durum yandakine atlayarak | 16 | 16 | 0% | 16 | 0% | equal |
| fields.fire_trail | 89 | 13 | -85.393% | 13 | -85.393% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 123 | 84 | -31.707% | 84 | -31.707% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 115 | 76 | -33.913% | 76 | -33.913% | expected structural difference: E1, E3, E2 |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |

### v4-04 (scenario)

Recipes: `fire3{burn:[electric3{chain:[ice2]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 321.965492 | 305.765492 | -5.032% | 305.765492 | -5.032% | expected structural difference: E1, E3, E2 |
| damage_capped | 321.965492 | 305.765492 | -5.032% | 305.765492 | -5.032% | expected structural difference: E1, E3, E2 |
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
| applications | 130 | 112 | -13.846% | 112 | -13.846% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 32 | 32 | 0% | 32 | 0% | equal |
| status_instances | 7 | 6 | -14.286% | 7 | 0% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.fire | 220.5 | 204.3 | -7.347% | 204.3 | -7.347% | expected structural difference: E1, E3, E2 |
| by_element.electric | 88.853121 | 88.853121 | 0% | 88.853121 | 0% | tolerance (floating arithmetic) |
| by_element.ice | 12.612371 | 12.612371 | 0% | 12.612371 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 23 | 23 | 0% | 23 | 0% | equal |
| statuses.slow | 16 | 16 | 0% | 16 | 0% | equal |
| hops.durum yandakine atlayarak | 16 | 16 | 0% | 16 | 0% | equal |
| fields.fire_trail | 82 | 13 | -84.146% | 13 | -84.146% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 98 | 80 | -18.367% | 80 | -18.367% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 90 | 72 | -20.000% | 72 | -20.000% | expected structural difference: E1, E3, E2 |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |

### v4-05 (scenario)

Recipes: `fire5{burn:[electric3,poison2,blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 651.186795 | 683.646091 | +4.985% | 679.846326 | +4.401% | expected structural difference: E1, E3, E2 |
| damage_capped | 621.6 | 662.35399 | +6.556% | 662.19649 | +6.531% | expected structural difference: E1, E3, E2 |
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
| applications | 134 | 131 | -2.239% | 127 | -5.224% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 58 | 88 | +51.724% | 80 | +37.931% | expected structural difference: E1, E3, E2 |
| status_instances | 11 | 18 | +63.636% | 18 | +63.636% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 12 | +100.000% | 10 | +66.667% | expected structural difference: E1, E3, E2 |
| by_element.fire | 319.05 | 292.95 | -8.181% | 292.5 | -8.322% | expected structural difference: E1, E3, E2 |
| by_element.electric | 50.684295 | 72.703591 | +43.444% | 69.038826 | +36.213% | expected structural difference: E1, E3, E2 |
| by_element.blood | 96.075 | 110.0925 | +14.590% | 110.4075 | +14.918% | expected structural difference: E1, E3, E2 |
| by_element.poison | 185.3775 | 207.9 | +12.150% | 207.9 | +12.150% | expected structural difference: E1, E3, E2 |
| statuses.burn | 11 | 16 | +45.455% | 15 | +36.364% | expected structural difference: E1, E3, E2 |
| statuses.poison | 27 | 40 | +48.148% | 37 | +37.037% | expected structural difference: E1, E3, E2 |
| statuses.bleed | 27 | 40 | +48.148% | 37 | +37.037% | expected structural difference: E1, E3, E2 |
| hops.durum yandakine atlayarak | 6 | 12 | +100.000% | 10 | +66.667% | expected structural difference: E1, E3, E2 |
| fields.fire_trail | 56 | 9 | -83.929% | 9 | -83.929% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 122 | 107 | -12.295% | 107 | -12.295% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 119 | 101 | -15.126% | 102 | -14.286% | expected structural difference: E1, E3, E2 |
| roots.using_5_applications | 3 | 6 | +100.000% | 5 | +66.667% | expected structural difference: E1, E3, E2 |

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
| damage | 110.889 | 111.114 | +0.203% | 110.889 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| damage_capped | 110.889 | 111.114 | +0.203% | 110.889 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
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
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | expected structural difference: E1, E3; tolerance (floating arithmetic) |
| by_element.water | 45.864 | 45.864 | 0% | 45.864 | 0% | tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.wet | 14 | 14 | 0% | 14 | 0% | equal |
| roots.with_applications | 21 | 21 | 0% | 21 | 0% | equal |
| roots.using_1_applications | 21 | 21 | 0% | 21 | 0% | equal |

### v4-09 (scenario)

Recipes: `fire3`, `water4{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 278.89875 | 298.20375 | +6.922% | 262.96875 | -5.712% | expected structural difference: E1, E3, E2 |
| damage_capped | 258 | 296.80125 | +15.039% | 248.1 | -3.837% | expected structural difference: E1, E3, E2 |
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
| applications | 43 | 46 | +6.977% | 37 | -13.953% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 4 | 9 | +125.000% | 5 | +25.000% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 3.825 | 4.725 | +23.529% | 3.825 | 0% | expected structural difference: E1, E3, E2 |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 14 | 0% | 14 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 112.5 | 123.3 | +9.600% | 97.2 | -13.600% | expected structural difference: E1, E3, E2 |
| by_element.water | 126 | 126 | 0% | 126 | 0% | equal |
| by_element.blood | 40.39875 | 48.90375 | +21.053% | 39.76875 | -1.559% | expected structural difference: E1, E3, E2 |
| statuses.burn | 6 | 7 | +16.667% | 6 | 0% | expected structural difference: E1, E3, E2 |
| statuses.wet | 6 | 7 | +16.667% | 6 | 0% | expected structural difference: E1, E3, E2 |
| statuses.bleed | 6 | 7 | +16.667% | 6 | 0% | expected structural difference: E1, E3, E2 |
| fields.fire_trail | 20 | 11 | -45.000% | 7 | -65.000% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 43 | 46 | +6.977% | 37 | -13.953% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 43 | 46 | +6.977% | 37 | -13.953% | expected structural difference: E1, E3, E2 |

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
| damage | 468.820403 | 444.574614 | -5.172% | 478.165449 | +1.993% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 468.813379 | 444.574614 | -5.170% | 478.165449 | +1.995% | expected structural difference: E1, E3, E2, E4 |
| kills | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| mana | 2 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 8 | 6 | -25.000% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| applications | 124 | 103 | -16.935% | 115 | -7.258% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 41 | 40 | -2.439% | 47 | +14.634% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 5 | 6 | +20.000% | 6 | +20.000% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 16 | +6.667% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 283.365922 | 275.23134 | -2.871% | 287.65134 | +1.512% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 86.241802 | 83.76606 | -2.871% | 87.54606 | +1.512% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 73.930148 | 62.239494 | -15.813% | 72.823494 | -1.497% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 25.28253 | 23.33772 | -7.692% | 30.144555 | +19.231% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 15 | 16 | +6.667% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 26 | 24 | -7.692% | 31 | +19.231% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 16 | +6.667% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 61 | 8 | -86.885% | 13 | -78.689% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 84 | 63 | -25.000% | 73 | -13.095% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 76 | 55 | -27.632% | 65 | -14.474% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 6 | 8 | +33.333% | 7 | +16.667% | expected structural difference: E1, E3, E2, E4 |
| roots.using_8_applications | 1 | 0 | -100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |

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
| damage | 234.36 | 181.8 | -22.427% | 221.13 | -5.645% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 234.03 | 179.58 | -23.266% | 219.54 | -6.192% | expected structural difference: E1, E3, E2, E4 |
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
| applications | 49 | 26 | -46.939% | 31 | -36.735% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 138.6 | 118.8 | -14.286% | 138.6 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| by_element.fire | 95.76 | 63 | -34.211% | 82.53 | -13.816% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 8 | 5 | -37.500% | 7 | -12.500% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 27 | 7 | -74.074% | 9 | -66.667% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 49 | 26 | -46.939% | 31 | -36.735% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 49 | 26 | -46.939% | 31 | -36.735% | expected structural difference: E1, E3, E2, E4 |

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
| damage | 399.6 | 288.45 | -27.815% | 284.4 | -28.829% | expected structural difference: E1, E3, E2 |
| damage_capped | 399.6 | 286.05 | -28.416% | 282 | -29.429% | expected structural difference: E1, E3, E2 |
| kills | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2 |
| mana | 0 | 2 | new (ref=0) | 2 | new (ref=0) | expected structural difference: E1, E3, E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 129 | 74 | -42.636% | 73 | -43.411% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 6 | 9 | +50.000% | 9 | +50.000% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 308.25 | 209.7 | -31.971% | 205.65 | -33.285% | expected structural difference: E1, E3, E2 |
| by_element.poison | 91.35 | 78.75 | -13.793% | 78.75 | -13.793% | expected structural difference: E1, E3, E2 |
| statuses.burn | 7 | 6 | -14.286% | 6 | -14.286% | expected structural difference: E1, E3, E2 |
| statuses.poison | 78 | 30 | -61.538% | 30 | -61.538% | expected structural difference: E1, E3, E2 |
| fields.fire_trail | 44 | 10 | -77.273% | 10 | -77.273% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 129 | 74 | -42.636% | 73 | -43.411% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 129 | 74 | -42.636% | 73 | -43.411% | expected structural difference: E1, E3, E2 |

### v4-22 (scenario)

Recipes: `volcano5{lava_blob:[fire3,electric3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

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
| damage | 129.672 | 166.986 | +28.776% | 170.352 | +31.371% | expected structural difference: E1, E3, E2 |
| damage_capped | 129.672 | 166.986 | +28.776% | 170.352 | +31.371% | expected structural difference: E1, E3, E2 |
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
| applications | 29 | 48 | +65.517% | 49 | +68.966% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 7 | +250.000% | 7 | +250.000% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 120.6 | 134.1 | +11.194% | 138.6 | +14.925% | expected structural difference: E1, E3, E2 |
| by_element.ice | 9.072 | 32.886 | +262.500% | 31.752 | +250.000% | expected structural difference: E1, E3, E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.slow | 8 | 29 | +262.500% | 28 | +250.000% | expected structural difference: E1, E3, E2 |
| fields.fire_trail | 38 | 8 | -78.947% | 8 | -78.947% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 29 | 48 | +65.517% | 49 | +68.966% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 29 | 48 | +65.517% | 49 | +68.966% | expected structural difference: E1, E3, E2 |

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
| damage | 160.5915 | 144.3915 | -10.088% | 144.3915 | -10.088% | expected structural difference: E1, E3, E2 |
| damage_capped | 160.5915 | 144.3915 | -10.088% | 144.3915 | -10.088% | expected structural difference: E1, E3, E2 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 20.357078 | 20.357077 | 0% | 20.357077 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 20.357078 | 20.357077 | 0% | 20.357077 | 0% | tolerance (floating arithmetic) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | expected structural difference: E1, E3, E2 |
| by_element.arcane | 13.8915 | 13.8915 | 0% | 13.8915 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |

### mana-mark (scenario)

Recipes: `mana3`, `stone3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 246.3 | 246.3 | 0% | 246.3 | 0% | equal |
| damage_capped | 231.5 | 231.5 | 0% | 231.5 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 84.745 | 84.745 | 0% | 84.745 | 0% | equal |
| mana_siphon | 50.625 | 50.625 | 0% | 50.625 | 0% | equal |
| mana_mark | 32.12 | 32.12 | 0% | 32.12 | 0% | equal |
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
| damage | 742.2 | 699.1 | -5.807% | 690.6 | -6.952% | expected structural difference: E1, E3, E2 |
| damage_capped | 666.4 | 641.5 | -3.736% | 633 | -5.012% | expected structural difference: E1, E3, E2 |
| kills | 4 | 4 | 0% | 4 | 0% | equal |
| mana | 209.1375 | 207.03 | -1.008% | 206.4675 | -1.277% | expected structural difference: E1, E3, E2 |
| mana_siphon | 109.45 | 109.45 | 0% | 109.45 | 0% | tolerance (floating arithmetic) |
| mana_mark | 91.6875 | 89.58 | -2.299% | 89.0175 | -2.912% | expected structural difference: E1, E3, E2 |
| stones | 12 | 12 | 0% | 12 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 99 | 75 | -24.242% | 72 | -27.273% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 22 | 22 | 0% | 22 | 0% | equal |
| status_instances | 17 | 17 | 0% | 17 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 21 | 21 | 0% | 21 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 11 | 11 | 0% | 11 | 0% | equal |
| by_element.arcane | 173.8 | 173.8 | 0% | 173.8 | 0% | equal |
| by_element.fire | 263.9 | 220.8 | -16.332% | 212.3 | -19.553% | expected structural difference: E1, E3, E2 |
| by_element.physical | 304.5 | 304.5 | 0% | 304.5 | 0% | equal |
| statuses.mana_mark | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.burn | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.shred | 12 | 12 | 0% | 12 | 0% | equal |
| statuses.stun | 12 | 12 | 0% | 12 | 0% | equal |
| hops.parça | 11 | 11 | 0% | 11 | 0% | equal |
| fields.fire_trail | 22 | 8 | -63.636% | 7 | -68.182% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 77 | 53 | -31.169% | 50 | -35.065% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 72 | 48 | -33.333% | 45 | -37.500% | expected structural difference: E1, E3, E2 |
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
| damage | 217.701 | 190.1295 | -12.665% | 191.0295 | -12.251% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 213.7575 | 187.6575 | -12.210% | 188.5575 | -11.789% | expected structural difference: E1, E3, E2, E4 |
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
| applications | 58 | 35 | -39.655% | 36 | -37.931% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 124.2 | -15.337% | 125.1 | -14.724% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 71.001 | 65.9295 | -7.143% | 65.9295 | -7.143% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 58 | 35 | -39.655% | 36 | -37.931% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 58 | 35 | -39.655% | 36 | -37.931% | expected structural difference: E1, E3, E2, E4 |

### rej-pierce-tick (scenario)

Recipes: `fire3{burn:[light3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 186.831 | 170.631 | -8.671% | 170.631 | -8.671% | expected structural difference: E1, E3, E2 |
| damage_capped | 186.831 | 170.631 | -8.671% | 170.631 | -8.671% | expected structural difference: E1, E3, E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 11 | 11 | 0% | 11 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | expected structural difference: E1, E3, E2 |
| by_element.light | 40.131 | 40.131 | 0% | 40.131 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.blind | 14 | 14 | 0% | 14 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |

### stress-24 (scenario)

Recipes: `fire5{fire_hit:[electric5{chain:[ice5{chill:[poison5,blood5]},stone3]},meteor3],burn:[electric3{chain:[ice2,water3]},poison4{poison_tick:[blood2]}],fire_trail:[ice3{freeze:[light3]},hive1,golem1,volcano2{lava_blob:[fire2,water2{wet:[electric2,poison1]}]},stone2{armor_shred:[light2]},blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 739.359243 | 758.250325 | +2.555% | 744.451868 | +0.689% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 720 | 720 | 0% | 720 | 0% | tolerance (floating arithmetic) |
| kills | 6 | 6 | 0% | 6 | 0% | equal |
| mana | 12 | 12 | 0% | 12 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 6 | 6 | 0% | 6 | 0% | equal |
| frozen | 5 | 3 | -40.000% | 3 | -40.000% | expected structural difference: E1, E3, E2, E4 |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 13 | 13 | 0% | 13 | 0% | equal |
| applications | 142 | 134 | -5.634% | 139 | -2.113% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 216 | 180 | -16.667% | 175 | -18.981% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 78 | 90 | +15.385% | 73 | -6.410% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 1.004457 | 1.004457 | 0% | 1.004457 | 0% | tolerance (floating arithmetic) |
| seconds | 5.65 | 7.15 | +26.549% | 12.4 | +119.469% | expected structural difference: E1, E3, E2, E4 |
| host_attacks | 3 | 4 | +33.333% | 3 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 24 | 27 | +12.500% | 25 | +4.167% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 175.141431 | 189.015992 | +7.922% | 133.575992 | -23.732% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 114.162571 | 131.722356 | +15.381% | 107.222636 | -6.079% | expected structural difference: E1, E3, E2, E4 |
| by_element.impact | 77.115924 | 115.71338 | +50.051% | 78.54786 | +1.857% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 44.940139 | 36.69146 | -18.355% | 32.806779 | -26.999% | expected structural difference: E1, E3, E2, E4 |
| by_element.physical | 61.310592 | 44.914634 | -26.742% | 41.627597 | -32.104% | expected structural difference: E1, E3, E2, E4 |
| by_element.blood | 44.484046 | 49.9505 | +12.289% | 73.391785 | +64.985% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 42.547974 | 28.212534 | -33.692% | 28.212534 | -33.692% | expected structural difference: E1, E3, E2, E4 |
| by_element.water | 21.950686 | 18.551146 | -15.487% | 18.551146 | -15.487% | expected structural difference: E1, E3, E2, E4 |
| by_element.light | 71.05 | 47.63192 | -32.960% | 47.63192 | -32.960% | expected structural difference: E1, E3, E2, E4 |
| by_element.poison | 86.655879 | 95.846403 | +10.606% | 182.883619 | +111.046% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 30 | 30 | 0% | 27 | -10.000% | expected structural difference: E1, E3, E2, E4 |
| statuses.charge | 9 | 12 | +33.333% | 9 | 0% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 28 | 24 | -14.286% | 23 | -17.857% | expected structural difference: E1, E3, E2, E4 |
| statuses.poison | 52 | 48 | -7.692% | 46 | -11.538% | expected structural difference: E1, E3, E2, E4 |
| statuses.bleed | 24 | 19 | -20.833% | 22 | -8.333% | expected structural difference: E1, E3, E2, E4 |
| statuses.cold | 20 | 16 | -20.000% | 15 | -25.000% | expected structural difference: E1, E3, E2, E4 |
| statuses.shred | 20 | 16 | -20.000% | 15 | -25.000% | expected structural difference: E1, E3, E2, E4 |
| statuses.blind | 18 | 13 | -27.778% | 13 | -27.778% | expected structural difference: E1, E3, E2, E4 |
| statuses.wet | 21 | 18 | -14.286% | 18 | -14.286% | expected structural difference: E1, E3, E2, E4 |
| hops.mermi sekerek | 6 | 7 | +16.667% | 6 | 0% | expected structural difference: E1, E3, E2, E4 |
| hops.parça | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| hops.durum yandakine geçerek | 9 | 10 | +11.111% | 10 | +11.111% | expected structural difference: E1, E3, E2, E4 |
| hops.durum yandakine atlayarak | 8 | 8 | 0% | 8 | 0% | equal |
| fields.fire_trail | 16 | 3 | -81.250% | 3 | -81.250% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 51 | 44 | -13.725% | 56 | +9.804% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 28 | 23 | -17.857% | 36 | +28.571% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 3 | 4 | +33.333% | 4 | +33.333% | expected structural difference: E1, E3, E2, E4 |
| roots.using_3_applications | 3 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 2 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 11 | 11 | 0% | 11 | 0% | equal |
| roots.using_6_applications | 2 | 3 | +50.000% | 3 | +50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_11_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_13_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_8_applications | 0 | 1 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_9_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

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
| damage | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | expected structural difference: E1, E3, E2 |
| damage_capped | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | expected structural difference: E1, E3, E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | expected structural difference: E1, E3, E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | expected structural difference: E1, E3, E2 |

### plain-fire5 (plain)

Recipes: `fire5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 308.25 | 221.4 | -28.175% | 219.15 | -28.905% | expected structural difference: E1, E3, E2 |
| damage_capped | 308.25 | 219.9 | -28.662% | 217.65 | -29.392% | expected structural difference: E1, E3, E2 |
| kills | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2 |
| mana | 0 | 2 | new (ref=0) | 2 | new (ref=0) | expected structural difference: E1, E3, E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 100 | 52 | -48.000% | 52 | -48.000% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 3 | +50.000% | 3 | +50.000% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 308.25 | 221.4 | -28.175% | 219.15 | -28.905% | expected structural difference: E1, E3, E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 44 | 10 | -77.273% | 10 | -77.273% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 100 | 52 | -48.000% | 52 | -48.000% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 100 | 52 | -48.000% | 52 | -48.000% | expected structural difference: E1, E3, E2 |

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
| mana | 58.5 | 58.5 | 0% | 58.5 | 0% | equal |
| mana_siphon | 49.5 | 49.5 | 0% | 49.5 | 0% | equal |
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
| mana | 147.18 | 147.18 | 0% | 147.18 | 0% | equal |
| mana_siphon | 105.6 | 105.6 | 0% | 105.6 | 0% | tolerance (floating arithmetic) |
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
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

### shuffle-1 (probe)

Recipes: `volcano5{lava_blob:[fire3,ice2,electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

### shuffle-2 (probe)

Recipes: `volcano5{lava_blob:[electric3,fire3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

### shuffle-3 (probe)

Recipes: `volcano5{lava_blob:[electric3,ice2,fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

### shuffle-4 (probe)

Recipes: `volcano5{lava_blob:[ice2,fire3,electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

### shuffle-5 (probe)

Recipes: `volcano5{lava_blob:[ice2,electric3,fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | expected structural difference: E1, E3, E2, E4 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | expected structural difference: E1, E3, E2, E4 |
| kills | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | expected structural difference: E1, E3, E2, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | expected structural difference: E1, E3, E2, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | expected structural difference: E1, E3, E2, E4 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | expected structural difference: E1, E3, E2, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | expected structural difference: E1, E3, E2, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | expected structural difference: E1, E3, E2, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | expected structural difference: E1, E3, E2, E4 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | expected structural difference: E1, E3, E2, E4 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | expected structural difference: E1, E3, E2, E4 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | expected structural difference: E1, E3, E2, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | expected structural difference: E1, E3, E2, E4 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | expected structural difference: E1, E3, E2, E4 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | expected structural difference: E1, E3, E2, E4 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | expected structural difference: E1, E3, E2, E4 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | expected structural difference: E1, E3, E2, E4 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | expected structural difference: E1, E3, E2, E4 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | expected structural difference: E1, E3, E2, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2, E4 |

### deep3 (probe)

Recipes: `fire5{burn:[electric5{chain:[ice5{freeze:[poison4]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 718.232006 | 745.055773 | +3.735% | 701.862806 | -2.279% | expected structural difference: E1, E3, E2 |
| damage_capped | 693.09294 | 718.296095 | +3.636% | 688.125635 | -0.717% | expected structural difference: E1, E3, E2 |
| kills | 5 | 5 | 0% | 4 | -20.000% | expected structural difference: E1, E3, E2 |
| mana | 10 | 10 | 0% | 8 | -20.000% | expected structural difference: E1, E3, E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 5 | 0% | 4 | -20.000% | expected structural difference: E1, E3, E2 |
| frozen | 15 | 15 | 0% | 15 | 0% | equal |
| nova_frozen | 10 | 10 | 0% | 10 | 0% | equal |
| shards | 2 | 1 | -50.000% | 2 | 0% | expected structural difference: E1, E3, E2 |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 9 | 9 | 0% | 9 | 0% | equal |
| applications | 156 | 158 | +1.282% | 153 | -1.923% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 137 | 133 | -2.920% | 137 | 0% | expected structural difference: E1, E3, E2 |
| status_instances | 23 | 21 | -8.696% | 23 | 0% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 27 | 24 | -11.111% | 27 | 0% | expected structural difference: E1, E3, E2 |
| by_element.fire | 350.1 | 364.05 | +3.985% | 329.85 | -5.784% | expected structural difference: E1, E3, E2 |
| by_element.electric | 257.991391 | 278.930937 | +8.116% | 260.637391 | +1.026% | expected structural difference: E1, E3, E2 |
| by_element.ice | 78.035815 | 65.030836 | -16.665% | 78.035815 | 0% | expected structural difference: E1, E3, E2; tolerance (floating arithmetic) |
| by_element.poison | 32.1048 | 37.044 | +15.385% | 33.3396 | +3.846% | expected structural difference: E1, E3, E2 |
| statuses.burn | 30 | 28 | -6.667% | 30 | 0% | expected structural difference: E1, E3, E2 |
| statuses.charge | 61 | 62 | +1.639% | 61 | 0% | expected structural difference: E1, E3, E2 |
| statuses.slow | 24 | 22 | -8.333% | 24 | 0% | expected structural difference: E1, E3, E2 |
| statuses.cold | 24 | 22 | -8.333% | 24 | 0% | expected structural difference: E1, E3, E2 |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| hops.durum yandakine atlayarak | 24 | 22 | -8.333% | 24 | 0% | expected structural difference: E1, E3, E2 |
| hops.buz parçası düşer | 3 | 2 | -33.333% | 3 | 0% | expected structural difference: E1, E3, E2 |
| fields.fire_trail | 62 | 13 | -79.032% | 13 | -79.032% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 101 | 107 | +5.941% | 97 | -3.960% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 90 | 98 | +8.889% | 86 | -4.444% | expected structural difference: E1, E3, E2 |
| roots.using_2_applications | 2 | 0 | -100.000% | 1 | -50.000% | expected structural difference: E1, E3, E2 |
| roots.using_5_applications | 1 | 0 | -100.000% | 1 | 0% | expected structural difference: E1, E3, E2 |
| roots.using_6_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_9_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E1, E3, E2 |

### deep4 (probe)

Recipes: `fire5{burn:[electric5{chain:[ice5{freeze:[poison4{poison_tick:[blood2]}]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 720.427958 | 755.26366 | +4.835% | 708.159879 | -1.703% | expected structural difference: E1, E3, E2 |
| damage_capped | 693.09294 | 720 | +3.882% | 692.569428 | -0.076% | expected structural difference: E1, E3, E2 |
| kills | 5 | 6 | +20.000% | 4 | -20.000% | expected structural difference: E1, E3, E2 |
| mana | 10 | 12 | +20.000% | 8 | -20.000% | expected structural difference: E1, E3, E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 4 | -20.000% | expected structural difference: E1, E3, E2 |
| frozen | 15 | 15 | 0% | 15 | 0% | equal |
| nova_frozen | 10 | 10 | 0% | 10 | 0% | equal |
| shards | 2 | 2 | 0% | 2 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 9 | 9 | 0% | 9 | 0% | equal |
| applications | 151 | 156 | +3.311% | 149 | -1.325% | expected structural difference: E1, E3, E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 141 | 146 | +3.546% | 146 | +3.546% | expected structural difference: E1, E3, E2 |
| status_instances | 26 | 24 | -7.692% | 26 | 0% | expected structural difference: E1, E3, E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 13.4 | -4.286% | 14 | 0% | expected structural difference: E1, E3, E2; tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 26 | 25 | -3.846% | 27 | +3.846% | expected structural difference: E1, E3, E2 |
| by_element.fire | 346.05 | 358.2 | +3.511% | 321.75 | -7.022% | expected structural difference: E1, E3, E2 |
| by_element.electric | 251.970087 | 276.284937 | +9.650% | 255.345391 | +1.340% | expected structural difference: E1, E3, E2 |
| by_element.ice | 72.527836 | 72.527836 | 0% | 76.139626 | +4.980% | tolerance (floating arithmetic); expected structural difference: E1, E3, E2 |
| by_element.poison | 32.1048 | 34.5744 | +7.692% | 37.044 | +15.385% | expected structural difference: E1, E3, E2 |
| by_element.blood | 17.775235 | 13.676487 | -23.059% | 17.880863 | +0.594% | expected structural difference: E1, E3, E2 |
| statuses.burn | 28 | 28 | 0% | 29 | +3.571% | expected structural difference: E1, E3, E2 |
| statuses.charge | 59 | 62 | +5.085% | 60 | +1.695% | expected structural difference: E1, E3, E2 |
| statuses.slow | 22 | 22 | 0% | 23 | +4.545% | expected structural difference: E1, E3, E2 |
| statuses.cold | 22 | 22 | 0% | 23 | +4.545% | expected structural difference: E1, E3, E2 |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 12 | 13 | +8.333% | 13 | +8.333% | expected structural difference: E1, E3, E2 |
| hops.durum yandakine atlayarak | 23 | 22 | -4.348% | 24 | +4.348% | expected structural difference: E1, E3, E2 |
| hops.buz parçası düşer | 3 | 3 | 0% | 3 | 0% | equal |
| fields.fire_trail | 62 | 13 | -79.032% | 13 | -79.032% | expected structural difference: E1, E3, E2 |
| roots.with_applications | 99 | 104 | +5.051% | 95 | -4.040% | expected structural difference: E1, E3, E2 |
| roots.using_1_applications | 88 | 94 | +6.818% | 84 | -4.545% | expected structural difference: E1, E3, E2 |
| roots.using_2_applications | 3 | 1 | -66.667% | 2 | -33.333% | expected structural difference: E1, E3, E2 |
| roots.using_6_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_9_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 0 | 1 | new (ref=0) | 0 | 0% | expected structural difference: E1, E3, E2 |
| roots.using_4_applications | 0 | 0 | 0% | 1 | new (ref=0) | expected structural difference: E1, E3, E2 |

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
| damage | 18 | 18 | 0% | 18 | 0% | equal |
| damage_capped | 18 | 18 | 0% | 18 | 0% | equal |
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
| pushed_tiles | 0.35 | 0.35 | 0% | 0.35 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.water | 11.7 | 11.7 | 0% | 11.7 | 0% | tolerance (floating arithmetic) |
| by_element.electric | 6.3 | 6.3 | 0% | 6.3 | 0% | equal |
| statuses.wet | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

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
| mana | 2.6 | 2.6 | 0% | 2.6 | 0% | equal |
| mana_siphon | 0.6 | 0.6 | 0% | 0.6 | 0% | equal |
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
| mana | 2.75 | 2.75 | 0% | 2.75 | 0% | equal |
| mana_siphon | 0.75 | 0.75 | 0% | 0.75 | 0% | equal |
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
| mana | 11.21 | 11.21 | 0% | 11.21 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 9.21 | 9.21 | 0% | 9.21 | 0% | equal |
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
| damage | 505.658879 | 505.658879 | 0% | 505.658879 | 0% | tolerance (floating arithmetic) |
| damage_capped | 505.658879 | 505.658879 | 0% | 505.658879 | 0% | tolerance (floating arithmetic) |
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
| applications | 74 | 74 | 0% | 74 | 0% | equal |
| rejected_events | 21 | 19 | -9.524% | 19 | -9.524% | expected structural difference: E2, E4 |
| spread_status | 87 | 87 | 0% | 87 | 0% | equal |
| status_instances | 15 | 15 | 0% | 15 | 0% | equal |
| pushed_tiles | 1.004457 | 1.004457 | 0% | 1.004457 | 0% | tolerance (floating arithmetic) |
| seconds | 4 | 4 | 0% | 4 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 13 | 13 | 0% | 13 | 0% | equal |
| by_element.fire | 119.209984 | 119.209984 | 0% | 119.209984 | 0% | equal |
| by_element.electric | 83.548363 | 83.548363 | 0% | 83.548363 | 0% | equal |
| by_element.impact | 58.683131 | 58.683131 | 0% | 58.683131 | 0% | tolerance (floating arithmetic) |
| by_element.ice | 13.322174 | 13.322174 | 0% | 13.322174 | 0% | tolerance (floating arithmetic) |
| by_element.physical | 5.502944 | 5.502944 | 0% | 5.502944 | 0% | tolerance (floating arithmetic) |
| by_element.water | 9.849226 | 9.849226 | 0% | 9.849226 | 0% | tolerance (floating arithmetic) |
| by_element.blood | 5.715385 | 5.715385 | 0% | 5.715385 | 0% | tolerance (floating arithmetic) |
| by_element.poison | 209.827672 | 209.827672 | 0% | 209.827672 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 15 | 15 | 0% | 15 | 0% | equal |
| statuses.charge | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.slow | 11 | 11 | 0% | 11 | 0% | equal |
| statuses.poison | 27 | 27 | 0% | 27 | 0% | equal |
| statuses.bleed | 17 | 17 | 0% | 17 | 0% | equal |
| statuses.cold | 3 | 3 | 0% | 3 | 0% | equal |
| statuses.shred | 3 | 3 | 0% | 3 | 0% | equal |
| statuses.wet | 8 | 8 | 0% | 8 | 0% | equal |
| hops.mermi sekerek | 3 | 3 | 0% | 3 | 0% | equal |
| hops.parça | 2 | 2 | 0% | 2 | 0% | equal |
| hops.durum yandakine atlayarak | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 43 | 43 | 0% | 43 | 0% | equal |
| roots.using_1_applications | 38 | 38 | 0% | 38 | 0% | equal |
| roots.using_5_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_16_applications | 1 | 1 | 0% | 1 | 0% | equal |

### cap-same-node (direct)

Actions: `[{"kind":"event","recipe":"mana1","target":0,"tower":0},{"kind":"event","recipe":"mana1","target":1,"tower":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| damage_capped | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 3.09 | 3.09 | 0% | 3.09 | 0% | equal |
| mana_siphon | 3.09 | 3.09 | 0% | 3.09 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 2 | 2 | 0% | 2 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| roots.with_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_1_applications | 2 | 2 | 0% | 2 | 0% | equal |

### cap-distinct-towers (direct)

Actions: `[{"kind":"event","recipe":"mana1","target":0,"tower":0},{"kind":"event","recipe":"mana1","target":1,"tower":1}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| damage_capped | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 4.86 | 4.86 | 0% | 4.86 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 4.86 | 4.86 | 0% | 4.86 | 0% | tolerance (floating arithmetic) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 2 | 2 | 0% | 2 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| roots.with_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_1_applications | 2 | 2 | 0% | 2 | 0% | equal |

### cap-next-second (direct)

Actions: `[{"kind":"event","recipe":"mana1","target":0,"tower":0},{"kind":"tick","dt":1},{"kind":"event","recipe":"mana1","target":1,"tower":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| damage_capped | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 4.86 | 4.86 | 0% | 4.86 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 4.86 | 4.86 | 0% | 4.86 | 0% | tolerance (floating arithmetic) |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 2 | 2 | 0% | 2 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 1 | 1 | 0% | 1 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 8.1 | 8.1 | 0% | 8.1 | 0% | equal |
| roots.with_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_1_applications | 2 | 2 | 0% | 2 | 0% | equal |

### mark-cap-distinct-towers (direct)

Actions: `[{"kind":"position","target":0,"value":6},{"kind":"position","target":1,"value":16},{"kind":"status","recipe":"mana3","status":"mana_mark","target":0,"tower":0},{"kind":"status","recipe":"mana3","status":"mana_mark","target":1,"tower":1},{"kind":"damage","target":0,"amount":20,"element":"physical"},{"kind":"damage","target":1,"amount":20,"element":"physical"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 36 | 36 | 0% | 36 | 0% | equal |
| damage_capped | 36 | 36 | 0% | 36 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 6.3 | 6.3 | 0% | 6.3 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 6.3 | 6.3 | 0% | 6.3 | 0% | tolerance (floating arithmetic) |
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
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 36 | 36 | 0% | 36 | 0% | equal |
| statuses.mana_mark | 2 | 2 | 0% | 2 | 0% | equal |
| roots.with_applications | 0 | 0 | 0% | 0 | 0% | equal |

### mark-cap-same-tower (direct)

Actions: `[{"kind":"position","target":0,"value":6},{"kind":"position","target":1,"value":16},{"kind":"status","recipe":"mana3","status":"mana_mark","target":0,"tower":0},{"kind":"status","recipe":"mana3","status":"mana_mark","target":1,"tower":0},{"kind":"damage","target":0,"amount":20,"element":"physical"},{"kind":"damage","target":1,"amount":20,"element":"physical"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 36 | 36 | 0% | 36 | 0% | equal |
| damage_capped | 36 | 36 | 0% | 36 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 6.3 | 6.3 | 0% | 6.3 | 0% | tolerance (floating arithmetic) |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 6.3 | 6.3 | 0% | 6.3 | 0% | tolerance (floating arithmetic) |
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
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 36 | 36 | 0% | 36 | 0% | equal |
| statuses.mana_mark | 2 | 2 | 0% | 2 | 0% | equal |
| roots.with_applications | 0 | 0 | 0% | 0 | 0% | equal |

### cap-shared-node-channels (direct)

Actions: `[{"kind":"event","recipe":"mana3","target":0},{"kind":"event","recipe":"mana3","target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 18 | 18 | 0% | 18 | 0% | equal |
| damage_capped | 18 | 18 | 0% | 18 | 0% | equal |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 9.675 | 9.675 | 0% | 9.675 | 0% | equal |
| mana_siphon | 7.875 | 7.875 | 0% | 7.875 | 0% | equal |
| mana_mark | 1.8 | 1.8 | 0% | 1.8 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 2 | 2 | 0% | 2 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.arcane | 18 | 18 | 0% | 18 | 0% | equal |
| statuses.mana_mark | 2 | 2 | 0% | 2 | 0% | equal |
| roots.with_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_1_applications | 2 | 2 | 0% | 2 | 0% | equal |

### siphon-two-nodes (direct)

Actions: `[{"kind":"event","recipe":"fire1{fire_hit:[mana1,mana1]}","tower":0,"target":0}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 13.2525 | 13.2525 | 0% | 13.2525 | 0% | tolerance (floating arithmetic) |
| damage_capped | 13.2525 | 13.2525 | 0% | 13.2525 | 0% | tolerance (floating arithmetic) |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 4.658025 | 4.658025 | 0% | 4.658025 | 0% | equal |
| mana_siphon | 4.658025 | 4.658025 | 0% | 4.658025 | 0% | equal |
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
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 9 | 9 | 0% | 9 | 0% | equal |
| by_element.arcane | 4.2525 | 4.2525 | 0% | 4.2525 | 0% | tolerance (floating arithmetic) |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_1_applications | 1 | 1 | 0% | 1 | 0% | equal |

### mark-overkill (direct)

Actions: `[{"kind":"status","recipe":"mana5","status":"mana_mark","tower":0,"repeat":1,"target":0},{"kind":"damage","target":0,"amount":1000,"element":"physical"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 900 | 900 | 0% | 900 | 0% | equal |
| damage_capped | 1 | 1 | 0% | 1 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2.3 | 2.3 | 0% | 2.3 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0.3 | 0.3 | 0% | 0.3 | 0% | equal |
| stones | 3 | 3 | 0% | 3 | 0% | equal |
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
| by_element.physical | 900 | 900 | 0% | 900 | 0% | equal |
| statuses.mana_mark | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 0 | 0 | 0% | 0 | 0% | equal |

### crystal-single-mark (direct)

Actions: `[{"kind":"status","recipe":"mana5","status":"mana_mark","tower":0,"repeat":1,"target":0},{"kind":"damage","target":0,"amount":1000,"element":"physical"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 900 | 900 | 0% | 900 | 0% | equal |
| damage_capped | 1 | 1 | 0% | 1 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2.3 | 2.3 | 0% | 2.3 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0.3 | 0.3 | 0% | 0.3 | 0% | equal |
| stones | 3 | 3 | 0% | 3 | 0% | equal |
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
| by_element.physical | 900 | 900 | 0% | 900 | 0% | equal |
| statuses.mana_mark | 1 | 1 | 0% | 1 | 0% | equal |
| roots.with_applications | 0 | 0 | 0% | 0 | 0% | equal |

### crystal-two-marks (direct)

Actions: `[{"kind":"status","recipe":"mana5","status":"mana_mark","tower":0,"repeat":1,"target":0},{"kind":"status","recipe":"fire1{fire_hit:[mana5]}","status":"mana_mark","tower":0,"repeat":1,"target":0},{"kind":"damage","target":0,"amount":1000,"element":"physical"}]`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 900 | 900 | 0% | 900 | 0% | equal |
| damage_capped | 1 | 1 | 0% | 1 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 2.3 | 2.3 | 0% | 2.3 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0.3 | 0.3 | 0% | 0.3 | 0% | equal |
| stones | 3 | 3 | 0% | 3 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 0 | 0 | 0% | 0 | 0% | equal |
| applications | 0 | 0 | 0% | 0 | 0% | equal |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 900 | 900 | 0% | 900 | 0% | equal |
| statuses.mana_mark | 2 | 2 | 0% | 2 | 0% | equal |
| roots.with_applications | 0 | 0 | 0% | 0 | 0% | equal |

### trail-real-crossing (direct)

Actions: `[{"kind":"position","target":0,"value":6.49},{"kind":"status","recipe":"fire3","status":"burn","tower":0,"repeat":1,"target":0},{"kind":"move","target":0,"dist":0.02,"forced":false}]`

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
| fields.fire_trail | 0 | 1 | new (ref=0) | 1 | new (ref=0) | expected structural difference: E2 |

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

## Commit delta: 6c65ef4 → 94a1c1a

The original 136 cases (99 combat) are compared on identical inputs; new controls are not counted as changed old cases. The original adapter/report-generator snapshots and results are preserved under validation/harness_6c65ef4/, results_6c65ef4/ and REPORT_6c65ef4.md. Every changed table/counter metric appears below; results/commit-deltas.json retains exact full precision, including arithmetic-only changes. results/raw-commit-deltas.json additionally enumerates every changed raw state/trace leaf, including enemy state, root application records, status UID/tower metadata and compiler structures.

| Stream | Old combat cases with material metric changes | Changed metrics | Damage equality before → after | All-metric equality before → after |
|---|---:|---:|---|---|
| Python | 8 | 18 | — | — |
| grid | 51 | 353 | 42 → 44 | 35 → 39 |
| replay | 49 | 305 | 67 → 67 | 57 → 60 |

Reasons distinguish revised economy and repaired movement/trails from new defects. No old Python non-economy metric should change; any such row is explicitly flagged Investigate. Godot damage/target/status/field/root changes can be coupled consequences of both repairs; this is source-diff/path attribution, not an experimental decomposition into one cause per changed number. No new compiler rejection or runaway budget is accepted.

| Stream / case | Metric | Before → after | Reason |
|---|---|---|---|
| Python / mana-graft | mana | 21.71043 → 20.357078 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-graft | mana_siphon | 21.71043 → 20.357078 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-mark | mana | 97.98 → 84.745 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-mark | mana_mark | 37.48 → 32.12 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-mark | mana_siphon | 58.5 → 50.625 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-crystal | mana | 306.81 → 209.1375 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-crystal | mana_mark | 125.01 → 91.6875 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mana-crystal | mana_siphon | 173.8 → 109.45 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / plain-mana3 | mana | 63 → 58.5 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / plain-mana3 | mana_siphon | 54 → 49.5 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / plain-mana5 | mana | 199.98 → 147.18 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / plain-mana5 | mana_siphon | 158.4 → 105.6 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / siphon-lethal-mana1 | mana | 2 → 2.6 | B3 payout fixed in Python; both engines now exclude overkill |
| Python / siphon-lethal-mana1 | mana_siphon | 0 → 0.6 | B3 payout fixed in Python; both engines now exclude overkill |
| Python / siphon-lethal-mana3 | mana | 2 → 2.75 | B3 payout fixed in Python; both engines now exclude overkill |
| Python / siphon-lethal-mana3 | mana_siphon | 0 → 0.75 | B3 payout fixed in Python; both engines now exclude overkill |
| Python / mark-economics | mana | 13.91 → 11.21 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| Python / mark-economics | mana_mark | 11.91 → 9.21 | Expected revised economy: lethal siphon + overkill exclusion + per-source soft cap; N1/N2/N3 source grouping remains shared |
| grid / budget-dense-64 | applications | 75 → 74 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | bleed_forced | 6.565835 → 5.715385 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | by_element.blood | 6.565835 → 5.715385 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | by_element.electric | 83.976924 → 83.548363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | by_element.ice | 13.417161 → 13.322174 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | by_element.poison | 221.364232 → 209.827672 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | by_element.water | 9.986428 → 9.849226 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | by_tower.0 | 518.70664 → 505.658879 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / budget-dense-64 | damage | 518.70664 → 505.658879 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | damage_capped | 518.70664 → 505.658879 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | roots.with_applications | 44 → 43 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | spread_status | 88 → 87 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | status_instances | 14 → 15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / budget-dense-64 | statuses.bleed | 18 → 17 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | applications | 164 → 158 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | by_element.electric | 268.724937 → 278.930937 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | by_element.fire | 376.65 → 364.05 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | by_element.ice | 72.527836 → 65.030836 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | by_element.poison | 33.3396 → 37.044 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | by_tower.0 | 751.242373 → 718.296095 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / deep3 | damage | 751.242373 → 745.055773 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | damage_capped | 720 → 718.296095 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | fields.fire_trail | 14 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | hops.buz parçası düşer | 3 → 2 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | hops.total | 25 → 24 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | kills | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | mana | 12 → 10 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| grid / deep3 | roots.using_1_applications | 102 → 98 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | roots.using_2_applications | 1 → 0 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | roots.with_applications | 112 → 107 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | seconds | 13.4 → 14 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | shards | 2 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | spread_status | 132 → 133 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | statuses.charge | 61 → 62 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep3 | stones | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | applications | 160 → 156 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | by_element.electric | 261.164937 → 276.284937 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | by_element.fire | 370.8 → 358.2 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | by_element.ice | 70.631646 → 72.527836 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | by_element.poison | 33.3396 → 34.5744 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | by_tower.0 | 749.61267 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / deep4 | damage | 749.61267 → 755.26366 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | fields.fire_trail | 14 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | frozen | 12 → 15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | max_budget_used | 8 → 9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | nova_frozen | 8 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | roots.using_1_applications | 101 → 94 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | roots.using_2_applications | 2 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | roots.using_3_applications | 0 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | roots.using_7_applications | 5 → 4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | roots.using_9_applications | 0 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | roots.with_applications | 111 → 104 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | spread_status | 139 → 146 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | status_instances | 23 → 24 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | statuses.burn | 27 → 28 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | statuses.charge | 60 → 62 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | statuses.cold | 21 → 22 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | statuses.poison | 5 → 7 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / deep4 | statuses.slow | 21 → 22 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / frozen-death-shards | by_tower.0 | 930.564909 → 31.564909 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / mana-crystal | applications | 84 → 75 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-crystal | by_element.fire | 237.6 → 220.8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-crystal | by_tower.1 | 237.6 → 220.8 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / mana-crystal | by_tower.2 | 304.5 → 246.9 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / mana-crystal | damage | 715.9 → 699.1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-crystal | damage_capped | 650.7 → 641.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-crystal | mana | 303.54 → 207.03 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| grid / mana-crystal | mana_mark | 121.74 → 89.58 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| grid / mana-crystal | mana_siphon | 173.8 → 109.45 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| grid / mana-crystal | roots.using_1_applications | 57 → 48 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-crystal | roots.with_applications | 62 → 53 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | by_element.fire | 134.1 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | by_tower.0 | 147.9915 → 144.3915 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / mana-graft | damage | 147.9915 → 144.3915 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | damage_capped | 147.9915 → 144.3915 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | fields.fire_trail | 15 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | mana | 21.71043 → 20.357077 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| grid / mana-graft | mana_siphon | 21.71043 → 20.357077 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| grid / mana-graft | roots.using_1_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-graft | roots.with_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / mana-mark | by_tower.1 | 168.3 → 153.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / mana-mark | mana | 97.98 → 84.745 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / mana-mark | mana_mark | 37.48 → 32.12 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / mana-mark | mana_siphon | 58.5 → 50.625 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / mark-economics | by_tower.0 | 39.7 → 30.7 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / mark-economics | mana | 13.91 → 11.21 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / mark-economics | mana_mark | 11.91 → 9.21 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / plain-blood5 | by_tower.0 | 249.66 → 249.6 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-fire3 | applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire3 | by_element.fire | 134.1 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire3 | by_tower.0 | 134.1 → 130.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-fire3 | damage | 134.1 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire3 | damage_capped | 134.1 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire3 | fields.fire_trail | 15 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire3 | roots.using_1_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire3 | roots.with_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | applications | 58 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | by_element.fire | 232.2 → 221.4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | by_tower.0 | 232.2 → 219.9 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-fire5 | damage | 232.2 → 221.4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | damage_capped | 228.9 → 219.9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | fields.fire_trail | 11 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | roots.using_1_applications | 58 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-fire5 | roots.with_applications | 58 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / plain-golem5 | by_tower.0 | 270 → 255 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-hive3 | by_tower.0 | 130.5 → 129 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-hive5 | by_tower.0 | 340.2 → 337.2 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-ice5 | by_tower.0 | 163.8 → 143.4 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-light5 | by_tower.0 | 307.881 → 300.306 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-mana3 | mana | 63 → 58.5 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / plain-mana3 | mana_siphon | 54 → 49.5 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / plain-mana5 | mana | 199.98 → 147.18 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / plain-mana5 | mana_siphon | 158.4 → 105.6 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| grid / plain-meteor5 | by_tower.0 | 302.4 → 292.8 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-poison5 | by_tower.0 | 257.4 → 238.8 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / plain-water5 | by_tower.0 | 188.1 → 169.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / push-chain-stale-position | applications | 5 → 1 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | by_element.electric | 10.470757 → 6.3 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | by_element.water | 19.445692 → 11.7 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | by_tower.0 | 29.91645 → 18 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / push-chain-stale-position | damage | 29.91645 → 18 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | damage_capped | 29.91645 → 18 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | hops.mermi sekerek | 2 → 0 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | hops.total | 2 → 0 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | max_budget_used | 5 → 1 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | max_gen | 1 → 0 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | max_status_gen | 1 → 0 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | pushed_tiles | 0.581709 → 0.35 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | roots.using_1_applications | 0 → 1 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | roots.using_5_applications | 1 → 0 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | spread_status | 2 → 0 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | status_instances | 3 → 1 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / push-chain-stale-position | statuses.wet | 3 → 1 | B1 fixed: post-move transform removes unintended chains and downstream payloads |
| grid / rej-pierce-tick | applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-pierce-tick | by_element.fire | 134.1 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-pierce-tick | by_tower.0 | 174.231 → 170.631 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / rej-pierce-tick | damage | 174.231 → 170.631 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-pierce-tick | damage_capped | 174.231 → 170.631 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-pierce-tick | fields.fire_trail | 15 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-pierce-tick | roots.using_1_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-pierce-tick | roots.with_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | applications | 40 → 35 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | by_element.fire | 128.7 → 124.2 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | by_tower.0 | 194.6295 → 187.6575 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / rej-summon | damage | 194.6295 → 190.1295 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | damage_capped | 191.2575 → 187.6575 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | fields.fire_trail | 15 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | roots.using_1_applications | 40 → 35 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / rej-summon | roots.with_applications | 40 → 35 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / shuffle-0 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-0 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / shuffle-1 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-1 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / shuffle-2 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-2 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / shuffle-3 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-3 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / shuffle-4 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-4 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / shuffle-5 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / shuffle-5 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / siphon-lethal-mana1 | by_tower.0 | 4.05 → 1 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / siphon-lethal-mana1 | mana | 4.43 → 2.6 | B3 payout fixed in Python; both engines now exclude overkill |
| grid / siphon-lethal-mana1 | mana_siphon | 2.43 → 0.6 | B3 payout fixed in Python; both engines now exclude overkill |
| grid / siphon-lethal-mana3 | by_tower.0 | 9 → 1 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / siphon-lethal-mana3 | mana | 8.75 → 2.75 | B3 payout fixed in Python; both engines now exclude overkill |
| grid / siphon-lethal-mana3 | mana_siphon | 6.75 → 0.75 | B3 payout fixed in Python; both engines now exclude overkill |
| grid / stress-24 | applications | 139 → 134 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | bleed_forced | 8.880674 → 8.130834 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | bleed_walk | 40.298444 → 41.819666 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.blood | 49.179118 → 49.9505 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.electric | 124.072838 → 131.722356 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.fire | 171.365537 → 189.015992 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.ice | 41.255708 → 36.69146 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.impact | 108.055544 → 115.71338 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.lava | 34.186614 → 28.212534 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.light | 60.17984 → 47.63192 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.physical | 51.973572 → 44.914634 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.poison | 64.853236 → 95.846403 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_element.water | 22.035064 → 18.551146 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | by_tower.0 | 727.157071 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / stress-24 | damage | 727.157071 → 758.250325 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | damage_capped | 720 → 720 | Floating arithmetic only (within stated tolerance) |
| grid / stress-24 | fields.fire_trail | 5 → 3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | frozen | 4 → 3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | hops.durum yandakine atlayarak | 9 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | hops.parça | 1 → 2 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | host_attacks | 3 → 4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | pushed_tiles | 1.090751 → 1.004457 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | roots.using_3_applications | 3 → 0 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | roots.using_5_applications | 12 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | roots.using_9_applications | 0 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | roots.with_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | seconds | 5.95 → 7.15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | spread_status | 192 → 180 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | status_instances | 100 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.blind | 15 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.burn | 29 → 30 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.charge | 9 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.cold | 18 → 16 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.poison | 50 → 48 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.shred | 18 → 16 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.slow | 27 → 24 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / stress-24 | statuses.wet | 20 → 18 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / trail-spurious-cell-drop | fields.fire_trail | 1 → 0 | B2 fixed: first last_drop is snapped, no initial field |
| grid / user-trail-ice | applications | 45 → 48 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | by_element.fire | 131.4 → 134.1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | by_element.ice | 29.484 → 32.886 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | by_tower.0 | 160.884 → 166.986 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / user-trail-ice | damage | 160.884 → 166.986 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | damage_capped | 160.884 → 166.986 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | roots.using_1_applications | 45 → 48 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | roots.with_applications | 45 → 48 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | status_instances | 5 → 7 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / user-trail-ice | statuses.slow | 26 → 29 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | by_element.fire | 134.1 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | by_tower.0 | 161.883 → 158.283 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-01 | damage | 161.883 → 158.283 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | damage_capped | 161.883 → 158.283 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | fields.fire_trail | 15 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | roots.using_1_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-01 | roots.with_applications | 44 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | applications | 115 → 114 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | by_element.fire | 262.44909 → 261.54909 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | by_tower.0 | 335.744392 → 334.844393 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-02 | damage | 335.744392 → 334.844393 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | damage_capped | 335.744392 → 334.844393 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | fields.fire_trail | 15 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | roots.using_1_applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-02 | roots.with_applications | 87 → 86 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-03 | applications | 120 → 116 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-03 | by_element.fire | 211.5 → 207.9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-03 | by_tower.0 | 300.353121 → 296.753121 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-03 | damage | 300.353121 → 296.753121 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-03 | damage_capped | 300.353121 → 296.753121 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-03 | roots.using_1_applications | 80 → 76 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-03 | roots.with_applications | 88 → 84 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | applications | 118 → 112 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | by_element.fire | 209.7 → 204.3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | by_tower.0 | 311.165492 → 305.765492 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-04 | damage | 311.165492 → 305.765492 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | damage_capped | 311.165492 → 305.765492 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | fields.fire_trail | 15 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | roots.using_1_applications | 78 → 72 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-04 | roots.with_applications | 86 → 80 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | applications | 137 → 131 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | bleed_walk | 109.62 → 110.0925 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | by_element.blood | 109.62 → 110.0925 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | by_element.electric | 70.498591 → 72.703591 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | by_element.fire | 305.55 → 292.95 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | by_tower.0 | 693.568591 → 662.35399 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-05 | damage | 693.568591 → 683.646091 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | damage_capped | 664.15399 → 662.35399 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | fields.fire_trail | 11 → 9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | roots.using_1_applications | 107 → 101 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-05 | roots.with_applications | 113 → 107 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-06 | by_tower.0 | 122.4 → 108.4 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-07 | by_tower.0 | 120.015 → 120 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-09 | applications | 50 → 46 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | bleed_walk | 34.1775 → 34.02 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | by_element.blood | 49.06125 → 48.90375 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | by_element.fire | 126.9 → 123.3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | by_tower.0 | 126.9 → 121.8975 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-09 | by_tower.1 | 175.06125 → 174.90375 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-09 | damage | 301.96125 → 298.20375 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | damage_capped | 300.40125 → 296.80125 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | fields.fire_trail | 12 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | roots.using_1_applications | 50 → 46 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09 | roots.with_applications | 50 → 46 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-09-alone | by_tower.0 | 176.2425 → 176.16 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-12 | applications | 105 → 103 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-12 | by_element.fire | 63.121494 → 62.239494 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-12 | by_tower.0 | 445.456614 → 444.574614 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-12 | damage | 445.456614 → 444.574614 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-12 | damage_capped | 445.456614 → 444.574614 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-12 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-12 | roots.using_1_applications | 57 → 55 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-12 | roots.with_applications | 65 → 63 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | applications | 30 → 26 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | by_element.fire | 65.52 → 63 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | by_tower.0 | 184.32 → 179.58 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-15 | damage | 184.32 → 181.8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | damage_capped | 182.1 → 179.58 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | fields.fire_trail | 9 → 7 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | roots.using_1_applications | 30 → 26 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-15 | roots.with_applications | 30 → 26 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-17 | by_tower.0 | 164.205 → 164.19 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-18 | by_tower.0 | 196.335 → 194.79 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-21 | applications | 85 → 74 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | by_element.fire | 218.7 → 209.7 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | by_element.poison | 97.65 → 78.75 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | by_tower.0 | 316.35 → 286.05 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-21 | damage | 316.35 → 288.45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | damage_capped | 309 → 286.05 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | fields.fire_trail | 11 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | roots.using_1_applications | 85 → 74 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | roots.with_applications | 85 → 74 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-21 | statuses.poison | 35 → 30 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | applications | 80 → 79 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | by_element.fire | 123.861654 → 121.341654 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | by_tower.0 | 742.832554 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| grid / v4-22 | damage | 742.832554 → 740.312554 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | fields.fire_trail | 6 → 5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | roots.using_1_applications | 39 → 38 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | roots.with_applications | 46 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | seconds | 10.9 → 10.25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / v4-22 | status_instances | 10 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| grid / wet-electric | by_tower.1 | 186.57 → 185.07 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / deep3 | applications | 162 → 153 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | by_element.electric | 247.785391 → 260.637391 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | by_element.fire | 345.6 → 329.85 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | by_tower.0 | 704.760806 → 688.125635 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / deep3 | damage | 704.760806 → 701.862806 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | damage_capped | 691.725635 → 688.125635 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | fields.fire_trail | 16 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | roots.using_1_applications | 95 → 86 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | roots.with_applications | 106 → 97 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | spread_status | 134 → 137 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | statuses.charge | 60 → 61 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | statuses.cold | 23 → 24 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep3 | statuses.slow | 23 → 24 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | applications | 155 → 149 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | by_element.electric | 247.056087 → 255.345391 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | by_element.fire | 339.75 → 321.75 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | by_element.ice | 70.631646 → 76.139626 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | by_element.poison | 34.5744 → 37.044 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | by_tower.0 | 709.892995 → 692.569428 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / deep4 | damage | 709.892995 → 708.159879 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | damage_capped | 693.699828 → 692.569428 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | fields.fire_trail | 16 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | frozen | 12 → 15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | hops.durum yandakine atlayarak | 23 → 24 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | hops.total | 26 → 27 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | max_budget_used | 8 → 9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | nova_frozen | 8 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | roots.using_1_applications | 94 → 84 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | roots.using_2_applications | 3 → 2 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | roots.using_4_applications | 0 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | roots.using_7_applications | 5 → 4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | roots.using_9_applications | 0 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | roots.with_applications | 105 → 95 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | spread_status | 137 → 146 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | status_instances | 25 → 26 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | statuses.burn | 27 → 29 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | statuses.charge | 59 → 60 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | statuses.cold | 21 → 23 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | statuses.poison | 5 → 7 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / deep4 | statuses.slow | 21 → 23 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / frozen-death-shards | by_tower.0 | 930.564909 → 31.564909 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / mana-crystal | applications | 84 → 72 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-crystal | by_element.fire | 235.1 → 212.3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-crystal | by_tower.1 | 235.1 → 212.3 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / mana-crystal | by_tower.2 | 304.5 → 246.9 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / mana-crystal | damage | 713.4 → 690.6 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-crystal | damage_capped | 644.4 → 633 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-crystal | fields.fire_trail | 9 → 7 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-crystal | mana | 301.05 → 206.4675 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| replay / mana-crystal | mana_mark | 119.25 → 89.0175 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| replay / mana-crystal | mana_siphon | 173.8 → 109.45 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| replay / mana-crystal | roots.using_1_applications | 57 → 45 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-crystal | roots.with_applications | 62 → 50 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | by_element.fire | 132.3 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | by_tower.0 | 146.1915 → 144.3915 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / mana-graft | damage | 146.1915 → 144.3915 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | damage_capped | 146.1915 → 144.3915 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | fields.fire_trail | 14 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | mana | 21.71043 → 20.357077 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| replay / mana-graft | mana_siphon | 21.71043 → 20.357077 | Expected revised economy plus B1/B2 movement/trail cascade; N1/N2/N3 source grouping remains shared |
| replay / mana-graft | roots.using_1_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-graft | roots.with_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / mana-mark | by_tower.1 | 168.3 → 153.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / mana-mark | mana | 97.98 → 84.745 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / mana-mark | mana_mark | 37.48 → 32.12 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / mana-mark | mana_siphon | 58.5 → 50.625 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / mark-economics | by_tower.0 | 39.7 → 30.7 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / mark-economics | mana | 13.91 → 11.21 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / mark-economics | mana_mark | 11.91 → 9.21 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / plain-blood5 | by_tower.0 | 248.04 → 247.98 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-fire3 | applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire3 | by_element.fire | 132.3 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire3 | by_tower.0 | 132.3 → 130.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-fire3 | damage | 132.3 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire3 | damage_capped | 132.3 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire3 | fields.fire_trail | 14 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire3 | roots.using_1_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire3 | roots.with_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | applications | 56 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | by_element.fire | 226.35 → 219.15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | by_tower.0 | 226.35 → 217.65 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-fire5 | damage | 226.35 → 219.15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | damage_capped | 223.05 → 217.65 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | fields.fire_trail | 12 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | roots.using_1_applications | 56 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-fire5 | roots.with_applications | 56 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / plain-golem5 | by_tower.0 | 315 → 285 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-hive3 | by_tower.0 | 135 → 133.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-hive5 | by_tower.0 | 356.4 → 353.4 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-ice5 | by_tower.0 | 163.8 → 143.4 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-light5 | by_tower.0 | 307.2006 → 299.6256 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-mana3 | mana | 63 → 58.5 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / plain-mana3 | mana_siphon | 54 → 49.5 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / plain-mana5 | mana | 199.98 → 147.18 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / plain-mana5 | mana_siphon | 158.4 → 105.6 | Expected revised economy: overkill exclusion + soft cap; N1/N2/N3 source grouping remains shared |
| replay / plain-meteor5 | by_tower.0 | 288 → 278.4 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-poison5 | by_tower.0 | 257.4 → 238.8 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / plain-water5 | by_tower.0 | 188.1 → 169.5 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / rej-pierce-tick | applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-pierce-tick | by_element.fire | 132.3 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-pierce-tick | by_tower.0 | 172.431 → 170.631 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / rej-pierce-tick | damage | 172.431 → 170.631 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-pierce-tick | damage_capped | 172.431 → 170.631 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-pierce-tick | fields.fire_trail | 14 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-pierce-tick | roots.using_1_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-pierce-tick | roots.with_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | applications | 38 → 36 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | by_element.fire | 126.9 → 125.1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | by_tower.0 | 192.8295 → 188.5575 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / rej-summon | damage | 192.8295 → 191.0295 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | damage_capped | 189.4575 → 188.5575 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | fields.fire_trail | 14 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | roots.using_1_applications | 38 → 36 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / rej-summon | roots.with_applications | 38 → 36 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-0 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-0 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-0 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / shuffle-0 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-0 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-0 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-0 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-1 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-1 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-1 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / shuffle-1 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-1 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-1 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-1 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-2 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-2 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-2 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / shuffle-2 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-2 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-2 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-2 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-3 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-3 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-3 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / shuffle-3 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-3 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-3 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-3 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-4 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-4 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-4 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / shuffle-4 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-4 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-4 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-4 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-5 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-5 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-5 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / shuffle-5 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-5 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-5 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / shuffle-5 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / siphon-lethal-mana1 | by_tower.0 | 4.05 → 1 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / siphon-lethal-mana1 | mana | 4.43 → 2.6 | B3 payout fixed in Python; both engines now exclude overkill |
| replay / siphon-lethal-mana1 | mana_siphon | 2.43 → 0.6 | B3 payout fixed in Python; both engines now exclude overkill |
| replay / siphon-lethal-mana3 | by_tower.0 | 9 → 1 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / siphon-lethal-mana3 | mana | 8.75 → 2.75 | B3 payout fixed in Python; both engines now exclude overkill |
| replay / siphon-lethal-mana3 | mana_siphon | 6.75 → 0.75 | B3 payout fixed in Python; both engines now exclude overkill |
| replay / stress-24 | applications | 154 → 139 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | bleed_forced | 7.621823 → 8.130834 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | bleed_walk | 38.685925 → 65.260951 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.blood | 46.307748 → 73.391785 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.electric | 118.619273 → 107.222636 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.fire | 163.699052 → 133.575992 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.ice | 43.285894 → 32.806779 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.impact | 64.512879 → 78.54786 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.lava | 39.784374 → 28.212534 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.light | 78.10992 → 47.63192 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.physical | 58.634202 → 41.627597 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.poison | 102.380376 → 182.883619 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_element.water | 21.975382 → 18.551146 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | by_tower.0 | 737.309101 → 720 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / stress-24 | damage | 737.309101 → 744.451868 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | damage_capped | 720 → 720 | Floating arithmetic only (within stated tolerance) |
| replay / stress-24 | fields.fire_trail | 5 → 3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | frozen | 6 → 3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | hops.durum yandakine geçerek | 13 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | hops.mermi sekerek | 8 → 6 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | hops.total | 30 → 25 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_1_applications | 29 → 36 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_2_applications | 3 → 4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_3_applications | 1 → 0 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_4_applications | 1 → 0 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_6_applications | 6 → 3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_8_applications | 1 → 0 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.using_9_applications | 0 → 1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | roots.with_applications | 53 → 56 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | seconds | 6.5 → 12.4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | spread_status | 199 → 175 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | status_instances | 92 → 73 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.bleed | 24 → 22 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.blind | 20 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.burn | 30 → 27 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.charge | 8 → 9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.cold | 20 → 15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.poison | 56 → 46 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.shred | 20 → 15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.slow | 28 → 23 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / stress-24 | statuses.wet | 22 → 18 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / trail-spurious-cell-drop | fields.fire_trail | 1 → 0 | B2 fixed: first last_drop is snapped, no initial field |
| replay / user-trail-ice | applications | 56 → 49 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | by_element.fire | 144.9 → 138.6 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | by_element.ice | 39.69 → 31.752 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | by_tower.0 | 184.59 → 170.352 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / user-trail-ice | damage | 184.59 → 170.352 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | damage_capped | 184.59 → 170.352 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | fields.fire_trail | 11 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | roots.using_1_applications | 56 → 49 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | roots.with_applications | 56 → 49 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / user-trail-ice | statuses.slow | 35 → 28 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | by_element.fire | 132.3 → 130.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | by_tower.0 | 160.083 → 158.283 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-01 | damage | 160.083 → 158.283 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | damage_capped | 160.083 → 158.283 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | fields.fire_trail | 14 → 12 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | roots.using_1_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-01 | roots.with_applications | 42 → 40 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | applications | 115 → 112 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | by_element.fire | 262.44909 → 259.74909 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | by_tower.0 | 335.744393 → 333.044393 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-02 | damage | 335.744393 → 333.044393 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | damage_capped | 335.744393 → 333.044393 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | fields.fire_trail | 14 → 11 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | roots.using_1_applications | 80 → 77 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-02 | roots.with_applications | 87 → 84 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-03 | applications | 121 → 116 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-03 | by_element.fire | 212.4 → 207.9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-03 | by_tower.0 | 301.253121 → 296.753121 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-03 | damage | 301.253121 → 296.753121 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-03 | damage_capped | 301.253121 → 296.753121 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-03 | roots.using_1_applications | 81 → 76 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-03 | roots.with_applications | 89 → 84 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | applications | 123 → 112 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | by_element.fire | 214.2 → 204.3 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | by_tower.0 | 315.665492 → 305.765492 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-04 | damage | 315.665492 → 305.765492 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | damage_capped | 315.665492 → 305.765492 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | fields.fire_trail | 14 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | roots.using_1_applications | 83 → 72 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-04 | roots.with_applications | 91 → 80 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | applications | 132 → 127 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | bleed_walk | 109.1475 → 110.4075 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | by_element.blood | 109.1475 → 110.4075 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | by_element.electric | 66.833826 → 69.038826 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | by_element.fire | 303.3 → 292.5 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | by_element.poison | 200.97 → 207.9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | by_tower.0 | 680.251326 → 662.19649 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-05 | damage | 680.251326 → 679.846326 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | damage_capped | 663.99649 → 662.19649 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | fields.fire_trail | 10 → 9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | roots.using_1_applications | 107 → 102 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | roots.with_applications | 112 → 107 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-05 | statuses.burn | 14 → 15 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-06 | by_tower.0 | 122.4 → 108.4 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-07 | by_tower.0 | 120.015 → 120 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-09 | applications | 40 → 37 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-09 | by_element.fire | 99.9 → 97.2 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-09 | by_tower.0 | 99.9 → 96.47625 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-09 | by_tower.1 | 165.76875 → 151.62375 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-09 | damage | 265.66875 → 262.96875 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-09 | damage_capped | 249.9 → 248.1 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-09 | roots.using_1_applications | 40 → 37 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-09 | roots.with_applications | 40 → 37 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-09-alone | by_tower.0 | 176.085 → 176.0025 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-12 | applications | 121 → 115 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-12 | by_element.fire | 75.469494 → 72.823494 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-12 | by_tower.0 | 480.811449 → 478.165449 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-12 | damage | 480.811449 → 478.165449 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-12 | damage_capped | 480.811449 → 478.165449 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-12 | fields.fire_trail | 16 → 13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-12 | roots.using_1_applications | 71 → 65 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-12 | roots.with_applications | 79 → 73 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | applications | 34 → 31 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | by_element.fire | 84.42 → 82.53 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | by_tower.0 | 223.02 → 219.54 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-15 | damage | 223.02 → 221.13 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | damage_capped | 220.8 → 219.54 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | fields.fire_trail | 11 → 9 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | roots.using_1_applications | 34 → 31 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-15 | roots.with_applications | 34 → 31 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-17 | by_tower.0 | 169.65 → 169.635 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-18 | by_tower.0 | 207.765 → 206.22 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-21 | applications | 82 → 73 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | by_element.fire | 212.85 → 205.65 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | by_element.poison | 94.5 → 78.75 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | by_tower.0 | 307.35 → 282 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-21 | damage | 307.35 → 284.4 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | damage_capped | 300 → 282 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | fields.fire_trail | 12 → 10 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | roots.using_1_applications | 82 → 73 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | roots.with_applications | 82 → 73 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-21 | statuses.poison | 34 → 30 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-22 | applications | 93 → 90 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-22 | by_element.fire | 127.140363 → 125.250363 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-22 | by_tower.0 | 784.020058 → 707.806426 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |
| replay / v4-22 | damage | 784.020058 → 782.130058 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-22 | fields.fire_trail | 10 → 8 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-22 | roots.using_1_applications | 47 → 44 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / v4-22 | roots.with_applications | 55 → 52 | Expected B1/B2 repair cascade: movement resync before bleed/trails/propagation and snapped first trail; E1-E4 remain |
| replay / wet-electric | by_tower.1 | 186.57 → 185.07 | Expected callback contract: Godot tower damage is now capped HP damage (combat.gd:131) |

### New and resolved parity discrepancies

No original case that previously matched total damage or all compared metrics lost that whole-case equality. Grid damage equality improves 42→44/99; replay stays 67/99. Grid all-metric equality improves 35→39/99; replay 57→60/99. New individual mismatching cells do appear inside already divergent recipes: 16 grid and 26 replay cells, enumerated below. They occur in fire/trail/propagation cases, consistent with B1/B2 repair cascades and remaining E1-E4 differences; no additional isolated Godot-only defect was established. This source/path explanation does not establish the exact causal share of each fix. All resolved cells are also retained in results/parity-transitions.json.

| Mode / case | Newly differing metric | Before Python / Godot | After Python / Godot | Reason |
|---|---|---|---|---|
| grid / v4-22 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / stress-24 | hops.parça | 1 / 1 | 1 / 2 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / stress-24 | host_attacks | 3 / 3 | 3 / 4 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / stress-24 | roots.using_3_applications | 3 / 3 | 3 / 0 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / stress-24 | roots.using_9_applications | 0 / 0 | 0 / 1 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / stress-24 | statuses.charge | 9 / 9 | 9 / 12 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / shuffle-0 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / shuffle-1 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / shuffle-2 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / shuffle-3 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / shuffle-4 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / shuffle-5 | status_instances | 10 / 10 | 10 / 11 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / deep3 | hops.buz parçası düşer | 3 / 3 | 3 / 2 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / deep3 | shards | 2 / 2 | 2 / 1 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / deep3 | statuses.charge | 61 / 61 | 61 / 62 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| grid / deep4 | roots.using_3_applications | 0 / 0 | 0 / 1 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / v4-22 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / v4-22 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | roots.using_2_applications | 3 / 3 | 3 / 4 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | roots.using_9_applications | 0 / 0 | 0 / 1 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | statuses.bleed | 24 / 24 | 24 / 22 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | statuses.burn | 30 / 30 | 30 / 27 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | statuses.cold | 20 / 20 | 20 / 15 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | statuses.shred | 20 / 20 | 20 / 15 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / stress-24 | statuses.slow | 28 / 28 | 28 / 23 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-0 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-0 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-1 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-1 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-2 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-2 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-3 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-3 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-4 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-4 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-5 | roots.using_1_applications | 47 / 47 | 47 / 44 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / shuffle-5 | roots.with_applications | 55 / 55 | 55 / 52 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / deep4 | hops.durum yandakine atlayarak | 23 / 23 | 23 / 24 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / deep4 | hops.total | 26 / 26 | 26 / 27 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / deep4 | roots.using_2_applications | 3 / 3 | 3 / 2 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / deep4 | roots.using_4_applications | 0 / 0 | 0 / 1 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
| replay / deep4 | statuses.charge | 59 / 59 | 59 / 60 | B1/B2 repair-associated movement/trail cascade in an already divergent E1-E4 case |
