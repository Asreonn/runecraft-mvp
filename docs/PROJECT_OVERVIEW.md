# RuneCraft MVP — project overview (for reviewers and planning agents)

RuneCraft is a voxel tower-defense prototype built in Godot 4.7 (GL Compatibility renderer, GDScript only).
- **Core idea.** Towers have no fixed type. Each tower holds one **rune**.
- **Grades.** Runes grow by **combining** two equal runes (G1 → G5). Each grade unlocks one distinct ability.
- **Grafting.** Runes can be **grafted** into each other's abilities without limit. A rule compiler resolves every
  combination automatically; there is no pair-specific code.

The user's original Turkish notes, requests and their status live in [`TODO.md`](../TODO.md). That file is the
authoritative list of what was asked and what is done.

## Running and checking

```sh
godot --path .                                                # play
godot --path . -- --seed 42                                   # a specific random map
godot --headless --path . -- --demo --auto --quit-after 120   # scripted session; prints AUTO lines per wave
godot --headless --path . -- --demo --savetest --seed 9       # save -> reload -> compare state
python3 design/rune_mechanics/mechanics/test_mechanics.py     # rule-compiler reference tests (121)
```

Command-line flags (after `--`) are parsed in `scripts/game.gd` `_parse_args`:

| Flag | Effect |
|---|---|
| `--seed N` | fixed map |
| `--demo` | scripted resources, towers and a craft |
| `--auto` | auto-starts waves |
| `--shots DIR` | saves screenshots |
| `--tabs` | captures every right-panel tab |
| `--burst` | close-up combat captures |
| `--quit-after S` | quits after S seconds |

## Architecture (file map)

| File | Responsibility |
|---|---|
| `scripts/game.gd` | Hub: world setup, camera, economy (mana, mana stones), waves, building, inventory, combine, craft table, grid helpers and indicators, settings, save/load, demo and capture modes. Game speed scales only the simulation (`time_mult()`); UI and camera run in real time. |
| `scripts/map_gen.gd` | Pure-data deterministic map generator. Produces the path, a meandering river with one bridge, plateaus with stairs, a mountain cluster, forests of one tree per tile (size by forest depth), props anchored on the voxel grid, and an 8-tile decorative apron. 300/300 seed test in the Codex worker repo. |
| `scripts/world_builder.gd` | Turns map data into 3D nodes. The playable map uses individual nodes; the apron is batched with MultiMesh. Also builds the enemy path curve and the castle. |
| `scripts/camera_rig.gd` | Orthographic 45° camera. WASD arcade pan, wheel zoom at the cursor, middle-drag, Q/E 90° snaps. Analytic bounds keep the view inside the tiled area. |
| `scripts/rune_lib.gd` + `scripts/locale/{en,tr}.json` | Rule compiler (GDScript port of `design/rune_mechanics/mechanics/resolver.py`): parse, canonical recipe, compile to per-event op lists, describe (localised), cost, graft checks. |
| `scripts/combat.gd` | Runtime twin of `sim.py`. Executes compiled ops: damage, statuses, chains, pierce, area, fragments, forced moves, ground fields (one grid cell each), mana siphon, deaths. |
| `scripts/tower.gd` | One rune per tower. Picks the attack kind from the compiled program (projectile, beam, meteor, volcano, golem, hive). Targeting is cell-based. Summons snap to cell centres. |
| `scripts/enemy.gd` | Path follower with statuses, tint and HP bar. |
| `scripts/vfx.gd` | Projectiles, chain/hop visuals, sprites (Penpot `vfx_*` textures), fields, damage numbers. |
| `scripts/grid_overlay.gd` | Cell-set overlay used for ranges, build coverage and drop targets. |
| `scripts/glb.gd` | Runtime GLB loader with cache. Assets sit in a `.gdignore` folder, so no editor import step is needed. |
| `ui/hud.gd` | HUD v4. Top-left: naked resource bars. Top-centre: wave counter, enemies left, pause and speed, next-wave row. Right panel tabs: Craft, Shop, Menu (the Menu tab pauses the game). Also the tower card, tooltip, banner and drag hints. |
| `ui/craft_table.gd` | Runic craft table: base rune, ability slots, output, craft animation. |
| `ui/slot.gd`, `ui/drag_preview.gd`, `ui/world_input.gd` | Drag and drop, drop-target glow, "what happens" hint chip, rune-onto-tower preview. |
| `ui/skin.gd`, `ui/tex_box.gd` | Load the Penpot-exported @2x textures (`assets/ui`) and draw them as 9-slice StyleBoxes. |
| `data/rune_mechanics_v1.json` | The rune spec: runes, grades, abilities, carriers, coefficients, budgets, economy, balance. Same file as `design/rune_mechanics/spec/`. |

## Design sources

- **Rune mechanics.**
  - Design doc: `design/RUNE_MECHANICS.md` (Turkish).
  - Reference implementation and tests: `design/rune_mechanics/`.
  - Generated reports: `design/rune_mechanics/reports/` — balance, 24 scenario walkthroughs, rune cards.
- **Original GDD and briefs.** `design/source_package/`. User decisions recorded in `TODO.md` and
  `RUNE_MECHANICS.md` override the GDD where they differ.
- **UI.**
  - Designed in Penpot (page "HUD v3 · Stone", token set `runecraft-stone`; not in this repo).
  - The Penpot-side generator is `ui_design/penpot_stone_v4.js`.
  - Every board named `rcui / <name>` is exported at 2× and pulled with `ui_design/pull_penpot_exports.sh` into
    `assets/ui/`.
  - Rule: **do not draw UI art procedurally in code — design it in Penpot and export.**
  - Visual language: chunky faceted rock blocks in the terrain rock palette, moss, rune-teal glow, dark readable
    insides. Not bricks.
- **Voxel art.** Tiles, props, runes, units and summons are GLB exports of project-made `.vox` sources. The sources
  live in the parent (non-public) project; this repo only carries the runtime GLBs.

## Gameplay systems (current state)

- **Economy.**
  - Mana: +3/s, +2 per kill, Mana-rune siphons. It buys runes (40, or 60 for summon runes) and pays combine and
    graft fees.
  - Mana stones: dropped by enemies. They pay for towers (4 + 2·n).
  - Castle HP: 20.
- **Waves.** Normal, fast, brute and boss enemies, with HP ×1.22 per wave. An early-call bonus gives mana.
- **Runes.** 13 runes: Fire, Ice, Electric, Poison, Water, Stone, Light, Blood, Meteor, Volcano, Golem, Hive, Mana.
- **Crafting.**
  - Place a base rune, drop donors onto its open ability slots, press Craft.
  - There is deliberately **no preview**: the result is read from the output rune's description.
  - Grafts can be removed: the rune returns, the fee is lost.
- **Grid rules.** Everything snaps to the grid:
  - props to the 0.04-unit voxel grid;
  - towers to cells;
  - ranges are cell sets, shown only on hover, while building or while dragging a rune;
  - ground fields cover one cell.
- **Proposal awaiting user approval.** Towers on plateaus get +1 range.

## Known gaps / limitations

- Enemies never attack, so golem armour and poison heal suppression have no effect.
- No audio and no main menu or title screen. Quit exits the game directly.
- Balance is prototype-level; only the early waves were checked by auto-play.
- Only the rune ability text is localised (TR/EN). UI strings are English literals; a UI translation layer is not
  built yet.
- River corners are square because the tileset has square bends.
- Tested only through headless runs and scripted screenshots. Real mouse play (drag and drop feel, camera feel) has
  not been verified by the user yet.

## Open questions for planning

- Should enemies attack towers or summons (this would activate the defensive abilities)?
- Progression beyond one map: meta-progression, rune unlocks, difficulty modes?
- Should the high-ground +1 range bonus stay?
- Audio direction, main menu, onboarding/tutorial for crafting.
- Performance budget for bigger maps (the apron is already batched; map props are nodes).
