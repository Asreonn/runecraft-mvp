extends SceneTree
## Standalone runner and shared, guarded test helpers. No project autoloads required.

var checks := 0
var passed := 0
var context := "runner"
var completed := false
var scene: Node
var game: Node
var active_test := ""
var fixture_dir := "res://tests/fixtures"
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(cond: bool, name: String, detail: String = "") -> bool:
	checks += 1
	var label := context + ": " + name
	if cond:
		passed += 1
		print("PASS " + label)
	else:
		var line := "FAIL " + label + ": " + (detail if detail != "" else "condition was false")
		failures.append(line)
		print(line)
	return cond

func finish() -> void:
	completed = true

func require_api(obj: Object, names: Array, label: String = "") -> bool:
	var ok := true
	for method in names:
		if obj == null or not is_instance_valid(obj) or not obj.has_method(method):
			check(false, (label + " " + str(method)).strip_edges(), "missing API: " + str(method))
			ok = false
	return ok

func accepts(obj: Object, method: String, argc: int) -> bool:
	if not require_api(obj, [method]):
		return false
	for info in obj.get_method_list():
		if info.name == method:
			var maximum: int = info.args.size()
			var minimum: int = maximum - info.default_args.size()
			if argc >= minimum and argc <= maximum:
				return true
			check(false, method + " signature", "missing API: %s accepting %d arguments (has %d..%d)" % [method, argc, minimum, maximum])
			return false
	return false

func invoke(obj: Object, method: String, args: Array = []) -> Variant:
	if not accepts(obj, method, args.size()):
		return null
	return obj.callv(method, args)

func fresh_game() -> Node:
	if is_instance_valid(scene):
		root.remove_child(scene)
		scene.free()
	await process_frame
	seed(3) # The game may choose its map seed in _ready; no user CLI flags needed.
	var packed = load("res://main.tscn")
	if not packed is PackedScene:
		check(false, "load main scene", "res://main.tscn is not a PackedScene")
		return null
	scene = packed.instantiate()
	root.add_child(scene) # _ready runs synchronously here for this scene.
	current_scene = scene
	await process_frame
	game = null
	for child in root.get_children():
		var script = child.get_script()
		if script != null and script.resource_path == "res://scripts/game.gd":
			game = child
			break
	if not check(game != null, "fresh scene ready", "missing game root child with res://scripts/game.gd"):
		return null
	# Freeze simulation so real frame time cannot affect item/economy assertions.
	game.set("paused", true)
	game.set("mana", 99999.0)
	game.set("stones", 99999)
	return game

func node(rid: String = "fire", grade: int = 1, grafts: Dictionary = {}) -> Dictionary:
	return {"rune": rid, "grade": grade, "grafts": grafts.duplicate(true)}

func nested() -> Dictionary:
	return node("ice", 2, {"ice_hit": [node("stone")]})

func fill(g: Object, full: bool) -> void:
	var inv = g.get("inventory")
	if not check(inv is Array and inv.size() > 2, "inventory fixture", "missing API: inventory Array"):
		return
	for i in inv.size():
		inv[i] = node("mana") if full else null

func craft_fixture(g: Object) -> void:
	g.set("craft", {"base": node("fire", 3, {"fire_hit": [node("water")]}),
		"pending": {"fire_hit": [nested(), node("stone")], "burn": [node("poison")]},
		"output": null})

func build(g: Object) -> Variant:
	var wb = g.get("wb")
	if not check(wb != null and wb.get("buildable") is Dictionary, "build cells", "missing API: wb.buildable Dictionary"):
		return null
	var cells: Array = wb.get("buildable").keys()
	cells.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	if not check(not cells.is_empty(), "available build cell"):
		return null
	var result = invoke(g, "try_build", [cells[0]])
	check(result is bool and result == true, "fixture try_build returns true", "got " + str(result))
	var towers = g.get("towers")
	if not towers is Array or towers.is_empty():
		check(false, "fixture tower created", "missing tower after try_build")
		return null
	return towers.back()

# Independent storage census: never use all_items() as its own expected result.
func census(g: Object) -> Array:
	var out: Array = []
	var inv = g.get("inventory")
	if inv is Array:
		for item in inv:
			if item is Dictionary:
				out.append(item)
	var craft = g.get("craft")
	if craft is Dictionary:
		if craft.get("base") is Dictionary:
			out.append(craft.base)
		for donors in craft.get("pending", {}).values():
			out.append_array(donors)
		if craft.get("output") is Dictionary:
			out.append(craft.output)
	var towers = g.get("towers")
	if towers is Array:
		for tower in towers:
			if is_instance_valid(tower) and tower.get("rune") is Dictionary:
				out.append(tower.get("rune"))
	return out

func bag(g: Object, nodes: Array) -> Array:
	var result: Array = []
	if not require_api(g, ["recipe"]):
		return result
	for item in nodes:
		if not item is Dictionary:
			check(false, "rune Dictionary", "all_items contains " + str(item))
			continue
		var recipe = g.call("recipe", item)
		if recipe is String:
			result.append(recipe)
		else:
			check(false, "canonical recipe type", str(recipe))
	result.sort()
	return result

func items(g: Object) -> Array:
	# Diagnostic fallback lets baseline behavior run even before all_items lands.
	# Missing API is always a failure, never a skip or an implicit pass.
	if not require_api(g, ["all_items"]):
		return bag(g, census(g))
	var result = g.call("all_items")
	if not check(result is Array, "all_items returns Array", "got " + str(result)):
		return bag(g, census(g))
	var actual := bag(g, result)
	check(actual == bag(g, census(g)), "all_items matches every storage location", "actual=" + str(actual) + " census=" + str(bag(g, census(g))))
	return actual

func rune_recipe(g: Object, item: Variant) -> String:
	if item == null:
		return "<empty>"
	if not item is Dictionary or not require_api(g, ["recipe"]):
		return "<missing API>"
	return str(g.call("recipe", item))

func tower_rows(g: Object) -> Array:
	var rows: Array = []
	for tower in g.get("towers"):
		if is_instance_valid(tower):
			rows.append([tower.get("cell"), rune_recipe(g, tower.get("rune"))])
	rows.sort_custom(func(a, b): return str(a) < str(b))
	return rows

func prices(g: Object) -> Dictionary:
	var result := {}
	if g.has_method("rune_cost") and g.get("spec") is Dictionary:
		for rid in g.get("spec").get("runes", {}):
			result[rid] = g.call("rune_cost", rid)
	if g.has_method("tower_cost"):
		result["_tower"] = g.call("tower_cost")
	return result

func snapshot(g: Object) -> Dictionary:
	var wb = g.get("wb")
	return {"inventory": g.get("inventory").duplicate(true), "craft": g.get("craft").duplicate(true),
		"towers": tower_rows(g), "mana": g.get("mana"), "stones": g.get("stones"),
		"castle_hp": g.get("castle_hp"), "wave": g.get("wave"), "wave_state": g.get("wave_state"),
		"prices": prices(g), "next_tid": g.get("next_tid"),
		"buildable": wb.get("buildable").duplicate(true) if wb != null else {}}

func operation(g: Object, method: String, args: Array, success: bool) -> Variant:
	var before := snapshot(g)
	var result = invoke(g, method, args)
	check(result is bool and result == success, method + " returns " + str(success), "got " + str(result) + "; contract requires bool")
	if not success:
		check(snapshot(g) == before, method + " failure is atomic", "items/placements, economy, prices, towers, cells or wave changed")
	return result

func conserved(g: Object, before: Array, label: String = "conservation") -> void:
	var after := items(g)
	check(after == before, label, "before=" + str(before) + " after=" + str(after))

func expected_items(g: Object, removed: Array, added: Array, before: Array) -> Array:
	var expected := before.duplicate()
	for item in bag(g, removed):
		var idx := expected.find(item)
		if check(idx >= 0, "expected source rune exists", str(item)):
			expected.remove_at(idx)
	expected.append_array(bag(g, added))
	expected.sort()
	return expected

func wallet_same(g: Object, before: Dictionary, label: String = "wallet unchanged") -> void:
	check(g.get("mana") == before.mana and g.get("stones") == before.stones, label)

func flush_summons() -> void:
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	await process_frame

func write_fixture(name: String, content: String) -> String:
	var path := fixture_dir.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "fixture file " + name, "could not write " + path):
		return ""
	file.store_string(content)
	file.close()
	return path

func _run() -> void:
	create_timer(180.0).timeout.connect(func():
		check(false, "watchdog", "test did not finish within 180 seconds: " + active_test)
		print("%d/%d checks passed" % [passed, checks])
		quit(1)
	)
	# Persistent and self-contained fixtures; never touch a player's user:// save.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir))
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()
	check(not files.is_empty(), "test discovery")
	for file in files:
		var start_checks := checks
		var start_passed := passed
		context = file
		active_test = file
		var script = load("res://tests/" + file)
		if not check(script != null and script.can_instantiate(), "load test", "parse error or invalid test script"):
			continue
		var test = script.new()
		if not check(test is RefCounted and test.has_method("run"), "test interface", "expected RefCounted.run(game, t)"):
			continue
		var fresh = await fresh_game()
		if fresh == null:
			continue
		completed = false
		# A synchronous GDScript runtime error aborts the test function; finish()
		# makes that visible as a failure even if its earlier assertions passed.
		await test.run(fresh, self)
		check(completed, "test completed", "test aborted before t.finish(); inspect engine errors in log")
		print("FILE_RESULT %s %d/%d" % [file, passed - start_passed, checks - start_checks])
	context = "runner"
	if is_instance_valid(scene):
		root.remove_child(scene)
		scene.free()
	await process_frame
	print("%d/%d checks passed" % [passed, checks])
	print("SUITE_EXIT_CODE=%d" % (0 if passed == checks else 1))
	quit(0 if passed == checks else 1)
