# RuneCraft — current decisions (authoritative)

Last update: 2026-10-31 (revision task "Hata Düzeltme, Mekanik Revizyon ve Dokümantasyon Senkronizasyonu").

**Precedence.** This file wins over every other document: `RUNE_MECHANICS.md`, the reports, the GDD and briefs in
`design/source_package/`, and older TODO wording. Older documents are kept for history. Where they disagree, the
older text is marked as superseded rather than deleted.

Status labels used here and in `TODO.md`:

| Label | Meaning |
|---|---|
| **decided** | the user decided it |
| **implemented** | in the Godot game, verified by tests or captures |
| **reference-only** | verified only in the Python reference simulation |
| **provisional** | implemented, but the numbers are not balance-proven |
| **evaluating** | an option, not a decision |
| **future** | planned, not built |

## Decisions

| # | Decision | Status |
|---|---|---|
| 1 | RuneCraft is a **3D voxel** tower-defense game, viewed from a high orthographic angle, minimalist. | decided |
| 2 | **Camera:** 90° top-down is *not* required (an earlier review claiming it was is wrong). 45° is the current default but **not final approved**. ~30° and a zoom-dependent angle are being evaluated. Whatever is chosen must keep towers, runes, enemies, elevation and VFX readable at all zoom levels, and must not break controls, targeting or grid coordinates. | evaluating (Settings → *Camera angle (testing)*: 45° / 30° / zoom-based) |
| 3 | The **Mana rune stays** (an earlier suggestion to drop it is void). It is the economy rune: grafting or socketing it lets the player build a mana-heavy strategy. | decided; mechanics implemented and provisional |
| 4 | **Shop prices grow multiplicatively** with purchases, for runes and towers. The ratios are examples (1.1×, 1.2× …), not final. | decided; implemented and provisional |
| 5 | The **grafting paradigm stays**: unlimited nested grafts, the automatic compiler, and no mandatory pre-craft preview. The output rune's description is shown after crafting. | decided, implemented |
| 6 | **Rune readability** must improve: rune identity, grade, which donor feeds which ability, nested grafts, active / locked / incompatible states — without cluttering the world. | decided; first pass implemented |
| 7 | **Light / Fog of War**, **Golem defence** and **Poison heal suppression** stay in the design. They gain meaning later: fog and exploration, enemies attacking summons, healer enemies. They are not built now and must not be removed. | future |
| 8 | **Roguelike scope** is the long-term goal, not built now: tower chassis / variety, global artifacts, local tower modifiers, post-wave rewards, map exploration + fog, chests / merchants / finds, multiple biomes, three castles / stages, god powers, run-based progression, the Demon God story and rebirth cycle. Nothing here is cancelled. | future |

## Implemented numbers (all provisional, in `data/rune_mechanics_v1.json`)

### Shop (`economy.shop`)

- **Rune price** = base (40, summon runes 60) × 1.15^k, capped at ×3.
  - `k` = recent purchases of that rune.
  - Every cleared wave keeps ⌊k × 0.5⌋, so prices cool down.
- **Tower price** = 4 × 1.25^n, where `n` = towers owned.
  - Selling refunds 50 % of min(price paid, price to rebuild).
  - A sell → rebuy cycle therefore always costs stones.
- **Persistence:** prices are saved and restored.
- **UI:** the shop shows the live price. Gold means above base; red means not affordable.

### Mana rune

**Abilities (unchanged):**
- G1 siphon: a share of the event's damage becomes mana.
- G3 mana mark: damage from any tower near the marked enemy becomes mana.
- G5 crystallize: the marked enemy drops +2 mana stones.

**New rules:**
- **Overkill** damage never becomes mana. This also fixes DPS inflation.
- **Lethal hits** still pay their siphon (the Python reference was fixed to match).
- **Income cap:** mana from siphon or marks is soft-capped per producing Mana node.
  - The caps are 2.5 / 4 / 6 / 8 / 11 mana/s for G1–G5.
  - Above the cap only 25 % of the excess counts.
  - A node is identified by its tower plus its place in the recipe. The siphon and the mark of one node share a
    cap; two Mana donors or two towers with the same recipe have separate caps (parity findings N1–N3, fixed in
    both engines).
- **Crystals:** several crystal marks on one enemy crystallise **once**.
- **Display:** the HUD shows the real income rate (passive regen plus recent rune income). The tower card shows
  "+x mana/s" per tower.

**Measured in the Godot game:** 8 waves, seed 3, 3 fixed towers plus one variant tower placed first on the path;
`reports/mana_economy.md` has the details and the placement comparison.

| Variant tower | Rune mana | Total mana gained | vs none |
|---|---|---|---|
| none | 0 | 1904 | — |
| Mana G1 | 244 | 2101 | +10 % |
| Mana G3 | 689 | 2467 | +30 % |
| Mana G5 | 1256 | 2873 | +51 % |
| Fire G3 with Mana G5 on `fire_hit` | 1053 | 2561 | +35 % |

Interpretation:
- The economic contribution grows clearly with grade.
- Placement matters: a Mana tower behind strong towers earns far less.
- There is no runaway loop.
- These are measurements, not final balance.

### Save / load (format v2; v1 files still load)

- **Contents:** everything owned is saved — inventory, towers with full graft trees, craft table, mana, stones,
  castle HP, shop price state and the early-call countdown.
- **When:** saving is allowed **only between waves**. A load always resumes at "next wave", so no wave can be
  skipped and no resources duplicated.
- **Bad files:** corrupt, unknown-version or incomplete files are rejected without changing the running game.
- **Old maps:** if a saved tower cell is no longer buildable (an older map generator), the tower moves to the
  nearest buildable cell. Its rune is never lost.

### Grid

- Towers target enemies whose cell is within range (cell-centre distance), and ground fields cover one cell.
- This differs on purpose from the Python reference's continuous radius. The differences are measured in the
  parity report.
- The **high-ground bonus** (+1 range on plateaus) is in the code and **awaits user approval**.

## Known open design questions

- Should two towers with an identical recipe stack the same status on one enemy?
  - Today the second application refreshes the first instance, and ticks are attributed to the first tower.
  - Both the Godot and Python implementations behave this way.
- The camera angle (decision 2).
- Balance of shop growth ratios, Mana income caps and tower price growth (decisions 3–4).
- The high-ground +1 range bonus.
