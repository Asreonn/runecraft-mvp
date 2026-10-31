# RuneCraft — Mana rune economy, measured in the Godot game

Probe: `godot --headless --fixed-fps 60 --path . -- --econ <variant> [--front] --seed 3 --waves 8` (map seed 3, 3×).
Three fixed towers (Fire G3, Ice G3, Electric G3) plus one variant tower near the path; mana is never spent.
Cells: rune mana / total mana gained in that wave (passive +3/s, +2 per kill, rune mana). Wave 5 has a boss.
Rules: overkill excluded, one soft income cap per producing Mana node (2.5 / 4 / 6 / 8 / 11 mana/s, 25 % above).
Values are **provisional** (see `design/DECISIONS.md`).

## Variant tower first on the path (`--front`) — it meets every enemy

| Variant | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Σ rune mana | Σ total | vs none | castle HP |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 0 / 89 | 0 / 93 | 0 / 184 | 0 / 194 | 0 / 374 | 0 / 284 | 0 / 342 | 0 / 343 | 0 | 1904 | +0% | 14 |
| mana1 | 0 / 89 | 0 / 93 | 10 / 186 | 17 / 205 | 57 / 419 | 44 / 317 | 57 / 391 | 58 / 401 | 244 | 2101 | +10% | 15 |
| mana3 | 0 / 89 | 0 / 93 | 19 / 186 | 42 / 221 | 192 / 511 | 107 / 372 | 160 / 478 | 169 / 515 | 689 | 2467 | +30% | 17 |
| mana5 | 0 / 89 | 0 / 93 | 26 / 189 | 52 / 223 | 320 / 583 | 225 / 435 | 304 / 591 | 330 / 670 | 1256 | 2873 | +51% | 20 |
| fire3+mana5 | 0 / 89 | 0 / 93 | 20 / 183 | 38 / 206 | 235 / 488 | 166 / 368 | 304 / 539 | 291 / 594 | 1053 | 2561 | +35% | 20 |

## Variant tower last on the path — earlier towers kill most enemies first

| Variant | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Σ rune mana | Σ total | vs none | castle HP |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | 0 / 89 | 0 / 93 | 0 / 165 | 0 / 172 | 0 / 276 | 0 / 217 | 0 / 341 | 0 / 335 | 0 | 1689 | +0% | 8 |
| mana1 | 0 / 89 | 0 / 93 | 0 / 165 | 0 / 172 | 0 / 276 | 0 / 217 | 49 / 390 | 74 / 415 | 123 | 1818 | +8% | 11 |
| mana3 | 0 / 89 | 0 / 93 | 0 / 165 | 0 / 172 | 0 / 276 | 0 / 217 | 108 / 428 | 207 / 551 | 314 | 1992 | +18% | 16 |
| mana5 | 0 / 89 | 0 / 93 | 0 / 165 | 0 / 172 | 0 / 276 | 0 / 217 | 113 / 396 | 300 / 615 | 413 | 2024 | +20% | 20 |
| fire3+mana5 | 0 / 89 | 0 / 93 | 0 / 165 | 0 / 172 | 0 / 276 | 0 / 217 | 72 / 355 | 201 / 499 | 273 | 1867 | +11% | 20 |

## Reading

- The Mana rune's value grows clearly with grade (front placement over 8 waves: see the `vs none` column).
- Grafting Mana G5 onto a Fire G3 hit gives most of the dedicated tower's rune mana while keeping Fire's damage.
- Placement matters: a Mana tower behind strong towers earns little (it only damages what survives).
- No runaway loop: per-node caps and overkill exclusion bound the income.
