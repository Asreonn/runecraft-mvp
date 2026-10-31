extends Node3D
## Combat VFX for the MVP. Godot-native: unshaded/additive cubes, ImmediateMesh ribbons and
## lightning (midpoint displacement), CPUParticles3D bursts, Label3D numbers. Colours come from
## the rune palette of the damage element. Chain/hop visuals follow the HOST carrier verb.

const GLB := preload("res://scripts/glb.gd")

var game
var cam: Camera3D
var mats: Dictionary = {}
var movers: Array = []          # projectiles / blobs / shards / meteors
var links: Array = []           # bolts & beams drawn into link_mesh
var link_mesh := ImmediateMesh.new()
var fx: Array = []              # timed nodes {node, age, life, kind}
var numbers: Dictionary = {}    # enemy id -> {amount, el, t}
var floaters: Array = []
var field_nodes: Dictionary = {}
var rng := RandomNumberGenerator.new()


func setup(g, camera: Camera3D) -> void:
	game = g
	cam = camera
	var mi := MeshInstance3D.new()
	mi.mesh = link_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	rng.seed = 7


func col(el: String, which := "mid") -> Color:
	return game.element_color(el, which)


# ------------------------------------------------------------------ materials

func add_mat(c: Color, alpha := 1.0, additive := true) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [c.to_html(), alpha, additive]
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mats[key] = m
	return mats[key]


func ribbon_mat(additive: bool, hdr := 1.0) -> StandardMaterial3D:
	var key := "rib|%s|%.2f" % [additive, hdr]
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(hdr, hdr, hdr, 1.0)
		mats[key] = m
	return mats[key]


func cube(size: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func particles(at: Vector3, c1: Color, c2: Color, amount := 16, vel := 2.2, size := 0.08, life := 0.5, gravity := -5.0, spread := 180.0, dir := Vector3.UP) -> void:
	var e := CPUParticles3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.4, 1.4, 1.4)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	bm.material = m
	e.mesh = bm
	e.amount = amount
	e.lifetime = life
	e.one_shot = true
	e.explosiveness = 0.95
	e.local_coords = false
	e.direction = dir
	e.spread = spread
	e.initial_velocity_min = vel * 0.4
	e.initial_velocity_max = vel
	e.gravity = Vector3(0, gravity, 0)
	e.angular_velocity_min = -200
	e.angular_velocity_max = 200
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(1, 0.1))
	e.scale_amount_curve = sc
	var g := Gradient.new()
	var c3 := c2; c3.a = 0.0
	g.colors = PackedColorArray([c1, c2, c3])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	e.color_ramp = g
	e.position = at
	add_child(e)
	e.emitting = true
	fx.append({"node": e, "age": 0.0, "life": life + 0.2, "kind": "free"})


## Expanding ground ring: Penpot sprite (rcui / vfx_ring) lying flat on the ground.
func ring(at: Vector3, c: Color, radius: float, life := 0.45) -> void:
	sprite(Vector3(at.x, at.y + 0.08, at.z), "vfx_ring", c, radius * 2.0, life, 0.0, true)


## Hit flash: a voxel cube core plus a billboard glow + spark sprite (Penpot exports rcui / vfx_glow, vfx_spark).
func flash(at: Vector3, c: Color, size := 0.5, life := 0.14) -> void:
	var mi := cube(size * 0.6, add_mat(c, 0.9).duplicate())
	mi.position = at
	add_child(mi)
	fx.append({"node": mi, "age": 0.0, "life": life, "kind": "pop", "mat": mi.material_override})
	sprite(at, "vfx_glow", c, size * 2.4, life * 1.6)
	sprite(at, "vfx_spark", c.lerp(Color.WHITE, 0.4), size * 1.6, life * 1.3, randf() * TAU)


static var _sprite_tex: Dictionary = {}


func _vfx_tex(name: String) -> Texture2D:
	if not _sprite_tex.has(name):
		_sprite_tex[name] = load("res://ui/skin.gd").tex(name)
	return _sprite_tex[name]


## Additive billboard sprite that pops and fades (also used for impact rings on the ground when flat = true).
func sprite(at: Vector3, tex_name: String, c: Color, size: float, life: float, rot := 0.0, flat := false) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _vfx_tex(tex_name)
	m.albedo_color = Color(c.r, c.g, c.b, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = not flat
	if not flat:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	if flat:
		mi.rotation = Vector3(-PI * 0.5, rot, 0)
	else:
		mi.rotation.z = rot
	add_child(mi)
	fx.append({"node": mi, "age": 0.0, "life": life, "kind": "sprite", "mat": m, "flat": flat})


# ------------------------------------------------------------------ public API used by combat/tower

func projectile(from: Vector3, target, el: String, rune_id: String, cb: Callable) -> void:
	var c := col(el)
	var core := cube(0.24, add_mat(col(el, "hot"), 1.0))
	var halo := cube(0.46, add_mat(c, 0.32))
	core.add_child(halo)
	core.position = from
	add_child(core)
	var lob := 0.0
	if rune_id in ["stone", "poison", "blood"]:
		lob = 1.2
	movers.append({"node": core, "from": from, "target": target, "to": target.global_position + Vector3(0, 0.45, 0),
		"t": 0.0, "dur": maxf(0.18, from.distance_to(target.global_position) / 15.0), "lob": lob, "cb": cb,
		"trail": [], "c": c, "hot": col(el, "hot"), "el": el, "spin": rune_id == "stone"})
	particles(from, col(el, "hot"), c, 6, 1.2, 0.06, 0.25, 0.0)


func beam(a: Vector3, b: Vector3, el: String) -> void:
	links.append({"kind": "beam", "a": a, "b": b, "age": 0.0, "life": 0.18, "c": col(el), "hot": col(el, "hot")})
	flash(b, col(el, "hot"), 0.35, 0.12)
	particles(b, col(el, "hot"), col(el), 8, 2.0, 0.06, 0.35)


func link(a: Vector3, b: Vector3, el: String, verb: String) -> void:
	var c := col(el)
	a.y = maxf(a.y, 0.5); b.y = maxf(b.y, 0.45)
	if "lav" in verb:
		var blob := GLB.instance("summons/lava_blob.glb")
		blob.scale = Vector3.ONE * 0.5
		add_child(blob)
		movers.append({"node": blob, "from": a, "to": b, "target": null, "t": 0.0, "dur": 0.32, "lob": 1.0,
			"cb": Callable(), "trail": [], "c": col("lava"), "hot": col("lava", "hot"), "el": "lava", "spin": true})
	elif "mermi" in verb or "vuruş" in verb or "ısırık" in verb:
		var core := cube(0.13, add_mat(col(el, "hot"), 1.0))
		add_child(core)
		movers.append({"node": core, "from": a, "to": b, "target": null, "t": 0.0, "dur": 0.16, "lob": 0.25,
			"cb": Callable(), "trail": [], "c": c, "hot": col(el, "hot"), "el": el, "spin": false})
	elif "ışın" in verb:
		links.append({"kind": "beam", "a": a, "b": b, "age": 0.0, "life": 0.16, "c": c, "hot": col(el, "hot")})
	elif "parça" in verb:
		shard(a, null, 0, el, b)
	elif "durum" in verb or "alev" in verb or "atla" in verb or "bulaşma" in verb:
		links.append({"kind": "bolt", "a": a, "b": b, "age": 0.0, "life": 0.35, "c": c, "hot": col(el, "hot"),
			"jag": 0.22, "w": 0.16, "seed": rng.randi(), "pts": []})
		particles(b, col(el, "hot"), c, 8, 1.6, 0.07, 0.4, 1.0)
	else:
		links.append({"kind": "bolt", "a": a, "b": b, "age": 0.0, "life": 0.3, "c": col("electric"), "hot": Color(0.95, 0.92, 1.0),
			"jag": 0.11, "w": 0.13, "seed": rng.randi(), "pts": []})
		flash(b, col("electric", "hot"), 0.3, 0.1)


## Area impacts flash the grid cells they touch (cells whose square intersects the impact circle).
func area(at: Vector3, r: float, el: String) -> void:
	var tp := Vector2(at.x, -at.z) * 0.5
	var c0 := Vector2i(roundi(tp.x), roundi(tp.y))
	var k := int(ceil(r + 0.5))
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			var c := c0 + Vector2i(dx, dy)
			var q := Vector2(clampf(tp.x, c.x - 0.5, c.x + 0.5), clampf(tp.y, c.y - 0.5, c.y + 0.5))
			if (q - tp).length() <= r or c == c0:
				cell_flash(c, col(el, "hot"), 0.45, 0.04 * (absi(dx) + absi(dy)))
	particles(at + Vector3(0, 0.2, 0), col(el, "hot"), col(el), 18, 3.0, 0.09, 0.5, -6.0, 70.0)


func cell_flash(c: Vector2i, colr: Color, life := 0.45, delay := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.04, 1.8)
	mi.mesh = bm
	var m := add_mat(colr, 0.0, true).duplicate() as StandardMaterial3D
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(c.x * 2.0, game.cell_height(c) + 0.06, -c.y * 2.0)
	add_child(mi)
	fx.append({"node": mi, "age": -delay, "life": life, "kind": "cell", "mat": m})


func burst(at: Vector3, el: String, scale := 1.0) -> void:
	particles(at + Vector3(0, 0.45, 0), col(el, "hot"), col(el), int(14 * scale), 2.6 * scale, 0.08, 0.45)
	flash(at + Vector3(0, 0.45, 0), col(el, "hot"), 0.45 * scale, 0.14)


func tick(e, el: String) -> void:
	particles(e.global_position + Vector3(0, 0.55, 0), col(el, "hot"), col(el), 4, 0.9, 0.06, 0.45, 1.5, 40.0)


func puff(at: Vector3, c: Color) -> void:
	particles(at + Vector3(0, 0.6, 0), c, Color(c, 0.5), 10, 1.0, 0.12, 0.7, 1.2, 60.0)


func freeze(e, dur: float) -> void:
	var shell := cube(0.75, add_mat(Color(0.7, 0.9, 1.0), 0.35, false))
	shell.position = Vector3(0, 0.38, 0)
	e.add_child(shell)
	fx.append({"node": shell, "age": 0.0, "life": dur, "kind": "shell"})
	particles(e.global_position + Vector3(0, 0.5, 0), Color(0.9, 0.97, 1.0), col("ice"), 10, 1.6, 0.07, 0.4)


func stun(e) -> void:
	var star := cube(0.12, add_mat(Color(1.0, 0.9, 0.5), 1.0))
	star.position = Vector3(0, 1.05, 0)
	e.add_child(star)
	fx.append({"node": star, "age": 0.0, "life": 0.5, "kind": "spin"})


func mark(e, r: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 2.0 - 0.07
	tm.outer_radius = r * 2.0
	tm.rings = 48
	tm.ring_segments = 3
	mi.mesh = tm
	mi.material_override = add_mat(col("arcane"), 0.75)
	mi.position = Vector3(0, 0.08, 0)
	mi.scale = Vector3(1, 0.05, 1)
	e.add_child(mi)
	var gem := cube(0.16, add_mat(col("arcane", "hot"), 1.0))
	gem.position = Vector3(0, 1.25, 0)
	gem.rotation_degrees = Vector3(45, 0, 45)
	e.add_child(gem)
	fx.append({"node": mi, "age": 0.0, "life": dur, "kind": "free_after"})
	fx.append({"node": gem, "age": 0.0, "life": dur, "kind": "spin"})


func push(e) -> void:
	particles(e.global_position + Vector3(0, 0.3, 0), Color(0.85, 0.97, 1.0), col("water"), 12, 2.2, 0.08, 0.45, -5.0, 60.0)


func shard(from: Vector3, target, i: int, el := "ice", to := Vector3.ZERO) -> void:
	var c := col(el)
	var n := cube(0.12, add_mat(col(el, "hot"), 1.0))
	add_child(n)
	var dest: Vector3 = target.global_position + Vector3(0, 0.4, 0) if target != null else (to if to != Vector3.ZERO else from + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.0)
	movers.append({"node": n, "from": from + Vector3(0, 0.4, 0), "to": dest, "target": null, "t": 0.0, "dur": 0.3,
		"lob": 0.6, "cb": Callable(), "trail": [], "c": c, "hot": col(el, "hot"), "el": el, "spin": true})


func meteor(at: Vector3, delay: float, cb: Callable) -> void:
	var rock := GLB.instance("summons/meteor_rock.glb")
	rock.scale = Vector3.ONE * 0.8
	add_child(rock)
	var shadow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6; cm.bottom_radius = 0.6; cm.height = 0.02
	shadow.mesh = cm
	shadow.material_override = add_mat(Color(0.15, 0.05, 0.0), 0.35, false)
	shadow.position = Vector3(at.x, 0.05, at.z)
	shadow.scale = Vector3(0.2, 1, 0.2)
	add_child(shadow)
	movers.append({"node": rock, "from": at + Vector3(-3.0, 9.0, 2.0), "to": at + Vector3(0, 0.2, 0), "target": null,
		"t": 0.0, "dur": delay, "lob": 0.0, "cb": cb, "trail": [], "c": col("impact"), "hot": col("lava", "hot"),
		"el": "impact", "spin": true, "shadow": shadow, "big": true})


func mini_meteor(at: Vector3) -> void:
	particles(at + Vector3(0, 0.3, 0), col("lava", "hot"), col("impact"), 10, 2.4, 0.09, 0.45)
	ring(at, col("impact"), 0.9, 0.35)


func summon(rel: String, pos: Vector3, sc: float, owner := -1) -> Node3D:
	var n := GLB.instance(rel)
	n.add_to_group("summons")
	n.set_meta("summon_owner", owner)
	n.position = pos
	n.scale = Vector3.ONE * 0.01
	add_child(n)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * sc, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	particles(pos + Vector3(0, 0.3, 0), Color(1, 0.95, 0.8), Color(0.7, 0.6, 0.45), 16, 2.0, 0.1, 0.5, -4.0, 70.0)
	return n


func unsummon(n: Node3D) -> void:
	if not is_instance_valid(n):
		return
	n.remove_from_group("summons")       # gone for gameplay at once; the shrink tween is only visual
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(n.queue_free)


func eruption(at: Vector3) -> void:
	particles(at + Vector3(0, 1.0, 0), col("lava", "hot"), Color(0.3, 0.25, 0.25), 12, 2.4, 0.12, 0.7, -3.0, 25.0)


func lava_blob(from: Vector3, target, flight: float, cb: Callable) -> void:
	var blob := GLB.instance("summons/lava_blob.glb")
	blob.scale = Vector3.ONE * 0.6
	add_child(blob)
	movers.append({"node": blob, "from": from, "target": target, "to": target.global_position + Vector3(0, 0.3, 0),
		"t": 0.0, "dur": flight, "lob": 1.6, "cb": cb, "trail": [], "c": col("lava"), "hot": col("lava", "hot"),
		"el": "lava", "spin": true})


func punch(n: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(n, "scale", n.scale * Vector3(1.15, 0.85, 1.15), 0.08)
	tw.tween_property(n, "scale", n.scale, 0.12)


func focus(e) -> void:
	var m := cube(0.14, add_mat(Color(1.0, 0.35, 0.3), 1.0))
	m.position = Vector3(0, 1.15, 0)
	m.rotation_degrees = Vector3(45, 0, 45)
	e.add_child(m)
	fx.append({"node": m, "age": 0.0, "life": 2.5, "kind": "spin"})


## Ground fields fill exactly one grid cell: a glowing square slab with a brighter rim, on the cell's level.
func field_start(f: Dictionary) -> void:
	var c: Color = {"fire_trail": col("fire"), "lava_pool": col("lava"), "crater": Color(0.45, 0.32, 0.22)}.get(f.kind, col("arcane"))
	var cell := Vector2i(roundi(f.pos.x), roundi(-f.pos.y))
	var y: float = game.cell_height(cell) + 0.05
	var root := Node3D.new()
	root.position = Vector3(cell.x * 2.0, y, -cell.y * 2.0)
	var m := add_mat(c, 0.5, false).duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.2
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.72, 0.03, 1.72)
	slab.mesh = bm
	slab.material_override = m
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(slab)
	var rim_m := add_mat(col(_el_of(f.kind), "hot"), 0.85, true)
	for k in 4:
		var rim := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(1.84, 0.05, 0.08) if k < 2 else Vector3(0.08, 0.05, 1.84)
		rim.mesh = rb
		rim.material_override = rim_m
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rim.position = [Vector3(0, 0.01, -0.88), Vector3(0, 0.01, 0.88), Vector3(-0.88, 0.01, 0), Vector3(0.88, 0.01, 0)][k]
		root.add_child(rim)
	root.scale = Vector3(0.3, 1, 0.3)
	add_child(root)
	create_tween().tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	field_nodes[int(f.fid)] = {"node": root, "mat": m, "f": f}
	if f.kind == "fire_trail" or f.kind == "lava_pool":
		particles(root.position + Vector3(0, 0.1, 0), col(_el_of(f.kind), "hot"), c, 6, 0.8, 0.07, 0.6, 1.5, 25.0)


func _el_of(kind: String) -> String:
	return {"fire_trail": "fire", "lava_pool": "lava", "crater": "impact"}.get(kind, "arcane")


func field_end(f: Dictionary) -> void:
	var id := int(f.get("fid", -1))
	if field_nodes.has(id):
		var n: Node3D = field_nodes[id].node
		field_nodes.erase(id)
		if is_instance_valid(n):
			n.queue_free()


func damage_number(e, amount: float, el: String) -> void:
	if not game.settings.get("numbers", true):
		return
	var k: int = e.eid
	if not numbers.has(k):
		numbers[k] = {"amount": 0.0, "el": el, "t": 0.0, "e": e}
	numbers[k].amount += amount
	numbers[k].el = el


func float_text(at: Vector3, text: String, c: Color, size := 34) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = c
	l.outline_modulate = Color(0.12, 0.08, 0.05, 0.9)
	l.outline_size = 8
	l.font_size = size
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 3
	l.position = at + Vector3(rng.randf_range(-0.25, 0.25), 1.1, 0)
	l.font = game.font_bold
	add_child(l)
	floaters.append({"node": l, "age": 0.0, "life": 0.9})


# ------------------------------------------------------------------ update

func _process(dt: float) -> void:
	var sdt: float = dt * game.time_mult()   # world VFX follow the simulation speed (paused -> frozen)
	_update_movers(sdt)
	_update_fx(sdt)
	_draw_links(sdt)
	# flush accumulated damage numbers ~4x per second per enemy
	for k in numbers.keys():
		var n: Dictionary = numbers[k]
		n.t += sdt
		if n.t >= 0.25:
			if n.amount >= 0.5 and is_instance_valid(n.e):
				float_text(n.e.global_position, str(roundi(n.amount)), col(n.el, "hot").lerp(Color.WHITE, 0.25), 30)
			numbers.erase(k)
	for f in floaters.duplicate():
		f.age += sdt
		var l: Label3D = f.node
		l.position.y += sdt * 0.9
		l.modulate.a = 1.0 - smoothstep(0.55, 1.0, f.age / f.life)
		if f.age >= f.life:
			l.queue_free()
			floaters.erase(f)
	for id in field_nodes:
		var fn: Dictionary = field_nodes[id]
		var f: Dictionary = fn.f
		var a := clampf(float(f.left) / maxf(float(f.dur), 0.01), 0.0, 1.0)
		(fn.mat as StandardMaterial3D).albedo_color.a = 0.55 * minf(1.0, a * 3.0)


func _update_movers(dt: float) -> void:
	for m in movers.duplicate():
		m.t += dt
		if m.target != null and is_instance_valid(m.target) and m.target.alive:
			m.to = m.target.global_position + Vector3(0, 0.45, 0)
		var u := clampf(m.t / m.dur, 0.0, 1.0)
		var p: Vector3 = m.from.lerp(m.to, u)
		p.y += sin(u * PI) * m.lob
		var n: Node3D = m.node
		if is_instance_valid(n):
			n.position = p
			if m.spin:
				n.rotation += Vector3(7, 9, 5) * dt
		m.trail.append(p)
		if m.trail.size() > 9:
			m.trail.pop_front()
		if m.has("shadow"):
			var sh: Node3D = m.shadow
			sh.scale = Vector3.ONE * lerpf(0.2, 1.0, u)
		if u >= 1.0:
			movers.erase(m)
			if is_instance_valid(n):
				n.queue_free()
			if m.has("shadow"):
				m.shadow.queue_free()
			var big: bool = m.get("big", false)
			particles(m.to, m.hot, m.c, 22 if big else 9, 3.6 if big else 2.0, 0.1 if big else 0.07, 0.55 if big else 0.35)
			flash(m.to, m.hot, 0.9 if big else 0.32, 0.16)
			if big:
				ring(m.to, m.c, 1.6, 0.5)
			if m.cb.is_valid():
				m.cb.call()


func _update_fx(dt: float) -> void:
	for f in fx.duplicate():
		f.age += dt
		var n = f.node
		if not is_instance_valid(n):
			fx.erase(f)
			continue
		if n is CPUParticles3D:
			(n as CPUParticles3D).speed_scale = maxf(game.time_mult(), 0.0001)   # particles follow game speed / pause
		var t: float = f.age / f.life
		match f.kind:
			"sprite":
				var k := minf(t, 1.0)
				n.scale = Vector3.ONE * ((0.6 + 0.8 * k) if not f.flat else (0.3 + 1.0 * (1.0 - pow(1.0 - k, 3.0))))
				f.mat.albedo_color.a = 1.0 - k
			"pop":
				n.scale = Vector3.ONE * (1.0 + t * 1.5)
				f.mat.albedo_color.a = 0.9 * (1.0 - t)
			"spin":
				n.rotation.y += dt * 5.0
			"cell":
				f.mat.albedo_color.a = 0.0 if t < 0.0 else 0.75 * (1.0 - t) * minf(1.0, t * 8.0 + 0.3)
		if f.age >= f.life:
			fx.erase(f)
			n.queue_free()


func _draw_links(dt: float) -> void:
	link_mesh.clear_surfaces()
	for m in movers:
		if m.trail.size() > 1:
			_strip(m.trail, 0.24 if not m.get("big", false) else 0.5, m.c, 0.6, false, true)
			_strip(m.trail, 0.08 if not m.get("big", false) else 0.16, m.hot, 0.95, true, true)
	for l in links.duplicate():
		l.age += dt
		var t: float = l.age / l.life
		var env: float = (1.0 - smoothstep(0.5, 1.0, t))
		if l.kind == "beam":
			var pts := [l.a, l.b]
			_strip(pts, 0.26, l.c, 0.5 * env, false, false)
			_strip(pts, 0.08, l.hot, env, true, false)
		else:
			if l.pts.is_empty() or int(l.age * 18.0) != l.get("frame", -1):
				l.frame = int(l.age * 18.0)
				var r := RandomNumberGenerator.new()
				r.seed = l.seed + l.frame
				l.pts = _displace(l.a, l.b, 4, l.jag, r)
			env *= 0.75 + 0.25 * sin(l.age * 90.0)
			_strip(l.pts, l.w, l.c, 0.5 * env, false, false)
			_strip(l.pts, l.w * 0.25, l.hot, env, true, false)
		if t >= 1.0:
			links.erase(l)


func _displace(a: Vector3, b: Vector3, levels: int, jag: float, r: RandomNumberGenerator) -> Array:
	var pts := [a, b]
	var dir := (b - a).normalized()
	var s1 := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var s2 := dir.cross(s1).normalized()
	var amp := jag * a.distance_to(b)
	for _l in levels:
		var out := []
		for i in pts.size() - 1:
			out.append(pts[i])
			out.append((pts[i] + pts[i + 1]) * 0.5 + s1 * r.randf_range(-amp, amp) + s2 * r.randf_range(-amp, amp))
		out.append(pts[-1])
		pts = out
		amp *= 0.52
	return pts


func _strip(pts: Array, width: float, c: Color, alpha: float, additive: bool, taper: bool) -> void:
	var n := pts.size()
	if n < 2 or alpha <= 0.01:
		return
	var view := -cam.global_transform.basis.z
	link_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, ribbon_mat(additive, 1.6 if additive else 1.0))
	for i in n:
		var f := float(i) / float(n - 1)
		var d: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if d.length() < 0.0001:
			d = Vector3.RIGHT
		var w := width * (f if taper else minf(1.0, minf(f, 1.0 - f) * 8.0 + 0.3))
		var side := d.normalized().cross(view).normalized() * w
		var cc := c
		cc.a = alpha * (f if taper else 1.0)
		link_mesh.surface_set_color(cc)
		link_mesh.surface_add_vertex(pts[i] - side)
		link_mesh.surface_set_color(cc)
		link_mesh.surface_add_vertex(pts[i] + side)
	link_mesh.surface_end()
