extends Control
## A rune slot: chamfered inset well + rune icon. Drag source and drop target via callbacks.
## kind: "inv" | "base" | "graft" | "pending" | "output" | "socket" | "shop"

const S := preload("res://ui/style.gd")
const Icon := preload("res://ui/rune_icon.gd")
const UISkin := preload("res://ui/skin.gd")

var game
var kind := "inv"
var index: Variant = -1
var node = null
var selected := false
var hover := false
var hint := ""
var dim := false
var on_click: Callable
var on_drop: Callable              # func(data) -> void
var can_drop: Callable             # func(data) -> bool
var tooltip_fn: Callable           # func() -> String
var stack_existing := 0
var stack_pending := 0
var hover_t := 0.0
var drop_t := 0.0                  # 0..1 "can accept the current drag" glow
var drop_hint: Callable            # func(data) -> String shown next to the dragged rune
var pulse := 0.0


func _init(g, k: String, i: Variant = -1, sz := Vector2(58, 58)) -> void:
	game = g
	kind = k
	index = i
	custom_minimum_size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hover = true; _tip(true))
	mouse_exited.connect(func():
		hover = false
		_tip(false)
		if game and game.hud:
			game.hud.clear_drag_hint(self))


func set_node(n, sel := false) -> void:
	node = n
	selected = sel
	queue_redraw()


func _tip(on: bool) -> void:
	if game and game.hud:
		if on and tooltip_fn.is_valid():
			game.hud.show_tip(tooltip_fn.call(), self)
		elif not on:
			game.hud.hide_tip(self)


func _process(dt: float) -> void:
	var target := 1.0 if hover else 0.0
	var vp := get_viewport()
	var dragging := vp.gui_is_dragging()
	var dt_target := 0.0
	if dragging and kind != "shop" and can_drop.is_valid():
		var d = vp.gui_get_drag_data()
		if d is Dictionary and d.get("from") != self and can_drop.call(d):
			dt_target = 1.0
	if dragging:
		target = 0.0 if dt_target == 0.0 else target
	var changed := false
	if absf(hover_t - target) > 0.01:
		hover_t = move_toward(hover_t, target, dt * 9.0)
		changed = true
	if absf(drop_t - dt_target) > 0.01:
		drop_t = move_toward(drop_t, dt_target, dt * 8.0)
		changed = true
	if drop_t > 0.01:
		pulse += dt
		changed = true
	if changed:
		queue_redraw()


## Socket art is the Penpot export for the current state (slot_normal / hover / selected / drop / output).
func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var r := Rect2(Vector2.ZERO, size.round())
	var st := "normal"
	if hover_t > 0.5:
		st = "hover"
	if selected:
		st = "selected"
	if kind == "output" and node != null:
		st = "output"
	if drop_t > 0.05:
		st = "drop"
	if drop_t > 0.01:          # extra pulsing rune light while a drag can land here
		var a := drop_t * (0.18 + 0.12 * sin(pulse * 6.0)) + (0.2 if hover else 0.0) * drop_t
		var glow := UISkin.tex("vfx_glow")
		draw_texture_rect(glow, r.grow(10.0), false, Color(S.RUNE, a))
	draw_style_box(_box(st), r)
	if node != null:
		var grow := -6.0 + 2.0 * hover_t
		Icon.draw(self, r.grow(grow), node, game, dim)
	elif hint != "":
		var f := S.font("medium")
		var fs := 22 if hint.length() <= 1 else 12
		var ts := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(f, Vector2(roundf((size.x - ts.x) * 0.5), roundf(size.y * 0.5 + fs * 0.35)), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(S.TEXT_MUTED, 0.8 + 0.2 * drop_t))
	if stack_pending > 0:
		_badge("+%d" % stack_pending, Vector2(size.x - 1, size.y - 16), Color("#2F6FA8"))
	if stack_existing > 0:
		_badge("%d" % stack_existing, Vector2(size.x - 1, 1), Color("#4E4E58"))


static var _boxes: Dictionary = {}


func _box(st: String) -> StyleBox:
	if not _boxes.has(st):
		_boxes[st] = UISkin.box("slot_" + st)
	return _boxes[st]


func _badge(text: String, at: Vector2, fill: Color) -> void:
	var f := S.font("bold")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
	var rr := Rect2(at - Vector2(w, 0), Vector2(w, 15))
	draw_rect(rr, Color("#120E0B"))
	draw_rect(rr.grow(-1), fill)
	draw_string(f, rr.position + Vector2(4, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if on_click.is_valid():
			on_click.call(ev.double_click)
			accept_event()


func _get_drag_data(_p: Vector2) -> Variant:
	if node == null or kind == "shop":
		return null
	var prev := Control.new()
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.set_script(load("res://ui/drag_preview.gd"))
	holder.game = game
	holder.node = node
	holder.size = Vector2(60, 60)
	holder.position = Vector2(-30, -30)
	prev.add_child(holder)
	set_drag_preview(prev)
	game.hud.on_drag_start()
	return {"src": kind, "idx": index, "node": node, "from": self}


func _can_drop_data(_p: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("src") and can_drop.is_valid() and can_drop.call(data)
	if game and game.hud and data is Dictionary and data.get("from") != self:
		var t := ""
		if drop_hint.is_valid():
			t = drop_hint.call(data)
		game.hud.set_drag_hint(self, t, ok)
	return ok


func _drop_data(_p: Vector2, data: Variant) -> void:
	if on_drop.is_valid():
		on_drop.call(data)
