extends RefCounted

func run(game, t) -> void:
	t.context = "save/API"
	var versioned: bool = game.get_script().get_script_constant_map().has("SAVE_VERSION")
	t.check(versioned, "SAVE_VERSION constant", "missing API: SAVE_VERSION")
	# Each path is guarded independently so main records every missing API.
	var can_serialize: bool = t.require_api(game, ["serialize"])
	var can_restore: bool = t.accepts(game, "restore", 1)
	var can_save: bool = t.accepts(game, "save_game", 1)
	var can_load: bool = t.accepts(game, "load_game", 1)
	if can_serialize and can_restore:
		await _round_trip(t, false)
	if can_serialize and can_save and can_load:
		await _round_trip(t, true)
	if can_serialize and can_restore and versioned:
		for phase in ["spawning", "fighting"]:
			await _interrupted_wave(t, phase)
	if can_load:
		await _bad_loads(t, can_serialize, versioned)
	t.finish()

func _populate(t):
	var game = await t.fresh_game()
	t.fill(game, false)
	# Exercise persistent purchase counters for multiple rune types.
	for rid in ["fire", "fire", "ice"]:
		t.operation(game, "buy_rune", [rid], true)
	for i in 3:
		var tower = t.build(game)
		if tower != null:
			if i == 0:
				t.operation(game, "sell_tower", [tower], true)
			else:
				tower.call("set_rune", t.node("golem") if i == 1 else t.node("fire", 3, {"fire_hit": [t.nested()]}))
	t.craft_fixture(game)
	game.craft.output = t.node("water", 3, {"water_hit": [t.node("stone")]})
	game.inventory[5] = t.nested()
	game.mana = 1234.567
	game.stones = 54321
	game.castle_hp = 13
	return game

func _round_trip(t, disk: bool) -> void:
	t.context = "save/" + ("disk" if disk else "JSON_restore")
	var game = await _populate(t)
	var expected := {"items": t.items(game), "mana": game.mana, "stones": game.stones,
		"castle_hp": game.castle_hp, "towers": t.tower_rows(game), "prices": t.prices(game)}
	var state: Dictionary = t.snapshot(game)
	var raw = t.invoke(game, "serialize")
	if not t.check(raw is Dictionary, "serialize returns Dictionary", str(raw)):
		return
	var constants: Dictionary = game.get_script().get_script_constant_map()
	t.check(constants.has("SAVE_VERSION") and raw.get("version") == constants.get("SAVE_VERSION"), "serialize includes current SAVE_VERSION")
	t.check(t.snapshot(game) == state, "serialize is read-only")
	var parsed = JSON.parse_string(JSON.stringify(raw))
	if not t.check(parsed is Dictionary, "serialized data survives JSON stringify/parse"):
		return
	var path := "res://tests/fixtures/roundtrip.json"
	if disk:
		var saved = t.invoke(game, "save_game", [path])
		t.check(saved is bool and saved == true, "save_game(path) returns true", str(saved))
		t.check(FileAccess.file_exists(path), "save exists at explicit fixture path")
		t.check(t.snapshot(game) == state, "save_game is read-only")
	game = await t.fresh_game() # Restore/load is always applied to a new scene.
	var result = t.invoke(game, "load_game", [path]) if disk else t.invoke(game, "restore", [parsed])
	t.check(result is bool and result == true, "load/restore returns true", str(result))
	# Freeze again in case restore sets pause state. No simulated frame between comparisons.
	game.set("paused", true)
	t.check(t.items(game) == expected.items, "round trip all_items multiset")
	t.check(absf(game.mana - expected.mana) <= 0.01, "round trip mana within 0.01")
	t.check(game.stones == expected.stones, "round trip stones")
	t.check(game.castle_hp == expected.castle_hp, "round trip castle_hp")
	t.check(t.tower_rows(game) == expected.towers, "round trip tower cells and recipes")
	t.check(t.prices(game) == expected.prices, "round trip every rune price and tower price")
	# Arrays/Dictionary locations must also survive; multiset equality alone
	# would miss pending/output/inventory being silently rearranged.
	t.check(game.inventory == state.inventory and game.craft == state.craft, "round trip inventory and craft placements")

func _interrupted_wave(t, phase: String) -> void:
	t.context = "save/interrupted/" + phase
	var game = await t.fresh_game()
	if not t.require_api(game, ["start_wave"]):
		return
	game.wave = 3
	game.call("start_wave")
	if phase == "fighting":
		game.wave_state = "fighting"
		game.to_spawn = []
	var interrupted: int = game.wave
	var raw = t.invoke(game, "serialize")
	if not t.check(raw is Dictionary, "wave serialize returns Dictionary"):
		return
	var parsed = JSON.parse_string(JSON.stringify(raw))
	if not t.check(parsed is Dictionary, "wave JSON Dictionary"):
		return
	game = await t.fresh_game()
	var restored = t.invoke(game, "restore", [parsed])
	t.check(restored is bool and restored == true, "wave restore returns true", str(restored))
	game.paused = true
	t.check(game.wave_state == "build", "restored wave returns to build")
	t.check(game.wave == interrupted - 1, "interrupted wave is scheduled again", "interrupted=%d restored=%d" % [interrupted, game.wave])
	game.call("start_wave")
	t.check(game.wave == interrupted, "next start replays interrupted wave; no skip")

func _bad_loads(t, can_serialize: bool, versioned: bool) -> void:
	for kind in ["corrupt", "missing", "wrong_version"]:
		t.context = "save/reject/" + kind
		var game = await _populate(t)
		var path: String = "res://tests/fixtures/" + kind + ".json"
		if kind == "corrupt":
			path = t.write_fixture("corrupt.json", "{not valid JSON\n")
		elif kind == "missing":
			# Reserve a unique filename without deleting any existing artifact.
			var suffix := 0
			while FileAccess.file_exists(path):
				suffix += 1
				path = "res://tests/fixtures/missing_%d.json" % suffix
		elif kind == "wrong_version":
			if not can_serialize or not versioned:
				t.check(false, "wrong version fixture", "missing API: serialize / SAVE_VERSION")
				continue
			var raw = t.invoke(game, "serialize")
			if not t.check(raw is Dictionary, "wrong version source Dictionary"):
				continue
			var data: Dictionary = raw.duplicate(true)
			var version = game.get_script().get_script_constant_map().get("SAVE_VERSION")
			if not t.check(version is int and data.has("version"), "serialized version field", "expected integer SAVE_VERSION and serialized version"):
				continue
			data["version"] = version + 1000
			path = t.write_fixture("wrong_version.json", JSON.stringify(data))
		if path == "":
			continue
		var before: Dictionary = t.snapshot(game)
		var serialized_before = t.invoke(game, "serialize") if can_serialize else null
		var result = t.invoke(game, "load_game", [path])
		t.check(result is bool and result == false, "bad load returns false", str(result))
		t.check(t.snapshot(game) == before, "bad load leaves all state unchanged")
		if can_serialize:
			t.check(t.invoke(game, "serialize") == serialized_before, "bad load preserves complete serialized state")
