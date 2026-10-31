extends RefCounted
## Status stacking and credit (user-approved 2026-10-31): damage-over-time statuses (burn, poison, bleed) are one
## instance per tower; utility statuses stay one per recipe node (strongest wins); death effects — contagion,
## frozen-death shards, crystal grafts — are credited to the tower that owns them, not to the killer.

func _op(game, recipe: Dictionary, status: String):
	for o in game.rl.walk(game.rl.compile_recipe(recipe).ops):
		if o.family == "ApplyStatus" and o.params.get("status") == status:
			return o
	return null


func _two(game, t) -> Array:
	for old in game.enemies:              # earlier fixtures must not be picked as "nearest"
		old.alive = false
	game.call("start_wave")
	game.call("_spawn", "normal")
	game.call("_spawn", "normal")
	var a = game.enemies[game.enemies.size() - 2]
	var b = game.enemies[game.enemies.size() - 1]
	a.hp = 999999.0
	b.hp = 999999.0
	b.position = a.position + Vector3(0.4, 0, 0)
	return [a, b]


func run(game, t) -> void:
	t.context = "ownership"
	game = await t.fresh_game()
	if game == null:
		t.finish()
		return
	var c = game.combat
	var ab := _two(game, t)
	var a = ab[0]
	var burn = _op(game, t.node("fire", 3), "burn")
	c.apply_status(a, burn, c.ctx_new(1, 0))
	c.apply_status(a, burn, c.ctx_new(2, 0))
	c.apply_status(a, burn, c.ctx_new(2, 0))
	var burns: Array = a.get_all("burn")
	t.check(burns.size() == 2, "identical recipes on two towers: two burn instances", str(burns.size()))
	t.check(burns.map(func(v): return int(v.tower)).has(1) and burns.map(func(v): return int(v.tower)).has(2), "each burn keeps its own tower")
	var pois = _op(game, t.node("poison", 3), "poison")
	c.apply_status(a, pois, c.ctx_new(1, 0))
	c.apply_status(a, pois, c.ctx_new(2, 0))
	t.check(a.get_all("poison").size() == 2, "identical poison from two towers: two instances")
	var slow = _op(game, t.node("ice", 2), "slow")
	c.apply_status(a, slow, c.ctx_new(1, 0))
	c.apply_status(a, slow, c.ctx_new(2, 0))
	t.check(a.get_all("slow").size() == 1, "utility status (slow) stays one instance per recipe node")
	# per-tower burn ticks credit their own tower
	game.dmg_log.clear()
	for i in 70:
		c.tick_statuses(a, 1.0 / 60.0)
	t.check(game.dmg_log.has(1) and game.dmg_log.has(2), "both towers' burns tick and are credited", str(game.dmg_log.keys()))
	# contagion: poisoner 7, killer 9 → the spread poison belongs to 7
	ab = _two(game, t)
	a = ab[0]
	var b = ab[1]
	var cont = _op(game, t.node("poison", 4), "poison")
	if t.check(cont != null and float(cont.params.get("contagion", 0)) > 0, "Poison G4 carries contagion"):
		c.apply_status(a, cont, c.ctx_new(7, 0))
		c.kill(a, c.ctx_new(9, 0))
		var owners: Array = b.get_all("poison").map(func(v): return int(v.tower))
		t.check(owners == [7], "contagion keeps the poisoning tower's credit", str(owners))
	# frozen-death shards: freezer 7, killer 9 → shard damage credited to 7
	ab = _two(game, t)
	a = ab[0]
	b = ab[1]
	var fr = null
	for o in game.rl.walk(game.rl.compile_recipe(t.node("ice", 4)).ops):
		if float(o.params.get("shards", 0)) > 0:
			fr = o
	if t.check(fr != null, "Ice G4 carries frozen-death shards"):
		game.dmg_log.clear()
		c.freeze(a, fr, 2.0, c.ctx_new(7, 0), false)
		c.kill(a, c.ctx_new(9, 0))
		t.check(game.dmg_log.has(7) and not game.dmg_log.has(9), "frozen-death shards credit the freezing tower", str(game.dmg_log.keys()))
	t.finish()
