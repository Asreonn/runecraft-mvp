extends Node3D
## A tower: the approved tower model + one floating main rune. The rune's compiled program
## (rune_lib.compile_recipe) decides the attack: projectile / beam / meteor / volcano / golem / hive.

const GLB := preload("res://scripts/glb.gd")
const RUNE_Y := 2.05
const RUNE_SCALE := 0.5

var game
var tid := 0
var cell := Vector2i.ZERO
var rune = null                 # node dict {rune, grade, grafts} or null
var compiled: Dictionary = {}
var rdef: Dictionary = {}
var kind := ""
var hit_ops: Array = []
var summon = null               # summon op dict
var timer := 0.4
var target = null
var entity = null               # volcano / golem / hive state
var beetles: Array = []
var rune_node: Node3D
var orbit: Node3D
var bob := 0.0
var model: Node3D
var rune_gen := 0               # bumped on every rune change; in-flight lava/meteors of an old rune do nothing


func setup(g, id: int, c: Vector2i) -> void:
	game = g
	tid = id
	cell = c
	model = GLB.instance("units/tower.glb")
	add_child(model)
	orbit = Node3D.new()
	orbit.position.y = RUNE_Y
	add_child(orbit)
	bob = float(id) * 1.3


## Build animation in real time (independent of game speed / pause): rises from the cell with a squash.
func pop_in() -> void:
	model.scale = Vector3(1.25, 0.05, 1.25)
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(0.9, 1.15, 0.9), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## While a rune is dragged over this tower, its own rune hides so the incoming one reads clearly.
func preview_hide(on := false) -> void:
	if is_instance_valid(orbit):
		orbit.visible = not on


func range_tiles() -> float:
	return game.tower_range(game.cell_level(cell))


func set_rune(node) -> void:
	cleanup()                        # the old rune's volcano / golem / hive / beetles leave with it
	rune_gen += 1
	rune = node
	for ch in orbit.get_children():
		ch.queue_free()
	if rune == null:
		compiled = {}
		kind = ""
		return
	compiled = game.rl.compile_recipe(rune)
	rdef = game.spec.runes[rune.rune]
	kind = rdef.kind
	hit_ops = compiled.ops.filter(func(o): return not (o.family in ["SummonVolcano", "SummonGolem", "SummonHive", "MeteorCall", "ModifyIncomingDamage"]))
	summon = null
	for o in compiled.ops:
		if o.family in ["SummonVolcano", "SummonGolem", "SummonHive", "MeteorCall"]:
			summon = o
	rune_node = GLB.instance("runes/%s_g%d.glb" % [game.color_id(rune.rune), int(rune.grade)])
	rune_node.scale = Vector3.ONE * RUNE_SCALE
	orbit.add_child(rune_node)
	# grafted donors: at most 4 direct donors orbit the main rune (canonical order, so a recipe always looks the
	# same); every further graft node is summarised by one small "+N" tag instead of more models (no clutter).
	var donors := []
	for a in rdef.abilities:
		donors.append_array(game.rl.sorted_kids(rune.grafts.get(a.id, [])))
	var shown := mini(donors.size(), 4)
	for i in shown:
		var d = donors[i]
		var mc := GLB.instance("runes/%s_g%d.glb" % [game.color_id(d.rune), int(d.grade)])
		mc.scale = Vector3.ONE * 0.16
		mc.set_meta("orbit_i", i)
		mc.set_meta("orbit_n", shown)
		orbit.add_child(mc)
	var extra: int = game.rl.node_size(rune) - 1 - shown
	if extra > 0:
		var tag := Label3D.new()
		tag.text = "+%d" % extra
		tag.font = game.font_bold
		tag.font_size = 40
		tag.pixel_size = 0.008
		tag.outline_size = 10
		tag.modulate = Color("#D8FBFF")
		tag.outline_modulate = Color(0.06, 0.06, 0.08, 0.9)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0.55, 0.42, 0)
		orbit.add_child(tag)
	timer = 0.3


func _process(dt: float) -> void:
	bob += dt
	if rune_node:
		rune_node.position.y = sin(bob * 1.9) * 0.05
		rune_node.rotation.y = bob * 0.6
	for ch in orbit.get_children():
		if ch.has_meta("orbit_i"):
			var n: int = ch.get_meta("orbit_n")
			var a := bob * 1.4 + TAU * float(ch.get_meta("orbit_i")) / n
			ch.position = Vector3(cos(a) * 0.62, 0.05 + sin(a * 2.0) * 0.08, sin(a) * 0.62)
			ch.rotation.y = -a


## Grid targeting: an enemy is in range when the cell it stands on is inside this tower's range cells
## (cell-centre distance <= range), exactly the squares shown by the range overlay.
func in_range() -> Array:
	var r := range_tiles() + 0.01
	var es: Array = game.combat.alive().filter(func(e): return Vector2(e.cell() - cell).length() <= r)
	es.sort_custom(func(a, b): return a.s > b.s if a.s != b.s else a.eid < b.eid)
	return es


func pick():
	var tg := in_range()
	if target != null and is_instance_valid(target) and target in tg:
		return target
	target = tg[0] if not tg.is_empty() else null
	return target


func root_ctx() -> Dictionary:
	return game.combat.ctx_new(tid)


func period() -> float:
	return float(rdef.get("attack_s", game.spec.reference.attack_period_s))


func step(dt: float) -> void:
	if rune == null:
		return
	timer -= dt
	match kind:
		"projectile", "beam":
			if timer <= 0.0:
				var t = pick()
				if t != null:
					timer = period()
					_fire(t)
		"meteor":
			if timer <= 0.0:
				var t = pick()
				if t != null:
					timer = float(summon.params.period)
					_meteor(t)
		"volcano":
			_volcano(dt)
		"golem":
			_golem(dt)
		"hive":
			_hive(dt)


func _muzzle() -> Vector3:
	return global_position + Vector3(0, RUNE_Y, 0)


func _fire(t) -> void:
	var el: String = rdef.element
	if kind == "beam":
		game.vfx.beam(_muzzle(), t.global_position + Vector3(0, 0.45, 0), el)
		game.combat.run_event(hit_ops, t, t.tile_pos(), root_ctx())
		return
	# capture the target's id, not the target: the enemy may be freed while the bolt flies
	var tid: int = t.get_instance_id()
	game.vfx.projectile(_muzzle(), t, el, rune.rune, func():
		var tt = instance_from_id(tid)
		if tt != null and tt.alive and not tt.leaked:
			game.combat.run_event(hit_ops, tt, tt.tile_pos(), root_ctx())
	)


func _meteor(t) -> void:
	var P: Dictionary = summon.params
	var lead_raw: Vector3 = game.path_point(t.s + t.base_speed * t.speed_factor(game.now) * float(P.delay) * 0.9)
	var lead: Vector3 = game.cell_world(game.wb.world_to_cell(lead_raw))     # meteors land on cell centres
	var g := rune_gen
	game.vfx.meteor(lead, float(P.delay), func():
		if not is_instance_valid(self) or g != rune_gen:
			return
		var at := Vector2(lead.x, lead.z) * 0.5
		var n = game.combat.nearest(at, {}, 0.45)
		game.combat.run_event(hit_ops, n, at, root_ctx())
	)


# ---------------------------------------------------------------- summons

## Summons stand on a free grid cell next to the path, ahead of the target (cell centre, on its level).
func _side_point(t) -> Vector3:
	var ahead: Vector3 = game.path_point(t.s + 1.0)
	return game.cell_world(game.summon_cell(ahead))


func _volcano(dt: float) -> void:
	var P: Dictionary = summon.params
	if entity == null:
		if timer <= 0.0:
			var tg := in_range()
			if not tg.is_empty():
				var pos := _side_point(tg[0])
				entity = {"pos": pos, "left": float(P.life), "next": 0.6, "node": game.vfx.summon("summons/volcano.glb", pos, 0.9, tid)}
		return
	entity.left -= dt
	entity.next -= dt
	if entity.left <= 0.0:
		game.vfx.unsummon(entity.node)
		entity = null
		timer = 1.0
		return
	if entity.next <= 0.0:
		entity.next = float(P.period)
		var vp := Vector2(entity.pos.x, entity.pos.z) * 0.5
		var near: Array = game.combat.alive().filter(func(e): return (e.tile_pos() - vp).length() <= float(P.reach))
		if near.is_empty():
			return
		near.sort_custom(func(a, b): return (a.tile_pos() - vp).length() < (b.tile_pos() - vp).length())
		var extra: Array = summon.slots.get("extra_blobs", [])
		game.vfx.eruption(entity.pos)
		var g := rune_gen
		for i in int(P.blobs):
			var tgt = near[i % near.size()]
			var ops: Array = hit_ops + (extra if i > 0 else [])
			var tid: int = tgt.get_instance_id()
			game.vfx.lava_blob(entity.pos + Vector3(0, 1.0, 0), tgt, float(P.flight), func():
				var tt = instance_from_id(tid)
				if g == rune_gen and tt != null and tt.alive and not tt.leaked:
					game.combat.run_event(ops, tt, tt.tile_pos(), root_ctx())
			)


func _golem(dt: float) -> void:
	var P: Dictionary = summon.params
	if entity == null:
		if timer <= 0.0 and not in_range().is_empty():
			var pos: Vector3 = game.cell_world(game.summon_cell(global_position + Vector3(0, 0, 2.0)))
			entity = {"pos": pos, "left": float(P.life), "cd": 0.0, "n": 0, "target": null,
				"node": game.vfx.summon("summons/golem.glb", pos, 1.0, tid)}
		return
	entity.left -= dt
	entity.cd -= dt
	if entity.left <= 0.0:
		game.vfx.unsummon(entity.node)
		entity = null
		timer = 1.5
		return
	var t = entity.target
	if t == null or not t.alive or t.leaked:
		t = game.combat.nearest(Vector2(entity.pos.x, entity.pos.z) * 0.5, {}, 4.0)
		entity.target = t
	if t == null:
		return
	var tp: Vector3 = t.global_position
	var d := Vector3(tp.x - entity.pos.x, 0, tp.z - entity.pos.z)
	if d.length() > 0.6:
		entity.pos += d.normalized() * minf(d.length() - 0.5, float(P.speed) * 2.0 * dt)
	var n: Node3D = entity.node
	n.position = entity.pos
	if d.length() > 0.05:
		n.rotation.y = atan2(-d.z, d.x)
	if d.length() <= 1.0 and entity.cd <= 0.0:
		entity.cd = float(P.attack_s)
		entity.n += 1
		game.vfx.punch(n)
		if float(P.get("slam_r", 0)) > 0 and int(P.get("slam_every", 0)) > 0 and entity.n % int(P.slam_every) == 0:
			var dmg := hit_ops.filter(func(o): return o.family == "Damage" and int(o.depth) == 0)
			var subs: Array = summon.slots.get("slam", [])
			var gp := Vector2(entity.pos.x, entity.pos.z) * 0.5
			game.vfx.area(entity.pos, float(P.slam_r), "physical")
			for e in game.combat.alive():
				if (e.tile_pos() - gp).length() <= float(P.slam_r):
					game.combat.run_event(dmg + subs, e, e.tile_pos(), root_ctx())
		else:
			game.combat.run_event(hit_ops, t, t.tile_pos(), root_ctx())


func _hive(dt: float) -> void:
	var P: Dictionary = summon.params
	if entity == null:
		if timer <= 0.0:
			var tg := in_range()
			if not tg.is_empty():
				var pos := _side_point(tg[0])
				entity = {"pos": pos, "left": float(P.life), "spawn": 0.0, "extra": 0, "mark": null,
					"node": game.vfx.summon("summons/hive.glb", pos, 0.9, tid)}
				for b in beetles:
					game.vfx.unsummon(b.node)
				beetles.clear()
		return
	entity.left -= dt
	entity.spawn -= dt
	if entity.left <= 0.0:
		game.vfx.unsummon(entity.node)
		for b in beetles:
			game.vfx.unsummon(b.node)
		beetles.clear()
		entity = null
		timer = 1.5
		return
	var cap := int(P.beetles) + int(entity.extra)
	if entity.spawn <= 0.0 and beetles.size() < cap:
		entity.spawn = float(P.spawn_s)
		_spawn_beetle()
	var hp := Vector2(entity.pos.x, entity.pos.z) * 0.5
	var mark = null
	if float(P.get("focus", 0)) > 0:
		mark = entity.mark
		if mark == null or not mark.alive or mark.leaked:
			mark = game.combat.nearest(hp, {}, 2.5)
			entity.mark = mark
			if mark != null:
				game.vfx.focus(mark)
				var ms: Array = summon.slots.get("mark", [])
				if not ms.is_empty():
					game.combat.run_event(ms, mark, mark.tile_pos(), root_ctx())
	for b in beetles:
		b.cd -= dt
		var t = mark
		if t == null:
			t = b.t if (b.t != null and b.t.alive and not b.t.leaked) else game.combat.nearest(Vector2(b.pos.x, b.pos.z) * 0.5, {}, 2.5)
		b.t = t
		var n: Node3D = b.node
		if t == null:
			b.pos = b.pos.lerp(entity.pos + Vector3(0, 0.8, 0), dt * 2.0)
		else:
			var tp: Vector3 = t.global_position + Vector3(0, 0.5, 0)
			var d: Vector3 = tp - b.pos
			if d.length() > 0.3:
				b.pos += d.normalized() * minf(d.length() - 0.2, float(P.speed) * 2.0 * dt)
			if d.length() <= 0.6 and b.cd <= 0.0:
				b.cd = float(P.bite_s)
				var was: bool = t.alive
				game.combat.run_event(hit_ops, t, t.tile_pos(), root_ctx())
				if was and not t.alive and float(P.get("brood", 0)) > 0 and int(entity.extra) < int(game.spec.budgets.extra_beetles_from_brood):
					entity.extra += 1
					_spawn_beetle()
		n.position = b.pos + Vector3(0, sin(game.now * 14.0 + b.ph) * 0.06, 0)


func _spawn_beetle() -> void:
	var pos: Vector3 = entity.pos + Vector3(0, 0.9, 0)
	beetles.append({"pos": pos, "cd": 0.0, "t": null, "ph": randf() * 6.0, "node": game.vfx.summon("summons/bug.glb", pos, 0.8, tid)})
	var subs: Array = summon.slots.get("birth", [])
	if not subs.is_empty():
		var hp := Vector2(entity.pos.x, entity.pos.z) * 0.5
		for e in game.combat.alive():
			if (e.tile_pos() - hp).length() <= 0.3:
				game.combat.run_event(subs, e, e.tile_pos(), root_ctx())


## Remove every summon this tower owns (rune change, sell, unsocket). Safe to call repeatedly.
func cleanup() -> void:
	if entity != null and entity.has("node"):
		game.vfx.unsummon(entity.node)
	for b in beetles:
		game.vfx.unsummon(b.node)
	entity = null
	beetles.clear()
	target = null
