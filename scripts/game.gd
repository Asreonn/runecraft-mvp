extends Node3D
## RuneCraft MVP hub: random map, economy (mana / mana stone), waves, castle HP, tower
## building, rune inventory, combine (grade up), craft table (graft / ungraft) and the HUD.
## Command line (after "--"):  --seed N  --demo  --shots <dir>  --quit-after S

const MapGen := preload("res://scripts/map_gen.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")
const Combat := preload("res://scripts/combat.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TowerScript := preload("res://scripts/tower.gd")
const VfxScript := preload("res://scripts/vfx.gd")
const HudScript := preload("res://ui/hud.gd")
const GLB := preload("res://scripts/glb.gd")
const Overlay := preload("res://scripts/grid_overlay.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const LEVEL_H := 0.96                    # one terrain level (24 voxels)

const COLOR_ID := {"fire": "ates", "ice": "buz", "electric": "elektrik", "poison": "zehir", "water": "su",
	"stone": "tas", "light": "isik", "blood": "kan", "meteor": "meteor", "volcano": "volkan", "golem": "golem",
	"hive": "kovan", "mana": "mana"}
const ELEMENT_RUNE := {"fire": "fire", "ice": "ice", "electric": "electric", "poison": "poison", "water": "water",
	"physical": "stone", "light": "light", "blood": "blood", "impact": "meteor", "lava": "volcano", "arcane": "mana"}
const INV_SIZE := 24

signal changed

var spec: Dictionary
var colors: Dictionary
var rl                                  # rune_lib instance
var seed_value := 0
var map: Dictionary
var wb
var combat
var vfx
var hud
var cam: Camera3D
var cam_rig
var font_bold: Font
var now := 0.0

# economy
var mana := 0.0
var stones := 0
var castle_hp := 20
var castle_max := 20
var mana_regen := 3.0

# waves
var wave := 0
var wave_state := "build"               # build | spawning | fighting | lost
var countdown := 20.0
var to_spawn: Array = []
var spawn_timer := 0.0
var next_eid := 0
var next_tid := 0
var enemies: Array = []

# towers / runes
var towers: Array = []
var selected_tower = null
var build_mode := false
var ghost: Node3D
var inventory: Array = []               # INV_SIZE entries: node dict or null
var craft := {"base": null, "pending": {}, "output": null}
var message := ""
var message_t := 0.0
var speed := 1.0
var paused := false

var dmg_log: Dictionary = {}           # tower id -> Array[[time, amount]]
# grid indicators
var range_ov                            # hovered tower / build ghost range
var cover_ov                            # faint coverage of all towers while building
var drop_ov                             # rune drag: candidate towers + the one under the cursor
var hovered_tower = null
var drop_tower = null                   # tower under the cursor while a rune is dragged
var drop_ghost: Node3D
var drop_ghost_key := ""
var args := {}
var settings := {"lang": "en", "numbers": true, "fullscreen": false, "cam_speed": 1.0, "edge_pan": false}
const SETTINGS_PATH := "user://runecraft_settings.json"
const SAVE_PATH := "user://runecraft_save.json"
var _shot_i := 0


func _ready() -> void:
	args = _parse_args(OS.get_cmdline_user_args())
	_load_settings()
	spec = JSON.parse_string(FileAccess.get_file_as_string("res://data/rune_mechanics_v1.json"))
	colors = JSON.parse_string(FileAccess.get_file_as_string("res://data/rune_colors_v4.json")).runes
	rl = load("res://scripts/rune_lib.gd").new("res://data/rune_mechanics_v1.json")
	rl.set_locale("res://scripts/locale/%s.json" % settings.get("lang", "en"))
	font_bold = preload("res://ui/style.gd").font("bold")
	var e: Dictionary = spec.economy
	mana = float(e.start.mana)
	stones = int(e.start.mana_stone)
	castle_hp = int(e.start.castle_hp)
	castle_max = castle_hp
	mana_regen = float(e.mana_regen_per_s)
	inventory.resize(INV_SIZE)
	seed_value = int(args.get("seed", randi() % 100000))
	var loaded = pending_load
	pending_load = null
	if loaded != null:
		seed_value = int(loaded.seed)
	_build_world()
	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	notify("Wave 1 incoming — build a tower and socket a rune.")
	_apply_settings()
	if loaded != null:
		_apply_load(loaded)
	if args.has("demo") and loaded == null:
		_demo()
	if args.has("auto"):
		changed.connect(_auto_log)
	if args.has("savetest"):
		_savetest.call_deferred(loaded != null)
	if args.has("quit-after") and not args.has("shots"):
		var secs := float(args["quit-after"]) if str(args["quit-after"]).is_valid_float() else 3.0
		get_tree().create_timer(secs, true, false, true).timeout.connect(get_tree().quit)


func _parse_args(a: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < a.size():
		var k := a[i].trim_prefix("--")
		if i + 1 < a.size() and not a[i + 1].begins_with("--"):
			out[k] = a[i + 1]
			i += 2
		else:
			out[k] = true
			i += 1
	return out


# ------------------------------------------------------------------ world

func _build_world() -> void:
	map = MapGen.generate(seed_value, 22, 14)
	wb = WorldBuilder.new()
	wb.build(map, self)
	_setup_env()
	vfx = VfxScript.new()
	vfx.name = "Vfx"
	add_child(vfx)
	vfx.setup(self, cam)
	combat = Combat.new(self, spec)
	ghost = GLB.instance("units/tower.glb")
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 1.0, 0.7, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(mi as MeshInstance3D).material_override = m
	ghost.visible = false
	add_child(ghost)
	range_ov = Overlay.new(); add_child(range_ov)
	cover_ov = Overlay.new(); add_child(cover_ov)
	drop_ov = Overlay.new(); add_child(drop_ov)
	drop_ov.pulse_amp = 0.45


func _setup_env() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = float(args.get("sun", "0.42"))
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0E1410")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#DDE6F0")
	env.ambient_light_energy = float(args.get("amb", "0.18"))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(args.get("exp", "1.0"))
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.5)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	_frame_camera()
	# screen-space grade + vignette (below the HUD layer)
	var post := CanvasLayer.new()
	post.layer = 0
	add_child(post)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string("res://shaders/runecraft_post.gdshader")
	sm.shader = sh
	sm.set_shader_parameter("vignette_strength", 0.22)
	rect.material = sm
	post.add_child(rect)


## Camera rig: WASD/arrows arcade pan, wheel zoom at the
## cursor, middle-drag grab, Q/E snappy 90° turns. It never shows anything outside the tiled area
## (map + apron), even fully zoomed out or mid-rotation.
func _frame_camera() -> void:
	var w: float = map.size.x * 2.0
	var h: float = map.size.y * 2.0
	var centre := Vector3((map.size.x - 1) * 1.0, 0.0, -(map.size.y - 1) * 1.0)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / vp.y
	var free_w := 0.74                    # the right panel covers the rest
	var size := maxf(h * sin(deg_to_rad(45.0)) + 3.0, (w + 2.0) / (aspect * free_w))
	var shift := (size * aspect) * (1.0 - free_w) * 0.5
	cam_rig = CameraRig.new()
	cam_rig.name = "CameraRig"
	add_child(cam_rig)
	cam_rig.min_size = 8.0
	cam_rig.max_size = size * 1.25
	var b: Rect2 = wb.bounds.grow(-0.6)
	cam_rig.setup(cam, b, centre + Vector3(shift, 0, 0.8), size)


# ------------------------------------------------------------------ grid helpers

func cell_level(c: Vector2i) -> int:
	return wb.level_of(c)


func cell_height(c: Vector2i) -> float:
	return float(wb.level_of(c)) * LEVEL_H


func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map.size.x and c.y < map.size.y


## Cells whose centre lies within r tiles of c (a grid disk). Towers target enemies standing in these cells.
func range_cells(c: Vector2i, r: float) -> Array:
	var out := []
	var k := int(ceil(r))
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			if Vector2(dx, dy).length() <= r + 0.01:
				var cc := c + Vector2i(dx, dy)
				if in_map(cc):
					out.append(cc)
	return out


func tower_range(level: int) -> float:
	return float(spec.reference.tower_range_tiles) + (1.0 if level >= 1 else 0.0)   # high ground: +1 tile


## A free grid cell near `want` (world) for a temporary summon: not path / water / tower / blocked.
func summon_cell(want: Vector3, avoid_path := true) -> Vector2i:
	var c0 := WorldBuilder.world_to_cell(want)
	var best := c0
	var bd := 1e9
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := c0 + Vector2i(dx, dy)
			if not in_map(c) or not wb.summon_ok(c) or (avoid_path and wb.path_set.has(c)) or tower_at_cell(c) != null:
				continue
			var d := (WorldBuilder.cell_to_world(c) - Vector3(want.x, 0, want.z)).length()
			if d < bd:
				bd = d
				best = c
	return best


func cell_world(c: Vector2i) -> Vector3:
	return WorldBuilder.cell_to_world(c) + Vector3(0, cell_height(c), 0)


func path_point(s_tiles: float) -> Vector3:
	return wb.curve.sample_baked(clampf(s_tiles * 2.0, 0.0, wb.curve.get_baked_length()))


# ------------------------------------------------------------------ colours

func color_id(rune_id: String) -> String:
	return COLOR_ID.get(rune_id, "mana")


func rune_colors(rune_id: String) -> Dictionary:
	return colors[color_id(rune_id)]


func element_color(el: String, which := "mid") -> Color:
	var c: Dictionary = rune_colors(ELEMENT_RUNE.get(el, "mana"))
	match which:
		"hot":
			return Color(c.glow).lerp(Color.WHITE, 0.3)
		"dark":
			return Color(c.frame)
		"glow":
			return Color(c.glow)
	return Color(c.core)


# ------------------------------------------------------------------ loop

## Game speed only scales the simulation (enemies, towers, combat, world VFX). Engine.time_scale stays 1,
## so the HUD, craft table, camera and tweens always run in real time.
func time_mult() -> float:
	return 0.0 if paused or wave_state == "lost" else speed


func _process(real_dt: float) -> void:
	message_t -= real_dt
	_update_indicators()
	if paused or wave_state == "lost":
		_update_ghost()
		return
	var dt := real_dt * speed
	now += dt
	mana += mana_regen * dt
	_waves(dt)
	for e in enemies.duplicate():
		if not e.alive:
			continue
		combat.tick_statuses(e, dt)
		if not e.alive:
			continue
		var sp: float = e.base_speed * e.speed_factor(now) * float(spec.reference.wave.speed_tiles_s)
		if sp > 0.0:
			combat.move(e, sp * dt, false)
		e.refresh_visual(now, dt)
		if e.s * 2.0 >= wb.curve.get_baked_length() - 0.4 and e.alive:
			_leak(e)
	combat.update_fields(dt)
	for t in towers:
		t.step(dt)
	_cleanup_dead()
	_update_ghost()


func _cleanup_dead() -> void:
	for e in enemies.duplicate():
		if not e.alive or e.leaked:
			enemies.erase(e)
			if not e.leaked:
				vfx.particles(e.global_position + Vector3(0, 0.4, 0), Color(1, 0.9, 0.8), Color(0.6, 0.25, 0.25), 18, 2.6, 0.1, 0.5)
				var tw: Tween = e.create_tween()
				tw.tween_property(e, "scale", Vector3(1.3, 0.2, 1.3), 0.14)
				tw.tween_callback(e.queue_free)
			else:
				e.queue_free()


func _leak(e) -> void:
	e.leaked = true
	castle_hp -= 2 if e.kind == "boss" else 1
	vfx.particles(wb.castle_pos + Vector3(0, 1.2, 0), Color(1, 0.6, 0.5), Color(0.8, 0.2, 0.2), 20, 3.0, 0.1, 0.6)
	if castle_hp <= 0:
		castle_hp = 0
		wave_state = "lost"
		notify("The castle has fallen! Wave %d." % wave)
	changed.emit()


# ------------------------------------------------------------------ waves

func _waves(dt: float) -> void:
	match wave_state:
		"build":
			countdown -= dt
			if countdown <= 0.0:
				start_wave()
		"spawning":
			spawn_timer -= dt
			if spawn_timer <= 0.0 and not to_spawn.is_empty():
				var k: String = to_spawn.pop_front()
				_spawn(k)
				spawn_timer = 0.55 if k == "fast" else 0.85
			if to_spawn.is_empty():
				wave_state = "fighting"
		"fighting":
			if enemies.is_empty():
				wave_state = "build"
				countdown = 15.0
				notify("Wave %d cleared." % wave)
				changed.emit()


func start_wave() -> void:
	if wave_state != "build":
		return
	wave += 1
	to_spawn = wave_plan(wave)
	wave_state = "spawning"
	spawn_timer = 0.0
	if countdown > 1.0:
		var bonus := roundi(countdown)
		mana += bonus
		notify("Early call: +%d mana" % bonus)
	countdown = 0.0
	changed.emit()


func wave_plan(n: int) -> Array:
	var count := mini(6 + n * 2, 34)
	var plan := []
	for i in count:
		var k := "normal"
		if n >= 2 and i % 3 == 2:
			k = "fast"
		if n >= 3 and i % 5 == 4:
			k = "brute"
		plan.append(k)
	if n % 5 == 0:
		plan.append("boss")
	return plan


func wave_hp(n: int) -> float:
	return 14.0 * pow(1.22, n - 1)


func remaining() -> int:
	return to_spawn.size() + enemies.filter(func(e): return e.alive and not e.leaked).size()


func _spawn(kind: String) -> void:
	var e := Node3D.new()
	e.set_script(EnemyScript)
	add_child(e)
	e.setup(next_eid, kind, wave_hp(wave), wb.curve)
	next_eid += 1
	e.s = 0.0
	e.refresh_visual(now, 0.0)
	enemies.append(e)


func on_enemy_killed(e) -> void:
	add_mana(float(spec.economy.mana_per_kill), e.global_position, "kill")
	add_stones(int(e.stones), e.global_position)


func add_mana(x: float, at: Vector3, why := "") -> void:
	mana += x
	if why != "kill" and x >= 1.0:
		vfx.float_text(at + Vector3(0, 0.3, 0), "+%d" % roundi(x), Color("#7FD3FF"), 28)


func add_stones(n: int, at: Vector3) -> void:
	stones += n
	vfx.float_text(at + Vector3(0, 0.5, 0), "+%d ◆" % n, Color("#C69CFF"), 30)
	changed.emit()


func record_damage(tower_id: int, amount: float) -> void:
	if not dmg_log.has(tower_id):
		dmg_log[tower_id] = []
	dmg_log[tower_id].append([now, amount])


func tower_dps(t) -> float:
	var lst: Array = dmg_log.get(t.tid, [])
	while not lst.is_empty() and lst[0][0] < now - 8.0:
		lst.pop_front()
	var tot := 0.0
	for x in lst:
		tot += x[1]
	return tot / 8.0


func notify(t: String) -> void:
	message = t
	message_t = 3.5
	changed.emit()


# ------------------------------------------------------------------ building

func tower_cost() -> int:
	return 4 + 2 * towers.size()


func toggle_build() -> void:
	build_mode = not build_mode
	if build_mode:
		select_tower(null)
	ghost.visible = false
	changed.emit()


func mouse_cell() -> Variant:
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 1e-4:
		return null
	# elevated cells first: a ray hitting the plateau top (y = LEVEL_H) on a level-1 cell wins
	var hi := from + dir * ((LEVEL_H - from.y) / dir.y)
	var ch := WorldBuilder.world_to_cell(hi)
	if wb.level_of(ch) >= 1:
		return ch
	var hit := from + dir * (-from.y / dir.y)
	return WorldBuilder.world_to_cell(hit)


func _update_ghost() -> void:
	if not build_mode:
		ghost.visible = false
		return
	var c = mouse_cell()
	if c == null:
		ghost.visible = false
		return
	ghost.visible = true
	ghost.position = cell_world(c)
	var ok: bool = wb.buildable.has(c) and stones >= tower_cost()
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		m.albedo_color = Color(0.55, 1.0, 0.65, 0.45) if ok else Color(1.0, 0.45, 0.4, 0.45)


func try_build(c: Vector2i) -> bool:
	if not wb.buildable.has(c):
		notify("You can't build here.")
		return false
	var cost := tower_cost()
	if stones < cost:
		notify("Not enough mana stones (%d needed)." % cost)
		return false
	stones -= cost
	wb.take_cell(c)
	var t := Node3D.new()
	t.set_script(TowerScript)
	add_child(t)
	t.position = cell_world(c)
	t.setup(self, next_tid, c)
	next_tid += 1
	towers.append(t)
	t.pop_in()
	vfx.ring(t.position, Color("#EECB8E"), 2.2, 0.5)
	vfx.particles(t.position + Vector3(0, 0.3, 0), Color(1, 0.95, 0.8), Color(0.7, 0.6, 0.45), 16, 2.0, 0.1, 0.5)
	select_tower(t)
	if not Input.is_key_pressed(KEY_SHIFT):
		build_mode = false
	changed.emit()
	return true


func select_tower(t) -> void:
	selected_tower = t
	changed.emit()


## Grid indicators, every frame in real time: range of the hovered tower or of the build ghost,
## faint coverage of all towers while building, and the rune drop target while dragging.
func _update_indicators() -> void:
	var vp := get_viewport()
	var over_world: bool = hud != null and vp.gui_get_hovered_control() == hud.world_input
	var dragging := vp.gui_is_dragging()
	hovered_tower = null
	if over_world and not build_mode:
		var c = mouse_cell()
		if c != null:
			hovered_tower = tower_at_cell(c)
	if not dragging:
		drop_tower = null
	var hf := func(cc): return cell_height(cc)
	if build_mode and over_world:
		var c = mouse_cell()
		if c != null and in_map(c):
			var ok: bool = wb.buildable.has(c) and stones >= tower_cost()
			range_ov.show_cells(range_cells(c, tower_range(cell_level(c))), hf,
				Color(0.55, 1.0, 0.65, 0.16) if ok else Color(1.0, 0.45, 0.4, 0.12),
				Color(0.75, 1.0, 0.8, 0.85) if ok else Color(1.0, 0.55, 0.5, 0.7))
		else:
			range_ov.clear()
		var cover := {}
		for t in towers:
			for cc in range_cells(t.cell, t.range_tiles()):
				cover[cc] = true
		cover_ov.show_cells(cover.keys(), hf, Color(1.0, 0.95, 0.8, 0.07), Color(1.0, 0.95, 0.8, 0.28))
	else:
		cover_ov.clear()
		var show = drop_tower if drop_tower != null else hovered_tower
		if show != null and is_instance_valid(show):
			range_ov.show_cells(range_cells(show.cell, show.range_tiles()), hf, Color(1.0, 0.93, 0.7, 0.13), Color(1.0, 0.93, 0.7, 0.75))
		else:
			range_ov.clear()
	# rune drag: every tower is a target (outlined); the one under the cursor shows the incoming rune
	var dd = vp.gui_get_drag_data() if dragging else null
	if dd is Dictionary and dd.get("src", "") in ["inv", "output"] and not towers.is_empty():
		var cells := []
		for t in towers:
			cells.append(t.cell)
		drop_ov.show_cells(cells, hf, Color(0.5, 0.9, 0.95, 0.10), Color(0.5, 0.9, 0.95, 0.9))
		_drop_ghost(dd.node if drop_tower != null else null)
	else:
		drop_ov.clear()
		_drop_ghost(null)


func _drop_ghost(node) -> void:
	if node == null or drop_tower == null:
		if drop_ghost != null:
			drop_ghost.queue_free()
			drop_ghost = null
			drop_ghost_key = ""
		if drop_tower != null:
			drop_tower.preview_hide()
		return
	var key := "%s%d|%d" % [node.rune, int(node.grade), drop_tower.tid]
	if key != drop_ghost_key:
		if drop_ghost != null:
			drop_ghost.queue_free()
		for t in towers:
			t.preview_hide()
		drop_ghost_key = key
		drop_ghost = GLB.instance("runes/%s_g%d.glb" % [color_id(node.rune), int(node.grade)])
		drop_ghost.scale = Vector3.ONE * 0.5
		add_child(drop_ghost)
		drop_tower.preview_hide(true)
		vfx.ring(drop_tower.position, element_color(spec.runes[node.rune].element, "glow"), 1.4, 0.35)
	var t := Time.get_ticks_msec() * 0.001
	drop_ghost.position = drop_tower.position + Vector3(0, drop_tower.RUNE_Y + 0.35 + sin(t * 6.0) * 0.08, 0)
	drop_ghost.rotation.y = t * 2.5


func tower_at_cell(c: Vector2i):
	for t in towers:
		if t.cell == c:
			return t
	return null


func sell_tower(t) -> void:
	if t.rune != null:
		if not inv_put(t.rune):
			notify("Inventory is full.")
			return
	stones += int((4 + 2 * (towers.size() - 1)) * 0.5)
	t.cleanup()
	towers.erase(t)
	wb.buildable[t.cell] = true
	if selected_tower == t:
		selected_tower = null
	t.queue_free()
	changed.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var c = mouse_cell()
			if c == null:
				return
			if build_mode:
				try_build(c)
			else:
				select_tower(tower_at_cell(c))
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			build_mode = false
			select_tower(null)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SPACE:
				toggle_pause()
			KEY_B:
				toggle_build()
			KEY_ESCAPE:
				build_mode = false
				select_tower(null)
			KEY_N:
				start_wave()
			KEY_1:
				set_speed(1.0)
			KEY_2:
				set_speed(2.0)
			KEY_3:
				set_speed(3.0)


# ------------------------------------------------------------------ speed

func set_speed(x: float) -> void:
	speed = x
	paused = false
	changed.emit()


func toggle_pause() -> void:
	paused = not paused
	_menu_paused = false
	changed.emit()


var _menu_paused := false


## The Menu tab pauses the simulation; leaving the tab resumes only if the menu was what paused it.
func set_menu_pause(on: bool) -> void:
	if on and not paused:
		paused = true
		_menu_paused = true
	elif not on and _menu_paused:
		paused = false
		_menu_paused = false
	changed.emit()


# ------------------------------------------------------------------ settings / save

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			settings.merge(d, true)


func apply_setting(key: String, value) -> void:
	settings[key] = value
	_apply_settings()
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func _apply_settings() -> void:
	if cam_rig:
		cam_rig.pan_speed = 1.15 * float(settings.get("cam_speed", 1.0))
		cam_rig.edge_margin = 24.0 if settings.get("edge_pan", false) else 0.0
	if not args.has("shots"):
		var fs: bool = settings.get("fullscreen", false)
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(want)


static var pending_load = null


func save_game() -> void:
	var tw := []
	for t in towers:
		tw.append({"cell": [t.cell.x, t.cell.y], "rune": t.rune})
	var data := {"version": 1, "seed": seed_value, "wave": wave, "mana": mana, "stones": stones, "castle_hp": castle_hp,
		"inventory": inventory, "towers": tw, "craft": craft}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		notify("Could not save.")
		return
	f.store_string(JSON.stringify(data))
	notify("Game saved (wave %d)." % wave)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		notify("No saved game yet.")
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary:
		notify("The save file is damaged.")
		return
	pending_load = _ints(d)
	get_tree().reload_current_scene()


## JSON turns every number into a float; rune grades must be ints again.
func _ints(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = int(v[k]) if k == "grade" and v[k] != null else _ints(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _ints(x))
	return v


func _apply_load(d: Dictionary) -> void:
	wave = int(d.wave)
	mana = float(d.mana)
	stones = int(d.stones)
	castle_hp = int(d.castle_hp)
	for i in INV_SIZE:
		inventory[i] = d.inventory[i] if i < d.inventory.size() else null
	for t in d.towers:
		var c := Vector2i(int(t.cell[0]), int(t.cell[1]))
		stones += tower_cost()
		if try_build(c) and t.rune != null:
			towers.back().set_rune(t.rune)
	build_mode = false
	if d.has("craft") and d.craft is Dictionary:
		craft = {"base": d.craft.get("base"), "pending": d.craft.get("pending", {}), "output": d.craft.get("output")}
	wave_state = "build"
	countdown = 20.0
	notify("Game loaded — wave %d." % (wave + 1))
	changed.emit()


# ------------------------------------------------------------------ inventory / runes

func rune_cost(rid: String) -> int:
	return int(spec.economy.rune_buy_g1_mana[spec.runes[rid].buy])


func inv_put(node) -> bool:
	for i in INV_SIZE:
		if inventory[i] == null:
			inventory[i] = node
			changed.emit()
			return true
	return false


func buy_rune(rid: String) -> void:
	var c := rune_cost(rid)
	if mana < c:
		notify("Not enough mana (%d needed)." % c)
		return
	if not inv_put({"rune": rid, "grade": 1, "grafts": {}}):
		notify("Inventory is full.")
		return
	mana -= c
	changed.emit()


func combine_fee(grade: int) -> int:
	return int(spec.economy.combine.fee_mana_per_target_grade_minus_1) * grade


func combine(a: int, b: int) -> bool:
	var ra = inventory[a]
	var rb = inventory[b]
	if a == b or ra == null or rb == null:
		return false
	if ra.rune != rb.rune or int(ra.grade) != int(rb.grade):
		notify("Combine needs two runes of the same type and grade.")
		return false
	if int(ra.grade) >= 5:
		notify("G5 is the highest grade.")
		return false
	var fee := combine_fee(int(ra.grade))
	if mana < fee:
		notify("Combining costs %d mana." % fee)
		return false
	mana -= fee
	var out := {"rune": ra.rune, "grade": int(ra.grade) + 1, "grafts": {}}
	for src in [ra, rb]:
		for ab in src.grafts:
			if not out.grafts.has(ab):
				out.grafts[ab] = []
			out.grafts[ab] += src.grafts[ab]
	inventory[a] = out
	inventory[b] = null
	notify("%s G%d forged." % [rl.rune_name(out.rune), out.grade])
	changed.emit()
	return true


func socket(t, idx: int) -> void:
	var r = inventory[idx]
	if r == null or t == null:
		return
	inventory[idx] = t.rune          # swap: the old rune goes back
	t.set_rune(r)
	vfx.ring(t.position, element_color(spec.runes[r.rune].element, "glow"), 1.8, 0.45)
	vfx.particles(t.position + Vector3(0, 2.0, 0), element_color(spec.runes[r.rune].element, "hot"), element_color(spec.runes[r.rune].element), 16, 2.2, 0.08, 0.5)
	changed.emit()


func socket_output(t) -> void:
	if craft.output == null or t == null:
		return
	var old = t.rune
	t.set_rune(craft.output)
	craft.output = null
	if old != null:
		inv_put(old)
	vfx.ring(t.position, element_color(spec.runes[t.rune.rune].element, "glow"), 1.8, 0.45)
	changed.emit()


func unsocket(t) -> void:
	if t.rune == null:
		return
	if inv_put(t.rune):
		t.set_rune(null)
	else:
		notify("Inventory is full.")
	changed.emit()


func recipe(node) -> String:
	return rl.canonical(node)


var _describe_cache: Dictionary = {}


func describe(node) -> String:
	var key := recipe(node)
	if not _describe_cache.has(key):
		_describe_cache[key] = rl.describe(rl.compile_recipe(node))
	return _describe_cache[key]


# ------------------------------------------------------------------ craft table

func craft_set_base(idx: int) -> void:
	var r = inventory[idx]
	if r == null:
		return
	if craft.base != null:
		_craft_return_all()
	craft.base = r
	craft.pending = {}
	inventory[idx] = null
	changed.emit()


func craft_clear() -> void:
	_craft_return_all()
	changed.emit()


func _craft_return_all() -> void:
	if craft.base != null:
		inv_put(craft.base)
	for ab in craft.pending:
		for d in craft.pending[ab]:
			inv_put(d)
	craft.base = null
	craft.pending = {}


func open_abilities(node) -> Array:
	var r: Dictionary = spec.runes[node.rune]
	return r.abilities.filter(func(a): return int(a.grade) <= int(node.grade))


var _graft_cache: Dictionary = {}


## [ok, reasons] for grafting `donor` onto the current base's `ability` (cached; used every frame while dragging).
func graft_check(ability: String, donor) -> Array:
	if craft.base == null or donor == null:
		return [false, ["no base rune"]]
	var key := "%s|%s|%s" % [recipe(craft.base), ability, recipe(donor)]
	if not _graft_cache.has(key):
		_graft_cache[key] = rl.check_graft(recipe(craft.base), ability, recipe(donor))
	return _graft_cache[key]


func craft_add(ability: String, idx: int) -> void:
	var d = inventory[idx]
	if d == null or craft.base == null:
		return
	var res: Array = graft_check(ability, d)
	if not res[0]:
		var why: String = res[1][0] if res[1].size() > 0 else "incompatible"
		notify("Graft rejected: " + why)
		return
	if not craft.pending.has(ability):
		craft.pending[ability] = []
	craft.pending[ability].append(d)
	inventory[idx] = null
	changed.emit()


func craft_remove_pending(ability: String, i: int) -> void:
	var d = craft.pending[ability][i]
	craft.pending[ability].remove_at(i)
	inv_put(d)
	changed.emit()


func craft_ungraft(ability: String, i: int) -> void:
	# Ungraft: the donor (with its own sub-grafts) returns; the fee paid for it is lost.
	var d = craft.base.grafts[ability][i]
	if not inv_put(d):
		notify("Inventory is full.")
		return
	craft.base.grafts[ability].remove_at(i)
	if craft.base.grafts[ability].is_empty():
		craft.base.grafts.erase(ability)
	notify("Graft removed — the rune is back, the fee is lost.")
	changed.emit()


func _merged() -> Dictionary:
	var out: Dictionary = craft.base.duplicate(true)
	for ab in craft.pending:
		if not out.grafts.has(ab):
			out.grafts[ab] = []
		for d in craft.pending[ab]:
			out.grafts[ab].append(d.duplicate(true))
	return out


func craft_fee() -> int:
	if craft.base == null:
		return 0
	var n: int = rl.node_size(craft.base)
	var fee := 0.0
	for ab in craft.pending:
		for d in craft.pending[ab]:
			n += rl.node_size(d)
			fee += rl.graft_fee(n)
	return roundi(fee)


func do_craft() -> void:
	if craft.base == null or craft.pending.is_empty():
		notify("Needs a base rune and at least one graft.")
		return
	if craft.output != null:
		notify("Take the output rune first.")
		return
	var fee := craft_fee()
	if mana < fee:
		notify("Graft fee: %d mana." % fee)
		return
	mana -= fee
	craft.output = _merged()
	craft.base = null
	craft.pending = {}
	notify("Crafted — read the result on the output rune.")
	changed.emit()


func take_output() -> void:
	if craft.output == null:
		return
	if inv_put(craft.output):
		craft.output = null
	else:
		notify("Inventory is full.")
	changed.emit()


# ------------------------------------------------------------------ demo / screenshots

func _demo() -> void:
	# scripted session for headless verification captures
	mana = 4000.0
	stones = 60
	for rid in ["fire", "fire", "electric", "electric", "ice", "ice", "volcano", "mana", "water", "blood", "stone", "light"]:
		buy_rune(rid)
	combine(0, 1)
	combine(2, 3)
	combine(4, 5)
	var spots: Array = []
	for c in map.buildable:
		var near := false
		for p in map.path:
			if absi(p.x - c.x) <= 1 and absi(p.y - c.y) <= 1:
				near = true
		if near:
			spots.append(c)
	var picks := [spots[4], spots[spots.size() / 3], spots[spots.size() / 2], spots[(spots.size() * 2) / 3], spots[spots.size() - 6]]
	for c in picks:
		try_build(c)
	# craft: Fire G2 . burn <- Electric G2
	craft_set_base(0)
	craft_add("burn", 2)
	do_craft()
	take_output()
	socket(towers[0], _inv_find("fire"))
	socket(towers[1], _inv_find("volcano"))
	socket(towers[2], _inv_find("ice"))
	socket(towers[3], _inv_find("mana"))
	socket(towers[4], _inv_find("light"))
	# craft table showcase: Ice G3 base (3 ability slots), pending donors on two slots
	for i in 4:
		buy_rune("ice")
	var ices := []
	for i in INV_SIZE:
		if inventory[i] != null and inventory[i].rune == "ice" and int(inventory[i].grade) == 1:
			ices.append(i)
	combine(ices[0], ices[1])
	combine(ices[2], ices[3])
	combine(ices[0], ices[2])
	craft_set_base(ices[0])
	buy_rune("electric")
	craft_add("freeze", _inv_find("electric"))
	buy_rune("poison")
	craft_add("chill", _inv_find("poison"))
	hud.table.selected_ability = "freeze"
	select_tower(towers[0])
	var dir: String = args.get("shots", "")
	if dir != "":
		_shots(dir)


## Headless check: --savetest saves, reloads the scene from the save and prints both states.
func _savetest(after_load: bool) -> void:
	await get_tree().create_timer(1.0).timeout
	var state := "seed=%d wave=%d mana=%d stones=%d towers=%d inv=%d" % [seed_value, wave, int(mana), stones, towers.size(), inventory.filter(func(x): return x != null).size()]
	if after_load:
		print("SAVETEST loaded ", state)
		get_tree().quit()
		return
	print("SAVETEST saved  ", state)
	save_game()
	load_game()


var _auto_last := -1


func _auto_log() -> void:
	if wave != _auto_last and wave_state == "build" and wave > 0:
		_auto_last = wave
		print("AUTO wave=%d hp=%d mana=%d stones=%d towers=%d dmg=%.0f t=%.1f" % [wave, castle_hp, int(mana), stones, towers.size(), combat.damage_total, now])
	if wave_state == "build":
		start_wave.call_deferred()


func _inv_find(rid: String) -> int:
	for i in INV_SIZE:
		if inventory[i] != null and inventory[i].rune == rid:
			return i
	return -1


func _shots(dir: String) -> void:
	await get_tree().create_timer(1.0).timeout
	await _snap(dir, "00_build")
	if args.has("tabs"):
		hud.select_tab("shop")
		await get_tree().create_timer(0.4).timeout
		await _snap(dir, "00_shop")
		hud.select_tab("menu")
		hud.settings_box.visible = true
		await get_tree().create_timer(0.4).timeout
		await _snap(dir, "00_menu")
		hud.select_tab("craft")
		await get_tree().create_timer(0.3).timeout
	start_wave()
	if args.has("burst"):
		await get_tree().create_timer(float(args.get("burst_at", "9"))).timeout
		var keep_pos: Vector3 = cam_rig.global_position
		var keep_size := cam.size
		for i in 12:
			await get_tree().create_timer(0.12).timeout
			if not enemies.is_empty():
				cam_rig.focus(enemies[0].global_position + Vector3(1.5, 0, -0.5), 12.0)
				cam_rig.snap_now()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/burst_%02d.png" % [dir, i])
		cam_rig.focus(keep_pos, keep_size)
		cam_rig.snap_now()
	for t in [3.0, 4.0, 4.0, 5.0]:
		await get_tree().create_timer(t).timeout
		await _snap(dir, "%02d_wave" % (_shot_i))
	if args.has("quit-after"):
		get_tree().quit()


func _snap(dir: String, name: String) -> void:
	print("vfx movers=%d links=%d fx=%d floaters=%d fields=%d enemies=%d dmg=%.0f" % [vfx.movers.size(), vfx.links.size(), vfx.fx.size(), vfx.floaters.size(), combat.fields.size(), enemies.size(), combat.damage_total])
	if args.has("closeup") and not enemies.is_empty():
		var keep_pos: Vector3 = cam_rig.global_position
		var keep_size := cam.size
		cam_rig.focus(enemies[0].global_position + Vector3(2.5, 0, 0), 11.0)
		cam_rig.snap_now()
		await RenderingServer.frame_post_draw
		var img2 := get_viewport().get_texture().get_image()
		img2.save_png("%s/%s_close.png" % [dir, name])
		cam_rig.focus(keep_pos, keep_size)
		cam_rig.snap_now()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_i += 1
	img.save_png("%s/%s.png" % [dir, name])
	print("shot ", name)
