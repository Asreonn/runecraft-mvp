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
- [`docs/PARITY_REPORT.md`](PARITY_REPORT.md) — how the Godot runtime compares with the Python reference
  (latest re-run: [`PARITY_RERUN_5065a12.md`](PARITY_RERUN_5065a12.md)).
- [`docs/ECONOMY_STACKING.md`](ECONOMY_STACKING.md) — Mana economy, shop loops and status stacking measurements.
- [`docs/UI_REVIEW.md`](UI_REVIEW.md) — Craft tab / rune tree / inspector redesign, before-after captures, resolution tests.

## Running and checking

```sh
godot --path .                                                # play
godot --path . -- --seed 42                                   # a specific random map
bash tests/run.sh                                             # headless invariant suite (1462 checks)
python3 design/rune_mechanics/mechanics/test_mechanics.py     # rule compiler + reference sim (136 checks)
gamescope --backend headless -w 1280 -h 720 -- godot --path . --resolution 1280x720 \
  --script res://tests/ui/run_ui.gd -- [--lang tr] [--shots DIR]  # UI interaction + layout (66 checks, real renderer)
gamescope --backend headless -w 640 -h 640 -- godot --path . --script tools/render_rune_icons.gd   # rune icon renders
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
| `--cam 45\|30\|dynamic` | camera angle (45° is the default) |
| `--lang en\|tr` | UI and rune text language |
| `--uishots DIR` | with `--demo`: Craft tab, rune tree, tooltip, inspector, shop and menu captures |
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
| `ui/hud.gd` | HUD: naked bars (the mana bar shows the real income rate), wave counter, tabs Craft / Shop / Menu (Menu pauses), the Craft page (**crafting → rune structure → inventory**), tower card, tooltip, banner, drag hints. Anchored to the screen edges; the panels are 9-slice. |
| `ui/craft_table.gd` | Crafting area: engraved magic circle, base socket, one socket per ability (locked ones sealed with their grade), output column with the Craft button (fee) and a status line, craft animation. |
| `ui/rune_view.gd` | Data model shared by the rune tree, inspector and captions: built from the compiled program (what the tower really does), incl. per-donor contributions, uncarried effects and pending (not yet crafted) donors. |
| `ui/rune_tree.gd` | **Radial stone rune tree**: main rune in the middle, abilities on a glyph ring, donors branching outward through carved grooves, nested donors further out; rune light flows in grooves that carry something. Click = pick, hover = preview. Compact (Craft tab) or full depth (inspector). Layout relaxes overlaps. |
| `ui/rune_inspector.gd` | **Floating inspector**: centred stone panel with the full tree and a detail plaque. Opens on right-click / *Inspect* / *Details*; closes on ✕, Esc or a click outside; follows or closes when its rune changes, leaves the player or a game is loaded; blocks world input (the game is not paused). |
| `ui/i18n.gd` | UI strings from `scripts/locale/<lang>.json` → `ui` (EN / TR). |
| `ui/slot.gd`, `ui/rune_icon.gd`, `ui/drag_preview.gd`, `ui/world_input.gd` | Square stone sockets (states normal / hover / selected / drop / invalid / output / pending / locked), rune on its grade light (loot rarity colours), drag and drop with a square target light and a hint chip, drop-on-tower preview. |
| `ui/skin.gd`, `ui/tex_box.gd` | Penpot-exported @2x textures as 9-slice StyleBoxes. |
| `tools/render_rune_icons.gd` | Renders the 65 rune icons from the in-game rune GLBs (3/4 view, key / fill / rim light, bloom, carved outline). |
| `tests/` | Headless invariant suite: conservation of runes, transactional failures, shop pricing and refunds, summon cleanup, save round trip / interrupted wave / bad files, **status ownership**. `tests/ui/run_ui.gd`: UI interaction and layout checks with a real renderer. |

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
  - Faster path (v5+): a whole kit board is exported once with a transparent background and cut by
    `ui_design/pull_penpot_sheets.sh <kit>` using `ui_design/sheets/<kit>.json`.
  - Rune icons are renders of the 3D runes (`tools/render_rune_icons.gd`), not Penpot drawings.
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
| Rune readability | radial stone tree (Craft tab + floating inspector), loot-style grade lights, rendered rune icons, short tooltips; UI tests 66 × 7 configurations |
| Status stacking | DoTs one instance per tower, utility statuses strongest-only, death effects credited to their owner (both engines, tested) |
| Camera angle | **45° default** (decided); 30° and zoom-based are options |
| Godot ↔ Python parity | compiler identical; combat partially equal, differences classified in `docs/PARITY_REPORT.md`. N1–N3 confirmed fixed by the 5065a12 re-run in Python, grid and replay (`docs/PARITY_RERUN_5065a12.md`); its findings R1 (chain label) and R2 (DoT tick tolerance) are fixed afterwards in Godot. The status-stacking change is not yet re-run in the harness |
| High-ground +1 range | implemented, **kept** (decided) |

## Known gaps / limitations

- **Future features, kept in the design and not built now:**
  - enemies attacking summons (golem defence), healer enemies (poison heal suppression), Fog of War (light);
  - the roguelike layer: tower chassis, artifacts, modifiers, rewards, biomes, 3 castles, god powers, Demon God
    story.
- No audio and no title screen.
- Balance is prototype-level: shop growth ratios, Mana caps and tower price growth are provisional.
- UI text is localised (EN / TR); the language applies after a restart.
- The UI reference is 1920×1080 with an `expand` aspect. Layout is checked by `tests/ui/run_ui.gd` at 1280×720,
  1366×768, 1920×1080, 2560×1080 and 1440×1080 (EN and TR). Text at 1280×720 is scaled to 2/3 (13 px design text
  ≈ 9 px on screen).
- Mouse interaction is tested with synthetic events through Godot's real input path; feel with a physical mouse has
  not been verified by the user yet.
- **Recipe width × Mana siphon** is superlinear (see `docs/ECONOMY_STACKING.md`); awaiting a decision.

## Open questions for planning

- **Recipe width:** add a per-tower total Mana cap (recommended) or keep the per-node caps only?
- **Next feature from the roguelike scope:** which one comes first?
