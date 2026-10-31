extends Control
## Radial rune tree: the main rune sits in a carved socket in the middle, its abilities sit on an engraved glyph
## ring around it, donor runes branch outward from their ability through chiselled grooves, nested donors branch
## further out. Rune light flows only through grooves that actually carry something. Every piece of art is a Penpot
## export (node_*, groove*, tree_ring, grade_g*, rune icons); this script only places it.
## compact = true: abilities + direct donors (a "+N" badge marks a donor that carries nested grafts).
## Click a node → `picked(item)`; the owner shows the details. Hover → `hovered(item)` (null when leaving).

signal picked(item)
signal hovered(item)

const UISkin := preload("res://ui/skin.gd")
const S := preload("res://ui/style.gd")
const RV := preload("res://ui/rune_view.gd")
const T := preload("res://ui/i18n.gd")

var game
var compact := true
var root_item = null
var selected = null          # item
var hover_item = null
var _nodes: Array = []       # [{item, c: Vector2, s: float, parent: Vector2, lit, kind}]
var _edges: Array = []       # [{a, b, lit, pend}]
var _rings: Array = []       # ring radii to engrave
var _t := 0.0
var _dirty := true
var min_node := 22.0


func _init(g = null) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_item(it, keep_selection := false) -> void:
	root_item = it
	if not keep_selection or it == null:
		selected = it
	_dirty = true
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_dirty = true
	elif what == NOTIFICATION_MOUSE_EXIT and hover_item != null:
		hover_item = null
		hovered.emit(null)


# ------------------------------------------------------------------ layout

func _leaves(it: Dictionary, depth_cap: int) -> float:
	if it.kind == "ability" and it.state == "locked":
		return 0.7
	var kids: Array = _shown_kids(it, depth_cap)
	if kids.is_empty():
		return 1.0
	var s := 0.0
	for k in kids:
		s += _leaves(k, depth_cap)
	return maxf(s, 1.0)


func _shown_kids(it: Dictionary, depth_cap: int) -> Array:
	if it.kind == "rune" and it.depth >= depth_cap:
		return []
	return it.kids


func _max_rune_depth(it: Dictionary, depth_cap: int) -> int:
	var m: int = it.depth if it.kind == "rune" else 0
	for k in _shown_kids(it, depth_cap):
		m = maxi(m, _max_rune_depth(k, depth_cap))
	return m


func _layout() -> void:
	_dirty = false
	_nodes.clear()
	_edges.clear()
	_rings.clear()
	if root_item == null:
		return
	var cap := 1 if compact else 99
	var depth := maxi(1, _max_rune_depth(root_item, cap))
	# rings are ellipses that use the whole area: one radial "unit" per rune level, scaled per axis
	var m := Vector2(34, 24) if compact else Vector2(44, 40)
	var span := _rad(float(depth)) + 0.08
	_unit = Vector2((size.x * 0.5 - m.x) / span, (size.y * 0.5 - m.y) / span)
	var short := minf(_unit.x, _unit.y)
	var root_s := clampf(short * (0.62 if compact else 0.5), 46.0, 78.0)
	_place(root_item, -PI * 0.5, PI * 1.5, 0.0, short, root_s, cap, null)
	_rings.append(0.55)
	_relax()


## Push overlapping sockets apart: the deeper one moves outward along its spoke until the boxes clear, then
## everything is clamped back inside the area. A few passes settle crowded rings without changing the structure.
func _relax() -> void:
	var c := size * 0.5
	for _pass in 24:
		var moved := false
		for i in _nodes.size():
			for j in range(i + 1, _nodes.size()):
				var a: Dictionary = _nodes[i]
				var b: Dictionary = _nodes[j]
				var need: float = (a.s + b.s) * 0.5 + 3.0
				var d: Vector2 = b.c - a.c
				if absf(d.x) >= need or absf(d.y) >= need:
					continue
				var mv: Dictionary = b if int(b.item.depth) * 2 + (1 if b.kind == "rune" else 0) >= int(a.item.depth) * 2 + (1 if a.kind == "rune" else 0) else a
				if mv.item.depth == 0 and mv.kind == "rune":
					mv = a if is_same(mv, b) else b
				var out: Vector2 = (mv.c - c)
				out = out.normalized() if out.length() > 0.5 else Vector2.RIGHT
				# step along the spoke, plus a little sideways so two nodes on one spoke separate too
				var side := Vector2(-out.y, out.x) * (1.0 if (mv.c - (b.c if is_same(mv, a) else a.c)).dot(Vector2(-out.y, out.x)) >= 0.0 else -1.0)
				mv.c += out * 3.0 + side * 2.0
				moved = true
		for n in _nodes:
			var h: float = n.s * 0.5 + 2.0
			n.c = Vector2(clampf(n.c.x, h, size.x - h), clampf(n.c.y, h, size.y - h))
		if not moved:
			break


var _unit := Vector2.ONE


## Radius of a tree level: the first ring is one unit out, deeper rings come closer together (deeper levels hold
## fewer runes), so a 3-4 level recipe keeps big, readable sockets.
func _rad(level: float) -> float:
	return level if level <= 1.0 else 1.0 + (level - 1.0) * 0.72


func _place(it: Dictionary, a0: float, a1: float, r: float, short: float, root_s: float, cap: int, parent_node) -> void:
	var c := size * 0.5
	var mid := (a0 + a1) * 0.5
	var rr := _rad(r)
	var pos: Vector2 = c + Vector2(cos(mid) * _unit.x, sin(mid) * _unit.y) * rr
	var s: float
	if it.kind == "rune":
		s = root_s if it.depth == 0 else clampf(short * (0.5 if it.depth == 1 else 0.4), 34.0 if compact else 30.0, 56.0)
	else:
		s = clampf(short * 0.26, 24.0, 32.0)
	# keep siblings on one ring from overlapping: shrink to the arc that is available
	if r > 0.0:
		s = minf(s, maxf(min_node, (a1 - a0) * rr * short * 0.8 - 4.0))
	var n := {"item": it, "c": pos, "s": s, "kind": it.kind, "angle": mid}
	_nodes.append(n)
	if parent_node != null:
		var lit: bool = it.state in ["active", "root"]
		_edges.append({"pa": parent_node, "ch": n, "lit": lit, "pend": it.get("state") == "pending"})
	var kids := _shown_kids(it, cap)
	if kids.is_empty():
		return
	var total := 0.0
	for k in kids:
		total += _leaves(k, cap)
	var span := a1 - a0
	var nr: float
	if it.kind == "rune":
		nr = r + (0.55 if it.depth == 0 else 0.45)
	else:
		nr = float(it.depth) + 1.0
	if it.kind == "rune" and it.depth == 0 and kids.size() == 1:
		span = PI * 0.5
		a0 = mid - span * 0.5
	var a := a0
	for k in kids:
		var w := span * _leaves(k, cap) / total
		_place(k, a, a + w, nr, short, root_s, cap, n)
		a += w


# ------------------------------------------------------------------ input

func _hit(p: Vector2):
	for i in range(_nodes.size() - 1, -1, -1):
		var n: Dictionary = _nodes[i]
		var h: float = maxf(n.s * 0.5, 11.0)
		if absf(p.x - n.c.x) <= h and absf(p.y - n.c.y) <= h:
			return n.item
	return null


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h = _hit(ev.position)
		if not is_same(h, hover_item):
			hover_item = h
			hovered.emit(h)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != null else Control.CURSOR_ARROW
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var h = _hit(ev.position)
		if h != null:
			selected = h
			picked.emit(h)
			queue_redraw()
			accept_event()


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if _dirty:
		_layout()
	if root_item == null:
		return
	var c := size * 0.5
	for rr in _rings:
		# the engraved glyph ring passes through the ability sockets (an ellipse when the area is wide)
		var d: float = rr * 2.0 * 240.0 / 220.0
		draw_set_transform(c, 0.0, Vector2(_unit.x, _unit.y))
		draw_texture_rect(UISkin.tex("tree_ring"), Rect2(Vector2(-d, -d) * 0.5, Vector2(d, d)), false, Color(1, 1, 1, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in _edges:
		_groove(e)
	for n in _nodes:
		if n.kind == "ability":
			_ability_node(n)
		else:
			_rune_node(n)
	for n in _nodes:
		if n.kind == "ability" and (compact or n.item.depth == 0 or is_same(n.item, hover_item) or is_same(n.item, selected)):
			_ability_label(n)


func _groove(e: Dictionary) -> void:
	var a: Vector2 = e.pa.c
	var b: Vector2 = e.ch.c
	var dir := (b - a)
	var L := dir.length()
	if L < 1.0:
		return
	dir /= L
	var p0: Vector2 = a + dir * float(e.pa.s) * 0.4
	var p1: Vector2 = b - dir * float(e.ch.s) * 0.4
	var len: float = (p1 - p0).length()
	draw_set_transform(p0, dir.angle(), Vector2.ONE)
	var tex := UISkin.tex("groove_lit" if e.lit else "groove")
	var col := Color.WHITE
	if e.pend:
		col = Color(0.65, 0.85, 1.0, 0.55 + 0.35 * sin(_t * 4.0))
	draw_texture_rect(tex, Rect2(Vector2(0, -6), Vector2(len, 12)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e.lit:            # rune light travelling outward along the groove
		var u := fmod(_t * 0.7 + L * 0.013, 1.0)
		var sp: Vector2 = p0.lerp(p1, u)
		draw_texture_rect(UISkin.tex("vfx_spark"), Rect2(sp - Vector2(5, 5), Vector2(10, 10)), false, Color(S.RUNE, 0.9 * sin(u * PI)))


func _rect(n: Dictionary, grow := 0.0) -> Rect2:
	var s: float = n.s + grow
	return Rect2(((n.c as Vector2) - Vector2(s, s) * 0.5).round(), Vector2(s, s).round())


func _rune_node(n: Dictionary) -> void:
	var it: Dictionary = n.item
	var st := "active"
	match it.state:
		"root": st = "active"
		"off": st = "empty"
		"pending": st = "pending"
	if it.rejected.size() > 0 and it.ops.is_empty():
		st = "bad"
	if is_same(it, selected):
		st = "selected"
	var grow := 3.0 if is_same(it, hover_item) else 0.0
	var r := _rect(n, grow)
	if is_same(it, selected):
		draw_texture_rect(UISkin.tex("slot5_glow"), r.grow(r.size.x * 0.35), false, Color(S.GOLD, 0.8 + 0.2 * sin(_t * 4.0)))
	draw_texture_rect(UISkin.tex("node_" + st), r, false)
	var inner := r.grow(-r.size.x * 8.0 / 56.0)
	draw_texture_rect(UISkin.tex("grade_g%d" % clampi(it.grade, 1, 5)), inner, false, Color(1, 1, 1, 0.75 if it.state == "off" else 1.0))
	var ic := inner.grow(-inner.size.x * 0.06)
	var dim: bool = it.state == "off"
	draw_texture_rect(UISkin.tex("rune_%s_g%d" % [it.rune, clampi(it.grade, 1, 5)]), ic, false, Color(0.6, 0.6, 0.65) if dim else Color.WHITE)
	if compact and it.depth >= 1:
		var nested := RV.count_runes(it)
		if nested > 0:
			_badge("+%d" % nested, Vector2(r.end.x + 2, r.end.y - 14))


func _ability_node(n: Dictionary) -> void:
	var it: Dictionary = n.item
	var st: String = {"active": "active", "empty": "empty", "locked": "locked"}.get(it.state, "empty")
	if is_same(it, selected):
		st = "selected"
	var r := _rect(n, 2.0 if is_same(it, hover_item) else 0.0)
	if is_same(it, selected):
		draw_texture_rect(UISkin.tex("slot5_glow"), r.grow(r.size.x * 0.45), false, Color(S.GOLD, 0.8 + 0.2 * sin(_t * 4.0)))
	draw_texture_rect(UISkin.tex("node_" + st), r, false)
	if it.state != "locked":
		# carved rune gem in the socket: lit while the ability carries donors
		var cc := r.get_center()
		var k := r.size.x * 0.2
		var lit: bool = it.state == "active"
		var col := Color(S.RUNE, 0.75 + 0.25 * sin(_t * 3.0)) if lit else Color("#5F5B68")
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -k - 1.5), cc + Vector2(k + 1.5, 0), cc + Vector2(0, k + 1.5), cc + Vector2(-k - 1.5, 0)]), Color("#100F14"))
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -k), cc + Vector2(k, 0), cc + Vector2(0, k), cc + Vector2(-k, 0)]), col)
	else:
		var ls := r.size.x * 0.5
		draw_texture_rect(UISkin.tex("icon_lock"), Rect2(r.get_center() - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false, Color(1, 1, 1, 0.6))


func _ability_label(n: Dictionary) -> void:
	var it: Dictionary = n.item
	var f := S.font("bold")
	var fs := 11 if compact else 12
	var txt: String = game.rl.ability_name(it.rune, it.ability)
	if it.state == "locked":
		txt += "  " + T.t("grade_short", {"g": it.locked_at})
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# text sits beside the socket, on the side facing away from the centre horizontally (the spokes run radially,
	# so the horizontal neighbourhood of an ability socket is free); straight up/down sockets get it underneath
	var dir := Vector2(cos(n.angle), sin(n.angle))
	var half: float = n.s * 0.5 + 6.0
	var x: float
	var y: float = n.c.y + fs * 0.36
	if absf(dir.x) < 0.3:
		x = n.c.x + half
		y = n.c.y + fs * 0.36
	elif dir.x > 0.0:
		x = n.c.x + half
	else:
		x = n.c.x - half - w
	x = clampf(x, 2.0, size.x - w - 2.0)
	y = clampf(y, fs + 2.0, size.y - 3.0)
	var col := S.TEXT if it.state == "active" else (S.TEXT_MUTED if it.state == "locked" else S.TEXT_DIM)
	if is_same(it, selected) or is_same(it, hover_item):
		col = S.GOLD
	# a small carved plate behind the label keeps it readable where it crosses a groove or a socket
	var plate := Rect2(Vector2(x - 5.0, y - fs - 1.0), Vector2(w + 10.0, fs + 7.0)).abs()
	draw_style_box(UISkin.box("badge_dark", Vector4(5, 5, 5, 5)), Rect2(plate.position.round(), plate.size.round()))
	draw_string_outline(f, Vector2(x, y).round(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.06, 0.06, 0.08, 0.9))
	draw_string(f, Vector2(x, y).round(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _badge(text: String, at: Vector2) -> void:
	var f := S.font("bold")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
	var rr := Rect2(at - Vector2(w, 0), Vector2(w, 16))
	draw_style_box(UISkin.box("badge_rune", Vector4(5, 5, 5, 5)), rr)
	draw_string(f, rr.position + Vector2(5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


## Screen-space centre of the node showing `it` (tests and the drag hints use it).
func node_center(it) -> Vector2:
	if _dirty:
		_layout()
	for n in _nodes:
		if is_same(n.item, it):
			return get_global_transform() * (n.c as Vector2)
	return Vector2(-1, -1)


func all_items() -> Array:
	if _dirty:
		_layout()
	return _nodes.map(func(n): return n.item)


func overlaps() -> int:
	## pairs of nodes whose boxes intersect (layout quality check used by the UI tests)
	if _dirty:
		_layout()
	var k := 0
	for i in _nodes.size():
		for j in range(i + 1, _nodes.size()):
			if _rect(_nodes[i]).grow(-1).intersects(_rect(_nodes[j]).grow(-1)):
				k += 1
	return k


func out_of_bounds() -> int:
	if _dirty:
		_layout()
	var k := 0
	var box := Rect2(Vector2.ZERO, size)
	for n in _nodes:
		if not box.encloses(_rect(n)):
			k += 1
	return k
