extends Control
## Floating rune inspector: a carved stone panel in the middle of the screen with the rune's FULL radial tree
## (every nested graft) and, on the right, a stone plaque with what the picked node does. The compact tree in the
## Craft tab shows abilities + direct donors; this one shows the whole recipe — same model, two depths.
## Open: right-click any rune, "Inspect" on the tower card, "Details" in the Craft tab.
## Close: ✕, Esc, or a click outside the panel. While open, a veil blocks the world (no accidental building or
## selecting) and hotkeys are swallowed except pause / speed; the game is NOT paused (Space pauses as usual).
## The shown rune is re-validated on every game change: if its tower now holds another rune the view follows it;
## if the rune left the player's hands (sold, consumed, load) the inspector closes.

const S := preload("res://ui/style.gd")
const UISkin := preload("res://ui/skin.gd")
const RV := preload("res://ui/rune_view.gd")
const RuneTree := preload("res://ui/rune_tree.gd")
const T := preload("res://ui/i18n.gd")

var game
var hud
var panel: Panel
var tree
var title: Label
var subtitle: Label
var icon_rect: Control
var detail: RichTextLabel
var close_btn: Button
var node = null
var source := {}
var item = null
var picked_item = null
var _sig := ""                    # content signature of the shown rune (in-place edits rebuild the view)


func _init(g, h) -> void:
	game = g
	hud = h
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP           # the veil: clicks outside the panel close it
	visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.04, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", UISkin.box("panel_float", Vector4(34, 34, 34, 34)))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	# header: rune on its grade light, name, one line of identity
	icon_rect = Control.new()
	icon_rect.custom_minimum_size = Vector2(76, 76)
	icon_rect.draw.connect(_draw_icon)
	panel.add_child(icon_rect)
	title = S.label("", 28, S.TRIM_LIGHT, "head")
	panel.add_child(title)
	subtitle = S.label("", 14, S.TEXT_MUTED, "medium")
	subtitle.clip_text = true
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(subtitle)
	close_btn = Button.new()
	UISkin.button(close_btn, "coin")
	close_btn.icon = UISkin.tex("icon_close")
	close_btn.expand_icon = true
	close_btn.add_theme_constant_override("icon_max_width", 22)
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.tooltip_text = T.t("close_hint")
	close_btn.pressed.connect(hide_inspector)
	panel.add_child(close_btn)
	tree = RuneTree.new(game)
	tree.compact = false
	tree.picked.connect(func(it): picked_item = it; _show_detail(it))
	tree.hovered.connect(func(it): _show_detail(it if it != null else picked_item))
	panel.add_child(tree)
	var plaque := PanelContainer.new()
	plaque.name = "Plaque"
	plaque.add_theme_stylebox_override("panel", UISkin.box("plaque", Vector4(22, 22, 22, 22), Vector4(20, 18, 20, 18)))
	panel.add_child(plaque)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.scroll_active = true
	detail.add_theme_font_override("normal_font", S.font("body"))
	detail.add_theme_font_override("bold_font", S.font("bold"))
	detail.add_theme_font_size_override("normal_font_size", 15)
	detail.add_theme_font_size_override("bold_font_size", 16)
	detail.add_theme_color_override("default_color", S.TEXT_DIM)
	detail.add_theme_constant_override("line_separation", 3)
	plaque.add_child(detail)
	resized.connect(_layout)


func _layout() -> void:
	var vp := size
	var w := minf(1240.0, vp.x - 64.0)
	var h := minf(vp.y - 64.0, maxf(780.0, vp.y * 0.74))
	panel.size = Vector2(w, h).round()
	panel.position = ((vp - panel.size) * 0.5).round()
	icon_rect.position = Vector2(36, 30)
	icon_rect.size = Vector2(76, 76)
	title.position = Vector2(128, 34)
	title.size = Vector2(w - 220, 40)
	subtitle.position = Vector2(130, 76)
	subtitle.size = Vector2(w - 220, 22)
	close_btn.position = Vector2(w - 82, 32)
	close_btn.size = Vector2(44, 44)
	var pw := clampf(w * 0.34, 300.0, 380.0)
	tree.position = Vector2(30, 120)
	tree.size = Vector2(w - pw - 64, h - 150)
	var plaque: Control = panel.get_node("Plaque")
	plaque.position = Vector2(w - pw - 30, 124)
	plaque.size = Vector2(pw, h - 156)


func _draw_icon() -> void:
	if node == null:
		return
	var r := Rect2(Vector2.ZERO, icon_rect.size)
	icon_rect.draw_style_box(UISkin.box("slot5_selected", Vector4(12, 12, 12, 12)), r)
	preload("res://ui/rune_icon.gd").draw(icon_rect, r.grow(-r.size.x * 8.0 / 56.0), node, game)


## source: {"kind": "tower", "tower": t} | {"kind": "item"} — what the shown rune belongs to (for re-validation).
func show_rune(n, src := {}) -> void:
	if n == null:
		return
	node = n
	source = src
	_sig = var_to_str(n)
	item = RV.build(game, n)
	picked_item = item
	tree.set_item(item)
	title.text = "%s  G%d" % [game.rl.rune_name(n.rune), int(n.grade)]
	title.add_theme_color_override("font_color", RV.grade_color(int(n.grade)).lerp(S.TRIM_LIGHT, 0.45))
	subtitle.text = game.rl.rune_identity(n.rune)
	_show_detail(item)
	icon_rect.queue_redraw()
	if not visible:
		visible = true
		_layout()
		modulate.a = 0.0
		panel.scale = Vector2(0.96, 0.96)
		panel.pivot_offset = panel.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.14)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_inspector() -> void:
	visible = false
	node = null
	item = null
	picked_item = null
	source = {}
	tree.set_item(null)


## Called after every game change (HUD refresh).
func revalidate() -> void:
	if not visible or node == null:
		return
	if source.get("kind") == "tower":
		var t = source.tower
		if not is_instance_valid(t) or not game.towers.has(t) or t.rune == null:
			hide_inspector()
			return
		if not is_same(t.rune, node) or var_to_str(t.rune) != _sig:
			show_rune(t.rune, source)          # the tower got another rune (or it changed): follow it
		return
	for x in game.all_items():
		if is_same(x, node):
			if var_to_str(node) != _sig:
				show_rune(node, source)        # edited in place (e.g. ungraft on the table)
			return
	hide_inspector()                           # consumed by a craft / combine, or replaced by a load


func _show_detail(it) -> void:
	detail.text = RV.describe(game, it, true) if it != null else ""
	detail.scroll_to_line(0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if not panel.get_global_rect().has_point(ev.global_position):
			hide_inspector()
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE:
			hide_inspector()
		elif ev.keycode in [KEY_SPACE, KEY_1, KEY_2, KEY_3]:
			return                             # pause / speed stay available
		get_viewport().set_input_as_handled()
