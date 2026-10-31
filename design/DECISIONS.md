# RuneCraft — current decisions (authoritative)

Last update: 2026-10-31 (Craft UI / Rune Inspector / UX-QA revision; earlier the same day: "Hata Düzeltme, Mekanik Revizyon ve Dokümantasyon Senkronizasyonu").

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
| 2 | **Camera:** 90° top-down is *not* required. **45° is the default** (the user approved Claude's recommendation, 2026-10-31). 30° and a zoom-dependent angle stay available as options. Any angle must keep towers, runes, enemies, elevation and VFX readable at all zoom levels and must not break controls, targeting or grid coordinates. | decided (Settings → *Camera angle*: 45° default, 30°, zoom-based) |
| 3 | The **Mana rune stays** (an earlier suggestion to drop it is void). It is the economy rune: grafting or socketing it lets the player build a mana-heavy strategy. | decided; implemented; numbers are the approved baseline (decision 9) |
| 4 | **Shop prices grow multiplicatively** with purchases, for runes and towers. Current ratios are the approved baseline (decision 9), to be tuned with playtest data. | decided; implemented |
| 5 | The **grafting paradigm stays**: unlimited nested grafts, the automatic compiler, and no mandatory pre-craft preview. The output rune's description is shown after crafting. | decided, implemented |
| 6 | **Rune readability** must improve: rune identity, grade, which donor feeds which ability, nested grafts, active / locked / incompatible states — without cluttering the world. | decided; first pass implemented |
| 7 | **Light / Fog of War**, **Golem defence** and **Poison heal suppression** stay in the design. They gain meaning later: fog and exploration, enemies attacking summons, healer enemies. They are not built now and must not be removed. | future |
| 8 | **Roguelike scope** is the long-term goal, not built now: tower chassis / variety, global artifacts, local tower modifiers, post-wave rewards, map exploration + fog, chests / merchants / finds, multiple biomes, three castles / stages, god powers, run-based progression, the Demon God story and rebirth cycle. Nothing here is cancelled. | future |
| 9 | **Open questions settled by the user's "everything in F per Claude's recommendation" (2026-10-31):** the shop and Mana numbers below are the approved baseline (tune later with playtest data); the **high-ground +1 range bonus stays**; **saving stays between waves only**; **status stacking** follows rule 10. | decided |
| 10 | **Status stacking and credit:** damage-over-time statuses (**burn, poison, bleed**) are **one instance per tower** — two towers with the same recipe each burn the enemy with their own clock and credit. Utility statuses (**slow, wet, armor shred, blind, lit, mana mark**) stay one instance per recipe node and the strongest wins, so they never multiply. Death effects (**poison contagion, frozen-death shards, crystal grafts**) are credited to the tower that owns the effect, never to the killer. | decided; implemented in Godot and the Python reference, tested |
| 11 | **Rune readability (UI v6):** the rune is shown as a **radial stone tree** — the main rune in the middle, its abilities on an engraved glyph ring, donor runes branching outward through carved grooves, nested donors further out. The Craft tab shows abilities + direct donors; the floating Inspector shows the whole recipe. No metadata subtitles ("14 runes · depth 3"). **Grade reads like loot rarity**: the slot behind the rune glows grey / green / blue / purple / gold (G1–G5). Rune icons are renders of the in-game 3D voxel runes. | decided by the user's feedback; implemented |

## Implemented numbers (approved baseline per decision 9, in `data/rune_mechanics_v1.json`)

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
- The **high-ground bonus** (+1 range on plateaus) **stays** (decision 9).

## Measurements after the UI revision (Codex c1, commit 5065a12, before rule 10)

108 complete eight-wave runs on seeds 3 / 17 / 42 (`docs/ECONOMY_STACKING.md`):
- Mana G1 / G3 / G5 at the **front** of the path: +19.8 % / +55.4 % / +97.7 % total mana; in the **middle** +10.5 / +31.8 / +51.0 %; at the **back** +4.0 / +10.9 / +15.1 %. Placement matters ~5×.
- 1 → 6 towers carrying the same Mana recipe grow **sublinearly** (Mana G3: 2.93× for 6×). No reinvestment loop was found in eight waves.
- Shop: no profit loop in buy / combine / build / sell cycles (448 refund fixtures; selling always loses stones).

## Known open design questions

- **Recipe width × Mana siphon (new, needs a decision):** every Mana donor on one ability siphons the *whole* event's damage into its own capped bucket, so 1 → 64 donors on one Fire hit gives 7 → 940 mana per hit (superlinear, 134×). Graft fees grow ×1.3 per node, so wide recipes are expensive, but the payback has not been measured. Recommendation: one Mana total cap per tower (e.g. the highest node cap × 1.5) on top of the per-node caps. Not changed without approval.
- Long-horizon economy (more than eight waves, reinvestment, net return of buying high-grade grafts) is not measured yet.
