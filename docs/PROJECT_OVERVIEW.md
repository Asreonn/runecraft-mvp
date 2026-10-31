# RuneCraft MVP — project overview (for reviewers and planning agents)

RuneCraft is a **3D voxel** tower-defense prototype built in Godot 4.7 (GL Compatibility renderer, GDScript only),
viewed from a high orthographic angle.
- **Core idea.** Towers have no fixed type. Each tower holds one **rune**.
- **Grades.** Runes grow by **combining** two equal runes (G1 → G5).
- **Grafting.** Runes can be **grafted** into each other's abilities without limit. A rule compiler resolves every
  combination automatically; there is no pair-specific code.

Where to read further:
- [`design/DECISIONS.md`](../design/DECISIONS.md) — **current decisions; they override every other document.**
- [`TODO.md`](../TODO.md) — every user request and its status, in Turkish.
- [`docs/PARITY_REPORT.md`](PARITY_REPORT.md) — how the Godot runtime compares with the Python reference.

## Running and checking

```sh
godot --path .                                                # play
godot --path . -- --seed 42                                   # a specific random map
bash tests/run.sh                                             # headless invariant suite (1448 checks)
python3 design/rune_mechanics/mechanics/test_mechanics.py     # rule compiler + reference sim (127 checks)
godot --headless --fixed-fps 60 --path . -- --econ mana5 --seed 3 --waves 8    # economy probe
godot --headless --path . -- --demo --auto --quit-after 120   # scripted session, AUTO line per wave
```

Command-line flags (after `--`) are parsed in `scripts/game.gd` `_parse_args`:

| Flag | Effect |
|---|---|
| `--seed N` | fixed map |
| `--demo` | scripted resources, towers and a craft |
| `--auto` | auto-starts waves |
| `--econ VARIANT` | economy probe: `none`, `mana1`, `mana3`, `mana5`, `fire3+mana5`; `--waves N` |
| `--cam 45\|30\|dynamic` | camera angle (evaluation) |
| `--shots DIR` | saves screenshots; add `--tabs` (every tab), `--inspect` (rune inspector), `--burst` (combat close-ups) |
| `--savetest` | save → load round trip |
| `--quit-after S` | quits after S seconds |

## Architecture (file map)

| File | Responsibility |
|---|---|
| `scripts/game.gd` | Hub: world setup, camera, waves, building, grid helpers and indicators, settings, demo/probe/capture modes. Thin public API over the three modules below. Game speed scales only the simulation (`time_mult()`). |
| `scripts/rune_store.gd` | Every rune move: inventory, craft table, combine, socket and unsocket, take output. **Transactional**: an operation completes or changes nothing; runes are never lost or duplicated. |
| `scripts/economy.gd` | Shop prices (multiplicative, provisional), tower price and refund, Mana-rune income (overkill excluded, soft cap per Mana node), income rates for the HUD. |
| `scripts/save_system.gd` | Save format v2 (v1 still loads), validation, between-waves-only saving, restore (in place for the same map, or by scene reload for another seed). |
| `scripts/map_gen.gd` | Pure-data deterministic map generator. Produces a meandering river with one bridge, plateaus with stairs, rocks, forests (one tree per tile, sized by forest depth), voxel-grid props and the 8-tile apron. |
| `scripts/world_builder.gd` | Map data → 3D nodes; the apron uses MultiMesh. |
| `scripts/camera_rig.gd` | Orthographic camera: WASD pan, zoom at cursor, middle-drag, Q/E 90° snaps. Bounds keep the void out of view. `pitch_deg` is adjustable (evaluation). |
| `scripts/rune_lib.gd` + `scripts/locale/{en,tr}.json` | Rule compiler (GDScript port of `design/rune_mechanics/mechanics/resolver.py`) and localised descriptions. |
| `scripts/combat.gd` | Runtime twin of `sim.py`: damage, statuses, chains, pierce, areas, fragments, forced moves (position re-synced after a push), one-cell ground fields with stable ids, mana siphon and marks, deaths. |
| `scripts/tower.gd` | One rune per tower. Picks projectile / beam / meteor / volcano / golem / hive. Cell-based targeting. Summons are in group `summons` with meta `summon_owner`; they are removed on a rune change, unsocket or sale. In-flight lava and meteors of a replaced rune do nothing. |
| `scripts/enemy.gd`, `scripts/vfx.gd`, `scripts/grid_overlay.gd`, `scripts/glb.gd` | Enemies, effects (particles follow pause and speed), cell overlays, runtime GLB loading. |
| `ui/hud.gd` | HUD v4: naked bars (the mana bar shows the real income rate), wave counter, tabs Craft / Shop / Menu (Menu pauses), tower card (DPS, mana/s, Inspect / Remove / Sell), tooltip, banner, drag hints. Anchored to the screen edges; the panels are 9-slice. |
| `ui/rune_inspector.gd` | **Rune inspector**: the whole graft tree of a rune. Shows abilities (open, or locked with their unlock grade), donors per ability with their compiled contribution, uncarried effects (✗) and nested grafts. Open it by right-clicking any rune slot or with *Inspect* on the tower card. |
| `ui/craft_table.gd`, `ui/slot.gd`, `ui/drag_preview.gd`, `ui/world_input.gd` | Craft table, slots (a "+N" badge for big recipes), drag and drop with target glow and a hint chip, drop-on-tower preview. |
| `ui/skin.gd`, `ui/tex_box.gd` | Penpot-exported @2x textures as 9-slice StyleBoxes. |
| `tests/` | Headless invariant suite (Codex): conservation of runes, transactional failures, shop pricing and refunds, summon cleanup, save round trip / interrupted wave / bad files. |

## Design sources

- **Rune mechanics.**
  - Design doc: `design/RUNE_MECHANICS.md` (Turkish).
  - Reference implementation and tests: `design/rune_mechanics/`.
  - Generated reports: `design/rune_mechanics/reports/` — balance, scenario walkthroughs, rune cards.
- **GDD and briefs.** `design/source_package/` (historical; each file carries a status note pointing to
  `DECISIONS.md`).
- **UI.**
  - Designed **only in Penpot** (page "HUD v3 · Stone", token set `runecraft-stone`; not in this repo).
  - Boards named `rcui / <name>` are exported at 2× and pulled with `ui_design/pull_penpot_exports.sh`.
  - Do not draw UI art in code.
- **Voxel art.** The repo carries **runtime GLB exports only**. The `.vox` sources and generators live in the
  parent, non-public project, so the art cannot be regenerated from this repo.

## Current state

| Area | State |
|---|---|
| Inventory / craft / socket safety | implemented; 1448/1448 invariant checks (the first release scored 703/1134 on this suite) |
| Summon cleanup | implemented; covered by tests |
| Save / load v2 | implemented; covered by tests (round trip, interrupted wave, corrupt / wrong version / missing file) |
| Multiplicative shop prices | implemented, **provisional numbers** |
| Mana rune economy | implemented, **provisional numbers**; measured in 8 real waves (`DECISIONS.md`) |
| Rune readability | first pass: inspector, compact in-world donors (≤4 + "+N"), slot badges, ability donor counts |
| Camera angle | **evaluating** (45° default, 30°, zoom-based option in Settings) |
| Godot ↔ Python parity | compiler identical (188/188 comparisons); combat partially equal, differences classified in `docs/PARITY_REPORT.md`; its three bugs (B1, B2 in Godot; B3 in Python) are fixed |
| High-ground +1 range | implemented, **awaiting approval** |

## Known gaps / limitations

- **Future features, kept in the design and not built now:**
  - enemies attacking summons (golem defence), healer enemies (poison heal suppression), Fog of War (light);
  - the roguelike layer: tower chassis, artifacts, modifiers, rewards, biomes, 3 castles, god powers, Demon God
    story.
- No audio and no title screen.
- Balance is prototype-level: shop growth ratios, Mana caps and tower price growth are provisional.
- UI strings are English literals; only the rune text is localised.
- The UI reference is 1920×1080 with an `expand` aspect. Panels are anchored to the edges, and wide and 4:3
  layouts were checked by screenshots only.
- Real mouse play (drag and drop and camera feel) has not been verified by the user yet.

## Open questions for planning

- **Camera angle:** 45°, 30° or zoom-based?
- **Same status from two towers with an identical recipe:** stack, or refresh as today?
- **Final economy numbers:** rune growth ×1.15, cap ×3, cool-down ½ per wave; tower growth ×1.25; Mana income
  caps 2.5–11/s.
- **High-ground bonus:** keep it or not.
- **Next feature from the roguelike scope:** which one comes first?
