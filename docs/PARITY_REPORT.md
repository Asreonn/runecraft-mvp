# C2 — Python/Godot combat parity

Snapshot: `5065a12c7e3afd63c90af3e1e395711dc87101c0` (detached clone, fetched from origin). Engine `4.7.2.stable.arch_linux.ed1daf0bf`; Python `3.14.7`.

**N1, N2 and N3 are fixed in Python, Godot grid and Godot replay.** B1/B2/B3 remain fixed. Gameplay/reference sources and the existing adapters were not edited. The reporting layer now checks the 130-test suite and asserts all nine economy-contract values.

**Parity remains partial.** 147 cases: 110 combat, 36 expected compile rejections, one incompatible graft. **130/130 Python tests**, **1242/1242 harness/invariant checks**, **16/16 native field/tower probes**; 188 successful compiler comparisons match and 220 Godot combat runs satisfy finite/generation/budget bounds.

| Equality (same 110 combat cases) | 94a1c1a → 5065a12 |
|---|---:|
| grid damage | 55 → 55 / 110 |
| grid all compared metrics | 49 → 49 / 110 |
| replay damage | 78 → 78 / 110 |
| replay all compared metrics | 70 → 70 / 110 |

No damage, target, status-count, field-count or budget metric changes between these commits. All seven cases with material metric changes in each engine change only mana channels/totals. Python additionally persists the mark owner tower. No newly mismatching metric cells or lost whole-case equality were introduced.

## Re-run

From the parent project:

```sh
asset-work/codex-mvp/parity/run.sh
python3 asset-work/codex-mvp/parity/validation/verify_repeat.py
```

Isolation probes (from this directory):

```sh
PYTHONDONTWRITEBYTECODE=1 python3 validation/reclassify_probes.py
XDG_DATA_HOME="$PWD/harness/userdata" XDG_CONFIG_HOME="$PWD/harness/config" XDG_CACHE_HOME="$PWD/harness/cache" godot --headless --path harness --script reclassify_probes.gd
```

The clone stays pinned; run.sh refreshes runtime copies byte for byte, runs Python tests/reference, Godot grid and replay, native probes, and regenerates this report and RERUN_SUMMARY_5065a12.md. Exit success requires invariant and N1–N3 contract checks; residual model/implementation differences are reported rather than silently treated as equal. RERUN_SUMMARY.md remains the historical 94a1c1a summary. Baselines are preserved in results_94a1c1a/, REPORT_94a1c1a.md, RERUN_SUMMARY_94a1c1a.md and validation/harness_94a1c1a/. The older 6c65ef4 baseline is retained.

## Method and limits

- Coverage and equality denominator are unchanged: 147 cases, 110 combat. All scenario recipes, 13 runes at G1/G3/G5, six sibling permutations, depth 3/4, receiver locks, rejection cases and original direct probes are retained. The 39 separate isolation probes do not inflate those counts.
- Default: six 120-HP enemies, spacing 0.6 tile, armor 10%, speed 1 tile/s, dt 0.05, 14 s, tower tile (6,2), range 4. World uses 2 units/tile and a straight row; the adapter adds a 64-tile path offset. Source scale/art assets are not generated or imported.
- Native combat, compiler, tower attacks/summons, enemy statuses/speed, economy and selected real VFX field lifecycle paths run unchanged. Board/path/visual adapters are identical to the archived 94a1c1a adapters. Source-copy hashes/spec identity and Python observer comparisons with unwrapped sim.simulate guard integrity. Projectiles hit immediately; delayed lava/meteor callbacks use simulated time.
- Replay consumes Python tower/timer root events and positions while Godot executes native movement/statuses/fields. It removes host attack selection differences, not native Vector2 precision or field semantics. Coupled descendant effects are classified by evidenced mechanisms; there is no additive per-cell causal proof for large recipes.
- Numeric tolerance: absolute 1e-6 plus relative 1e-9. Discrete counts require equality. All-metric equality uses the historical flat metric set including host attacks and root histograms; by_tower and bleed_walk/bleed_forced are excluded because their definitions differ. Diagnostic mismatches are now separately enumerated, not discarded.
- Godot by_tower records HP removed; Python records nominal damage. Python movement-bleed counters are pre-armor; Godot observers count actual blood damage including descendants. Mana includes kill rewards, marks and siphon; starting mana/passive regen are excluded. Fields count creations, not refreshes. Raw enemy-state metadata and root traces are persisted but are not a byte-identical cross-engine oracle.
- Headless combat/economy/compiler and native field/tower state evidence only. Rendered visuals, real projectile/summon lifecycle, curved maps, inventory/save/load and physical play are outside this harness. Native field/tower probes cover integer field identity, merge/eviction/expiry and delayed-callback cancellation.
- Supplemental static lint remains non-clean: the copied real vfx.gd has a deferred UI load of res://ui/skin.gd outside the isolated harness, and the linter flags res://../ paths used successfully by this pipeline. Receipts: validation/lint-before-5065a12.json and validation/lint-after-5065a12.json. These are not claimed as successful whole-project checks. Actual headless execution has no engine errors.

## N1–N3 economy contracts

| Finding / metric | Python before → after | Grid before → after | Replay before → after | Expected |
|---|---:|---:|---:|---:|
| N1 / mark-cap-distinct-towers / mana_mark | 6.3 → 7.2 | 6.3 → 7.2 | 6.3 → 7.2 | 7.2 (pass all three) |
| N2 / siphon-two-nodes / mana_siphon | 4.658025 → 6.533025 | 4.658025 → 6.533025 | 4.658025 → 6.533025 | 6.533025 (pass all three) |
| N3 / cap-shared-node-channels / mana | 9.675 → 8.325 | 9.675 → 8.325 | 9.675 → 8.325 | 8.325 (pass all three) |

- N1: two disjoint HP-10000 enemies at X=6/16, mark each using mana3 from towers 0/1, deal 20 physical to each at t=0. Each removes 18 HP and yields 3.6 mana; expected 7.2. Same-tower control remains 6.3.
- N2: hit one HP-10000 enemy once with fire1{fire_hit:[mana1,mana1]}. HP removed 13.2525; each node has raw 5.56605. Two G1 caps yield 2×(2.5+(5.56605−2.5)×0.25)=6.533025.
- N3: hit one HP-10000 enemy twice using mana3 from tower 0 at t=0. Combined raw siphon+mark is 15.3; one G3 cap yields 6+(15.3−6)×0.25=8.325. Siphon remains 7.875, mark becomes 0.45.
- Current fix sites: repo/scripts/combat.gd:93–102,128,211; repo/design/rune_mechanics/mechanics/sim.py:206–211,247,322,553–555. Keys combine tower ID with recipe-node path; each siphon donor gets its own payout, and the mark stores its owner. Each contract is asserted independently for Python, grid and replay in results/verification.json.

## Residual divergence classification

Every material compared cell in both modes and every differing excluded per-tower/bleed diagnostic is enumerated in results/divergence-classification.json. Category (a) means expected documented model or evidenced numeric-boundary behavior; category (b) means an actual implementation difference. Arithmetic within tolerance is labeled separately in the scenario tables. Nothing is automatically called expected solely because it differs.

| ID | Category | Meaning | Godot / Python locations |
|---|---|---|---|
| E1 | (a) | Documented grid-cell targeting versus continuous-radius targeting | repo/scripts/tower.gd:124 / repo/design/rune_mechanics/mechanics/sim.py:594 |
| E2 | (a) | Documented one-cell fields, same-cell merging and cell-crossing trails versus continuous radius/distance fields | repo/scripts/combat.gd:338,385,400,418 / repo/design/rune_mechanics/mechanics/sim.py:151,439,475,481 |
| E3 | (a) | Spatial precision, tie selection or exposure boundary; discrete outcomes remain real mismatches, not tolerance-equal | repo/scripts/combat.gd:44,461; harness/observed_enemy.gd:7,10; harness/world.gd:87 / repo/design/rune_mechanics/mechanics/sim.py:104,127,509 |
| E4 | (a) | 2D/snapped meteor and summon placement, lead and attack lifecycle versus 1D model | repo/scripts/tower.gd:188,210,245,290; repo/scripts/combat.gd:489 / repo/design/rune_mechanics/mechanics/sim.py:538,612,633,665,699 |
| E5 | (a) | Different diagnostic accounting definitions: HP-removed per tower; nominal versus actual bleed counters | repo/scripts/combat.gd:131; harness/observed_combat.gd:81 / repo/design/rune_mechanics/mechanics/sim.py:251,445 |
| R1 | (b) | Pre-existing chain-label diagnostic difference: empty verb versus Python fallback seker; total hops and damage unchanged | repo/scripts/combat.gd:455; harness/stub_vfx.gd:7 / repo/design/rune_mechanics/mechanics/sim.py:507 |
| R2 | (b) | Pre-existing DoT scheduling implementation difference: next <= 0.0001 versus <= 1e-9; Godot can tick early | repo/scripts/combat.gd:308 / repo/design/rune_mechanics/mechanics/sim.py:416 |

Residual inventory: 1060 material compared cells plus 168 definition-different diagnostic cells. R1 accounts for the empty/seker dictionary-label cells; R2 is an additional isolated scheduling finding and is not assigned as the cause of fixed-dt scenario divergences.

### (a) Evidence and boundaries

- E1/E2 are explicit decisions in repo/design/DECISIONS.md:93–97. Grid tower range uses rounded enemy cells. Native fields snap to one cell and merge by tower/kind/cell; Python fields retain radius and separate records. trail-real-crossing moves X=6.49→6.51: Python creates 0 fields, Godot creates 1 in both modes. This is expected.
- E3: boundary-pierce uses X=6.2/7.1 and a 0.9 range. Python damage/hops are 18.72/1; Godot grid/replay 11.7/0. The spatial coordinate representation moves the comparison across the inclusive threshold. Control X=6.25/7.125 yields 18.72/1 in all three; X=6.25/7.25 yields 11.7/0. These discrete differences are counted, never hidden under floating tolerance.
- E3: dense initial root at spacing 0.05 yields rejected_events Python 21 versus Godot 19 while damage, successful applications and hops match. Binary-exact spacing 0.0625 yields 15 in all three; 0.125 yields 7. Differences already exist before any ticks. Native AreaImpact membership and nearest ties use Vector2; this is not evidence of a broken 16-application cap.
- E3: summon-loop seconds 21 versus 21.05 follows the strict >18 leak boundary, native accumulated s with a +64 offset, and Python x accumulation. Replay golem/hive damage and attacks match while the stop step differs. Other no-field replay differences (v4-19, v4-20, plain-light5 and final status exposure in plain-electric5) are associated with native nearest/range/tie/exposure boundaries. Exact per-descendant attribution is not proven; these are retained as numerical-model residuals, not newly introduced regressions.
- E4 includes snapped/slowed meteor lead, 2D multi-impact offsets and reach, adjacent summon cells, volcano initial 0.6 versus 0.5 s, and golem/beetle approach. Host differences disappear under replay where native field and numerical differences do not intervene. Aggregate E1/E2/E3/E4 cases can mix mechanisms.
- E5 records diagnostic definitions: it does not justify a damage mismatch. Same-status-two-towers still shares one refreshed status in both engines, the documented open design question at DECISIONS.md:102–104; it is not a new cross-engine divergence.

### (b) R1 — chain label fallback (pre-existing, diagnostic)

**Locations:** Godot repo/scripts/combat.gd:455 emits p.get("verb", ""); observer harness/stub_vfx.gd:7 counts that exact label. Python repo/design/rune_mechanics/mechanics/sim.py:507 uses p.verb or "seker". Both compilers return the same empty verb; this is a runtime diagnostic difference, not a compiler or damage defect.

**Minimal repro:** validation case chain-empty-verb: two HP-10000 enemies X=6/6.5, one electric3 event on enemy 0. Python hops {"seker":1}; grid/replay hops {"":1}. All return damage 14.85 and total hops 1. **Expected parity value:** one hop under the common reference label "seker". Main-suite affected cases: wet-electric, wet-electric-alone, plain-electric3, plain-electric5. The difference exists in the preserved 94a1c1a results and unchanged source; severity is diagnostic/P3, no gameplay regression established.

### (b) R2 — early DoT tick threshold (pre-existing)

**Locations:** Godot repo/scripts/combat.gd:308 uses next <= 0.0001; Python repo/design/rune_mechanics/mechanics/sim.py:416 uses next <= 1e-9. These branches are unchanged since 94a1c1a.

**Minimal repro:** validation case dot-tick-threshold-0.99995: one HP-10000 enemy, armor 10%, apply poison1 at t=0, tick once with dt=0.99995. next is about 0.00005: Python damage 0; grid/replay damage 4.5. **Expected value for a one-second tick contract:** 0 before 1 s (within the reference 1e-9 tolerance); at dt=1.0 all return 4.5. This is a real scheduling-policy difference, not a spatial model difference. The original harness uses dt=0.05 and does not reproduce this early tick there; do not attribute unrelated residuals to it. No game code was fixed.

## Targeted controls and validation

- B1 push-chain-stale-position: damage 18, hops 0 in all three. B2 trail-spurious-cell-drop: no fields. B3 lethal G1/G3 siphon: 0.6/0.75 plus kill reward 2. Same-node cap, distinct-tower cap and second rollover: 3.09/4.86/4.86. Mark overkill payout 0.3; one or two crystal marks both give 3 stones.
- Native field/tower probes remain 16/16: field cap 8, real VFX integer identity survives mutation/merge and clears on eviction/expiry; queued meteor and lava attacks deal damage in controls and zero after native rune clear. All six sibling permutations are identical inside each engine; depth/budget checks pass.
- Separate isolation receipts: validation/reclassification-cases.json, reclassification-python.json, reclassification-godot.json, reclassification-run.log. The 39 cases include 18 status-expiry controls; all 18 have matching damage. Two real differences above are reported rather than asserted as passing equality.
- Repeat receipts: validation/repeat-verification.json (written after the documented repeat run), validation/repeat-run.log. Baseline hashes: validation/baseline_94a1c1a_sha256.json. Current source provenance: results/provenance.json. Clone cleanliness and exact copied-source identity are independently checked by the repeat verifier.

## Scenario tables

The unchanged 147 cases follow. Absent dictionary entries are zero. Per-root histograms exclude empty roots; full raw state persists in results/python.json and results/godot.json.

### v4-01 (scenario)

Recipes: `fire3{burn:[electric1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 174.483 | 158.283 | -9.285% | 158.283 | -9.285% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 174.483 | 158.283 | -9.285% | 158.283 | -9.285% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 27.783 | 27.783 | 0% | 27.783 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### v4-02 (scenario)

Recipes: `fire3{fire_hit:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 378.944392 | 334.844393 | -11.638% | 333.044393 | -12.113% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 378.944392 | 334.844393 | -11.638% | 333.044393 | -12.113% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 165 | 114 | -30.909% | 112 | -32.121% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 14 | 14 | 0% | 14 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 14 | 14 | 0% | 14 | 0% | equal |
| by_element.fire | 305.64909 | 261.54909 | -14.428% | 259.74909 | -15.017% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 73.295302 | 73.295303 | 0% | 73.295303 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 21 | 21 | 0% | 21 | 0% | equal |
| hops.mermi sekerek | 14 | 14 | 0% | 14 | 0% | equal |
| fields.fire_trail | 98 | 12 | -87.755% | 11 | -88.776% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 137 | 86 | -37.226% | 84 | -38.686% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 130 | 79 | -39.231% | 77 | -40.769% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_5_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-03 (scenario)

Recipes: `fire3{burn:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 331.853121 | 296.753121 | -10.577% | 296.753121 | -10.577% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 331.853121 | 296.753121 | -10.577% | 296.753121 | -10.577% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 155 | 116 | -25.161% | 116 | -25.161% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 16 | 16 | 0% | 16 | 0% | equal |
| status_instances | 4 | 3 | -25.000% | 4 | 0% | (a) model/numerical difference: E2, E1 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.fire | 243 | 207.9 | -14.444% | 207.9 | -14.444% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 88.853121 | 88.853121 | 0% | 88.853121 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 23 | 23 | 0% | 23 | 0% | equal |
| hops.durum yandakine atlayarak | 16 | 16 | 0% | 16 | 0% | equal |
| fields.fire_trail | 89 | 13 | -85.393% | 13 | -85.393% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 123 | 84 | -31.707% | 84 | -31.707% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 115 | 76 | -33.913% | 76 | -33.913% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |

### v4-04 (scenario)

Recipes: `fire3{burn:[electric3{chain:[ice2]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 321.965492 | 305.765492 | -5.032% | 305.765492 | -5.032% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 321.965492 | 305.765492 | -5.032% | 305.765492 | -5.032% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 130 | 112 | -13.846% | 112 | -13.846% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 32 | 32 | 0% | 32 | 0% | equal |
| status_instances | 7 | 6 | -14.286% | 7 | 0% | (a) model/numerical difference: E2, E1 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 16 | 16 | 0% | 16 | 0% | equal |
| by_element.fire | 220.5 | 204.3 | -7.347% | 204.3 | -7.347% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 88.853121 | 88.853121 | 0% | 88.853121 | 0% | tolerance (floating arithmetic) |
| by_element.ice | 12.612371 | 12.612371 | 0% | 12.612371 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 23 | 23 | 0% | 23 | 0% | equal |
| statuses.slow | 16 | 16 | 0% | 16 | 0% | equal |
| hops.durum yandakine atlayarak | 16 | 16 | 0% | 16 | 0% | equal |
| fields.fire_trail | 82 | 13 | -84.146% | 13 | -84.146% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 98 | 80 | -18.367% | 80 | -18.367% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 90 | 72 | -20.000% | 72 | -20.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |

### v4-05 (scenario)

Recipes: `fire5{burn:[electric3,poison2,blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 651.186795 | 683.646091 | +4.985% | 679.846326 | +4.401% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 621.6 | 662.35399 | +6.556% | 662.19649 | +6.531% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 134 | 131 | -2.239% | 127 | -5.224% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 58 | 88 | +51.724% | 80 | +37.931% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| status_instances | 11 | 18 | +63.636% | 18 | +63.636% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 6 | 12 | +100.000% | 10 | +66.667% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.fire | 319.05 | 292.95 | -8.181% | 292.5 | -8.322% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 50.684295 | 72.703591 | +43.444% | 69.038826 | +36.213% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.blood | 96.075 | 110.0925 | +14.590% | 110.4075 | +14.918% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.poison | 185.3775 | 207.9 | +12.150% | 207.9 | +12.150% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 11 | 16 | +45.455% | 15 | +36.364% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.poison | 27 | 40 | +48.148% | 37 | +37.037% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.bleed | 27 | 40 | +48.148% | 37 | +37.037% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| hops.durum yandakine atlayarak | 6 | 12 | +100.000% | 10 | +66.667% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| fields.fire_trail | 56 | 9 | -83.929% | 9 | -83.929% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 122 | 107 | -12.295% | 107 | -12.295% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 119 | 101 | -15.126% | 102 | -14.286% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_5_applications | 3 | 6 | +100.000% | 5 | +66.667% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

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
| damage | 110.889 | 111.114 | +0.203% | 110.889 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 110.889 | 111.114 | +0.203% | 110.889 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| by_element.water | 45.864 | 45.864 | 0% | 45.864 | 0% | tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.wet | 14 | 14 | 0% | 14 | 0% | equal |
| roots.with_applications | 21 | 21 | 0% | 21 | 0% | equal |
| roots.using_1_applications | 21 | 21 | 0% | 21 | 0% | equal |

### v4-09 (scenario)

Recipes: `fire3`, `water4{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 278.89875 | 298.20375 | +6.922% | 262.96875 | -5.712% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 258 | 296.80125 | +15.039% | 248.1 | -3.837% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 43 | 46 | +6.977% | 37 | -13.953% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 4 | 9 | +125.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| pushed_tiles | 3.825 | 4.725 | +23.529% | 3.825 | 0% | (a) model/numerical difference: E2, E1 |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 14 | 0% | 14 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 112.5 | 123.3 | +9.600% | 97.2 | -13.600% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.water | 126 | 126 | 0% | 126 | 0% | equal |
| by_element.blood | 40.39875 | 48.90375 | +21.053% | 39.76875 | -1.559% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 6 | 7 | +16.667% | 6 | 0% | (a) model/numerical difference: E2, E1 |
| statuses.wet | 6 | 7 | +16.667% | 6 | 0% | (a) model/numerical difference: E2, E1 |
| statuses.bleed | 6 | 7 | +16.667% | 6 | 0% | (a) model/numerical difference: E2, E1 |
| fields.fire_trail | 20 | 11 | -45.000% | 7 | -65.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 43 | 46 | +6.977% | 37 | -13.953% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 43 | 46 | +6.977% | 37 | -13.953% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### v4-09-alone (comparison)

Recipes: `water4{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 176.085 | 176.2425 | +0.089% | 176.085 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 176.0025 | 176.16 | +0.089% | 176.0025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 50.085 | 50.2425 | +0.314% | 50.085 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| statuses.wet | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-10 (scenario)

Recipes: `ice2`, `blood1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 96.13125 | 96.35625 | +0.234% | 96.13125 | 0% | (a) model/numerical difference: E1 |
| damage_capped | 96.13125 | 96.35625 | +0.234% | 96.13125 | 0% | (a) model/numerical difference: E1 |
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
| by_element.blood | 39.43125 | 39.65625 | +0.571% | 39.43125 | 0% | (a) model/numerical difference: E1 |
| statuses.slow | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 14 | 14 | 0% | 14 | 0% | equal |
| roots.using_1_applications | 14 | 14 | 0% | 14 | 0% | equal |

### v4-10-alone (comparison)

Recipes: `blood1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### v4-11 (scenario)

Recipes: `volcano3{lava_blob:[electric3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 466.827347 | 493.192854 | +5.648% | 466.827347 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 466.827347 | 493.192854 | +5.648% | 466.827347 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 50 | 54 | +8.000% | 50 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 17 | 19 | +11.765% | 17 | 0% | (a) model/numerical difference: E1, E4 |
| status_instances | 5 | 4 | -20.000% | 5 | 0% | (a) model/numerical difference: E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 16 | +6.667% | 15 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.lava | 295.785922 | 312.49134 | +5.648% | 295.785923 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| by_element.ice | 81.019622 | 85.595454 | +5.648% | 81.019622 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.electric | 90.021802 | 95.10606 | +5.648% | 90.021803 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| statuses.slow | 25 | 27 | +8.000% | 25 | 0% | (a) model/numerical difference: E1, E4 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 16 | +6.667% | 15 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_4_applications | 1 | 0 | -100.000% | 1 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_6_applications | 5 | 5 | 0% | 5 | 0% | equal |
| roots.using_8_applications | 2 | 3 | +50.000% | 2 | 0% | (a) model/numerical difference: E1, E4 |

### v4-12 (scenario)

Recipes: `volcano3{lava_blob:[electric3{chain:[fire3{burn:[ice2]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 468.820403 | 444.574614 | -5.172% | 478.165449 | +1.993% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 468.813379 | 444.574614 | -5.170% | 478.165449 | +1.995% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| mana | 2 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 8 | 6 | -25.000% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| applications | 124 | 103 | -16.935% | 115 | -7.258% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 41 | 40 | -2.439% | 47 | +14.634% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 5 | 6 | +20.000% | 6 | +20.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 16 | +6.667% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 283.365922 | 275.23134 | -2.871% | 287.65134 | +1.512% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 86.241802 | 83.76606 | -2.871% | 87.54606 | +1.512% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 73.930148 | 62.239494 | -15.813% | 72.823494 | -1.497% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 25.28253 | 23.33772 | -7.692% | 30.144555 | +19.231% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 15 | 16 | +6.667% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.slow | 26 | 24 | -7.692% | 31 | +19.231% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 16 | +6.667% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 61 | 8 | -86.885% | 13 | -78.689% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 84 | 63 | -25.000% | 73 | -13.095% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 76 | 55 | -27.632% | 65 | -14.474% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_4_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 6 | 8 | +33.333% | 7 | +16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_8_applications | 1 | 0 | -100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |

### v4-13 (scenario)

Recipes: `meteor2{meteor_area:[poison1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 125.1 | 195.57 | +56.331% | 125.1 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 125.1 | 195.57 | +56.331% | 125.1 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| max_budget_used | 2 | 4 | +100.000% | 2 | 0% | (a) model/numerical difference: E1, E4 |
| applications | 18 | 33 | +83.333% | 18 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 4 | 7 | +75.000% | 4 | 0% | (a) model/numerical difference: E1, E4 |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.impact | 93.6 | 135.72 | +45.000% | 93.6 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| by_element.poison | 31.5 | 59.85 | +90.000% | 31.5 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| statuses.poison | 4 | 7 | +75.000% | 4 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 14 | 23 | +64.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 10 | 19 | +90.000% | 10 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_2_applications | 4 | 1 | -75.000% | 4 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_4_applications | 0 | 3 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |

### v4-14 (scenario)

Recipes: `meteor3{meteor_fragments:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 179.506136 | 272.089818 | +51.577% | 179.506136 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 179.506136 | 272.089818 | +51.577% | 179.506136 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| max_budget_used | 14 | 16 | +14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| applications | 38 | 62 | +63.158% | 38 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 24 | +60.000% | 15 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.impact | 163.8 | 246.96 | +50.769% | 163.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| by_element.electric | 15.706136 | 25.129818 | +60.000% | 15.706136 | 0% | (a) model/numerical difference: E1, E4 |
| hops.parça sekerek | 10 | 16 | +60.000% | 10 | 0% | (a) model/numerical difference: E1, E4 |
| hops.parça | 5 | 8 | +60.000% | 5 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 3 | 0 | -100.000% | 3 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_14_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_16_applications | 0 | 3 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |

### v4-15 (scenario)

Recipes: `golem3{golem_punch:[fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 234.36 | 181.8 | -22.427% | 221.13 | -5.645% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 234.03 | 179.58 | -23.266% | 219.54 | -6.192% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
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
| applications | 49 | 26 | -46.939% | 31 | -36.735% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 138.6 | 118.8 | -14.286% | 138.6 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| by_element.fire | 95.76 | 63 | -34.211% | 82.53 | -13.816% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 8 | 5 | -37.500% | 7 | -12.500% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 27 | 7 | -74.074% | 9 | -66.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 49 | 26 | -46.939% | 31 | -36.735% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 49 | 26 | -46.939% | 31 | -36.735% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### v4-16 (scenario)

Recipes: `golem3{ground_slam:[ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 185.616 | 165.816 | -10.667% | 185.616 | 0% | (a) model/numerical difference: E1, E4 |
| damage_capped | 185.616 | 165.816 | -10.667% | 185.616 | 0% | (a) model/numerical difference: E1, E4 |
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
| applications | 16 | 14 | -12.500% | 16 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 3 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 16 | 14 | -12.500% | 16 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 158.4 | 138.6 | -12.500% | 158.4 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| by_element.ice | 27.216 | 27.216 | 0% | 27.216 | 0% | equal |
| statuses.slow | 8 | 8 | 0% | 8 | 0% | equal |
| roots.with_applications | 16 | 14 | -12.500% | 16 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 16 | 14 | -12.500% | 16 | 0% | (a) model/numerical difference: E1, E4 |

### v4-17 (scenario)

Recipes: `hive3{beetle_bite:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 169.65 | 164.205 | -3.210% | 169.65 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 169.635 | 164.19 | -3.210% | 169.635 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 135 | 130.5 | -3.333% | 135 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.blood | 34.65 | 33.705 | -2.727% | 34.65 | 0% | (a) model/numerical difference: E1, E4 |
| statuses.bleed | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |

### v4-18 (scenario)

Recipes: `hive3{beetle_bite:[poison2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 207.765 | 196.335 | -5.501% | 207.765 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 206.22 | 194.79 | -5.543% | 206.22 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 40 | 38 | -5.000% | 40 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 135 | 130.5 | -3.333% | 135 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.poison | 72.765 | 65.835 | -9.524% | 72.765 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| statuses.poison | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 40 | 38 | -5.000% | 40 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 40 | 38 | -5.000% | 40 | 0% | (a) model/numerical difference: E1, E4 |

### v4-19 (scenario)

Recipes: `light3{pierce:[poison1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 212.58 | 218.88 | +2.964% | 215.73 | +1.482% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
| damage_capped | 212.58 | 218.88 | +2.964% | 215.73 | +1.482% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
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
| applications | 41 | 43 | +4.878% | 42 | +2.439% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 18 | 18 | 0% | 18 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 9 | 0% | 9 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 9 | 9 | 0% | 9 | 0% | equal |
| by_element.light | 168.48 | 168.48 | 0% | 168.48 | 0% | equal |
| by_element.poison | 44.1 | 50.4 | +14.286% | 47.25 | +7.143% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
| statuses.blind | 18 | 18 | 0% | 18 | 0% | equal |
| statuses.poison | 9 | 9 | 0% | 9 | 0% | equal |
| hops.ışın deler | 9 | 9 | 0% | 9 | 0% | equal |
| roots.with_applications | 23 | 25 | +8.696% | 24 | +4.348% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
| roots.using_1_applications | 14 | 16 | +14.286% | 15 | +7.143% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
| roots.using_3_applications | 9 | 9 | 0% | 9 | 0% | equal |

### v4-20 (scenario)

Recipes: `stone3{fragments:[electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 188.685414 | 188.833039 | +0.078% | 188.928589 | +0.129% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
| damage_capped | 188.685414 | 188.833039 | +0.078% | 188.928589 | +0.129% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
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
| by_element.electric | 20.385414 | 20.533039 | +0.724% | 20.628589 | +1.193% | (a) model/numerical difference: E1, E3; (a) model/numerical difference: E3 |
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
| damage | 399.6 | 288.45 | -27.815% | 284.4 | -28.829% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 399.6 | 286.05 | -28.416% | 282 | -29.429% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| kills | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana | 0 | 2 | new (ref=0) | 2 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 129 | 74 | -42.636% | 73 | -43.411% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 6 | 9 | +50.000% | 9 | +50.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 308.25 | 209.7 | -31.971% | 205.65 | -33.285% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.poison | 91.35 | 78.75 | -13.793% | 78.75 | -13.793% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 7 | 6 | -14.286% | 6 | -14.286% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.poison | 78 | 30 | -61.538% | 30 | -61.538% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| fields.fire_trail | 44 | 10 | -77.273% | 10 | -77.273% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 129 | 74 | -42.636% | 73 | -43.411% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 129 | 74 | -42.636% | 73 | -43.411% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### v4-22 (scenario)

Recipes: `volcano5{lava_blob:[fire3,electric3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### v4-23 (scenario)

Recipes: `water1{water_hit:[blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 83.3175 | 83.475 | +0.189% | 83.3175 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 83.3175 | 83.475 | +0.189% | 83.3175 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 45.5175 | 45.675 | +0.346% | 45.5175 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| damage | 129.672 | 166.986 | +28.776% | 170.352 | +31.371% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 129.672 | 166.986 | +28.776% | 170.352 | +31.371% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 29 | 48 | +65.517% | 49 | +68.966% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 7 | +250.000% | 7 | +250.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 120.6 | 134.1 | +11.194% | 138.6 | +14.925% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.ice | 9.072 | 32.886 | +262.500% | 31.752 | +250.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.slow | 8 | 29 | +262.500% | 28 | +250.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| fields.fire_trail | 38 | 8 | -78.947% | 8 | -78.947% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 29 | 48 | +65.517% | 49 | +68.966% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 29 | 48 | +65.517% | 49 | +68.966% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

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
| damage | 160.5915 | 144.3915 | -10.088% | 144.3915 | -10.088% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 160.5915 | 144.3915 | -10.088% | 144.3915 | -10.088% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.arcane | 13.8915 | 13.8915 | 0% | 13.8915 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### mana-mark (scenario)

Recipes: `mana3`, `stone3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 246.3 | 246.3 | 0% | 246.3 | 0% | equal |
| damage_capped | 231.5 | 231.5 | 0% | 231.5 | 0% | equal |
| kills | 1 | 1 | 0% | 1 | 0% | equal |
| mana | 70.21 | 70.21 | 0% | 70.21 | 0% | equal |
| mana_siphon | 43.545 | 43.545 | 0% | 43.545 | 0% | equal |
| mana_mark | 24.665 | 24.665 | 0% | 24.665 | 0% | tolerance (floating arithmetic) |
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
| damage | 742.2 | 699.1 | -5.807% | 690.6 | -6.952% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 666.4 | 641.5 | -3.736% | 633 | -5.012% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| kills | 4 | 4 | 0% | 4 | 0% | equal |
| mana | 160.0875 | 157.0425 | -1.902% | 159.6675 | -0.262% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana_siphon | 83.2 | 84.6625 | +1.758% | 83.65 | +0.541% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana_mark | 68.8875 | 64.38 | -6.543% | 68.0175 | -1.263% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| stones | 12 | 12 | 0% | 12 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 99 | 75 | -24.242% | 72 | -27.273% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 22 | 22 | 0% | 22 | 0% | equal |
| status_instances | 17 | 17 | 0% | 17 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 21 | 21 | 0% | 21 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 11 | 11 | 0% | 11 | 0% | equal |
| by_element.arcane | 173.8 | 173.8 | 0% | 173.8 | 0% | equal |
| by_element.fire | 263.9 | 220.8 | -16.332% | 212.3 | -19.553% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.physical | 304.5 | 304.5 | 0% | 304.5 | 0% | equal |
| statuses.mana_mark | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.burn | 8 | 8 | 0% | 8 | 0% | equal |
| statuses.shred | 12 | 12 | 0% | 12 | 0% | equal |
| statuses.stun | 12 | 12 | 0% | 12 | 0% | equal |
| hops.parça | 11 | 11 | 0% | 11 | 0% | equal |
| fields.fire_trail | 22 | 8 | -63.636% | 7 | -68.182% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 77 | 53 | -31.169% | 50 | -35.065% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 72 | 48 | -33.333% | 45 | -37.500% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| hops.seker | 16 | 0 | -100.000% | 0 | -100.000% | (b) implementation difference: R1 |
| roots.with_applications | 15 | 15 | 0% | 15 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 16 | new (ref=0) | 16 | new (ref=0) | (b) implementation difference: R1 |

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
| hops.seker | 16 | 0 | -100.000% | 0 | -100.000% | (b) implementation difference: R1 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 16 | new (ref=0) | 16 | new (ref=0) | (b) implementation difference: R1 |

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
| damage | 217.701 | 190.1295 | -12.665% | 191.0295 | -12.251% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 213.7575 | 187.6575 | -12.210% | 188.5575 | -11.789% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
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
| applications | 58 | 35 | -39.655% | 36 | -37.931% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 124.2 | -15.337% | 125.1 | -14.724% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 71.001 | 65.9295 | -7.143% | 65.9295 | -7.143% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 58 | 35 | -39.655% | 36 | -37.931% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 58 | 35 | -39.655% | 36 | -37.931% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### rej-pierce-tick (scenario)

Recipes: `fire3{burn:[light3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 186.831 | 170.631 | -8.671% | 170.631 | -8.671% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 186.831 | 170.631 | -8.671% | 170.631 | -8.671% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 11 | 11 | 0% | 11 | 0% | equal |
| status_instances | 3 | 3 | 0% | 3 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.light | 40.131 | 40.131 | 0% | 40.131 | 0% | tolerance (floating arithmetic) |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.blind | 14 | 14 | 0% | 14 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### stress-24 (scenario)

Recipes: `fire5{fire_hit:[electric5{chain:[ice5{chill:[poison5,blood5]},stone3]},meteor3],burn:[electric3{chain:[ice2,water3]},poison4{poison_tick:[blood2]}],fire_trail:[ice3{freeze:[light3]},hive1,golem1,volcano2{lava_blob:[fire2,water2{wet:[electric2,poison1]}]},stone2{armor_shred:[light2]},blood1]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 739.359243 | 758.250325 | +2.555% | 744.451868 | +0.689% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 720 | 720 | 0% | 720 | 0% | tolerance (floating arithmetic) |
| kills | 6 | 6 | 0% | 6 | 0% | equal |
| mana | 12 | 12 | 0% | 12 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 6 | 6 | 0% | 6 | 0% | equal |
| frozen | 5 | 3 | -40.000% | 3 | -40.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 13 | 13 | 0% | 13 | 0% | equal |
| applications | 142 | 134 | -5.634% | 139 | -2.113% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 216 | 180 | -16.667% | 175 | -18.981% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 78 | 90 | +15.385% | 73 | -6.410% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| pushed_tiles | 1.004457 | 1.004457 | 0% | 1.004457 | 0% | tolerance (floating arithmetic) |
| seconds | 5.65 | 7.15 | +26.549% | 12.4 | +119.469% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| host_attacks | 3 | 4 | +33.333% | 3 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 24 | 27 | +12.500% | 25 | +4.167% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 175.141431 | 189.015992 | +7.922% | 133.575992 | -23.732% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 114.162571 | 131.722356 | +15.381% | 107.222636 | -6.079% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.impact | 77.115924 | 115.71338 | +50.051% | 78.54786 | +1.857% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 44.940139 | 36.69146 | -18.355% | 32.806779 | -26.999% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.physical | 61.310592 | 44.914634 | -26.742% | 41.627597 | -32.104% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.blood | 44.484046 | 49.9505 | +12.289% | 73.391785 | +64.985% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 42.547974 | 28.212534 | -33.692% | 28.212534 | -33.692% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.water | 21.950686 | 18.551146 | -15.487% | 18.551146 | -15.487% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.light | 71.05 | 47.63192 | -32.960% | 47.63192 | -32.960% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.poison | 86.655879 | 95.846403 | +10.606% | 182.883619 | +111.046% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 30 | 30 | 0% | 27 | -10.000% | (a) model/numerical difference: E2 |
| statuses.charge | 9 | 12 | +33.333% | 9 | 0% | (a) model/numerical difference: E2, E1, E4 |
| statuses.slow | 28 | 24 | -14.286% | 23 | -17.857% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.poison | 52 | 48 | -7.692% | 46 | -11.538% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.bleed | 24 | 19 | -20.833% | 22 | -8.333% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.cold | 20 | 16 | -20.000% | 15 | -25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.shred | 20 | 16 | -20.000% | 15 | -25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.blind | 18 | 13 | -27.778% | 13 | -27.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.wet | 21 | 18 | -14.286% | 18 | -14.286% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| hops.mermi sekerek | 6 | 7 | +16.667% | 6 | 0% | (a) model/numerical difference: E2, E1, E4 |
| hops.parça | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| hops.durum yandakine geçerek | 9 | 10 | +11.111% | 10 | +11.111% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| hops.durum yandakine atlayarak | 8 | 8 | 0% | 8 | 0% | equal |
| fields.fire_trail | 16 | 3 | -81.250% | 3 | -81.250% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 51 | 44 | -13.725% | 56 | +9.804% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 28 | 23 | -17.857% | 36 | +28.571% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 3 | 4 | +33.333% | 4 | +33.333% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_3_applications | 3 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_4_applications | 2 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 11 | 11 | 0% | 11 | 0% | equal |
| roots.using_6_applications | 2 | 3 | +50.000% | 3 | +50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_11_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_13_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_8_applications | 0 | 1 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_9_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

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
| damage | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
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
| applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 1 | 1 | 0% | 1 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 146.7 | 130.5 | -11.043% | 130.5 | -11.043% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 38 | 12 | -68.421% | 12 | -68.421% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 58 | 40 | -31.034% | 40 | -31.034% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### plain-fire5 (plain)

Recipes: `fire5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 308.25 | 221.4 | -28.175% | 219.15 | -28.905% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 308.25 | 219.9 | -28.662% | 217.65 | -29.392% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| kills | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana | 0 | 2 | new (ref=0) | 2 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 100 | 52 | -48.000% | 52 | -48.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 3 | +50.000% | 3 | +50.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.fire | 308.25 | 221.4 | -28.175% | 219.15 | -28.905% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 7 | 7 | 0% | 7 | 0% | equal |
| fields.fire_trail | 44 | 10 | -77.273% | 10 | -77.273% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 100 | 52 | -48.000% | 52 | -48.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 100 | 52 | -48.000% | 52 | -48.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

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
| hops.seker | 16 | 0 | -100.000% | 0 | -100.000% | (b) implementation difference: R1 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_5_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 16 | new (ref=0) | 16 | new (ref=0) | (b) implementation difference: R1 |

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
| status_instances | 5 | 5 | 0% | 6 | +20.000% | (a) model/numerical difference: E3 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 24 | 24 | 0% | 24 | 0% | equal |
| by_element.electric | 322.65 | 322.65 | 0% | 322.65 | 0% | tolerance (floating arithmetic) |
| statuses.charge | 32 | 32 | 0% | 32 | 0% | equal |
| hops.seker | 24 | 0 | -100.000% | 0 | -100.000% | (b) implementation difference: R1 |
| roots.with_applications | 8 | 8 | 0% | 8 | 0% | equal |
| roots.using_7_applications | 8 | 8 | 0% | 8 | 0% | equal |
| hops. | 0 | 24 | new (ref=0) | 24 | new (ref=0) | (b) implementation difference: R1 |

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
| damage | 144.9 | 151.2 | +4.348% | 144.9 | 0% | (a) model/numerical difference: E1 |
| damage_capped | 144.9 | 151.2 | +4.348% | 144.9 | 0% | (a) model/numerical difference: E1 |
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
| applications | 22 | 23 | +4.545% | 22 | 0% | (a) model/numerical difference: E1 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 2 | 2 | 0% | 2 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 7 | 7 | 0% | 7 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.poison | 144.9 | 151.2 | +4.348% | 144.9 | 0% | (a) model/numerical difference: E1 |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 22 | 23 | +4.545% | 22 | 0% | (a) model/numerical difference: E1 |
| roots.using_1_applications | 22 | 23 | +4.545% | 22 | 0% | (a) model/numerical difference: E1 |

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
| damage | 307.881 | 307.881 | 0% | 307.2006 | -0.221% | (a) model/numerical difference: E3 |
| damage_capped | 300.306 | 300.306 | 0% | 299.6256 | -0.227% | tolerance (floating arithmetic); (a) model/numerical difference: E3 |
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
| by_element.light | 307.881 | 307.881 | 0% | 307.2006 | -0.221% | (a) model/numerical difference: E3 |
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
| damage | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 65.025 | 65.25 | +0.346% | 65.025 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-blood3 (plain)

Recipes: `blood3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 136.85625 | 137.53125 | +0.493% | 136.85625 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 136.85625 | 137.53125 | +0.493% | 136.85625 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 136.85625 | 137.53125 | +0.493% | 136.85625 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| statuses.bleed | 7 | 7 | 0% | 7 | 0% | equal |
| roots.with_applications | 7 | 7 | 0% | 7 | 0% | equal |
| roots.using_1_applications | 7 | 7 | 0% | 7 | 0% | equal |

### plain-blood5 (plain)

Recipes: `blood5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 248.04 | 249.66 | +0.653% | 248.04 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
| damage_capped | 247.98 | 249.6 | +0.653% | 247.98 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| by_element.blood | 248.04 | 249.66 | +0.653% | 248.04 | 0% | (a) model/numerical difference: E1; tolerance (floating arithmetic) |
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
| damage | 163.8 | 246.96 | +50.769% | 163.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 163.8 | 246.96 | +50.769% | 163.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| max_budget_used | 6 | 8 | +33.333% | 6 | 0% | (a) model/numerical difference: E1, E4 |
| applications | 18 | 30 | +66.667% | 18 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 5 | 8 | +60.000% | 5 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.impact | 163.8 | 246.96 | +50.769% | 163.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| hops.parça | 5 | 8 | +60.000% | 5 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_4_applications | 3 | 0 | -100.000% | 3 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_6_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_8_applications | 0 | 3 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |

### plain-meteor5 (plain)

Recipes: `meteor5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 288 | 302.4 | +5.000% | 288 | 0% | (a) model/numerical difference: E1, E4 |
| damage_capped | 278.4 | 292.8 | +5.172% | 278.4 | 0% | (a) model/numerical difference: E1, E4 |
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
| max_budget_used | 8 | 13 | +62.500% | 8 | 0% | (a) model/numerical difference: E1, E4 |
| applications | 31 | 33 | +6.452% | 31 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 4 | 4 | 0% | 4 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 4 | 5 | +25.000% | 4 | 0% | (a) model/numerical difference: E1, E4 |
| by_element.impact | 288 | 302.4 | +5.000% | 288 | 0% | (a) model/numerical difference: E1, E4 |
| hops.parça | 4 | 5 | +25.000% | 4 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_7_applications | 1 | 0 | -100.000% | 1 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_8_applications | 3 | 1 | -66.667% | 3 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_2_applications | 0 | 1 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_10_applications | 0 | 1 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_13_applications | 0 | 1 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E1, E4 |

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
| damage | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
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
| applications | 27 | 31 | +14.815% | 30 | +11.111% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.lava | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 8 | 5 | -37.500% | 6 | -25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 19 | 23 | +21.053% | 22 | +15.789% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 11 | 15 | +36.364% | 14 | +27.273% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 8 | 8 | 0% | 8 | 0% | equal |

### plain-golem1 (plain)

Recipes: `golem1`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 64.8 | 57.6 | -11.111% | 64.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 64.8 | 57.6 | -11.111% | 64.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 9 | 8 | -11.111% | 9 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 9 | 8 | -11.111% | 9 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 64.8 | 57.6 | -11.111% | 64.8 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| roots.with_applications | 9 | 8 | -11.111% | 9 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 9 | 8 | -11.111% | 9 | 0% | (a) model/numerical difference: E1, E4 |

### plain-golem3 (plain)

Recipes: `golem3`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 138.6 | 118.8 | -14.286% | 138.6 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 138.6 | 118.8 | -14.286% | 138.6 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 138.6 | 118.8 | -14.286% | 138.6 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| roots.with_applications | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |

### plain-golem5 (plain)

Recipes: `golem5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 315 | 270 | -14.286% | 315 | 0% | (a) model/numerical difference: E1, E4 |
| damage_capped | 285 | 255 | -10.526% | 285 | 0% | (a) model/numerical difference: E1, E4 |
| kills | 2 | 1 | -50.000% | 2 | 0% | (a) model/numerical difference: E1, E4 |
| mana | 4 | 2 | -50.000% | 4 | 0% | (a) model/numerical difference: E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 2 | 1 | -50.000% | 2 | 0% | (a) model/numerical difference: E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_status_gen | 0 | 0 | 0% | 0 | 0% | equal |
| max_budget_used | 1 | 1 | 0% | 1 | 0% | equal |
| applications | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 315 | 270 | -14.286% | 315 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 14 | 12 | -14.286% | 14 | 0% | (a) model/numerical difference: E1, E4 |

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
| damage | 135 | 130.5 | -3.333% | 135 | 0% | (a) model/numerical difference: E1, E4 |
| damage_capped | 133.5 | 129 | -3.371% | 133.5 | 0% | (a) model/numerical difference: E1, E4 |
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
| applications | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 135 | 130.5 | -3.333% | 135 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 30 | 29 | -3.333% | 30 | 0% | (a) model/numerical difference: E1, E4 |

### plain-hive5 (plain)

Recipes: `hive5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 356.4 | 340.2 | -4.545% | 356.4 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 353.4 | 337.2 | -4.584% | 353.4 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 44 | 42 | -4.545% | 44 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 45 | 43 | -4.444% | 45 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 356.4 | 340.2 | -4.545% | 356.4 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| roots.with_applications | 44 | 42 | -4.545% | 44 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 44 | 42 | -4.545% | 44 | 0% | (a) model/numerical difference: E1, E4 |

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
| mana | 51.75 | 51.75 | 0% | 51.75 | 0% | equal |
| mana_siphon | 42.75 | 42.75 | 0% | 42.75 | 0% | equal |
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
| mana | 115.995 | 115.995 | 0% | 115.995 | 0% | equal |
| mana_siphon | 74.415 | 74.415 | 0% | 74.415 | 0% | equal |
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
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### shuffle-1 (probe)

Recipes: `volcano5{lava_blob:[fire3,ice2,electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### shuffle-2 (probe)

Recipes: `volcano5{lava_blob:[electric3,fire3,ice2]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### shuffle-3 (probe)

Recipes: `volcano5{lava_blob:[electric3,ice2,fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### shuffle-4 (probe)

Recipes: `volcano5{lava_blob:[ice2,fire3,electric3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### shuffle-5 (probe)

Recipes: `volcano5{lava_blob:[ice2,electric3,fire3]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 760.740282 | 740.312554 | -2.685% | 782.130058 | +2.812% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 701.506426 | 720 | +2.636% | 707.806426 | +0.898% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana | 10 | 12 | +20.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 5 | 0% | (a) model/numerical difference: E2, E1, E4 |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 1 | 1 | 0% | 1 | 0% | equal |
| max_budget_used | 7 | 7 | 0% | 7 | 0% | equal |
| applications | 90 | 79 | -12.222% | 90 | 0% | (a) model/numerical difference: E2, E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 26 | 24 | -7.692% | 30 | +15.385% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| status_instances | 10 | 11 | +10.000% | 10 | 0% | (a) model/numerical difference: E2, E1, E4 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 10.25 | -26.786% | 14 | 0% | (a) model/numerical difference: E2, E1, E4; tolerance (floating arithmetic) |
| host_attacks | 8 | 7 | -12.500% | 8 | 0% | (a) model/numerical difference: E2, E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.lava | 502.540043 | 484.162965 | -3.657% | 522.40662 | +3.953% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.fire | 126.205254 | 121.341654 | -3.854% | 125.250363 | -0.757% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.ice | 62.523941 | 63.856391 | +2.131% | 63.697772 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| by_element.electric | 69.471045 | 70.951545 | +2.131% | 70.775302 | +1.877% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| statuses.burn | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| statuses.slow | 19 | 19 | 0% | 21 | +10.526% | (a) model/numerical difference: E2 |
| hops.lav topu düşmandan düşmana zıplayarak | 15 | 13 | -13.333% | 16 | +6.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 6 | 4 | -33.333% | 5 | -16.667% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.fire_trail | 36 | 5 | -86.111% | 8 | -77.778% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 55 | 45 | -18.182% | 52 | -5.455% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 47 | 38 | -19.149% | 44 | -6.383% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_5_applications | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_6_applications | 4 | 3 | -25.000% | 5 | +25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_7_applications | 1 | 2 | +100.000% | 1 | 0% | (a) model/numerical difference: E2, E1, E4 |
| roots.using_4_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |

### deep3 (probe)

Recipes: `fire5{burn:[electric5{chain:[ice5{freeze:[poison4]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 718.232006 | 745.055773 | +3.735% | 701.862806 | -2.279% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 693.09294 | 718.296095 | +3.636% | 688.125635 | -0.717% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| kills | 5 | 5 | 0% | 4 | -20.000% | (a) model/numerical difference: E2 |
| mana | 10 | 10 | 0% | 8 | -20.000% | (a) model/numerical difference: E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 5 | 0% | 4 | -20.000% | (a) model/numerical difference: E2 |
| frozen | 15 | 15 | 0% | 15 | 0% | equal |
| nova_frozen | 10 | 10 | 0% | 10 | 0% | equal |
| shards | 2 | 1 | -50.000% | 2 | 0% | (a) model/numerical difference: E2, E1 |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 9 | 9 | 0% | 9 | 0% | equal |
| applications | 156 | 158 | +1.282% | 153 | -1.923% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 137 | 133 | -2.920% | 137 | 0% | (a) model/numerical difference: E2, E1 |
| status_instances | 23 | 21 | -8.696% | 23 | 0% | (a) model/numerical difference: E2, E1 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 14 | 0% | 14 | 0% | tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 27 | 24 | -11.111% | 27 | 0% | (a) model/numerical difference: E2, E1 |
| by_element.fire | 350.1 | 364.05 | +3.985% | 329.85 | -5.784% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 257.991391 | 278.930937 | +8.116% | 260.637391 | +1.026% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.ice | 78.035815 | 65.030836 | -16.665% | 78.035815 | 0% | (a) model/numerical difference: E2, E1; tolerance (floating arithmetic) |
| by_element.poison | 32.1048 | 37.044 | +15.385% | 33.3396 | +3.846% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 30 | 28 | -6.667% | 30 | 0% | (a) model/numerical difference: E2, E1 |
| statuses.charge | 61 | 62 | +1.639% | 61 | 0% | (a) model/numerical difference: E2, E1 |
| statuses.slow | 24 | 22 | -8.333% | 24 | 0% | (a) model/numerical difference: E2, E1 |
| statuses.cold | 24 | 22 | -8.333% | 24 | 0% | (a) model/numerical difference: E2, E1 |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| hops.durum yandakine atlayarak | 24 | 22 | -8.333% | 24 | 0% | (a) model/numerical difference: E2, E1 |
| hops.buz parçası düşer | 3 | 2 | -33.333% | 3 | 0% | (a) model/numerical difference: E2, E1 |
| fields.fire_trail | 62 | 13 | -79.032% | 13 | -79.032% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 101 | 107 | +5.941% | 97 | -3.960% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 90 | 98 | +8.889% | 86 | -4.444% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_2_applications | 2 | 0 | -100.000% | 1 | -50.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_5_applications | 1 | 0 | -100.000% | 1 | 0% | (a) model/numerical difference: E2, E1 |
| roots.using_6_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_9_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |

### deep4 (probe)

Recipes: `fire5{burn:[electric5{chain:[ice5{freeze:[poison4{poison_tick:[blood2]}]}]}]}`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 720.427958 | 755.26366 | +4.835% | 708.159879 | -1.703% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| damage_capped | 693.09294 | 720 | +3.882% | 692.569428 | -0.076% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| kills | 5 | 6 | +20.000% | 4 | -20.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana | 10 | 12 | +20.000% | 8 | -20.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 5 | 6 | +20.000% | 4 | -20.000% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| frozen | 15 | 15 | 0% | 15 | 0% | equal |
| nova_frozen | 10 | 10 | 0% | 10 | 0% | equal |
| shards | 2 | 2 | 0% | 2 | 0% | equal |
| max_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_status_gen | 2 | 2 | 0% | 2 | 0% | equal |
| max_budget_used | 9 | 9 | 0% | 9 | 0% | equal |
| applications | 151 | 156 | +3.311% | 149 | -1.325% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 141 | 146 | +3.546% | 146 | +3.546% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| status_instances | 26 | 24 | -7.692% | 26 | 0% | (a) model/numerical difference: E2, E1 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 14 | 13.4 | -4.286% | 14 | 0% | (a) model/numerical difference: E2, E1; tolerance (floating arithmetic) |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 26 | 25 | -3.846% | 27 | +3.846% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.fire | 346.05 | 358.2 | +3.511% | 321.75 | -7.022% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.electric | 251.970087 | 276.284937 | +9.650% | 255.345391 | +1.340% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.ice | 72.527836 | 72.527836 | 0% | 76.139626 | +4.980% | tolerance (floating arithmetic); (a) model/numerical difference: E2 |
| by_element.poison | 32.1048 | 34.5744 | +7.692% | 37.044 | +15.385% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| by_element.blood | 17.775235 | 13.676487 | -23.059% | 17.880863 | +0.594% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.burn | 28 | 28 | 0% | 29 | +3.571% | (a) model/numerical difference: E2 |
| statuses.charge | 59 | 62 | +5.085% | 60 | +1.695% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| statuses.slow | 22 | 22 | 0% | 23 | +4.545% | (a) model/numerical difference: E2 |
| statuses.cold | 22 | 22 | 0% | 23 | +4.545% | (a) model/numerical difference: E2 |
| statuses.poison | 7 | 7 | 0% | 7 | 0% | equal |
| statuses.bleed | 12 | 13 | +8.333% | 13 | +8.333% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| hops.durum yandakine atlayarak | 23 | 22 | -4.348% | 24 | +4.348% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| hops.buz parçası düşer | 3 | 3 | 0% | 3 | 0% | equal |
| fields.fire_trail | 62 | 13 | -79.032% | 13 | -79.032% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.with_applications | 99 | 104 | +5.051% | 95 | -4.040% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_1_applications | 88 | 94 | +6.818% | 84 | -4.545% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_2_applications | 3 | 1 | -66.667% | 2 | -33.333% | (a) model/numerical difference: E2, E1; (a) model/numerical difference: E2 |
| roots.using_6_applications | 2 | 2 | 0% | 2 | 0% | equal |
| roots.using_7_applications | 4 | 4 | 0% | 4 | 0% | equal |
| roots.using_8_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_9_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 0 | 1 | new (ref=0) | 0 | 0% | (a) model/numerical difference: E2, E1 |
| roots.using_4_applications | 0 | 0 | 0% | 1 | new (ref=0) | (a) model/numerical difference: E2 |

### summon-loop-volcano (probe)

Recipes: `volcano5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| damage_capped | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
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
| applications | 27 | 31 | +14.815% | 30 | +11.111% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 21 | 21.05 | +0.238% | 21.05 | +0.238% | (a) model/numerical difference: E3 |
| host_attacks | 8 | 8 | 0% | 8 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.lava | 315.45 | 328.05 | +3.994% | 324.9 | +2.996% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| fields.lava_pool | 8 | 5 | -37.500% | 6 | -25.000% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.with_applications | 19 | 23 | +21.053% | 22 | +15.789% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_1_applications | 11 | 15 | +36.364% | 14 | +27.273% | (a) model/numerical difference: E2, E1, E4; (a) model/numerical difference: E2 |
| roots.using_2_applications | 8 | 8 | 0% | 8 | 0% | equal |

### summon-loop-golem (probe)

Recipes: `golem5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 405 | 382.5 | -5.556% | 405 | 0% | (a) model/numerical difference: E1, E4 |
| damage_capped | 405 | 382.5 | -5.556% | 405 | 0% | (a) model/numerical difference: E1, E4 |
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
| applications | 18 | 17 | -5.556% | 18 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 21 | 21.05 | +0.238% | 21.05 | +0.238% | (a) model/numerical difference: E3 |
| host_attacks | 18 | 17 | -5.556% | 18 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 405 | 382.5 | -5.556% | 405 | 0% | (a) model/numerical difference: E1, E4 |
| roots.with_applications | 18 | 17 | -5.556% | 18 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 18 | 17 | -5.556% | 18 | 0% | (a) model/numerical difference: E1, E4 |

### summon-loop-hive (probe)

Recipes: `hive5`

| Metric | Python | Godot grid | Δ grid | Godot replay | Δ replay | Classification of differing cells |
|---|---:|---:|---:|---:|---:|---|
| damage | 502.2 | 494.1 | -1.613% | 502.2 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| damage_capped | 502.2 | 494.1 | -1.613% | 502.2 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
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
| applications | 62 | 61 | -1.613% | 62 | 0% | (a) model/numerical difference: E1, E4 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 0 | 0 | 0% | 0 | 0% | equal |
| status_instances | 0 | 0 | 0% | 0 | 0% | equal |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 21 | 21.05 | +0.238% | 21.05 | +0.238% | (a) model/numerical difference: E3 |
| host_attacks | 62 | 61 | -1.613% | 62 | 0% | (a) model/numerical difference: E1, E4 |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 0 | 0 | 0% | 0 | 0% | equal |
| by_element.physical | 502.2 | 494.1 | -1.613% | 502.2 | 0% | (a) model/numerical difference: E1, E4; tolerance (floating arithmetic) |
| roots.with_applications | 62 | 61 | -1.613% | 62 | 0% | (a) model/numerical difference: E1, E4 |
| roots.using_1_applications | 62 | 61 | -1.613% | 62 | 0% | (a) model/numerical difference: E1, E4 |

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
| damage | 18.72 | 11.7 | -37.500% | 11.7 | -37.500% | (a) model/numerical difference: E3 |
| damage_capped | 18.72 | 11.7 | -37.500% | 11.7 | -37.500% | (a) model/numerical difference: E3 |
| kills | 0 | 0 | 0% | 0 | 0% | equal |
| mana | 0 | 0 | 0% | 0 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 0 | 0 | 0% | 0 | 0% | equal |
| stones | 0 | 0 | 0% | 0 | 0% | equal |
| frozen | 0 | 0 | 0% | 0 | 0% | equal |
| nova_frozen | 0 | 0 | 0% | 0 | 0% | equal |
| shards | 0 | 0 | 0% | 0 | 0% | equal |
| max_gen | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E3 |
| max_status_gen | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E3 |
| max_budget_used | 3 | 1 | -66.667% | 1 | -66.667% | (a) model/numerical difference: E3 |
| applications | 3 | 1 | -66.667% | 1 | -66.667% | (a) model/numerical difference: E3 |
| rejected_events | 0 | 0 | 0% | 0 | 0% | equal |
| spread_status | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E3 |
| status_instances | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E3 |
| pushed_tiles | 0 | 0 | 0% | 0 | 0% | equal |
| seconds | 0 | 0 | 0% | 0 | 0% | equal |
| host_attacks | 0 | 0 | 0% | 0 | 0% | equal |
| finite | true | true | 0 | true | 0 | equal |
| hops.total | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E3 |
| by_element.light | 18.72 | 11.7 | -37.500% | 11.7 | -37.500% | (a) model/numerical difference: E3 |
| statuses.blind | 2 | 1 | -50.000% | 1 | -50.000% | (a) model/numerical difference: E3 |
| hops.ışın deler | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E3 |
| roots.with_applications | 1 | 1 | 0% | 1 | 0% | equal |
| roots.using_3_applications | 1 | 0 | -100.000% | 0 | -100.000% | (a) model/numerical difference: E3 |
| roots.using_1_applications | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E3 |

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
| rejected_events | 21 | 19 | -9.524% | 19 | -9.524% | (a) model/numerical difference: E3 |
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
| mana | 7.2 | 7.2 | 0% | 7.2 | 0% | equal |
| mana_siphon | 0 | 0 | 0% | 0 | 0% | equal |
| mana_mark | 7.2 | 7.2 | 0% | 7.2 | 0% | equal |
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
| mana | 8.325 | 8.325 | 0% | 8.325 | 0% | equal |
| mana_siphon | 7.875 | 7.875 | 0% | 7.875 | 0% | equal |
| mana_mark | 0.45 | 0.45 | 0% | 0.45 | 0% | equal |
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
| mana | 6.533025 | 6.533025 | 0% | 6.533025 | 0% | equal |
| mana_siphon | 6.533025 | 6.533025 | 0% | 6.533025 | 0% | equal |
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
| fields.fire_trail | 0 | 1 | new (ref=0) | 1 | new (ref=0) | (a) model/numerical difference: E2 |

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

## Commit delta: 94a1c1a → 5065a12

Same 147 cases / 110 combat cases. Full metric and raw-state changes are in results/commit-deltas.json and results/raw-commit-deltas.json. No parity transitions remain in results/parity-transitions.json.

| Stream | Materially changed cases / 110 | Material metric changes |
|---|---:|---:|
| Python | 7 | 16 |
| grid | 7 | 16 |
| replay | 7 | 16 |

| Stream / case | Metric | Before → after | Reason |
|---|---|---:|---|
| Python / mana-mark | mana | 84.745 → 70.21 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mana-mark | mana_mark | 32.12 → 24.665 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mana-mark | mana_siphon | 50.625 → 43.545 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mana-crystal | mana | 209.1375 → 160.0875 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mana-crystal | mana_mark | 91.6875 → 68.8875 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mana-crystal | mana_siphon | 109.45 → 83.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / plain-mana3 | mana | 58.5 → 51.75 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / plain-mana3 | mana_siphon | 49.5 → 42.75 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / plain-mana5 | mana | 147.18 → 115.995 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / plain-mana5 | mana_siphon | 105.6 → 74.415 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mark-cap-distinct-towers | mana | 6.3 → 7.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / mark-cap-distinct-towers | mana_mark | 6.3 → 7.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / cap-shared-node-channels | mana | 9.675 → 8.325 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / cap-shared-node-channels | mana_mark | 1.8 → 0.45 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / siphon-two-nodes | mana | 4.658025 → 6.533025 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| Python / siphon-two-nodes | mana_siphon | 4.658025 → 6.533025 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / cap-shared-node-channels | mana | 9.675 → 8.325 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / cap-shared-node-channels | mana_mark | 1.8 → 0.45 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mana-crystal | mana | 207.03 → 157.0425 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mana-crystal | mana_mark | 89.58 → 64.38 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mana-crystal | mana_siphon | 109.45 → 84.6625 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mana-mark | mana | 84.745 → 70.21 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mana-mark | mana_mark | 32.12 → 24.665 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mana-mark | mana_siphon | 50.625 → 43.545 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mark-cap-distinct-towers | mana | 6.3 → 7.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / mark-cap-distinct-towers | mana_mark | 6.3 → 7.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / plain-mana3 | mana | 58.5 → 51.75 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / plain-mana3 | mana_siphon | 49.5 → 42.75 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / plain-mana5 | mana | 147.18 → 115.995 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / plain-mana5 | mana_siphon | 105.6 → 74.415 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / siphon-two-nodes | mana | 4.658025 → 6.533025 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| grid / siphon-two-nodes | mana_siphon | 4.658025 → 6.533025 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / cap-shared-node-channels | mana | 9.675 → 8.325 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / cap-shared-node-channels | mana_mark | 1.8 → 0.45 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mana-crystal | mana | 206.4675 → 159.6675 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mana-crystal | mana_mark | 89.0175 → 68.0175 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mana-crystal | mana_siphon | 109.45 → 83.65 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mana-mark | mana | 84.745 → 70.21 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mana-mark | mana_mark | 32.12 → 24.665 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mana-mark | mana_siphon | 50.625 → 43.545 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mark-cap-distinct-towers | mana | 6.3 → 7.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / mark-cap-distinct-towers | mana_mark | 6.3 → 7.2 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / plain-mana3 | mana | 58.5 → 51.75 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / plain-mana3 | mana_siphon | 49.5 → 42.75 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / plain-mana5 | mana | 147.18 → 115.995 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / plain-mana5 | mana_siphon | 105.6 → 74.415 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / siphon-two-nodes | mana | 4.658025 → 6.533025 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
| replay / siphon-two-nodes | mana_siphon | 4.658025 → 6.533025 | N1-N3 producing-node cap repair; economy channels now share one node bucket |
