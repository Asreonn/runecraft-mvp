# Agent Brief — RuneCraft Rune Visual Language / SYSTEM DESIGN ONLY

You are acting as a senior game art director, technical artist and procedural visual-system designer. Your job is to **UNDERSTAND the RuneCraft gameplay and crafting system**, then propose a robust, original, automatically composable visual design system for runes. **Do not create the actual art, models, textures, shaders, or prototypes yet.**

## Mandatory input

Read the accompanying `RuneCraft_Rune_Design_Brief_MVP_v3.md` **fully**, particularly all 12 runes with their five grades, the nested grafting rules, multiple grafts on one ability, tower-defense gameplay constraints, and the final visual design questions.

A previous concept/reference image is supplied with the brief. Treat it as **context**, not an approved production spec or a template you must copy. The rules and mechanics in the Markdown brief override anything implied by the image.

## Your specific responsibility

Design **the visual language and compositional rules yourself**. Do not assume a fixed surface treatment, shape evolution, color formula, number of orbiting parts, rune icons, geometry, exact materials, shader aesthetic or spatial organization merely because an earlier concept depicts one. Those choices are yours to investigate, compare and justify.

The non-negotiable GAME requirements are:

- This is a **clean, readable, minimalist/cubic 3D tower defense**, seen from a high-angle camera; not an RPG skill bar.
- A crafted **main rune is visible floating above its tower**; main-rune identity must remain readable.
- There are exactly **12 MVP rune identities** and **five grades (G1–G5)**. Each rune's actual ability unlocks and numerical development are specified in the brief.
- A crafted rune is a **recursive rune/graft tree**, not a fixed pair and not a fixed three-support-slot layout.
- A given ability can receive **multiple grafts**; grafts can themselves have grafts, their own grade and their own unlocks.
- Grade and crafting complexity should be **visually legible**, including deeply nested, heavily upgraded rune objects.
- **No bespoke artwork for each combination**: the visual system must be generated from reusable source assets + deterministic rules.
- The game mechanisms are automatically composed from unlocked abilities, not bespoke recipe scripts. Do not 'invent' effects or mechanics absent from the brief.
- The tower-view result should stay clean even with 20+ graft nodes; richer inspect/inventory presentation is allowed.

## Process and deliverables — NO asset production

1. Explain the gameplay and crafting system back in your own words, accurately, with examples (Fire/Burn ← Electric G3 ← Ice G1, and Volcano/Eruption ← Electric + Fire + Ice).
2. Identify the visual-design tensions: unique identity vs shared system, G1–G5 evolution vs production cost, recursive graft complexity vs readability, gameplay zoom vs inventory zoom.
3. Propose **at least two distinct original visual directions** and compare their coherence, production burden, high-camera legibility, and procedural composability. Do not merely reskin the reference.
4. Select and justify the best direction, with concrete **visual grammar** (what changes with main rune, grade, graft content, number and depth, active ability, and tower distance).
5. Describe how the chosen visual grammar could be built with reusable procedural building blocks **without making a separate model/texture for every combination**. This is a design proposal, not an implementation task.
6. Provide a **12-rune x 5-grade conceptual visual matrix**. These are concise written art-direction descriptions, not actual rendered assets or 60 hand-authored model requirements.
7. Explain representations for (a) one plain rune, (b) the same rune at G5, (c) one G1 graft, (d) one G5 graft, (e) several grafts on one ability, (f) recursively grafted donor runes, (g) 20+ graft nodes.
8. Separate the visual appearance of the **rune above the tower**, **crafting/inventory UI**, and the **actual spell/combat VFX**. These do not need to use the same level of detail.
9. Recommend one small proof-of-concept test plan and specific visual success/failure criteria; do NOT execute it.
10. State uncertainties and choices needing user approval before any production.

## Strict restrictions

**NO generation** of VOX files, meshes, textures, concept images, shaders, particles, scenes, Godot nodes, animation assets, or scripts. No bulk asset production. No redesigning the gameplay itself. No external framework installation or setup. No assumptions that every rune must cause explosions, leave persistent marks, or summon creatures. No fixed maximum of one donor per ability. No hard-coded combination-specific skins. No UI editor for programming trigger graphs.

**Output:** one comprehensive Markdown **visual-system design proposal** covering the points above. After delivering the proposal, stop and wait for approval before implementing or generating anything.

Write the document in **Turkish**. Be critical and practical; explicitly explain why your choice remains legible and scalable as crafted rune complexity grows.
