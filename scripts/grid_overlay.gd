extends MeshInstance3D
## Grid-aligned cell overlay: translucent squares for a set of cells plus an outline along the outer
## border of the set. Used for tower range (hover / build ghost), coverage while building and rune
## drop targets. The mesh is only rebuilt when the cell set or colours change.

const TILE := 2.0
const INSET := 0.07
const EDGE := 0.09

var im := ImmediateMesh.new()
var _key := ""
var pulse := 0.0
var pulse_amp := 0.0
var _mat: StandardMaterial3D


func _init() -> void:
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 1
	material_override = _mat


## cells: Array[Vector2i]; height_of: Callable(Vector2i) -> float (surface y of that cell)
func show_cells(cells: Array, height_of: Callable, fill: Color, edge: Color) -> void:
	var key := "%s|%s|%s" % [var_to_str(cells), fill.to_html(), edge.to_html()]
	visible = not cells.is_empty()
	if key == _key:
		return
	_key = key
	im.clear_surfaces()
	if cells.is_empty():
		return
	var set := {}
	for c in cells:
		set[c] = true
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := TILE * 0.5
	for c: Vector2i in cells:
		var y: float = height_of.call(c) + 0.045
		var cx := c.x * TILE
		var cz := -c.y * TILE
		if fill.a > 0.0:
			_quad(Vector3(cx - h + INSET, y, cz - h + INSET), Vector3(cx + h - INSET, y, cz + h - INSET), fill)
		# outline on sides that face outside the set (N, E, S, W)
		if not set.has(c + Vector2i(0, 1)):
			_quad(Vector3(cx - h + INSET, y + 0.002, cz - h + INSET), Vector3(cx + h - INSET, y + 0.002, cz - h + INSET + EDGE), edge)
		if not set.has(c + Vector2i(0, -1)):
			_quad(Vector3(cx - h + INSET, y + 0.002, cz + h - INSET - EDGE), Vector3(cx + h - INSET, y + 0.002, cz + h - INSET), edge)
		if not set.has(c + Vector2i(1, 0)):
			_quad(Vector3(cx + h - INSET - EDGE, y + 0.002, cz - h + INSET), Vector3(cx + h - INSET, y + 0.002, cz + h - INSET), edge)
		if not set.has(c + Vector2i(-1, 0)):
			_quad(Vector3(cx - h + INSET, y + 0.002, cz - h + INSET), Vector3(cx - h + INSET + EDGE, y + 0.002, cz + h - INSET), edge)
	im.surface_end()


func clear() -> void:
	show_cells([], func(_c): return 0.0, Color.TRANSPARENT, Color.TRANSPARENT)


func _quad(a: Vector3, b: Vector3, c: Color) -> void:
	var p := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	for i in [0, 1, 2, 0, 2, 3]:
		im.surface_set_color(c)
		im.surface_add_vertex(p[i])


func _process(dt: float) -> void:
	if pulse_amp > 0.0 and visible:
		pulse += dt
		_mat.albedo_color = Color(1, 1, 1, 1.0 - pulse_amp * (0.5 + 0.5 * sin(pulse * 5.0)))
