# Economy and status-stacking measurements (2026-10-31)

Measured by Codex c1 on commit **5065a12** (Godot 4.7.2, `--headless --fixed-fps 60`, 3× speed). Production game
code; fixture towers and runes only. Raw data, probes and exact commands stay in the measurement workspace
(`asset-work/codex-mvp/econ_stacking/` in the parent project — not part of this repo). This page summarises the
results and lists what changed afterwards.

## A. Mana rune by grade and placement

108 complete eight-wave runs (seeds 3 / 17 / 42). Fire G3 / Ice G3 / Electric G3 support towers stay fixed; one
variant tower sits at 8 % (front), 50 % (middle) or 92 % (back) of the path. "vs none" = total mana gained compared
with the same seed without the variant.

| Placement | Rune | Rune mana | Total mana | vs none |
|---|---|---|---|---|
| front | Mana G1 / G3 / G5 | 479 / 1,307 / 2,415 | 2,463 / 3,197 / 4,067 | +19.8 % / +55.4 % / +97.7 % |
| middle | Mana G1 / G3 / G5 | 267 / 767 / 1,255 | 2,269 / 2,701 / 3,091 | +10.5 % / +31.8 % / +51.0 % |
| back | Mana G1 / G3 / G5 | 95 / 259 / 382 | 2,139 / 2,280 / 2,366 | +4.0 % / +10.9 % / +15.1 % |

- Grade matters clearly; **placement matters about 5×** (front vs back, G3).
- Per-wave income grows with enemy HP and count (wave HP ×1.22 per wave), not with any reinvestment loop.

## B. Several Mana nodes / carriers

| Recipe (one per tower) | 1 tower | 2 | 4 | 6 | 6 ÷ 1 |
|---|---|---|---|---|---|
| `mana3` | 1,307 | 2,325 | 3,432 | 3,834 | 2.93× |
| `fire3{fire_hit:[mana3,mana3]}` | 2,308 | 3,512 | 4,061 | 4,126 | 1.79× |
| `fire3{fire_hit:[electric3{chain:[mana3]}]}` | 255 | 342 | 356 | 356 | 1.39× |
| `fire4{fire_trail:[mana3]}` | 730 | 783 | 637 | 588 | 0.81× |
| `volcano3{lava_blob:[mana3]}` | 1,007 | 1,359 | 1,486 | 1,489 | 1.48× |
| `hive3{beetle_bite:[mana3]}` | 1,495 | 1,705 | 1,829 | 1,844 | 1.23× |

Several towers grow **sublinearly**: they share a finite pool of enemy HP and kill faster. No runaway in eight waves.

### Open risk: recipe width (needs a decision)

One Fire hit with 1 → 64 Mana G3 donors on the same ability: **7 → 940 mana per hit** (134× for 64×). Every donor
siphons the *whole* event's damage into its own capped bucket, so mana grows roughly with n². Graft fees rise ×1.3
per node, so very wide recipes are expensive, but their payback is not measured. **Recommendation:** add one total
Mana cap per tower (for example the highest node cap × 1.5) on top of the per-node caps. Not changed — the economy
numbers are not changed without the user's approval.

## C. Shop loops

- Rune prices: 40, 46, 53, 61, 70, 80, 93, 106, 120 (cap ×3 at the 9th purchase); each cleared wave halves the
  purchase count (120 → 80 → 53 → 46 → 40).
- Towers 4, 5, 6, 8, 10, 12. Selling refunds `floor(½ · min(paid, rebuild))`, so **every sell → rebuy loses stones**
  (448 refund fixtures, 10 build/sell cycles: −20 stones).
- Runes cannot be sold; selling a tower returns its rune intact. Failed purchases charge nothing.
- **No profit loop found.**

## D. Same status from two towers — before and after

Isolated fixture: tower A applies at t = 0, tower B at t = 0.5, one high-HP enemy, 10 s.

| Status | One tower | Two identical towers, before | Independent (analytic) | Rule now |
|---|---|---|---|---|
| burn | 9 | 9 (B only refreshed A; all credit to A) | 18 | **per tower** → two instances |
| poison | 28 | 42 (stacks merged, all credit to A) | 56 | **per tower** |
| bleed | 15 | 20.6 | 30 | **per tower** |
| slow / wet / shred / blind / lit | — | one instance, strongest wins | multiplying | **unchanged** (strongest wins) |
| mana mark | 8 mana | 8 (last tower got it) | 16 | **unchanged** (one per node, strongest) |

The user approved Claude's recommendation (decision 10 in `design/DECISIONS.md`): damage-over-time statuses are one
instance per tower, utility statuses never multiply. Implemented in `scripts/combat.gd` (`apply_status`) and in the
Python reference `sim.py`; tested in `tests/test_ownership.gd` and `test_mechanics.py run_ownership()`.

### Accounting bugs found and fixed

| Bug | Before | Now |
|---|---|---|
| Poison contagion | the spread poison and its grafts (incl. Mana) were credited to the **killer** | credited to the poisoning tower |
| Frozen-death shards | shard damage and grafts credited to the **killer** | credited to the freezing tower (`enemy.frozen_tower`) |
| Crystal grafts | inherited the killer's context (static risk) | credited to the marking tower |

Both engines; covered by the new tests. These were misattributions (who gets the credit / which Mana cap), never
double counting.

### Also fixed from this measurement

- `vfx.gd` projectile / lava callbacks captured enemies that could be freed in flight; Godot logged
  "Lambda capture … was freed" in 70 of the 108 runs. Callbacks now capture instance ids.

## Not measured

Campaigns longer than eight waves, net return of buying high-grade grafts, randomised recipe fuzzing, save/load
manipulation. The eight-wave tables above were measured **before** the per-tower DoT rule. A check after it: the built-in probe
`--econ mana3 --front --seed 3 --waves 8` gives the same 688.7 rune mana / 2466.7 total / castle HP 17 (no
duplicate DoTs in that layout), with no callback errors. A full 108-run re-measurement was not repeated.
