extends RefCounted
## Turns a map_gen.generate() dictionary into 3D: tiles (incl. river, bridge, plateau, stairs),
## voxel-grid props, castle, path curve and the decorative apron around the map.
## Cell (x, y) with y = north -> world (x*2, 0, -y*2). Rotation k = quarter turns CCW.
## Props sit on the 0.04-unit voxel grid: anchor/foot are tile-local voxels (u east, v north).
## The apron (outside the playable map) is drawn with MultiMeshes so it costs a few draw calls.

const GLB := preload("res://scripts/glb.gd")
const TILE := 2.0
const VOX := 0.04
const LEVEL_H := 0.96

var root: Node3D
var curve := Curve3D.new()
var buildable: Dictionary = {}        # Vector2i -> true
var small_props: Dictionary = {}      # Vector2i -> Array[Node3D] (removed when building)
var path_set: Dictionary = {}
var levels: Dictionary = {}           # Vector2i -> int (map + apron)
var castle_node: Node3D
var castle_pos := Vector3.ZERO
var bounds := Rect2()                 # XZ rectangle covered by tiles (map + apron)
var _mm: Dictionary = {}              # "mesh_id" -> {mesh, xforms: Array[Transform3D]}


static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE, 0.0, -c.y * TILE)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE), roundi(-p.z / TILE))


func level_of(c: Vector2i) -> int:
	return levels.get(c, 0)


func summon_ok(c: Vector2i) -> bool:
	return buildable.has(c)


static func prop_position(p: Dictionary) -> Vector3:
	var c: Vector2i = p.cell
	var a: Vector2i = p.anchor
	var f: Vector2i = p.foot
	var x := c.x * TILE - TILE * 0.5 + (a.x + f.x * 0.5) * VOX
	var z := -c.y * TILE + TILE * 0.5 - (a.y + f.y * 0.5) * VOX
	return Vector3(x, float(p.get("level", 0)) * LEVEL_H, z)


func build(m: Dictionary, parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "World"
	parent.add_child(root)
	for t in m.tiles:
		levels[t.cell] = int(t.get("level", 0))
	for t in m.get("apron_tiles", []):
		levels[t.cell] = int(t.get("level", 0))
	var tiles := Node3D.new(); tiles.name = "Tiles"; root.add_child(tiles)
	for t in m.tiles:
		var n := GLB.instance("tiles/%s.glb" % t.id)
		n.position = cell_to_world(t.cell)
		n.rotation_degrees.y = t.rot * 90.0
		tiles.add_child(n)
	for c in m.path:
		path_set[c] = true
	for c in m.buildable:
		buildable[c] = true
	var props := Node3D.new(); props.name = "Props"; root.add_child(props)
	for p in m.props:
		var n := GLB.instance("props/%s.glb" % p.id)
		n.position = prop_position(p)
		n.rotation_degrees.y = p.rot * 90.0
		props.add_child(n)
		if not p.large:
			if not small_props.has(p.cell):
				small_props[p.cell] = []
			small_props[p.cell].append(n)
	# apron: batched
	for t in m.get("apron_tiles", []):
		_batch("tiles/%s.glb" % t.id, Transform3D(Basis(Vector3.UP, t.rot * PI * 0.5), cell_to_world(t.cell)))
	for p in m.get("apron_props", []):
		_batch("props/%s.glb" % p.id, Transform3D(Basis(Vector3.UP, p.rot * PI * 0.5), prop_position(p)))
	_flush_batches()
	var ap: int = int(m.get("apron", 0))
	var sz: Vector2i = m.size
	bounds = Rect2(-ap * TILE - TILE * 0.5, -(sz.y + ap - 1) * TILE - TILE * 0.5, (sz.x + 2 * ap) * TILE, (sz.y + 2 * ap) * TILE)
	_build_curve(m.path)
	_build_castle(m.path)
	_add_skirt()


## Collect every MeshInstance3D of a GLB (with its local transform) into per-mesh MultiMesh batches.
func _batch(rel: String, xf: Transform3D) -> void:
	var proto := GLB.instance(rel)
	for mi in proto.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local: Transform3D = _local_xf(proto, m)
		var key := "%s|%s" % [rel, m.name]
		if not _mm.has(key):
			_mm[key] = {"mesh": m.mesh, "xforms": []}
		_mm[key].xforms.append(xf * local)
	proto.free()


func _local_xf(top: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _flush_batches() -> void:
	var holder := Node3D.new(); holder.name = "Apron"; root.add_child(holder)
	for key in _mm:
		var e: Dictionary = _mm[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e.mesh
		mm.instance_count = e.xforms.size()
		for i in e.xforms.size():
			mm.set_instance_transform(i, e.xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		holder.add_child(mmi)
	_mm.clear()


func _build_curve(path: Array) -> void:
	curve.clear_points()
	var first: Vector2i = path[0]
	var second: Vector2i = path[1]
	var back := first - (second - first)
	var into := first + back * 3                       # enemies walk in along the apron path, 3 tiles out
	curve.add_point(cell_to_world(into))
	for c in path:
		curve.add_point(cell_to_world(c))
	curve.bake_interval = 0.1


func _build_castle(path: Array) -> void:
	var last: Vector2i = path[path.size() - 1]
	var prev: Vector2i = path[path.size() - 2]
	var d := cell_to_world(prev) - cell_to_world(last)
	d = d.normalized()
	castle_node = GLB.instance("units/castle.glb")
	# gate is on the model's -X side: turn it towards the incoming path, push the keep back a little
	castle_node.rotation.y = atan2(d.z, -d.x)
	castle_pos = cell_to_world(last) - d * 0.9
	castle_node.position = castle_pos
	castle_node.scale = Vector3.ONE * 1.05
	root.add_child(castle_node)


func _add_skirt() -> void:
	# soil block under the whole tiled area (never visible from inside the camera bounds, but keeps shadows sane)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(bounds.size.x, 1.4, bounds.size.y)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#8A5E36")
	mi.material_override = m
	mi.position = Vector3(bounds.get_center().x, -0.86, bounds.get_center().y)
	root.add_child(mi)


func take_cell(c: Vector2i) -> void:
	buildable.erase(c)
	if small_props.has(c):
		for n in small_props[c]:
			(n as Node3D).queue_free()
		small_props.erase(c)
