extends Control
## A rune slot: square well + rune icon on its grade (rarity) light. Drag source and drop target via callbacks.
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
var bad_t := 0.0                   # 0..1 "the hovered drag cannot land here" (incompatible / locked)
var locked := false               # an ability that is not open yet (shown, not droppable)


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
	var bad_target := 0.0
	if dragging and hover and dt_target == 0.0 and kind != "shop":
		var d2 = vp.gui_get_drag_data()
		if d2 is Dictionary and d2.get("from") != self:
			bad_target = 1.0
	if dragging:
		target = 0.0 if dt_target == 0.0 else target
	var changed := false
	if absf(bad_t - bad_target) > 0.01:
		bad_t = move_toward(bad_t, bad_target, dt * 10.0)
		changed = true
	if absf(hover_t - target) > 0.01:
		hover_t = move_toward(hover_t, target, dt * 9.0)
		changed = true
	if absf(drop_t - dt_target) > 0.01:
		drop_t = move_toward(drop_t, dt_target, dt * 8.0)
		changed = true
	if drop_t > 0.01 or bad_t > 0.01:
		pulse += dt
		changed = true
	if changed:
		queue_redraw()


## Socket art is the Penpot export for the current state (slot5_normal / hover / selected / drop / invalid / output /
## pending / locked): square wells with one rim colour per state — nothing round behind the rune.
func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var r := Rect2(Vector2.ZERO, size.round())
	var st := "normal"
	if hover_t > 0.5:
		st = "hover"
	if selected:
		st = "selected"
	if kind in ["pending"]:
		st = "pending"
	if locked:
		st = "locked"
	if kind == "output" and node != null:
		st = "output"
	if drop_t > 0.05:
		st = "drop"
	if bad_t > 0.05:
		st = "invalid"
	if drop_t > 0.01 or bad_t > 0.01:          # square rune light around a slot that can (or cannot) take the drag
		var a := maxf(drop_t, bad_t) * (0.55 + 0.25 * sin(pulse * 6.0))
		draw_texture_rect(UISkin.tex("slot5_glow_bad" if bad_t > drop_t else "slot5_glow"), r.grow(r.size.x * 0.25), false, Color(1, 1, 1, a))
	draw_style_box(_box(st), r)
	var well := r.grow(-r.size.x * 5.0 / 64.0)
	if node != null:
		Icon.draw(self, well, node, game, dim, hover_t)
	elif locked:
		var ls := minf(22.0, size.x * 0.4)
		draw_texture_rect(UISkin.tex("icon_lock"), Rect2(r.get_center() - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false, Color(1, 1, 1, 0.55))
	elif hint != "":
		var f := S.font("medium")
		var fs := 22 if hint.length() <= 1 else 12
		var ts := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(f, Vector2(roundf((size.x - ts.x) * 0.5), roundf(size.y * 0.5 + fs * 0.35)), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(S.TEXT_MUTED, 0.8 + 0.2 * drop_t))
	if stack_pending > 0:
		_badge("+%d" % stack_pending, Vector2(size.x - 1, size.y - 16), "badge_rune")
	if stack_existing > 0:
		_badge("%d" % stack_existing, Vector2(size.x - 1, 1), "badge_dark")


static var _boxes: Dictionary = {}


func _box(st: String) -> StyleBox:
	if not _boxes.has(st):
		_boxes[st] = UISkin.box("slot5_" + st, Vector4(12, 12, 12, 12))
	return _boxes[st]


func _badge(text: String, at: Vector2, tex: String) -> void:
	var f := S.font("bold")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
	var rr := Rect2(at - Vector2(w, 0), Vector2(w, 16))
	draw_style_box(UISkin.box(tex, Vector4(5, 5, 5, 5)), rr)
	draw_string(f, rr.position + Vector2(5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if on_click.is_valid():
			on_click.call(ev.double_click)
			accept_event()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and node != null:
		game.hud.inspect(node, {"kind": "tower", "tower": game.selected_tower} if kind == "socket" else {})   # right-click: full tree
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
