extends RefCounted
## Generic effect runtime — GDScript twin of runes/mechanics/sim.py, on the real map.
## Ops come from rune_lib.compile_recipe(): Dictionaries {family, params, slots, verb, uid, ...}.
## No rune-pair code: every behaviour is a family/status handler. Distances are in tiles
## (world units / 2). Path "along" movement uses Enemy.s.

const PAYLOAD := ["Damage", "ApplyStatus", "ForceMove", "CreateGroundField", "ModifyIncomingDamage", "ManaSiphon"]
const PROPAGATORS := ["ChainTransfer", "Pierce", "AreaImpact", "SpawnFragments", "MultiImpact"]
const ORDER := {"Damage": 0, "ApplyStatus": 1, "CreateGroundField": 2, "ForceMove": 3, "ModifyIncomingDamage": 4, "ManaSiphon": 5}

var game                      # game.gd (now, enemies, add_mana, add_stones, vfx)
var BUD: Dictionary
var INTER: Dictionary = {}
var fields: Array = []        # Dictionaries
var damage_total := 0.0
var _fid := 0
var damage_real := 0.0         # damage that removed HP (overkill excluded) — mana and DPS use this


func _init(g, spec_dict: Dictionary) -> void:
	game = g
	BUD = spec_dict.budgets
	for i in spec_dict.interactions:
		INTER[i.id] = i


func ctx_new(tower_id: int, gen := 0, budget = null, power := 1.0) -> Dictionary:
	return {"gen": gen, "budget": budget if budget != null else {"left": int(BUD.applications_per_root_event)},
		"power": power, "carried": [], "tower": tower_id, "event_damage": 0.0}


func child_ctx(ctx: Dictionary, gen: int, power: float) -> Dictionary:
	return {"gen": gen, "budget": ctx.budget, "power": power, "carried": [], "tower": ctx.tower, "event_damage": 0.0}


func alive() -> Array:
	return game.enemies.filter(func(e): return e.alive and not e.leaked)


func dist_t(a, b) -> float:
	return (a.tile_pos() - b.tile_pos()).length()


func nearest(pos: Vector2, exclude: Dictionary, within: float, prefer := ""):
	var best = null
	var bk := [9, 1e9, 1 << 30]
	for e in alive():
		if exclude.has(e.eid):
			continue
		var d: float = (e.tile_pos() - pos).length()
		if d > within:
			continue
		var key := [0 if prefer != "" and e.has(prefer) else 1, d, e.eid]
		if key[0] < bk[0] or (key[0] == bk[0] and (key[1] < bk[1] or (key[1] == bk[1] and key[2] < bk[2]))):
			bk = key
			best = e
	return best


# ------------------------------------------------------------------ events

func run_event(ops: Array, target, pos: Vector2, ctx: Dictionary) -> void:
	var payload := ops.filter(func(o): return o.family in PAYLOAD)
	var props := ops.filter(func(o): return o.family in PROPAGATORS)
	if target != null:
		apply_payload(payload, target, ctx)
	if int(ctx.gen) < int(BUD.max_generation):
		var carry: Array = payload.filter(func(o): return o.family != "CreateGroundField") + ctx.carried
		for p in props:
			propagate(p, carry, target, pos, ctx)


func apply_payload(payload: Array, e, ctx: Dictionary) -> void:
	if not e.alive or int(ctx.budget.left) <= 0:
		return
	ctx.budget.left = int(ctx.budget.left) - 1
	var sorted := payload.duplicate()
	sorted.sort_custom(func(a, b): return ORDER[a.family] < ORDER[b.family])
	var before := damage_real
	for o in sorted:
		if not e.alive:
			break
		match o.family:
			"Damage":
				deal(e, float(o.params.amount) * float(ctx.power), o.params.element, ctx)
			"ApplyStatus":
				apply_status(e, o, ctx)
			"CreateGroundField":
				make_field(e.tile_pos(), o, ctx)
			"ForceMove":
				push(e, o, ctx)
	# overkill never becomes mana; every producing Mana node has its own soft cap (economy.gd)
	var dealt := damage_real - before + float(ctx.event_damage)
	for o in payload:
		if o.family == "ManaSiphon":
			game.economy.rune_income(dealt * float(o.params.siphon), mana_node_key(int(ctx.tower), o.uid), int(o.grade), int(ctx.tower), e.global_position, "siphon")


## One income cap per producing Mana rune node: tower + the node's path in the recipe (uid without the op key),
## so siphon and mark of the same node share it, and equal recipes on different towers do not.
func mana_node_key(tower: int, uid: String) -> String:
	return "%d|%s" % [tower, uid.rsplit(".", true, 1)[0]]


# ------------------------------------------------------------------ damage / death

func deal(e, amount: float, element: String, ctx: Dictionary) -> void:
	if not e.alive or amount <= 0.0:
		return
	var armor: float = e.armor
	for v in e.get_all("shred"):
		armor -= float(v.pct)
	amount *= 1.0 - maxf(0.0, armor)
	for v in e.get_all("lit"):
		amount *= 1.0 + float(v.pct)
	if element == "electric" and e.has("wet"):
		amount *= float(INTER.wet_conducts.effect.damage_mult)
	damage_total += amount
	var real := minf(amount, maxf(e.hp, 0.0))       # damage that actually removed HP (no overkill)
	damage_real += real
	# mana marks near the victim turn this damage into mana (any tower); the strongest mark counts
	var best = null
	for m in alive():
		for v in m.get_all("mana_mark"):
			if dist_t(m, e) <= float(v.op.params.r) and (best == null or float(v.op.params.mark_pct) > float(best.op.params.mark_pct)):
				best = v
	if best != null:
		game.economy.rune_income(real * float(best.op.params.mark_pct), mana_node_key(int(best.tower), best.op.uid), int(best.op.grade), int(best.tower), e.global_position, "mark")
	e.hp -= amount
	e.flash = 0.12
	game.record_damage(int(ctx.tower), real)
	game.vfx.damage_number(e, amount, element)
	if e.hp <= 0.0:
		kill(e, ctx)


func kill(e, ctx: Dictionary) -> void:
	e.alive = false
	game.on_enemy_killed(e)
	# Every death effect is credited to the tower that OWNS it (the freezer, the poisoner, the marker), not to the
	# tower that happened to land the killing blow (damage, Mana caps and DPS stay attributable).
	# frozen-death shards: only when the freezing op carries shards (source authority)
	if game.now < e.frozen_until and e.frozen_by != null and float(e.frozen_by.params.get("shards", 0)) > 0:
		var op = e.frozen_by
		var root := ctx_new(int(e.frozen_tower) if e.frozen_tower >= 0 else int(ctx.tower), 0)
		var subs: Array = op.slots.get("shards", [])
		var seek := subs.any(func(x): return x.family == "ChainTransfer")
		var hit := {e.eid: true}
		for i in int(op.params.shards):
			var tgt = nearest(e.tile_pos(), hit, 1.5 if seek else 0.6)
			if tgt == null:
				game.vfx.shard(e.global_position, null, i)
				continue
			hit[tgt.eid] = true
			var c := child_ctx(root, 1, 1.0)
			game.vfx.shard(e.global_position, tgt, i)
			deal(tgt, float(op.params.shard_dmg), "ice", c)
			run_event(subs, tgt, tgt.tile_pos(), c)
	# poison contagion
	for v in e.get_all("poison"):
		if float(v.op.params.get("contagion", 0)) > 0:
			var tgt = nearest(e.tile_pos(), {e.eid: true}, 1.5)
			if tgt != null:
				var stacks := maxi(1, ceili(float(v.stacks) * float(v.op.params.contagion)))
				var proot := ctx_new(int(v.tower), 0)
				game.vfx.link(e.global_position, tgt.global_position, "poison", "bulaşma")
				apply_status(tgt, v.op, child_ctx(proot, 1, 1.0), stacks)
				run_event(v.op.slots.get("infect", []), tgt, tgt.tile_pos(), child_ctx(proot, 1, 1.0))
	# mana crystal: several marks on one enemy still crystallise once (the best one)
	var cv = null
	for v in e.get_all("mana_mark"):
		if float(v.op.params.get("crystal", 0)) > 0 and (cv == null or float(v.op.params.crystal) > float(cv.op.params.crystal)):
			cv = v
	if cv != null:
		game.add_stones(int(cv.op.params.crystal), e.global_position)
		var subs2: Array = cv.op.slots.get("crystal", [])
		var tgt2 = nearest(e.tile_pos(), {e.eid: true}, 1.0)
		if not subs2.is_empty() and tgt2 != null:
			run_event(subs2, tgt2, tgt2.tile_pos(), child_ctx(ctx_new(int(cv.tower), 0), 1, 1.0))


# ------------------------------------------------------------------ statuses

func apply_status(e, o: Dictionary, ctx: Dictionary, stacks := 1) -> void:
	var p: Dictionary = o.params
	var s: String = p.status
	# Damage-over-time statuses are one instance PER TOWER (two towers with the same recipe both burn / poison /
	# bleed, each with its own clock and credit); utility statuses (slow, wet, shred, blind, lit, mark) keep one
	# instance per recipe node and the strongest wins, so they never multiply.
	var key: String = s + "|" + o.uid
	if s in ["burn", "poison", "bleed"]:
		key = "%s|t%d|%s" % [s, int(ctx.tower), o.uid]
	var cur = e.st.get(key)
	var now: float = game.now
	match s:
		"burn":
			var dur := float(p.dur)
			if e.has("wet"):
				dur *= float(INTER.wet_douses_burn.effect.duration_mult)
				for k in e.st.keys():
					if k.begins_with("wet|"):
						e.st.erase(k)
				game.vfx.puff(e.global_position, Color(0.9, 0.95, 1.0))
			if cur:
				cur.left = maxf(cur.left, dur)
				cur.dps = maxf(cur.dps, float(p.dps))
				cur.gen = mini(cur.gen, int(ctx.gen))
			else:
				e.st[key] = {"op": o, "dps": float(p.dps), "left": dur, "next": 1.0, "gen": int(ctx.gen),
					"last_drop": _cellv(e.tile_pos()), "tower": ctx.tower, "spread": false}
		"slow", "wet", "shred", "blind", "lit":
			e.st[key] = {"op": o, "pct": float(p.get("pct", 0.0)), "left": float(p.dur)}
			var subs: Array = o.slots.get("apply", []) + o.slots.get("lit", [])
			if not subs.is_empty():
				run_event(subs, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
		"mana_mark":
			if not cur:
				game.vfx.mark(e, float(p.r), float(p.dur))
			e.st[key] = {"op": o, "left": float(p.dur), "tower": int(ctx.tower)}
			var ms: Array = o.slots.get("mark", [])
			if not ms.is_empty():
				run_event(ms, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
		"stun":
			if now >= float(e.stun_icd.get(o.uid, -1.0)):
				e.stun_until = maxf(e.stun_until, now + float(p.dur))
				e.stun_icd[o.uid] = now + float(p.get("icd", 0.0))
				game.vfx.stun(e)
				var ss: Array = o.slots.get("stun", [])
				if not ss.is_empty():
					run_event(ss, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
		"cold":
			if not cur:
				cur = {"op": o, "stacks": 0, "left": 4.0}
				e.st[key] = cur
			cur.stacks += int(p.per_hit)
			cur.left = 4.0
			var thr := int(p.threshold) - (int(INTER.wet_freezes_faster.effect.threshold_minus) if e.has("wet") else 0)
			if float(p.get("freeze", 0)) > 0 and cur.stacks >= maxi(1, thr):
				cur.stacks = 0
				freeze(e, o, float(p.freeze), ctx, false)
				if float(p.get("nova_r", 0)) > 0:
					game.vfx.area(e.global_position, float(p.nova_r), "ice")
					for n in alive():
						if n != e and dist_t(n, e) <= float(p.nova_r):
							freeze(n, o, float(p.freeze) * 0.5, ctx, true)
							var ns: Array = o.slots.get("nova", [])
							if not ns.is_empty():
								run_event(ns, n, n.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
		"charge":
			if not cur:
				cur = {"op": o, "stacks": 0, "left": 4.0}
				e.st[key] = cur
			cur.stacks += 1
			cur.left = 4.0
			if cur.stacks >= int(p.max):
				cur.stacks = 0
				game.vfx.burst(e.global_position, "electric", 1.4)
				deal(e, float(p.burst), "electric", ctx)
				if e.alive and float(p.get("stun", 0)) > 0:
					e.stun_until = maxf(e.stun_until, now + float(p.stun))
				var ds: Array = o.slots.get("discharge", [])
				if not ds.is_empty() and e.alive:
					run_event(ds, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
		"poison":
			var mx := int(p.get("max_stacks", 1))
			if cur:
				var was: int = cur.stacks
				cur.stacks = mini(mx, cur.stacks + stacks)
				cur.left = float(p.dur)
				if mx > 1 and was < mx and cur.stacks >= mx:
					var ts: Array = o.slots.get("threshold", [])
					if not ts.is_empty():
						run_event(ts, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
			else:
				e.st[key] = {"op": o, "stacks": mini(mx, stacks), "left": float(p.dur), "next": 1.0,
					"gen": int(ctx.gen), "tower": ctx.tower, "spread": false}
		"bleed":
			var mi := int(p.get("max_int", 1))
			if cur:
				var w: int = cur.int
				cur.int = mini(mi, cur.int + 1)
				cur.left = float(p.dur)
				if mi > 1 and w < mi and cur.int >= mi:
					var bs: Array = o.slots.get("threshold", [])
					if not bs.is_empty():
						run_event(bs, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
					if float(p.get("rupture", 0)) > 0:
						cur.int = 1
						game.vfx.burst(e.global_position, "blood", 1.2)
						deal(e, float(p.rupture), "blood", ctx)
						var rs: Array = o.slots.get("rupture", [])
						if not rs.is_empty() and e.alive:
							run_event(rs, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))
			else:
				e.st[key] = {"op": o, "int": 1, "left": float(p.dur), "acc": 0.0, "gen": int(ctx.gen), "tower": ctx.tower}


func freeze(e, o: Dictionary, dur: float, ctx: Dictionary, nova: bool) -> void:
	e.frozen_until = maxf(e.frozen_until, game.now + dur)
	e.frozen_by = o
	e.frozen_tower = int(ctx.tower)
	game.vfx.freeze(e, dur)
	var subs: Array = o.slots.get("freeze", [])
	if not subs.is_empty() and not nova:
		run_event(subs, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))


func tick_statuses(e, dt: float) -> void:
	for key in e.st.keys():
		if not e.st.has(key):
			continue
		var v: Dictionary = e.st[key]
		v.left -= dt
		var s: String = key.get_slice("|", 0)
		if s == "burn" or s == "poison":
			v.next -= dt
			if v.next <= 1e-9 and v.left > -dt:          # same one-second contract as sim.py (parity R2)
				v.next += 1.0
				var op: Dictionary = v.op
				var dmg: float
				var el: String
				if s == "burn":
					dmg = v.dps
					el = "fire"
				else:
					dmg = float(op.params.dps) * (1.0 + float(op.params.get("stack_bonus", 0.5)) * (v.stacks - 1))
					el = "poison"
				# a status instance propagates only on its first tick
				var gen: int = v.gen if not v.spread else int(BUD.max_generation)
				v.spread = true
				var root := ctx_new(v.tower, gen)
				root.carried = [op]
				var d0 := damage_total
				deal(e, dmg, el, root)
				root.event_damage = damage_total - d0
				game.vfx.tick(e, el)
				if e.alive:
					run_event(op.slots.get("tick", []), e, e.tile_pos(), root)
				if not e.alive:
					return
		if v.left <= 0.0 and e.st.has(key):
			e.st.erase(key)


# ------------------------------------------------------------------ movement

func move(e, dist: float, forced: bool) -> void:
	e.s += -dist if forced else dist
	e.s = maxf(e.s, 0.0)
	e.sync_position()          # follow-on propagation (chains, fields) must see the post-move position
	for key in e.st.keys():
		if not e.alive or not e.st.has(key):
			continue
		var v: Dictionary = e.st[key]
		if key.begins_with("bleed|"):
			var p: Dictionary = v.op.params
			var dmg: float = float(p.per_tile) * dist * (1.0 + float(p.get("int_step", 0.25)) * (v.int - 1))
			var c := ctx_new(v.tower, v.gen)
			deal(e, dmg, "blood", c)
			v.acc += dist
			while v.acc >= 1.0 and e.alive:
				v.acc -= 1.0
				game.vfx.tick(e, "blood")
				var subs: Array = v.op.slots.get("move", [])
				if not subs.is_empty():
					run_event(subs, e, e.tile_pos(), c)
		elif key.begins_with("burn|") and not forced:
			var bp: Dictionary = v.op.params
			if float(bp.get("trail_dps", 0)) > 0 and _cellv(e.tile_pos()) != v.last_drop:
				v.last_drop = _cellv(e.tile_pos())
				var nat := [{"family": "Damage", "uid": "native.trail", "params": {"amount": float(bp.trail_dps), "element": "fire"}, "slots": {}}]
				add_field({"pos": e.tile_pos(), "r": float(bp.trail_r), "left": float(bp.trail_dur), "dur": float(bp.trail_dur),
					"native": nat, "subs": v.op.slots.get("trail", []), "gen": v.gen, "kind": "fire_trail",
					"tower": v.tower, "next_tick": game.now + 0.3})


func push(e, o: Dictionary, ctx: Dictionary) -> void:
	var d := float(o.params.dist) * minf(1.0, float(ctx.power))
	if e.has("burn"):
		d *= float(INTER.burning_push.effect.dist_mult)
	if game.now < e.frozen_until:
		d *= float(INTER.frozen_pushed_short.effect.dist_mult)
	game.vfx.push(e)
	move(e, d, true)
	var subs: Array = o.slots.get("push", [])
	if not subs.is_empty() and e.alive:
		run_event(subs, e, e.tile_pos(), child_ctx(ctx, ctx.gen, 1.0))


# ------------------------------------------------------------------ fields

## Fields are grid cells: a field covers exactly the cell it was created in (tile_pos space,
## cell centres are integer coordinates). Same kind + same tower on the same cell refreshes instead of stacking.
func _cellv(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x), roundf(p.y))


func make_field(pos: Vector2, o: Dictionary, ctx: Dictionary) -> void:
	var p: Dictionary = o.params
	var nat := []
	for n in p.get("native", []):
		var params: Dictionary = n.duplicate()
		params.erase("family")
		nat.append({"family": n.family, "uid": o.uid + ".native." + n.family, "params": params, "slots": {}})
	add_field({"pos": pos, "r": float(p.r), "left": float(p.dur), "dur": float(p.dur), "native": nat,
		"subs": o.slots.get("field", []), "gen": int(ctx.gen), "kind": p.kind, "tower": ctx.tower, "next_tick": game.now})


func add_field(f: Dictionary) -> void:
	f.pos = _cellv(f.pos)
	for x in fields:
		if x.tower == f.tower and x.kind == f.kind and x.pos == f.pos:
			x.left = maxf(x.left, f.left)
			x.dur = maxf(x.dur, f.dur)
			return
	var mine := fields.filter(func(x): return x.tower == f.tower)
	if mine.size() >= int(BUD.fields_per_tower):
		var old = mine[0]
		fields.remove_at(fields.find(old))
		game.vfx.field_end(old)
	_fid += 1
	f.fid = _fid                       # stable identity: field dictionaries change every tick
	fields.append(f)
	game.vfx.field_start(f)


func update_fields(dt: float) -> void:
	var touched := {}
	for f in fields.duplicate():
		f.left -= dt
		if f.left <= 0.0:
			fields.remove_at(fields.find(f))
			game.vfx.field_end(f)
			continue
		if game.now + 0.0001 >= f.next_tick:
			f.next_tick = game.now + 1.0
			for e in alive():
				var k := "%d|%s|%d" % [e.eid, f.kind, f.tower]
				if _cellv(e.tile_pos()) == f.pos and not touched.has(k):
					touched[k] = true
					run_event(f.native + f.subs, e, e.tile_pos(), ctx_new(f.tower, f.gen))


# ------------------------------------------------------------------ propagators

func propagate(p: Dictionary, carry: Array, target, pos: Vector2, ctx: Dictionary) -> void:
	var P: Dictionary = p.params
	var visited := {}
	if target != null:
		visited[target.eid] = true
	var origin = target
	match p.family:
		"ChainTransfer":
			var cur = target
			for k in range(1, int(P.hops) + 1):
				if cur == null:
					break
				var rng: float = float(BUD.chain_range_tiles) * (float(INTER.wet_conducts.effect.chain_range_mult) if cur.has("wet") else 1.0)
				var n = nearest(cur.tile_pos(), visited, rng, "wet")
				if n == null:
					break
				visited[n.eid] = true
				var c := child_ctx(ctx, ctx.gen + 1, float(ctx.power) * pow(float(P.power), k))
				game.vfx.link(cur.global_position, n.global_position, _carry_element(carry), (str(p.get("verb", "")) if str(p.get("verb", "")) != "" else "seker"))
				apply_payload(carry, n, c)
				run_event(p.slots.get("jump", []), n, n.tile_pos(), c)
				cur = n
		"Pierce":
			for k in range(1, int(P.n) + 1):
				var n = nearest(target.tile_pos() if target != null else pos, visited, 0.9)
				if n == null:
					break
				visited[n.eid] = true
				var c := child_ctx(ctx, ctx.gen + 1, float(ctx.power) * pow(float(P.power), k))
				game.vfx.link(origin.global_position if origin else Vector3(pos.x * 2, 0.6, pos.y * 2), n.global_position, "light", "ışın deler")
				apply_payload(carry, n, c)
				run_event(p.slots.get("pierce", []), n, n.tile_pos(), c)
		"AreaImpact":
			var c := child_ctx(ctx, ctx.gen + 1, float(ctx.power) * float(P.frac))
			game.vfx.area(Vector3(pos.x * 2.0, 0.05, pos.y * 2.0), float(P.r), _carry_element(carry))
			for n in alive():
				var inside: bool = (n.tile_pos() - pos).length() <= float(P.r)
				if not inside and not visited.has(n.eid):
					continue
				if not visited.has(n.eid):
					apply_payload(carry, n, c)
				run_event(p.slots.get("area", []), n, n.tile_pos(), c)
		"SpawnFragments":
			for i in int(P.n):
				var n = nearest(pos, visited, 1.0)
				if n == null:
					break
				visited[n.eid] = true
				var c := child_ctx(ctx, ctx.gen + 1, float(ctx.power) * float(P.frac))
				game.vfx.shard(Vector3(pos.x * 2.0, 0.3, pos.y * 2.0), n, i, _carry_element(carry))
				apply_payload(carry, n, c)
				run_event(p.slots.get("fragment", []), n, n.tile_pos(), c)
		"MultiImpact":
			for i in int(P.n):
				var sgn := 1.0 if i % 2 == 0 else -1.0
				var off := Vector2(float(P.spread) * sgn * (1 + i / 2), float(P.spread) * 0.5 * -sgn)
				var at := pos + off
				game.vfx.mini_meteor(Vector3(at.x * 2.0, 0.0, at.y * 2.0))
				var n = nearest(at, visited, 0.45)
				if n == null:
					continue
				visited[n.eid] = true
				var c := child_ctx(ctx, ctx.gen + 1, float(ctx.power) * float(P.frac))
				apply_payload(carry, n, c)
				run_event(p.slots.get("mini", []), n, n.tile_pos(), c)


func _carry_element(carry: Array) -> String:
	for o in carry:
		if o.family == "Damage":
			return o.params.element
	for o in carry:
		if o.family == "ApplyStatus":
			return {"burn": "fire", "poison": "poison", "slow": "ice", "cold": "ice", "bleed": "blood", "wet": "water"}.get(o.params.status, "arcane")
	return "electric"
