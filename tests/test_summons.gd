extends RefCounted

func run(game, t) -> void:
	for rid in ["volcano", "golem", "hive"]:
		for action in ["replace", "clear", "sell"]:
			t.context = "summons/%s/%s" % [rid, action]
			game = await t.fresh_game()
			if not t.require_api(game, ["start_wave", "_spawn"]):
				continue
			t.fill(game, false)
			var tower = t.build(game)
			if tower == null or not t.require_api(tower, ["set_rune", "step"]):
				continue
			if not t.check(tower.get("tid") is int and tower.get("beetles") is Array, "summon state API", "missing API: tid / beetles"):
				continue
			tower.call("set_rune", t.node(rid))
			game.call("start_wave")
			game.call("_spawn", "normal")
			if not t.check(game.enemies.size() > 0, "real enemy spawned"):
				continue
			# Drive the real tower spawn path with a nearby real enemy. Simulation
			# remains paused, preventing movement, natural expiration and respawns.
			var enemy = game.enemies.back()
			enemy.position = tower.position + Vector3(0, 0, 2)
			enemy.hp = 999999.0
			tower.set("timer", 0.0)
			tower.call("step", 0.01)
			if not t.check(tower.get("entity") is Dictionary, "entity spawned before cleanup"):
				continue
			if rid == "hive":
				tower.call("step", 0.01)
				t.check(not tower.get("beetles").is_empty(), "hive beetles spawned before cleanup")
			var tracked: Array = []
			var entity: Dictionary = tower.get("entity")
			if entity.get("node") is Node:
				tracked.append(weakref(entity.node))
			for beetle in tower.get("beetles"):
				if beetle.get("node") is Node:
					tracked.append(weakref(beetle.node))
			t.check(not tracked.is_empty(), "actual summon nodes tracked")
			var owner: int = tower.get("tid")
			for reference in tracked:
				var summon_node = reference.get_ref()
				t.check(summon_node != null and summon_node.is_in_group("summons"), "summon belongs to summons group", "missing API: summons group for " + rid)
				if summon_node != null:
					t.check(summon_node.has_meta("summon_owner") and summon_node.get_meta("summon_owner", -1) == owner, "summon_owner is tower tid", "missing API: summon_owner metadata")
			var tower_ref: WeakRef = weakref(tower)
			match action:
				"replace": tower.call("set_rune", t.node("fire"))
				"clear": tower.call("set_rune", null)
				"sell": t.operation(game, "sell_tower", [tower], true)
			# For sale inspect state before queue_free destroys the tower.
			var entity_cleared: bool = tower.get("entity") == null
			var beetles_cleared: bool = tower.get("beetles").is_empty()
			await t.flush_summons()
			t.check(entity_cleared, "cleanup sets entity null")
			t.check(beetles_cleared, "cleanup clears beetles")
			var owned_left := 0
			for summon_node in t.get_nodes_in_group("summons"):
				if summon_node.get_meta("summon_owner", -1) == owner:
					owned_left += 1
			t.check(owned_left == 0, "no owned summons after tween and queue_free", "remaining=" + str(owned_left))
			# Independent references also catch missing group registration and
			# cleanup that merely removes metadata while leaving visual orphans.
			for reference in tracked:
				t.check(reference.get_ref() == null, "spawned summon actually freed", "orphaned node after " + action)
			if action == "sell":
				t.check(tower_ref.get_ref() == null, "sold tower freed")
			else:
				var live_tower = tower_ref.get_ref()
				if t.check(live_tower != null, "tower survives rune change"):
					t.check(live_tower.get("entity") == null and live_tower.get("beetles").is_empty(), "cleared state persists after frames")
	t.finish()
