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
	# graft dots
	var donors := []
	for ab in node.grafts:
		for d in node.grafts[ab]:
			donors.append(d)
	for i in mini(donors.size(), 5):
		var dc: Dictionary = game.rune_colors(donors[i].rune)
		var p := Vector2(rect.end.x - 7.0 - i * 8.0, rect.position.y + 7.0)
		ci.draw_circle(p, 3.6, Color("#120E0B"))
		ci.draw_circle(p, 2.6, Color(dc.core))
	if donors.size() > 5:
		ci.draw_string(ThemeDB.fallback_font, Vector2(rect.end.x - 52, rect.position.y + 11), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


