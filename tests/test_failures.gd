extends RefCounted

func run(game, t) -> void:
	for scenario in ["combine_same", "combine_mismatch", "combine_max", "combine_poor", "socket_empty", "socket_null", "output_empty", "unsocket_empty", "base_empty", "add_no_base", "add_rejected", "craft_empty", "craft_output_occupied", "craft_poor", "take_empty", "build_invalid", "build_occupied", "build_poor"]:
		t.context = "failures/" + scenario
		game = await t.fresh_game()
		if game == null:
			continue
		t.fill(game, false)
		var before: Array = t.items(game)
		match scenario:
			"combine_same", "combine_mismatch", "combine_max", "combine_poor":
				game.inventory[0] = t.node("fire", 5 if scenario == "combine_max" else 1)
				game.inventory[1] = t.node("ice" if scenario == "combine_mismatch" else "fire", 5 if scenario == "combine_max" else 1)
				if scenario == "combine_poor":
					game.mana = 0.0
				t.operation(game, "combine", [0, 0 if scenario == "combine_same" else 1], false)
			"socket_empty", "socket_null", "output_empty", "unsocket_empty":
				var tower = t.build(game)
				if tower == null:
					continue
				match scenario:
					"socket_empty": t.operation(game, "socket", [tower, 0], false)
					"socket_null":
						game.inventory[0] = t.node()
						t.operation(game, "socket", [null, 0], false)
					"output_empty": t.operation(game, "socket_output", [tower], false)
					"unsocket_empty": t.operation(game, "unsocket", [tower], false)
			"base_empty": t.operation(game, "craft_set_base", [0], false)
			"add_no_base", "add_rejected":
				game.inventory[0] = t.node("stone")
				if scenario == "add_rejected":
					game.craft.base = t.node("fire", 1)
				# burn is locked on a G1 base; guard against an invalid spec key.
				t.operation(game, "craft_add", ["burn", 0], false)
			"craft_empty": t.operation(game, "do_craft", [], false)
			"craft_output_occupied", "craft_poor":
				t.craft_fixture(game)
				if scenario == "craft_output_occupied":
					game.craft.output = t.node("blood")
				else:
					game.mana = 0.0
				t.operation(game, "do_craft", [], false)
			"take_empty": t.operation(game, "take_output", [], false)
			"build_invalid": t.operation(game, "try_build", [Vector2i(-100, -100)], false)
			"build_occupied":
				var tower = t.build(game)
				if tower != null:
					t.operation(game, "try_build", [tower.get("cell")], false)
			"build_poor":
				game.stones = 0
				var cells: Array = game.wb.buildable.keys()
				cells.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
				if t.check(not cells.is_empty(), "poor build fixture has valid cell"):
					t.operation(game, "try_build", [cells[0]], false)
		# operation() compares placements and wallet immediately around the call;
		# this additional check exercises all_items even in no-item scenarios.
		before = t.items(game)
		t.check(before == t.bag(game, t.census(game)), "post-rejection ownership census")
	t.finish()
