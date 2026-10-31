extends RefCounted

func run(game, t) -> void:
	for full in [false, true]:
		for scenario in ["replace_base", "clear", "remove_pending", "ungraft", "combine", "add", "craft"]:
			t.context = "craft/%s/full=%s" % [scenario, full]
			game = await t.fresh_game()
			if game == null:
				continue
			t.fill(game, full)
			t.craft_fixture(game)
			var incoming: Dictionary = t.node("light", 3)
			var donor: Dictionary = t.nested()
			var a: Dictionary = t.node("fire", 3, {"fire_hit": [donor], "burn": [t.node("poison")]})
			var b: Dictionary = t.node("fire", 3, {"fire_hit": [t.node("water")], "fire_trail": [t.node("stone")]})
			if scenario == "replace_base":
				game.inventory[0] = incoming
			if scenario == "ungraft":
				game.craft.base = a.duplicate(true)
			if scenario == "combine":
				game.inventory[0] = a.duplicate(true)
				game.inventory[1] = b.duplicate(true)
			if scenario == "add":
				# Known valid G1 Stone donor onto Fire's hit carrier.
				game.inventory[0] = t.node("stone")
			if scenario == "clear":
				game.craft.output = t.node("blood", 2) # clearing inputs must preserve output
			var before: Array = t.items(game)
			var state: Dictionary = t.snapshot(game)
			match scenario:
				"replace_base":
					t.operation(game, "craft_set_base", [0], not full)
					if not full:
						t.check(t.rune_recipe(game, game.craft.base) == t.rune_recipe(game, incoming) and game.craft.pending.is_empty() and game.inventory[0] == null, "new base, old base and all donors returned")
				"clear":
					t.operation(game, "craft_clear", [], not full)
					if not full:
						t.check(game.craft.base == null and game.craft.pending.is_empty() and game.craft.output == state.craft.output, "inputs cleared, output retained")
				"remove_pending":
					t.operation(game, "craft_remove_pending", ["fire_hit", 0], not full)
					if not full:
						t.check(game.craft.pending.get("fire_hit", []).size() == 1, "only requested pending donor removed")
				"ungraft":
					var after_base: Dictionary = a.duplicate(true)
					after_base.grafts.erase("fire_hit")
					var expected: Array = before if full else t.expected_items(game, [a], [after_base, donor], before)
					t.operation(game, "craft_ungraft", ["fire_hit", 0], not full)
					t.check(t.items(game) == expected, "ungraft splits intact nested subtree")
					if not full:
						t.check(t.rune_recipe(game, game.craft.base) == t.rune_recipe(game, after_base), "only selected graft removed from base")
				"combine":
					var merged: Dictionary = t.node("fire", 4, {"fire_hit": [donor, t.node("water")], "burn": [t.node("poison")], "fire_trail": [t.node("stone")]})
					var expected: Array = t.expected_items(game, [a, b], [merged], before)
					t.operation(game, "combine", [0, 1], true)
					t.check(t.items(game) == expected, "combine merges grafts on both sources exactly once")
					t.check(t.rune_recipe(game, game.inventory[0]) == t.rune_recipe(game, merged) and game.inventory[1] == null, "combine destination and source")
				"add":
					t.operation(game, "craft_add", ["fire_hit", 0], true)
					t.check(game.inventory[0] == null and game.craft.pending.get("fire_hit", []).size() == 3, "donor moved into pending")
				"craft":
					var merged: Dictionary = state.craft.base.duplicate(true)
					var inputs: Array = [state.craft.base]
					for ability in state.craft.pending:
						if not merged.grafts.has(ability):
							merged.grafts[ability] = []
						for item in state.craft.pending[ability]:
							inputs.append(item)
							merged.grafts[ability].append(item.duplicate(true))
					var expected: Array = t.expected_items(game, inputs, [merged], before)
					t.operation(game, "do_craft", [], true)
					t.check(t.items(game) == expected, "craft appends every donor subtree to base")
					t.check(game.craft.base == null and game.craft.pending.is_empty() and t.rune_recipe(game, game.craft.output) == t.rune_recipe(game, merged), "crafted output and consumed inputs")
			if scenario not in ["ungraft", "combine", "craft"]:
				t.conserved(game, before)
			if scenario in ["combine", "craft"]:
				t.check(game.mana < state.mana and game.stones == state.stones, "successful transformation charges mana only")
			else:
				t.wallet_same(game, state)
	await _capacity_edges(t)
	t.finish()

func _capacity_edges(t) -> void:
	# Boundary cases catch partial returns when capacity is short by exactly one.
	for scenario in ["clear_short", "clear_exact", "replace_short", "replace_exact"]:
		t.context = "craft/capacity/" + scenario
		var game = await t.fresh_game()
		t.fill(game, true)
		t.craft_fixture(game) # base + 3 pending = 4 slots to return
		var replace: bool = scenario.begins_with("replace")
		var exact: bool = scenario.ends_with("exact")
		# Replacement releases its incoming slot, so only 3 holes are needed.
		var holes: int = (3 if replace else 4) - (0 if exact else 1)
		for i in holes:
			game.inventory[i + 1] = null
		if replace:
			game.inventory[0] = t.node("light", 3)
		var before: Array = t.items(game)
		t.operation(game, "craft_set_base" if replace else "craft_clear", [0] if replace else [], exact)
		t.conserved(game, before, "capacity edge preserves all runes")
