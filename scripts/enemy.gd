extends Node3D
## One enemy walking the path. Position is driven by `s` (distance along the path, in tiles);
## forced moves (push / pull) change `s`. Statuses live here, keyed "status|op_uid".

const GLB := preload("res://scripts/glb.gd")

const TYPES := {
	"normal": {"glb": "units/enemy_normal.glb", "hp": 1.0, "speed": 1.0, "armor": 0.10, "stones": 1, "scale": 1.0},
	"fast":   {"glb": "units/enemy_fast.glb", "hp": 0.55, "speed": 1.65, "armor": 0.0, "stones": 1, "scale": 1.0},
	"brute":  {"glb": "units/enemy_brute.glb", "hp": 2.6, "speed": 0.7, "armor": 0.25, "stones": 3, "scale": 1.0},
	"boss":   {"glb": "units/enemy_boss.glb", "hp": 12.0, "speed": 0.55, "armor": 0.2, "stones": 10, "scale": 1.15},
}

var eid := 0
var kind := "normal"
var hp := 100.0
var max_hp := 100.0
var base_speed := 1.0
var armor := 0.1
var stones := 1
var s := 0.0                      # distance along the path (tiles)
var alive := true
var leaked := false
var st: Dictionary = {}           # "status|uid" -> Dictionary
var frozen_until := -1.0
var frozen_by = null
var stun_until := -1.0
var stun_icd: Dictionary = {}
var path: Curve3D
var model: Node3D
var hp_bar: MeshInstance3D
var hp_back: MeshInstance3D
var flash := 0.0
var _mats: Array = []
var bob := 0.0
var bar_w := 0.9


func setup(id: int, type: String, hp_base: float, curve: Curve3D) -> void:
	eid = id
	kind = type
	var t: Dictionary = TYPES[type]
	max_hp = hp_base * t.hp
	hp = max_hp
	base_speed = t.speed
	armor = t.armor
	stones = t.stones
	path = curve
	model = GLB.instance(t.glb)
	model.scale = Vector3.ONE * t.scale
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var src := m.get_active_material(si)
			if src is BaseMaterial3D:
				var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				m.set_surface_override_material(si, mat)
				_mats.append(mat)
	_make_bar()
	bob = float(id) * 0.7


func _make_bar() -> void:
	var w := 0.9 if kind != "boss" else 1.6
	var top := 1.0 if kind != "boss" else 1.7
	hp_back = MeshInstance3D.new()
	var qb := QuadMesh.new()
	qb.size = Vector2(w + 0.08, 0.16)
	hp_back.mesh = qb
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.1, 0.07, 0.06, 0.85)
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mb.no_depth_test = true
	mb.render_priority = 1
	hp_back.material_override = mb
	hp_back.position = Vector3(0, top, 0)
	add_child(hp_back)
	hp_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, 0.1)
	hp_bar.mesh = q
	bar_w = w
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.36, 0.33)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 2
	hp_bar.material_override = m
	hp_bar.position = Vector3(0, top, 0)
	add_child(hp_bar)
	hp_bar.visible = false
	hp_back.visible = false


func world_pos() -> Vector3:
	return path.sample_baked(clampf(s * 2.0, 0.0, path.get_baked_length()))


func cell() -> Vector2i:
	return Vector2i(roundi(global_position.x / 2.0), roundi(-global_position.z / 2.0))


## Snap the node onto its path distance right away (forced moves happen mid-event, before the next visual refresh).
func sync_position() -> void:
	position = world_pos()


func tile_pos() -> Vector2:
	var p := global_position
	return Vector2(p.x, p.z) * 0.5


func has(status: String) -> bool:
	for k in st:
		if k.begins_with(status + "|"):
			return true
	return false


func get_all(status: String) -> Array:
	var out := []
	for k in st:
		if k.begins_with(status + "|"):
			out.append(st[k])
	return out


func speed_factor(now: float) -> float:
	if now < frozen_until or now < stun_until:
		return 0.0
	var slow := 0.0
	for v in get_all("slow"):
		slow = maxf(slow, v.pct)
	return maxf(0.2, 1.0 - slow)


func refresh_visual(now: float, dt: float) -> void:
	var p := world_pos()
	var ahead := path.sample_baked(clampf(s * 2.0 + 0.3, 0.0, path.get_baked_length()))
	bob += dt * 9.0 * speed_factor(now)
	position = p + Vector3(0, absf(sin(bob)) * 0.06, 0)
	var d := ahead - p
	if d.length() > 0.01:
		rotation.y = atan2(-d.z, d.x)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	hp_bar.visible = frac < 0.999
	hp_back.visible = hp_bar.visible
	var qm := hp_bar.mesh as QuadMesh
	qm.size.x = maxf(bar_w * frac, 0.001)
	qm.center_offset.x = -(bar_w - qm.size.x) * 0.5
	# status tint (frozen > burn > poison > slow > wet), plus hit flash
	var tint := Color(0, 0, 0)
	var energy := 0.0
	if now < frozen_until:
		tint = Color(0.6, 0.85, 1.0); energy = 0.9
	elif has("burn"):
		tint = Color(1.0, 0.45, 0.15); energy = 0.35 + 0.25 * sin(now * 18.0)
	elif has("poison"):
		tint = Color(0.45, 0.95, 0.3); energy = 0.3
	elif has("slow") or has("wet"):
		tint = Color(0.4, 0.7, 1.0); energy = 0.25
	if flash > 0.0:
		flash -= dt
		tint = Color(1, 1, 1); energy = 1.2 * flash / 0.12
	for m in _mats:
		var sm := m as BaseMaterial3D
		sm.emission_enabled = energy > 0.01
		sm.emission = tint
		sm.emission_energy_multiplier = energy
