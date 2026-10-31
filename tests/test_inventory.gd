extends RefCounted

func run(game, t) -> void:
	for full in [false, true]:
		for scenario in ["inv_put", "socket_empty", "socket_swap", "socket_output_empty", "socket_output_swap", "unsocket", "sell_rune", "sell_empty", "take_output"]:
			t.context = "inventory/%s/full=%s" % [scenario, full]
			game = await t.fresh_game()
			if game == null:
				continue
			t.fill(game, full)
			var tower = null
			if scenario not in ["inv_put", "take_output"]:
				tower = t.build(game)
				if tower == null or not t.require_api(tower, ["set_rune"]):
					continue
			var incoming: Dictionary = t.node("fire", 3, {"fire_hit": [t.nested()]})
			var old: Dictionary = t.node("water", 2)
			if scenario in ["socket_swap", "socket_output_swap", "unsocket", "sell_rune"]:
				tower.call("set_rune", old)
			if scenario in ["socket_empty", "socket_swap"]:
				game.inventory[0] = incoming
			if scenario in ["socket_output_empty", "socket_output_swap", "take_output"]:
				game.craft.output = incoming
			var before: Array = t.items(game)
			var state: Dictionary = t.snapshot(game)
			match scenario:
				"inv_put":
					t.operation(game, "inv_put", [incoming], not full)
					var expected: Array = before if full else t.expected_items(game, [], [incoming], before)
					t.check(t.items(game) == expected, "inv_put stores exactly once or nothing")
				"socket_empty", "socket_swap":
					# Socketing from the inventory always succeeds: the old tower rune takes the slot the
					# incoming rune frees, so even a full inventory swap loses nothing (revised contract).
					var success: bool = true
					t.operation(game, "socket", [tower, 0], success)
					if success:
						t.check(t.rune_recipe(game, tower.get("rune")) == t.rune_recipe(game, incoming), "incoming rune socketed")
						t.check(game.inventory[0] == null or scenario == "socket_swap", "empty socket releases source slot")
				"socket_output_empty", "socket_output_swap":
					var success: bool = scenario == "socket_output_empty" or not full
					t.operation(game, "socket_output", [tower], success)
					if success:
						t.check(game.craft.output == null and t.rune_recipe(game, tower.get("rune")) == t.rune_recipe(game, incoming), "output moved to tower")
				"unsocket":
					t.operation(game, "unsocket", [tower], not full)
					if not full:
						t.check(tower.get("rune") == null, "tower cleared")
				"sell_rune", "sell_empty":
					var success: bool = scenario == "sell_empty" or not full
					var cell = tower.get("cell")
					var tower_id: int = tower.get_instance_id()
					t.operation(game, "sell_tower", [tower], success)
					if success:
						var remains := false
						for owned in game.towers:
							if is_instance_valid(owned) and owned.get_instance_id() == tower_id:
								remains = true
						t.check(not remains and game.wb.buildable.has(cell), "sale removes tower and releases cell")
						t.check(game.stones > state.stones, "sale refunds stones")
				"take_output":
					t.operation(game, "take_output", [], not full)
					if not full:
						t.check(game.craft.output == null, "output cleared after taking")
			if scenario != "inv_put":
				t.conserved(game, before)
			if scenario not in ["sell_empty", "sell_rune"]:
				t.wallet_same(game, state)
			var free = t.invoke(game, "inv_free_slots")
			var counted := 0
			for item in game.inventory:
				if item == null:
					counted += 1
			t.check(free is int and free == counted, "inv_free_slots remains accurate", str(free))
	t.finish()
