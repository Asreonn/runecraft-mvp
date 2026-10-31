extends RefCounted

func run(game, t) -> void:
	for method in ["all_items", "inv_free_slots", "inv_put", "buy_rune", "combine", "socket", "socket_output",
		"unsocket", "sell_tower", "craft_set_base", "craft_add", "craft_remove_pending", "craft_ungraft",
		"craft_clear", "do_craft", "take_output", "try_build", "rune_cost", "tower_cost", "serialize", "restore", "save_game", "load_game"]:
		t.check(game.has_method(method), "API " + method, "missing API: " + method)
	var constants: Dictionary = game.get_script().get_script_constant_map()
	t.check(constants.has("SAVE_VERSION"), "SAVE_VERSION", "missing API: SAVE_VERSION constant")
	# Every possible top-level location plus deliberately repeated recipes.
	t.fill(game, false)
	game.inventory[0] = t.node("fire")
	game.inventory[2] = t.node("fire")
	t.craft_fixture(game)
	game.craft.output = t.node("electric", 3)
	var tower = t.build(game)
	if tower != null and t.require_api(tower, ["set_rune"]):
		tower.call("set_rune", t.node("golem"))
	var actual: Array = t.items(game)
	t.check(actual.size() == 8, "census has eight top-level runes", "nested children must not count separately: " + str(actual))
	var free = t.invoke(game, "inv_free_slots")
	t.check(free is int and free == game.inventory.size() - 2, "inv_free_slots counts holes", str(free))
	t.finish()
