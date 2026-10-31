extends Node3D
const T := preload("res://ui/i18n.gd")
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
const RuneStore := preload("res://scripts/rune_store.gd")
const Economy := preload("res://scripts/economy.gd")
const SaveSystem := preload("res://scripts/save_system.gd")
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
var store                               # rune_store.gd: inventory / craft / socket operations
var economy                             # economy.gd: shop prices, mana income
var saves                               # save_system.gd
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
var settings := {"lang": "en", "numbers": true, "fullscreen": false, "cam_speed": 1.0, "edge_pan": false, "cam_angle": "45"}
## Camera angle is NOT final: 45° (default), 30° and a zoom-dependent angle are offered for evaluation only.
const CAM_ANGLES := {"45": [45.0, 45.0], "30": [30.0, 30.0], "dynamic": [32.0, 52.0]}
const SETTINGS_PATH := "user://runecraft_settings.json"
const SAVE_PATH := "user://runecraft_save.json"
var _shot_i := 0


func _ready() -> void:
	args = _parse_args(OS.get_cmdline_user_args())
	_load_settings()
	if args.has("cam"):
		settings["cam_angle"] = str(args["cam"])
	if args.has("lang"):
		settings["lang"] = str(args["lang"])
	spec = JSON.parse_string(FileAccess.get_file_as_string("res://data/rune_mechanics_v1.json"))
	colors = JSON.parse_string(FileAccess.get_file_as_string("res://data/rune_colors_v4.json")).runes
	rl = load("res://scripts/rune_lib.gd").new("res://data/rune_mechanics_v1.json")
	rl.set_locale("res://scripts/locale/%s.json" % settings.get("lang", "en"))
	T.load_lang(str(settings.get("lang", "en")))
	font_bold = preload("res://ui/style.gd").font("bold")
	var e: Dictionary = spec.economy
	mana = float(e.start.mana)
	stones = int(e.start.mana_stone)
	castle_hp = int(e.start.castle_hp)
	castle_max = castle_hp
	mana_regen = float(e.mana_regen_per_s)
	inventory.resize(INV_SIZE)
	store = RuneStore.new(self)
	economy = Economy.new(self)
	saves = SaveSystem.new(self)
	seed_value = int(args.get("seed", randi() % 100000))
	var loaded = pending_load
	pending_load = null
	if loaded != null:
		seed_value = int(loaded.seed)
	_build_world()
	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	notify(T.t("msg_intro"))
	_apply_settings()
	if loaded != null:
		saves.restore(loaded)
	if args.has("demo") and loaded == null:
		_demo()
	if args.has("econ") and loaded == null:
		_econ_mode()
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
	_camera_angle()
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


## Zoom-dependent camera angle (evaluation option): lower angle when zoomed in, steeper when zoomed out.
func _camera_angle() -> void:
	var ang: Array = CAM_ANGLES.get(str(settings.get("cam_angle", "45")), CAM_ANGLES["45"])
	if cam_rig == null or ang[0] == ang[1]:
		return
	var t := clampf((cam.size - cam_rig.min_size) / maxf(cam_rig.max_size - cam_rig.min_size, 0.001), 0.0, 1.0)
	cam_rig.pitch_deg = lerpf(float(ang[0]), float(ang[1]), t)


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
		notify(T.t("msg_castle_fell", {"n": wave}))
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
				economy.on_wave_cleared()
				notify(T.t("msg_wave_cleared", {"n": wave}))
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
		notify(T.t("msg_early_call", {"n": bonus}))
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
	return economy.tower_cost()


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
		notify(T.t("msg_cant_build"))
		return false
	var cost := tower_cost()
	if stones < cost:
		notify(T.t("msg_need_stones", {"n": cost}))
		return false
	stones -= cost
	var t = place_tower(c, cost)
	t.pop_in()
	vfx.ring(t.position, Color("#EECB8E"), 2.2, 0.5)
	vfx.particles(t.position + Vector3(0, 0.3, 0), Color(1, 0.95, 0.8), Color(0.7, 0.6, 0.45), 16, 2.0, 0.1, 0.5)
	select_tower(t)
	if not Input.is_key_pressed(KEY_SHIFT):
		build_mode = false
	changed.emit()
	return true


## Create a tower on cell `c` without charging (used by try_build and by loading a save). `paid` = its price.
func place_tower(c: Vector2i, paid: int):
	wb.take_cell(c)
	var t := Node3D.new()
	t.set_script(TowerScript)
	add_child(t)
	t.position = cell_world(c)
	t.setup(self, next_tid, c)
	t.set_meta("paid", paid)
	next_tid += 1
	towers.append(t)
	return t


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


## Sell a tower: its rune goes back to the inventory (the sale fails if the inventory is full) and a share of
## the price paid comes back as mana stones.
func sell_tower(t) -> bool:
	if t == null or not t in towers:
		return false
	if t.rune != null and store.free_slots() == 0:
		notify(T.t("msg_inv_full"))
		return false
	var refund: int = economy.tower_refund(t)
	if t.rune != null:
		inv_put(t.rune)
		t.set_rune(null)
	stones += refund
	t.cleanup()
	towers.erase(t)
	wb.buildable[t.cell] = true
	if selected_tower == t:
		selected_tower = null
	t.queue_free()
	changed.emit()
	return true


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
		var ang: Array = CAM_ANGLES.get(str(settings.get("cam_angle", "45")), CAM_ANGLES["45"])
		cam_rig.pitch_deg = float(ang[0])
		cam_rig.edge_margin = 24.0 if settings.get("edge_pan", false) else 0.0
	if not args.has("shots"):
		var fs: bool = settings.get("fullscreen", false)
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(want)


static var pending_load = null
const SAVE_VERSION := SaveSystem.VERSION


func serialize() -> Dictionary:
	return saves.serialize()


## Apply a save Dictionary to this (freshly built, same seed) game.
func restore(d: Dictionary) -> bool:
	return saves.restore(SaveSystem.ints(d))


func save_game(path := SAVE_PATH) -> bool:
	return saves.save(path)


## Validates the file first; a bad file changes nothing. A save of the current map is applied in place; a save of
## another map reloads the scene with that seed.
func load_game(path := SAVE_PATH) -> bool:
	var d = saves.read(path)
	if d == null:
		return false
	if int(d.seed) == seed_value:
		_clear_run()
		return saves.restore(d)
	pending_load = d
	get_tree().reload_current_scene()
	return true


## Remove everything a run owns (towers, summons, enemies, fields, items, prices) — the map stays.
func _clear_run() -> void:
	for t in towers.duplicate():
		t.cleanup()
		wb.buildable[t.cell] = true
		t.queue_free()
	towers.clear()
	for e in enemies:
		e.queue_free()
	enemies.clear()
	to_spawn.clear()
	for f in combat.fields:
		vfx.field_end(f)
	combat.fields.clear()
	for i in INV_SIZE:
		inventory[i] = null
	craft = {"base": null, "pending": {}, "output": null}
	economy = Economy.new(self)
	selected_tower = null
	build_mode = false
	wave_state = "build"


# ------------------------------------------------------------------ inventory / runes
# Rune moves live in rune_store.gd (all-or-nothing, never lose or duplicate a rune); these wrappers keep the
# public API and refresh the HUD. Every operation returns true on success.

func rune_cost(rid: String) -> int:
	return economy.rune_cost(rid)


func inv_put(node) -> bool:
	var ok: bool = store.put(node)
	if ok:
		changed.emit()
	return ok


func inv_free_slots() -> int:
	return store.free_slots()


func all_items() -> Array:
	return store.all_items()


func _done(ok: bool) -> bool:
	changed.emit()
	return ok


func buy_rune(rid: String) -> bool:
	var c := rune_cost(rid)
	if mana < c:
		notify(T.t("msg_need_mana", {"n": c}))
		return false
	if not store.put({"rune": rid, "grade": 1, "grafts": {}}):
		notify(T.t("msg_inv_full"))
		return false
	mana -= c
	economy.on_rune_bought(rid)
	return _done(true)


func combine_fee(grade: int) -> int:
	return int(spec.economy.combine.fee_mana_per_target_grade_minus_1) * grade


func combine(a: int, b: int) -> bool:
	return _done(store.combine(a, b))


func _socket_fx(t) -> void:
	if t != null and t.rune != null:
		var el: String = spec.runes[t.rune.rune].element
		vfx.ring(t.position, element_color(el, "glow"), 1.8, 0.45)
		vfx.particles(t.position + Vector3(0, 2.0, 0), element_color(el, "hot"), element_color(el), 16, 2.2, 0.08, 0.5)


func socket(t, idx: int) -> bool:
	var ok: bool = store.socket(t, idx)
	if ok:
		_socket_fx(t)
	return _done(ok)


func socket_output(t) -> bool:
	var ok: bool = store.socket_output(t)
	if ok:
		_socket_fx(t)
	return _done(ok)


func unsocket(t) -> bool:
	return _done(store.unsocket(t))


func recipe(node) -> String:
	return rl.canonical(node)


var _describe_cache: Dictionary = {}


func describe(node) -> String:
	var key := recipe(node)
	if not _describe_cache.has(key):
		_describe_cache[key] = rl.describe(rl.compile_recipe(node))
	return _describe_cache[key]


# ------------------------------------------------------------------ craft table

func craft_set_base(idx: int) -> bool:
	return _done(store.set_base(idx))


func craft_clear() -> bool:
	return _done(store.clear_table())


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


func craft_add(ability: String, idx: int) -> bool:
	return _done(store.add_pending(ability, idx))


func craft_remove_pending(ability: String, i: int) -> bool:
	return _done(store.remove_pending(ability, i))


func craft_ungraft(ability: String, i: int) -> bool:
	return _done(store.ungraft(ability, i))


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


func do_craft() -> bool:
	return _done(store.craft())


func take_output() -> bool:
	return _done(store.take_output())


func output_to_slot(i: int) -> bool:
	return _done(store.output_to_slot(i))


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
	if args.has("uishots"):
		_ui_shots(str(args.uishots))


## UI captures for the Craft tab / rune structure / inspector / tooltip / tower card (--demo --uishots DIR).
func _ui_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# table: a crafted Fire G4 with nested grafts as the base, plus one pending donor
	store.clear_table()
	var base := {"rune": "ice", "grade": 3, "grafts": {
		"freeze": [{"rune": "electric", "grade": 3, "grafts": {"chain": [{"rune": "poison", "grade": 1, "grafts": {}}]}}],
		"chill": [{"rune": "water", "grade": 2, "grafts": {}}, {"rune": "mana", "grade": 1, "grafts": {}}]}}
	craft.base = base
	craft.pending = {"ice_hit": [{"rune": "stone", "grade": 1, "grafts": {}}]}
	for i in INV_SIZE:
		if inventory[i] == null:
			inventory[i] = {"rune": ["water", "golem", "hive", "meteor", "blood", "light"][i % 6], "grade": 1 + (i % 5), "grafts": {}}
			if i > 14:
				break
	towers[0].set_rune(base.duplicate(true))
	select_tower(towers[0])
	hud.show_structure_of("base")
	changed.emit()
	await get_tree().create_timer(1.2).timeout
	await _snap(dir, "01_craft")
	var it = hud.struct_tree.root_item
	hud.struct_tree.selected = it.kids[2]
	hud.struct_tree.picked.emit(it.kids[2])
	await get_tree().create_timer(0.3).timeout
	await _snap(dir, "02_craft_ability")
	var donor = it.kids[2].kids[0]
	hud.struct_tree.selected = donor
	hud.struct_tree.picked.emit(donor)
	await get_tree().create_timer(0.2).timeout
	hud.show_tip(hud.tip_for(base), hud.inv_slots[20])
	await get_tree().create_timer(0.3).timeout
	await _snap(dir, "03_tooltip")
	hud.hide_tip(hud.tip_owner)
	var deep := {"rune": "fire", "grade": 4, "grafts": {
		"fire_hit": [{"rune": "electric", "grade": 3, "grafts": {"chain": [{"rune": "ice", "grade": 2, "grafts": {}}, {"rune": "poison", "grade": 1, "grafts": {}}]}},
			{"rune": "water", "grade": 3, "grafts": {"push": [{"rune": "blood", "grade": 1, "grafts": {}}]}}],
		"burn": [{"rune": "mana", "grade": 3, "grafts": {}}, {"rune": "stone", "grade": 2, "grafts": {"armor_shred": [{"rune": "light", "grade": 1, "grafts": {}}]}}],
		"fire_trail": [{"rune": "ice", "grade": 3, "grafts": {"freeze": [{"rune": "electric", "grade": 2, "grafts": {}}]}}, {"rune": "golem", "grade": 1, "grafts": {}}]}}
	towers[1].set_rune(deep)
	select_tower(towers[1])
	hud.inspect(deep, {"kind": "tower", "tower": towers[1]})
	await get_tree().create_timer(0.6).timeout
	await _snap(dir, "04_inspector")
	var itd = hud.inspector.item
	hud.inspector.tree.selected = itd.kids[0].kids[0]
	hud.inspector.tree.picked.emit(itd.kids[0].kids[0])
	await get_tree().create_timer(0.3).timeout
	await _snap(dir, "05_inspector_donor")
	hud.inspector.hide_inspector()
	hud.select_tab("shop")
	await get_tree().create_timer(0.4).timeout
	await _snap(dir, "06_shop")
	hud.select_tab("menu")
	hud.settings_box.visible = true
	await get_tree().create_timer(0.4).timeout
	await _snap(dir, "07_menu")
	get_tree().quit()


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


## Headless economy probe: --econ <variant> builds the same 3 towers + one variant tower and plays waves at 3×,
## printing per-wave rune mana income. Variants: none, mana1, mana3, mana5, fire3+mana5 (Mana grafted on Fire).
func _econ_mode() -> void:
	mana = 0.0
	stones = 999
	var fixed := [{"rune": "fire", "grade": 3, "grafts": {}}, {"rune": "ice", "grade": 3, "grafts": {}}, {"rune": "electric", "grade": 3, "grafts": {}}]
	var v := str(args.econ)
	var extra = {"none": null, "mana1": {"rune": "mana", "grade": 1, "grafts": {}}, "mana3": {"rune": "mana", "grade": 3, "grafts": {}},
		"mana5": {"rune": "mana", "grade": 5, "grafts": {}},
		"fire3+mana5": {"rune": "fire", "grade": 3, "grafts": {"fire_hit": [{"rune": "mana", "grade": 5, "grafts": {}}]}}}.get(v, null)
	var spots: Array = []
	for c in map.buildable:
		for p in map.path:
			if absi(p.x - c.x) <= 1 and absi(p.y - c.y) <= 1:
				spots.append(c)
				break
	var picks := [spots[2], spots[spots.size() / 4], spots[spots.size() / 2], spots[(spots.size() * 3) / 4]]
	if args.has("front"):        # variant tower first on the path (it meets every enemy)
		picks = [picks[3], picks[1], picks[2], picks[0]]
	for i in 4:
		var t = place_tower(picks[i], 0)
		var r = fixed[i] if i < 3 else extra
		if r != null:
			t.set_rune(r)
	set_speed(3.0)
	var last_mana := 0.0
	var last_income := 0.0
	var waves := int(args.get("waves", "8"))
	start_wave()
	while wave <= waves and wave_state != "lost":
		await get_tree().process_frame
		if wave_state == "build":
			var inc: float = economy.total_rune_income
			print("ECON %s wave=%d rune_mana=%.1f total_mana_gain=%.1f hp=%d dmg=%.0f" % [v, wave, inc - last_income, mana - last_mana, castle_hp, combat.damage_real])
			last_income = inc
			last_mana = mana
			if wave >= waves:
				break
			start_wave()
	get_tree().quit()


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
	if args.has("inspect"):
		# a 14-rune recipe with nested grafts, as an inspector readability check
		var deep := {"rune": "fire", "grade": 4, "grafts": {
			"fire_hit": [{"rune": "electric", "grade": 3, "grafts": {"chain": [{"rune": "ice", "grade": 2, "grafts": {}}, {"rune": "poison", "grade": 1, "grafts": {}}]}},
				{"rune": "water", "grade": 3, "grafts": {"push": [{"rune": "blood", "grade": 1, "grafts": {}}]}}],
			"burn": [{"rune": "mana", "grade": 3, "grafts": {}}, {"rune": "stone", "grade": 2, "grafts": {"armor_shred": [{"rune": "light", "grade": 1, "grafts": {}}]}}],
			"fire_trail": [{"rune": "ice", "grade": 3, "grafts": {"freeze": [{"rune": "electric", "grade": 2, "grafts": {}}]}}, {"rune": "golem", "grade": 1, "grafts": {}}]}}
		towers[0].set_rune(deep)
		select_tower(towers[0])
		hud.inspect(deep)
		await get_tree().create_timer(0.5).timeout
		await _snap(dir, "00_inspect")
		hud.inspector.hide_inspector()
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
