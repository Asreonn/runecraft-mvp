extends RefCounted
const UISkin := preload("res://ui/skin.gd")
## Draws a rune the way loot is shown: the slot's well is filled with its grade light (rcui / grade_g1…g5 — grey,
## green, blue, purple, gold, brightest at the bottom), the Penpot rune cube on top, and donor-coloured graft marks at
## the top-right. No grade pips and nothing round: the grade reads from the light colour.

static func draw(ci: CanvasItem, well: Rect2, node, game, dim := false, lift := 0.0) -> void:
	if node == null:
		return
	var g := clampi(int(node.grade), 1, 5)
	ci.draw_texture_rect(UISkin.tex("grade_g%d" % g), well, false, Color(0.7, 0.7, 0.72) if dim else Color.WHITE)
	var s := minf(well.size.x, well.size.y) * (0.84 + 0.04 * lift)
	var r := Rect2(well.get_center() - Vector2(s, s) * 0.5 - Vector2(0, 2.0 * lift), Vector2(s, s))
	ci.draw_texture_rect(UISkin.tex("rune_%s_g%d" % [node.rune, g]), r, false, Color(0.55, 0.55, 0.6) if dim else Color.WHITE)
	# graft marks: small diamonds in the donors' colours (first 3 direct donors) + the recipe size when it is bigger
	var donors := []
	for ab in node.grafts:
		for d in node.grafts[ab]:
			donors.append(d)
	if donors.is_empty():
		return
	for i in mini(donors.size(), 3):
		var dc: Dictionary = game.rune_colors(donors[i].rune)
		var p := Vector2(well.end.x - 6.0 - i * 8.0, well.position.y + 6.0)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4.5), p + Vector2(4.5, 0), p + Vector2(0, 4.5), p + Vector2(-4.5, 0)]), Color("#100F14"))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]), Color(dc.core))
	var total: int = game.rl.node_size(node) - 1
	if total > 3:
		var f := preload("res://ui/style.gd").font("bold")
		var t := "+%d" % total
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var at := Vector2(well.end.x - w - 3.0, well.position.y + 21.0)
		ci.draw_string_outline(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color("#100F14"))
		ci.draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#D8FBFF"))
