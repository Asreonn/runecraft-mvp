extends Control
## Naked resource bar from Penpot textures: sunk stone well + coloured fill + centred value text.

const UISkin := preload("res://ui/skin.gd")
const S := preload("res://ui/style.gd")

var value := 1.0
var text := ""
var shine := 0.0
var _well: StyleBox
var _fill: StyleBox


func _init(k := "hp", sz := Vector2(220, 22)) -> void:
	custom_minimum_size = sz
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well = UISkin.box("well")
	_fill = UISkin.box("bar_" + k)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_well, r)
	var fw := roundf((size.x - 8) * clampf(value, 0.0, 1.0))
	if fw >= 6.0:
		draw_style_box(_fill, Rect2(Vector2(4, 4), Vector2(fw, size.y - 8)))
		if shine > 0.0:
			var x := roundf(fmod(shine, 1.0) * fw)
			draw_rect(Rect2(Vector2(4 + maxf(0.0, x - 14.0), 4), Vector2(minf(14.0, x), size.y - 8)), Color(1, 1, 1, 0.12))
	if text != "":
		var f := S.font("bold")
		var fs := 13
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(roundf((size.x - ts.x) * 0.5), roundf(size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5))
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.05, 0.06, 0.95))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
