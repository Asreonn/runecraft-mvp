# RuneCraft — Mana rune economy, measured in the Godot game

Probe: `godot --headless --fixed-fps 60 --path . -- --econ <variant> [--front] --seed 3 --waves 8` (map seed 3, game speed 3×).
Three fixed towers (Fire G3, Ice G3, Electric G3) plus one variant tower near the path; mana is never spent.
Cells: rune mana / total mana gained in that wave (passive +3/s, +2 per kill, rune mana). Wave 5 has a boss.
Values are **provisional** (see `design/DECISIONS.md`).

## Variant tower first on the path (`--front`) — it meets every enemy

| Variant | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Σ rune mana | Σ total | vs none | castle HP |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 0 / 89 | 0 / 93 | 0 / 184 | 0 / 194 | 0 / 374 | 0 / 284 | 0 / 342 | 0 / 343 | 0 | 1904 | +0% | 14 |
| mana1 | 0 / 89 | 0 / 93 | 10 / 186 | 17 / 205 | 57 / 419 | 44 / 317 | 57 / 391 | 58 / 401 | 244 | 2101 | +10% | 15 |
| mana3 | 0 / 89 | 0 / 93 | 22 / 190 | 50 / 229 | 237 / 556 | 120 / 385 | 182 / 501 | 188 / 535 | 800 | 2578 | +35% | 17 |
| mana5 | 0 / 89 | 0 / 93 | 31 / 194 | 59 / 231 | 403 / 666 | 249 / 459 | 339 / 626 | 377 / 717 | 1458 | 3075 | +62% | 20 |
| fire3+mana5 | 0 / 89 | 0 / 93 | 21 / 185 | 45 / 212 | 282 / 535 | 181 / 384 | 341 / 576 | 322 / 626 | 1192 | 2700 | +42% | 20 |

## Variant tower last on the path — earlier towers kill most enemies first

| Variant | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Σ rune mana | Σ total | vs none | castle HP |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 0 / 89 | 0 / 93 | 0 / 164 | 0 / 172 | 0 / 276 | 0 / 217 | 0 / 341 | 0 / 335 | 0 | 1688 | +0% | 8 |
| mana1 | 0 / 89 | 0 / 93 | 0 / 164 | 0 / 172 | 0 / 276 | 0 / 217 | 49 / 390 | 73 / 414 | 122 | 1816 | +8% | 11 |
| mana3 | 0 / 89 | 0 / 93 | 0 / 164 | 0 / 172 | 0 / 276 | 0 / 217 | 117 / 436 | 224 / 568 | 340 | 2017 | +19% | 16 |
| mana5 | 0 / 89 | 0 / 93 | 0 / 164 | 0 / 172 | 0 / 276 | 0 / 217 | 128 / 411 | 339 / 654 | 467 | 2077 | +23% | 20 |
| fire3+mana5 | 0 / 89 | 0 / 93 | 0 / 164 | 0 / 172 | 0 / 276 | 0 / 217 | 77 / 360 | 206 / 499 | 283 | 1872 | +11% | 20 |

## Reading

- The Mana rune's value grows clearly with grade: up front, G1 adds ~+11 % total mana over 8 waves, G3 ~+35 %, G5 ~+62 %.
- Grafting Mana G5 onto a Fire G3 hit gives ~80 % of the dedicated tower's rune mana while keeping Fire's damage.
- Placement matters: a Mana tower behind strong towers earns little (it only damages what survives).
- No runaway loop: per-node income caps (2.5 / 4 / 6 / 8 / 11 mana/s, 25 % above cap) and overkill exclusion bound
  the income; a G5 tower's rune mana stays in the same order of magnitude as passive regen + kill mana.
