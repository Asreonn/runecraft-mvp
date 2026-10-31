extends Control
## Floating rune while dragging: pops in, tilts with the mouse velocity, casts a soft shadow and shows
## what will happen on release ("Socket", "Combine → G3", ...) in a small stone chip.

const S := preload("res://ui/style.gd")
const Icon := preload("res://ui/rune_icon.gd")
const UISkin := preload("res://ui/skin.gd")

var game
var node
var t := 0.0
var tilt := 0.0
var last := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	last = get_global_mouse_position()


func _process(dt: float) -> void:
	t += dt
	var m := get_global_mouse_position()
	var vx := (m.x - last.x) / maxf(dt, 0.001)
	last = m
	tilt = lerpf(tilt, clampf(vx * 0.0006, -0.35, 0.35), clampf(dt * 14.0, 0.0, 1.0))
	rotation = tilt
	var pop := 1.0 + 0.18 * exp(-t * 9.0) * sin(t * 22.0) if t > 0.0 else 0.6
	scale = Vector2.ONE * minf(1.0, 0.6 + t * 5.0) * pop
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_circle(r.get_center() + Vector2(4, 10), size.x * 0.34, Color(0, 0, 0, 0.28))
	Icon.draw(self, r, node, game)
	var hint: String = game.hud.drag_hint if game and game.hud else ""
	if hint == "":
		return
	var f := S.font("bold")
	var fs := 13
	var tw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var chip := Rect2(Vector2(roundf(size.x * 0.5 - tw * 0.5 - 9), size.y + 4), Vector2(roundf(tw + 18), 22))
	var ok: bool = game.hud.drag_hint_ok
	draw_style_box(UISkin.box("chip_rune" if ok else "chip_bad"), chip)
	draw_string(f, chip.position + Vector2(9, 16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, S.RUNE.lightened(0.4) if ok else S.BAD)
