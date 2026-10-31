extends StyleBox
## 9-slice StyleBox for the Penpot-exported @2x textures. Margins are given in design pixels (1x);
## the source texture is sampled with doubled margins, so borders keep their designed thickness while
## the art stays HD (the canvas stretch then scales it up crisply on bigger screens).

var texture: Texture2D
var margin := Vector4(16, 16, 16, 16)       # left, top, right, bottom (1x)
var tex_scale := 2.0
var modulate := Color.WHITE
var expand := Vector4.ZERO                  # draw outside the rect (glows, drop shadows), 1x


func setup(t: Texture2D, m: Vector4, content := Vector4(-1, -1, -1, -1)) -> StyleBox:
	texture = t
	margin = m
	var c := m if content.x < 0 else content
	content_margin_left = c.x
	content_margin_top = c.y
	content_margin_right = c.z
	content_margin_bottom = c.w
	return self


func _draw(rid: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var r := Rect2(rect.position - Vector2(expand.x, expand.y), rect.size + Vector2(expand.x + expand.z, expand.y + expand.w))
	var ts := texture.get_size()
	var s := tex_scale
	var l := minf(margin.x, r.size.x * 0.5)
	var t := minf(margin.y, r.size.y * 0.5)
	var rr := minf(margin.z, r.size.x * 0.5)
	var b := minf(margin.w, r.size.y * 0.5)
	var xs := [0.0, l, r.size.x - rr, r.size.x]
	var ys := [0.0, t, r.size.y - b, r.size.y]
	var us := [0.0, l * s, ts.x - rr * s, ts.x]
	var vs := [0.0, t * s, ts.y - b * s, ts.y]
	var rid_t := texture.get_rid()
	for j in 3:
		for i in 3:
			var dst := Rect2(r.position + Vector2(xs[i], ys[j]), Vector2(xs[i + 1] - xs[i], ys[j + 1] - ys[j]))
			var src := Rect2(Vector2(us[i], vs[j]), Vector2(us[i + 1] - us[i], vs[j + 1] - vs[j]))
			if dst.size.x > 0.01 and dst.size.y > 0.01 and src.size.x > 0.01 and src.size.y > 0.01:
				RenderingServer.canvas_item_add_texture_rect_region(rid, dst, rid_t, src, modulate)
