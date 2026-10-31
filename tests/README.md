# RuneCraft headless invariant suite

Copy this `tests/` directory into the game project. The suite changes no gameplay
source and requires Godot 4.7.2, Bash and `awk`. No display, imported editor cache,
Python test framework, network connection or user command-line seed is required.

```sh
bash tests/run.sh
```

Set `GODOT_BIN` to use a different Godot executable. The wrapper redirects XDG
runtime data/config/cache and Godot logs into `tests/artifacts/`, preserving the
player's normal `user://` saves and settings. Do not pass demo, screenshot or
automatic-quit flags. The equivalent direct command is:

```sh
# Use a project-local XDG_DATA_HOME if invoking Godot directly.
godot --headless --path . --script res://tests/run_all.gd
```

Every assertion prints `PASS name` or `FAIL name: detail`. Each test file has a
`FILE_RESULT` line; the last assertion summary is `N/M checks passed`. Assertion
failures return status 1. Parse errors, missing APIs and aborted test functions
also fail. A 180-second watchdog bounds waits. The wrapper additionally rejects
script errors and unexpected engine errors even if Godot exits zero.

The ordinary unmodified headless game also emits `RasterizerSceneDummy` allocator
and RID-allocation leak diagnostics at shutdown. The wrapper leaves these in the
log but excludes only those two exact diagnostic families from its additional
engine-error gate. These messages are independent of the assertion result.

## Coverage

| File | Checks |
| --- | --- |
| `test_api.gd` | Required methods and `SAVE_VERSION`; exact top-level ownership census across inventory holes, craft base, pending donors on multiple abilities, output and a tower; duplicates count, nested donors do not count separately. |
| `test_inventory.gd` | Empty/full inventory variants of insertion, empty socket, inventory swap, output socket and swap, unsocket, sale with/without rune, taking output; canonical-recipe conservation, wallet, free slots and released build cells. |
| `test_craft.gd` | Empty/full inventory variants of replacing an existing base, clearing several donors on several abilities, removing a pending donor, splitting a nested graft, combining two grafted runes, adding a donor and crafting; exact-capacity and one-slot-short return boundaries. |
| `test_failures.gd` | Atomic rejection of invalid/same/max-grade/underfunded combines, empty or absent socket sources, absent base, locked graft ability, occupied output, underfunded/empty craft, empty output, invalid/occupied/underfunded building. |
| `test_shop.gd` | All 13 rune IDs, three purchases each: exact quoted charge, exactly one G1 added and increasing price. Full/underfunded purchase rejection. Four buy/sell cycles and an oldest-first sale of five towers check quoted tower cost, increasing next price, original paid-price refund bounds and pricing floor. |
| `test_summons.gd` | Real volcano/golem/hive spawn paths with a real nearby enemy, including hive beetles. Replacement, clearing and sale check group/owner metadata, entity/beetle reset, group cleanup and actual node destruction after two frames plus 0.4 seconds. |
| `test_save.gd` | Fresh-scene JSON serialize/restore and disk save/load; inventory/craft/tower placements, all-items multiset, mana tolerance, stones, castle HP, all rune prices and tower price. Spawning/fighting saves replay the interrupted wave. Corrupt JSON, wrong version and missing file fail without changing snapshot or serialized state. |

`fixtures/validate_recipes.gd` is an optional standalone fixture audit: it verifies
the chosen nested and multi-ability grafts against the existing rune compiler.
It is not discovered as an invariant test.

## Runner design and contract assumptions

- Each `test_*.gd` extends `RefCounted` and exposes `func run(game, t) -> void`.
  The runner discovers every matching file directly under `tests/`, sorts names,
  instantiates `main.tscn`, waits a process frame after `_ready`, and finds the root
  child whose script is `res://scripts/game.gd`. Every file and every stateful
  scenario gets a fresh scene. Finish a test with `t.finish()` so early aborts are
  detectable. Assertion failures do not short-circuit later checks.
- Helpers live in `run_all.gd`; tests use `t.check(condition, name, optional_detail)`.
  `t.invoke` guards method existence and accepted argument count before `callv`.
  Return values must be actual booleans; `void`/null fails the contract.
- Global RNG is reset with `seed(3)` before instantiation. No map coordinate is
  assumed: buildable cells are sorted from `game.wb.buildable`. The suite does
  not use `OS.get_cmdline_user_args` or depend on `game.seed_value`. Mana and stones
  are provisioned directly. Game simulation stays paused except explicit wave
  starts and direct tower spawn steps; real-time cleanup tweens still run.
- `all_items()` is compared against an independent census of every storage
  location. Conservation uses sorted recipe multisets, preserving multiplicity.
  If `all_items()` is missing/wrong-type, that is a **failure**, and a diagnostic
  census fallback lets the remaining behavioral checks expose baseline defects.
  A missing API can never make the suite pass. Missing save methods/signatures
  fail explicitly and their dependent scenarios are not run.
- Atomic-failure snapshots include complete inventory/craft trees, tower
  cell/recipe placements, mana, stones, castle HP, wave state, all prices,
  buildable cells and tower ID counter. They exclude user-facing notification
  text and animation state. Save rejection additionally compares `serialize()`.
- The contract explicitly requires a full-inventory **swap** to fail, even when
  the source inventory slot could hold the old rune. Empty-tower socketing may
  succeed when inventory is full. Replacing a craft base may reuse the slot
  released by its incoming rune; exact-capacity tests require that success.
- Rune-price growth is checked over the first three purchases, below any cap
  documented in the inspected main (there is currently no documented cap).
  No specific multiplier is assumed because the contract provides none.
- Serialization is expected to store `version == SAVE_VERSION`. Explicit
  `save_game(path)` / `load_game(path)` paths point to `res://tests/fixtures/`.
  Round trips run on fresh scenes. At a build screen `wave` counts completed
  waves: an interrupted wave N restores to N-1, so the next start plays N again.
- Summon setup uses current private `_spawn` and tower `step` paths, guarded
  before use. Metadata is never injected by tests. Weak references catch visual
  orphans even when a node lacks its required group or owner metadata.

Generated logs, caches and fixture saves stay in `tests/artifacts/` and
`tests/fixtures/`. A clean copy only needs the `.gd` files, `run.sh` and this
README; fixture directories are created by the runner. Keep raw results when
comparing author changes with the baseline.
