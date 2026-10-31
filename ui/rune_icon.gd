extends RefCounted
const UISkin := preload("res://ui/skin.gd")
## Draws Penpot rune cube art (including grade pips) and donor-coloured graft dots at the top-right.

static func draw(ci: CanvasItem, rect: Rect2, node, game, dim := false) -> void:
	# rune cube art is a Penpot export (rcui / rune_<id>_g<grade>); graft dots are drawn on top
	if node == null:
		return
	var tex := UISkin.tex("rune_%s_g%d" % [node.rune, clampi(int(node.grade), 1, 5)])
	var s := minf(rect.size.x, rect.size.y)
	var r := Rect2(rect.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
	ci.draw_texture_rect(tex, r, false, Color(0.55, 0.55, 0.6) if dim else Color.WHITE)
	# graft badge: donor colour dots (first 3 direct donors) + the recipe size when it has more runes
	var donors := []
	for ab in node.grafts:
		for d in node.grafts[ab]:
			donors.append(d)
	if donors.is_empty():
		return
	for i in mini(donors.size(), 3):
		var dc: Dictionary = game.rune_colors(donors[i].rune)
		var p := Vector2(rect.end.x - 6.0 - i * 7.0, rect.position.y + 6.0)
		ci.draw_circle(p, 3.4, Color("#120E0B"))
		ci.draw_circle(p, 2.4, Color(dc.core))
	var total: int = game.rl.node_size(node) - 1
	if total > 3:
		var f := ThemeDB.fallback_font
		var t := "+%d" % total
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var at := Vector2(rect.end.x - w - 2.0, rect.position.y + 20.0)
		ci.draw_string_outline(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color("#120E0B"))
		ci.draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#D8FBFF"))
