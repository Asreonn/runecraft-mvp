extends CanvasLayer
## RuneCraft HUD v4 — every texture is a Penpot export (page "HUD v3 · Stone", boards "rcui / *").
##  top-left   : naked bars (castle HP, mana, mana stone) — no panel behind them
##  top-centre : big wave counter "W3" + enemies-left chip + naked pause / 1× 2× 3× stones;
##               between waves a small row underneath: "Remaining 12s" + "Start now"
##  right      : tabbed stone panel — CRAFT (rune table + inventory) · SHOP (build tower + runes) ·
##               MENU (pauses the game: resume, settings, save, load, quit)
##  bottom-left: selected tower card
## All UI motion runs in real time (game speed only scales the simulation).

const S := preload("res://ui/style.gd")
const UISkin := preload("res://ui/skin.gd")
const Slot := preload("res://ui/slot.gd")
const Bar := preload("res://ui/bar.gd")
const CraftTable := preload("res://ui/craft_table.gd")
const RuneInspector := preload("res://ui/rune_inspector.gd")
const RuneTree := preload("res://ui/rune_tree.gd")
const RV := preload("res://ui/rune_view.gd")
const T := preload("res://ui/i18n.gd")

const PANEL_X := 1464
const PANEL_W := 440
const PAD := 26

var game
var root: Control
var world_input: Control
var fx_layer: Control
# top-left
var bars := {}
var shown_mana := 0.0
var shown_stones := 0.0
# top-centre
var wave_lbl: Label
var left_lbl: Label
var ctrl_btns: Array = []
var next_row: Control
var next_lbl: Label
var start_btn: Button
var banner: Label
var _last_wave_state := ""
# right panel
var tabs := {}
var pages := {}
var current_tab := "craft"
var table
var struct_tree
var struct_cap: RichTextLabel
var struct_name: Label
var struct_act: Button
var details_btn: Button
var struct_src := "base"                # which rune the structure view shows: base | output | inv
var struct_pick = null                  # picked tree item
var struct_node = null
var _struct_sig := ""
var inv_grid: GridContainer
var inv_title: Label
var inv_count: Label
var inv_bar
var inv_slots: Array = []
var sel_inv := -1
var build_btn: Button
var shop_count: Label
var shop_prices := {}                   # rune id -> Label (live price)
var save_btn: Button
var inspect_btn: Button
var inspector
var settings_box: VBoxContainer
var veil: ColorRect
# tower card
var tower_card: Control
var sock_slot
var tower_name: Label
var tower_info: Label
var tower_dps: Label
var tower_mana: Label
var sell_btn: Button
var take_rune_btn: Button
# misc
var toast: Label
var tip: PanelContainer
var tip_text: RichTextLabel
var tip_owner = null
var ui_sparks: Array = []
var drag_hint := ""
var drag_hint_ok := true
var drag_hint_owner = null
var _dirty := false
var _table_sig := ""


func setup(g) -> void:
	game = g
	layer = 10
	root = Control.new()
	var th := Theme.new()
	th.default_font = S.font("medium")
	th.default_font_size = 15
	root.theme = th
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_world_input()
	_veil()
	_top_left()
	_top_center()
	_right_panel()
	_tower_card()
	_toast()
	_banner()
	inspector = RuneInspector.new(game, self)
	root.add_child(inspector)
	_tooltip()
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.draw.connect(_draw_fx)
	root.add_child(fx_layer)
	shown_mana = game.mana
	shown_stones = game.stones
	game.changed.connect(func(): _dirty = true)     # coalesced: at most one refresh per frame
	select_tab("craft", false)
	refresh()
	_intro()


# ------------------------------------------------------------------ helpers

func _tex_rect(name: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UISkin.tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = sz
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _icon(name: String, px := 24) -> TextureRect:
	var t := _tex_rect("icon_" + name, Vector2(px, px))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _btn(text: String, kind := "btn", sz := Vector2(0, 44), icon := "", cb := Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = sz
	UISkin.button(b, kind)
	b.add_theme_font_override("font", S.font("bold"))
	b.add_theme_font_size_override("font_size", 15)
	if icon != "":
		b.icon = UISkin.tex("icon_" + icon)
		b.expand_icon = true                     # scale the 2x icon to the button, never inflate its height
		b.add_theme_constant_override("icon_max_width", 22)
		b.add_theme_constant_override("h_separation", 8)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cb.is_valid():
		b.pressed.connect(cb)
	b.mouse_entered.connect(func(): _pop(b, 1.04))
	return b


func _chip(edge := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UISkin.box("chip" + edge, Vector4(-1, -1, -1, -1), Vector4(10, 4, 12, 4)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _title(t: String, size := 16, col := Color("#B9B5BD")) -> Label:
	var l := S.label(t, size, col, "head")
	return l


func _pop(c: Control, sc := 1.15) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	c.scale = Vector2(sc, sc)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ builders

func _world_input() -> void:
	world_input = Control.new()
	world_input.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_input.mouse_filter = Control.MOUSE_FILTER_STOP
	world_input.set_script(load("res://ui/world_input.gd"))
	world_input.game = game
	root.add_child(world_input)


func _veil() -> void:
	veil = ColorRect.new()
	veil.color = Color(0.03, 0.03, 0.05, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP      # menu open: the world is not clickable
	veil.visible = false
	root.add_child(veil)


func _top_left() -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(20, 18)
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	for k in [["hp", "castle"], ["mana", "mana"], ["stone", "stone"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_icon(k[1], 28))
		var b := Bar.new(k[0], Vector2(220, 22))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		bars[k[0]] = b
		v.add_child(h)


func _top_center() -> void:
	var h := HBoxContainer.new()
	h.name = "WaveRow"
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.anchor_left = 0.5; h.anchor_right = 0.5
	h.grow_horizontal = Control.GROW_DIRECTION_BOTH
	h.offset_top = 10
	root.add_child(h)
	wave_lbl = S.label("W1", 44, S.TRIM_LIGHT, "head")
	wave_lbl.add_theme_constant_override("shadow_offset_y", 3)
	wave_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	wave_lbl.add_theme_constant_override("outline_size", 6)
	wave_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 0.85))
	h.add_child(wave_lbl)
	var chip := _chip()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 6)
	ch.add_child(_icon("enemy", 22))
	left_lbl = S.label("0", 18, S.TEXT, "bold")
	left_lbl.custom_minimum_size = Vector2(30, 0)
	ch.add_child(left_lbl)
	chip.add_child(ch)
	h.add_child(chip)
	var sep := ColorRect.new()
	sep.color = Color(0.06, 0.06, 0.08, 0.5)
	sep.custom_minimum_size = Vector2(2, 30)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sep)
	var pause := _btn("", "coin", Vector2(42, 42), "pause", func(): game.toggle_pause())
	pause.add_theme_constant_override("icon_max_width", 20)
	ctrl_btns.append(pause)
	h.add_child(pause)
	for x in [1.0, 2.0, 3.0]:
		var b := _btn("%d×" % int(x), "coin", Vector2(42, 42), "", func(): game.set_speed(x))
		b.add_theme_font_size_override("font_size", 15)
		ctrl_btns.append(b)
		h.add_child(b)
	# between waves: remaining time + start now
	next_row = HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 10)
	next_row.anchor_left = 0.5; next_row.anchor_right = 0.5
	next_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	next_row.offset_top = 68
	root.add_child(next_row)
	var rc := _chip()
	rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 6)
	rh.add_child(_icon("hourglass", 20))
	next_lbl = S.label(T.t("remaining", {"s": 20}), 14, S.TEXT, "bold")
	rh.add_child(next_lbl)
	rc.add_child(rh)
	next_row.add_child(rc)
	start_btn = _btn(T.t("start_now"), "btn_rune", Vector2(124, 38), "", func(): game.start_wave())
	start_btn.add_theme_font_size_override("font_size", 14)
	next_row.add_child(start_btn)


func _right_panel() -> void:
	var holder := Control.new()
	holder.name = "RightPanel"
	# anchored to the right edge so wider / narrower screens keep the panel flush (1920×1080 is the reference)
	holder.anchor_left = 1.0; holder.anchor_right = 1.0; holder.anchor_top = 0.0; holder.anchor_bottom = 1.0
	holder.offset_left = -PANEL_W - 16; holder.offset_right = -16; holder.offset_top = 16; holder.offset_bottom = -16
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("slide", Vector2(48, 0))
	root.add_child(holder)
	var panel := Panel.new()                  # Penpot panel art as a 9-slice, so the panel follows the screen height
	panel.add_theme_stylebox_override("panel", UISkin.box("panel_right", Vector4(40, 40, 40, 40)))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 40
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(panel)
	var group := ButtonGroup.new()
	var i := 0
	for k in [["craft", T.t("tab_craft"), "craft"], ["shop", T.t("tab_shop"), "shop"], ["menu", T.t("tab_menu"), "menu"]]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = k[1]
		b.icon = UISkin.tex("icon_" + k[2])
		b.expand_icon = true
		b.custom_minimum_size = Vector2(140, 44)
		b.add_theme_constant_override("icon_max_width", 22)
		b.add_theme_constant_override("h_separation", 8)
		b.add_theme_stylebox_override("normal", UISkin.box("tab_idle", Vector4(-1, -1, -1, -1), Vector4(14, 8, 14, 4)))
		b.add_theme_stylebox_override("hover", UISkin.box("tab_hover", Vector4(-1, -1, -1, -1), Vector4(14, 6, 14, 4)))
		b.add_theme_stylebox_override("pressed", UISkin.box("tab_active", Vector4(-1, -1, -1, -1), Vector4(14, 2, 14, 6)))
		b.add_theme_stylebox_override("hover_pressed", UISkin.box("tab_active", Vector4(-1, -1, -1, -1), Vector4(14, 2, 14, 6)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_override("font", S.font("head"))
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", S.TRIM_LIGHT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color("#24232A"))
		b.add_theme_color_override("font_hover_pressed_color", Color("#24232A"))
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		b.add_theme_constant_override("outline_size", 3)
		b.position = Vector2(i * 148, 0)
		b.size = Vector2(140, 44)
		var key: String = k[0]
		b.pressed.connect(func(): select_tab(key))
		holder.add_child(b)
		tabs[key] = b
		i += 1
	var content := Rect2(PAD, 40 + PAD, PANEL_W - 2 * PAD, 1008 - 2 * PAD)
	pages["craft"] = _craft_page(content)
	pages["shop"] = _shop_page(content)
	pages["menu"] = _menu_page(content)
	for k in pages:
		holder.add_child(pages[k])


func _page(content: Rect2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = content.position.x
	v.offset_top = content.position.y
	v.offset_right = -PAD
	v.offset_bottom = -PAD
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _craft_page(content: Rect2) -> Control:
	# Crafting area (top) → rune structure (middle, takes the free height) → inventory (bottom, always fully visible)
	var v := _page(content)
	v.add_theme_constant_override("separation", 6)
	v.add_child(_title(T.t("rune_table")))
	table = CraftTable.new(game, self)
	v.add_child(table)
	var sh := HBoxContainer.new()
	var st := _title(T.t("rune_structure"), 15)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(st)
	struct_name = S.label("", 13, S.TEXT_DIM, "bold")
	struct_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(struct_name)
	details_btn = _btn(T.t("details"), "btn", Vector2(0, 30), "expand", func(): _open_struct_details())
	details_btn.add_theme_font_size_override("font_size", 12)
	details_btn.add_theme_constant_override("icon_max_width", 16)
	sh.add_child(details_btn)
	v.add_child(sh)
	struct_tree = RuneTree.new(game)
	struct_tree.compact = true
	struct_tree.custom_minimum_size = Vector2(0, 150)
	struct_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	struct_tree.picked.connect(func(it): struct_pick = it; _struct_caption(it))
	struct_tree.hovered.connect(func(it): _struct_caption(it if it != null else struct_pick))
	v.add_child(struct_tree)
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", UISkin.box("plaque", Vector4(22, 22, 22, 22), Vector4(16, 12, 16, 12)))
	cap.custom_minimum_size = Vector2(0, 132)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	struct_cap = RichTextLabel.new()
	struct_cap.bbcode_enabled = true
	struct_cap.scroll_active = true
	struct_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	struct_cap.add_theme_font_override("normal_font", S.font("body"))
	struct_cap.add_theme_font_override("bold_font", S.font("bold"))
	struct_cap.add_theme_font_size_override("normal_font_size", 13)
	struct_cap.add_theme_font_size_override("bold_font_size", 14)
	struct_cap.add_theme_color_override("default_color", S.TEXT_DIM)
	ch.add_child(struct_cap)
	struct_act = _btn("", "btn", Vector2(0, 34), "", func(): _struct_action())
	struct_act.add_theme_font_size_override("font_size", 12)
	struct_act.size_flags_vertical = Control.SIZE_SHRINK_END
	struct_act.visible = false
	ch.add_child(struct_act)
	cap.add_child(ch)
	v.add_child(cap)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 10)
	inv_title = _title(T.t("inventory"), 15)
	ih.add_child(inv_title)
	inv_count = S.label("", 13, S.TEXT_DIM, "bold")
	inv_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ih.add_child(inv_count)
	inv_bar = Bar.new("wave", Vector2(120, 14))
	inv_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ih.add_child(inv_bar)
	v.add_child(ih)
	inv_grid = GridContainer.new()
	inv_grid.columns = 6
	inv_grid.add_theme_constant_override("h_separation", 8)
	inv_grid.add_theme_constant_override("v_separation", 8)
	for i in game.INV_SIZE:
		var sl = Slot.new(game, "inv", i, Vector2(56, 56))
		sl.can_drop = func(d): return d.src in ["inv", "output", "socket", "pending", "base"]
		sl.on_drop = func(d): _drop_on_inv(i, d)
		sl.on_click = func(dbl): _click_inv(i, dbl)
		sl.drop_hint = func(d): return _inv_hint(i, d)
		sl.tooltip_fn = func(): return tip_for(game.inventory[i]) + ("\n[color=#8C877D]%s[/color]" % T.t("tip_inv_actions") if game.inventory[i] != null else "")
		inv_slots.append(sl)
		inv_grid.add_child(sl)
	v.add_child(inv_grid)
	return v


func _shop_page(content: Rect2) -> Control:
	var v := _page(content)
	v.add_child(_title(T.t("build")))
	build_btn = _btn(T.t("build_tower"), "btn_rune", Vector2(0, 56), "tower", func(): game.toggle_build())
	build_btn.toggle_mode = true
	build_btn.add_theme_font_size_override("font_size", 17)
	v.add_child(build_btn)
	var hint := S.label(T.t("build_hint"), 13, S.TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 10); v.add_child(gap)
	v.add_child(_title(T.t("runes")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	for rid in game.spec.runes:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var sl = Slot.new(game, "shop", -1, Vector2(84, 76))
		sl.set_node({"rune": rid, "grade": 1, "grafts": {}})
		sl.on_click = func(_dbl):
			if game.buy_rune(rid):
				if Input.is_key_pressed(KEY_SHIFT):
					game.buy_rune(rid)
				_pop(sl)
				burst_at(sl.get_global_rect().get_center(), S.MANA)
		sl.tooltip_fn = func(): return "[b][color=#ECE6D6]%s[/color][/b]  [color=#9FD3FF]%d mana[/color]\n[color=#8C877D]%s[/color]\n[color=#8C877D]%s[/color]" % [game.rl.rune_name(rid), game.rune_cost(rid), game.rl.rune_identity(rid), T.t("tip_shop")]
		cell.add_child(sl)
		var ch := HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_theme_constant_override("separation", 3)
		ch.add_child(_icon("mana", 14))
		var price := S.label(str(game.rune_cost(rid)), 13, S.MANA.lightened(0.3), "bold")
		shop_prices[rid] = price
		ch.add_child(price)
		cell.add_child(ch)
		grid.add_child(cell)
	v.add_child(grid)
	shop_count = S.label("", 13, S.TEXT_DIM, "bold")
	v.add_child(shop_count)
	return v


func _menu_page(content: Rect2) -> Control:
	var v := _page(content)
	v.add_child(_title(T.t("paused"), 22))
	v.add_child(_btn(T.t("resume"), "btn_rune", Vector2(0, 52), "play", func(): select_tab("craft")))
	v.add_child(_btn(T.t("settings"), "btn", Vector2(0, 52), "gear", func(): settings_box.visible = not settings_box.visible))
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 6)
	settings_box.visible = false
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UISkin.box("chip", Vector4(-1, -1, -1, -1), Vector4(14, 10, 14, 10)))
	sp.add_child(settings_box)
	v.add_child(sp)
	settings_box.add_child(_toggle(T.t("set_numbers"), "numbers"))
	settings_box.add_child(_toggle(T.t("set_fullscreen"), "fullscreen"))
	settings_box.add_child(_toggle(T.t("set_edge_pan"), "edge_pan"))
	var sh := HBoxContainer.new()
	sh.add_child(S.label(T.t("set_cam_speed"), 14, S.TEXT, "medium"))
	var sl := HSlider.new()
	sl.min_value = 0.5; sl.max_value = 2.0; sl.step = 0.05
	sl.value = float(game.settings.get("cam_speed", 1.0))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(160, 24)
	sl.value_changed.connect(func(x): game.apply_setting("cam_speed", x))
	sh.add_child(sl)
	settings_box.add_child(sh)
	var ah := HBoxContainer.new()
	ah.add_child(S.label(T.t("set_cam_angle"), 14, S.TEXT, "medium"))
	var ob := OptionButton.new()
	for k in [["45", "45°"], ["30", "30°"], ["dynamic", T.t("cam_zoom_based")]]:
		ob.add_item(k[1])
		ob.set_item_metadata(ob.item_count - 1, k[0])
		if str(game.settings.get("cam_angle", "45")) == k[0]:
			ob.select(ob.item_count - 1)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.item_selected.connect(func(i): game.apply_setting("cam_angle", ob.get_item_metadata(i)))
	ah.add_child(ob)
	settings_box.add_child(ah)
	var lh := HBoxContainer.new()
	lh.add_child(S.label(T.t("set_language"), 14, S.TEXT, "medium"))
	var lo := OptionButton.new()
	for k in [["en", "English"], ["tr", "Türkçe"]]:
		lo.add_item(k[1])
		lo.set_item_metadata(lo.item_count - 1, k[0])
		if str(game.settings.get("lang", "en")) == k[0]:
			lo.select(lo.item_count - 1)
	lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lo.tooltip_text = T.t("set_language_note")
	lo.item_selected.connect(func(i): game.apply_setting("lang", lo.get_item_metadata(i)))
	lh.add_child(lo)
	settings_box.add_child(lh)
	save_btn = _btn(T.t("save_game"), "btn", Vector2(0, 52), "save", func(): game.save_game())
	v.add_child(save_btn)
	v.add_child(_btn(T.t("load_game"), "btn", Vector2(0, 52), "load", func(): game.load_game()))
	v.add_child(_btn(T.t("quit"), "btn_bad", Vector2(0, 52), "exit", func(): get_tree().quit()))
	var keys := S.label(T.t("controls_help"), 13, S.TEXT_MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys)
	return v


func _toggle(text: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(game.settings.get(key, false))
	c.add_theme_color_override("font_color", S.TEXT)
	c.add_theme_color_override("font_hover_color", Color.WHITE)
	c.add_theme_color_override("font_pressed_color", S.TEXT)
	c.add_theme_font_size_override("font_size", 14)
	c.toggled.connect(func(on): game.apply_setting(key, on))
	return c


func select_tab(key: String, animate := true) -> void:
	var prev := current_tab
	current_tab = key
	tabs[key].button_pressed = true
	for k in pages:
		var p: Control = pages[k]
		var on: bool = k == key
		if on and not p.visible and animate:
			p.modulate.a = 0.0
			p.offset_left = PAD + 18
			p.offset_right = -PAD + 18
			var tw := create_tween().set_parallel(true)
			tw.tween_property(p, "modulate:a", 1.0, 0.16)
			tw.tween_property(p, "offset_left", float(PAD), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "offset_right", float(-PAD), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		p.visible = on
	# the Menu tab pauses the game; leaving it resumes (if the menu paused it)
	if key == "menu" and prev != "menu":
		game.set_menu_pause(true)
	elif key != "menu" and prev == "menu":
		game.set_menu_pause(false)
	veil.visible = key == "menu"
	if key == "menu" and animate:
		veil.modulate.a = 0.0
		create_tween().tween_property(veil, "modulate:a", 1.0, 0.2)
	_dirty = true


func _tower_card() -> void:
	# bottom-left card: socket on its grade light · name (ellipsis when long) · DPS / mana row · 3 equal buttons.
	# Everything sits in containers inside the 9-slice, so long names or big numbers never leave the card.
	tower_card = Control.new()
	tower_card.anchor_top = 1.0; tower_card.anchor_bottom = 1.0
	tower_card.offset_left = 16; tower_card.offset_right = 456; tower_card.offset_top = -160; tower_card.offset_bottom = -16
	root.add_child(tower_card)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UISkin.box("card_tower", Vector4(34, 34, 34, 34)))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	tower_card.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 24)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower_card.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	m.add_child(h)
	sock_slot = Slot.new(game, "socket", -1, Vector2(80, 80))
	sock_slot.hint = "+"
	sock_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sock_slot.can_drop = func(d): return d.src in ["inv", "output"] and game.selected_tower != null
	sock_slot.on_drop = func(d):
		if d.src == "output":
			game.socket_output(game.selected_tower)
			return
		game.socket(game.selected_tower, d.idx)
		_pop(sock_slot)
	sock_slot.drop_hint = func(_d): return T.t("drop_socket") if game.selected_tower and game.selected_tower.rune == null else T.t("drop_swap")
	sock_slot.tooltip_fn = func(): return tip_for(game.selected_tower.rune if game.selected_tower else null)
	h.add_child(sock_slot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	tower_name = S.label("", 20, S.TRIM_LIGHT, "head")
	tower_name.clip_text = true
	tower_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tower_name.custom_minimum_size = Vector2(120, 0)
	v.add_child(tower_name)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 14)
	tower_dps = S.label("", 14, S.GOLD, "bold")
	tower_mana = S.label("", 14, S.MANA.lightened(0.25), "bold")
	sh.add_child(tower_dps); sh.add_child(tower_mana)
	v.add_child(sh)
	tower_info = S.label("", 13, S.TEXT_MUTED)
	tower_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tower_info.custom_minimum_size = Vector2(200, 0)
	v.add_child(tower_info)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 6)
	inspect_btn = _btn(T.t("inspect"), "btn_rune", Vector2(0, 36), "", func(): inspect(game.selected_tower.rune if game.selected_tower else null, {"kind": "tower", "tower": game.selected_tower}))
	take_rune_btn = _btn(T.t("remove"), "btn", Vector2(0, 36), "", func(): game.unsocket(game.selected_tower))
	sell_btn = _btn(T.t("sell"), "btn_bad", Vector2(0, 36), "", func(): game.sell_tower(game.selected_tower))
	for b in [inspect_btn, take_rune_btn, sell_btn]:
		b.add_theme_font_size_override("font_size", 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		bh.add_child(b)
	v.add_child(bh)
	h.add_child(v)


func _toast() -> void:
	toast = S.label("", 17, S.TEXT, "bold")
	toast.anchor_left = 0.0; toast.anchor_right = 1.0; toast.anchor_top = 1.0; toast.anchor_bottom = 1.0
	toast.offset_top = -64; toast.offset_bottom = -30; toast.offset_right = -470; toast.offset_left = 380
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 6)
	toast.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 0.9))
	root.add_child(toast)


func _banner() -> void:
	banner = S.label("", 60, S.TRIM_LIGHT, "head")
	banner.anchor_left = 0.0; banner.anchor_right = 1.0
	banner.offset_top = 300; banner.offset_bottom = 390; banner.offset_right = -460
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 0.85))
	banner.modulate.a = 0.0
	root.add_child(banner)


func show_banner(t: String, c := S.TRIM_LIGHT) -> void:
	banner.text = t
	banner.add_theme_color_override("font_color", c)
	banner.pivot_offset = Vector2(banner.size.x * 0.5, 45)
	banner.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.5)


func _tooltip() -> void:
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UISkin.box("plaque", Vector4(22, 22, 22, 22), Vector4(18, 14, 18, 14)))
	tip.custom_minimum_size = Vector2(348, 0)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = true
	tip_text.custom_minimum_size = Vector2(312, 0)
	tip_text.add_theme_font_override("normal_font", S.font("body"))
	tip_text.add_theme_font_override("bold_font", S.font("bold"))
	tip_text.add_theme_font_size_override("normal_font_size", 14)
	tip_text.add_theme_font_size_override("bold_font_size", 16)
	tip_text.add_theme_color_override("default_color", S.TEXT_DIM)
	tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(tip_text)
	root.add_child(tip)


func _intro() -> void:
	var i := 0
	for c in root.get_children():
		if c.has_meta("slide") or c == tower_card:
			var off: Vector2 = c.get_meta("slide", Vector2(0, 24))
			c.modulate.a = 0.0
			var tw := create_tween().set_parallel(true)
			tw.tween_property(c, "modulate:a", 1.0, 0.45).set_delay(0.08 * i)
			c.position += off
			tw.tween_property(c, "position", c.position - off, 0.5).set_delay(0.08 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			i += 1


# ------------------------------------------------------------------ interactions

func _drop_on_inv(i: int, d: Dictionary) -> void:
	match d.src:
		"inv":
			var a: int = d.idx
			if a == i:
				return
			var ra = game.inventory[a]
			var rb = game.inventory[i]
			if rb != null and ra.rune == rb.rune and int(ra.grade) == int(rb.grade):
				if game.combine(i, a):
					_pop(inv_slots[i])
					burst_at(inv_slots[i].get_global_rect().get_center())
			else:
				game.inventory[i] = ra
				game.inventory[a] = rb
				game.changed.emit()
		"output":
			game.output_to_slot(i)
		"socket":
			game.unsocket(game.selected_tower)
		"base":
			game.craft_clear()


func _inv_hint(i: int, d: Dictionary) -> String:
	var here = game.inventory[i]
	match d.src:
		"inv":
			var a = game.inventory[d.idx]
			if here != null and a != null and a.rune == here.rune and int(a.grade) == int(here.grade):
				return T.t("drop_combine", {"g": int(a.grade) + 1, "n": game.combine_fee(int(a.grade))}) if int(a.grade) < 5 else T.t("drop_max_grade")
			return T.t("drop_swap") if here != null else T.t("drop_move")
		"output":
			return T.t("drop_take")
		"socket":
			return T.t("drop_unsocket")
		"base":
			return T.t("drop_clear_table")
	return ""


func on_drag_start() -> void:
	drag_hint = ""
	drag_hint_owner = null


func set_drag_hint(owner, text: String, ok := true) -> void:
	drag_hint_owner = owner
	drag_hint = text
	drag_hint_ok = ok


func clear_drag_hint(owner) -> void:
	if drag_hint_owner == owner:
		drag_hint_owner = null
		drag_hint = ""


func _click_inv(i: int, dbl: bool) -> void:
	if game.inventory[i] == null:
		sel_inv = -1
		refresh()
		return
	if dbl:
		if game.selected_tower != null:
			game.socket(game.selected_tower, i)
		elif game.craft.base == null:
			game.craft_set_base(i)
		sel_inv = -1
		return
	if sel_inv >= 0 and sel_inv != i and game.inventory[sel_inv] != null:
		var a = game.inventory[sel_inv]
		var b = game.inventory[i]
		if a.rune == b.rune and int(a.grade) == int(b.grade):
			if game.combine(i, sel_inv):
				burst_at(inv_slots[i].get_global_rect().get_center())
			sel_inv = -1
			return
	sel_inv = i
	struct_src = "inv"
	_struct_sig = ""
	refresh()


# ------------------------------------------------------------------ rune structure (Craft tab middle)

## Which rune the structure view shows. "base" also shows the pending donors (as pending nodes: their effect is
## only described after crafting — no preview). Optional `ability` pre-selects that ability node.
func show_structure_of(which: String, ability := "") -> void:
	struct_src = which
	_struct_sig = ""
	_struct_update(ability)


func _struct_rune():
	match struct_src:
		"output":
			if game.craft.output != null:
				return game.craft.output
		"inv":
			if sel_inv >= 0 and game.inventory[sel_inv] != null:
				return game.inventory[sel_inv]
	if game.craft.output != null:
		return game.craft.output
	if game.craft.base != null:
		return game.craft.base
	if sel_inv >= 0 and game.inventory[sel_inv] != null:
		return game.inventory[sel_inv]
	return null


func _struct_update(ability := "") -> void:
	var n = _struct_rune()
	var is_base: bool = n != null and is_same(n, game.craft.base)
	var sig := var_to_str([n, game.craft.pending if is_base else null, struct_src])
	if sig == _struct_sig and ability == "":
		return
	_struct_sig = sig
	struct_node = n
	details_btn.disabled = n == null
	if n == null:
		struct_tree.set_item(null)
		struct_name.text = ""
		struct_pick = null
		struct_cap.text = "[color=#8C877D]%s[/color]" % T.t("structure_empty")
		struct_act.visible = false
		return
	var it := RV.build(game, n, game.craft.pending if is_base else {})
	var keep = struct_pick
	struct_tree.set_item(it)
	struct_pick = it
	struct_name.text = "%s G%d" % [game.rl.rune_name(n.rune), int(n.grade)]
	struct_name.add_theme_color_override("font_color", RV.grade_color(int(n.grade)).lerp(S.TRIM_LIGHT, 0.45))
	# keep the picked ability across rebuilds (same ability id), or take the requested one
	var want := ability
	if want == "" and keep != null and keep.kind == "ability" and keep.node.rune == n.rune:
		want = keep.ability
	if want != "":
		for ab in it.kids:
			if ab.ability == want:
				struct_pick = ab
				struct_tree.selected = ab
	_struct_caption(struct_pick)


func _struct_caption(it) -> void:
	struct_cap.text = RV.describe(game, it) if it != null else ""
	struct_cap.scroll_to_line(0)
	# actions on the table rune: take a pending donor back, or ungraft an existing donor (fee lost)
	struct_act.visible = false
	if it == null or it.kind != "rune" or it.depth != 1 or struct_node == null or not is_same(struct_node, game.craft.base):
		return
	struct_act.set_meta("item", it)
	struct_act.text = T.t("take_back") if it.pending else T.t("ungraft")
	struct_act.visible = true


func _struct_action() -> void:
	var it = struct_act.get_meta("item", null)
	if it == null or game.craft.base == null:
		return
	# find the ability and the index of this donor on the table rune
	for ab in game.spec.runes[game.craft.base.rune].abilities:
		if it.pending:
			var pend: Array = game.craft.pending.get(ab.id, [])
			for k in pend.size():
				if is_same(pend[k], it.node):
					game.craft_remove_pending(ab.id, k)
					return
		else:
			var ex: Array = game.craft.base.grafts.get(ab.id, [])
			for k in ex.size():
				if is_same(ex[k], it.node):
					game.craft_ungraft(ab.id, k)
					return


func _open_struct_details() -> void:
	if struct_node != null:
		inspect(struct_node)


func _ab(rid: String, ab: String) -> Dictionary:
	for a in game.spec.runes[rid].abilities:
		if a.id == ab:
			return a
	return {}


# ------------------------------------------------------------------ tooltip

func inspect(node, src := {}) -> void:
	if node == null:
		return
	hide_tip(tip_owner)
	inspector.show_rune(node, src)


## Short loot-style tooltip: name in its grade colour, one identity line, the abilities that carry grafts (max 4),
## then a hint. Everything longer lives in the inspector (right-click), so the tooltip never grows off-screen.
func tip_for(node) -> String:
	if node == null:
		return ""
	var rl = game.rl
	var g := int(node.grade)
	var out := "[b][color=#%s]%s G%d[/color][/b]\n" % [RV.grade_color(g).lerp(S.TRIM_LIGHT, 0.4).to_html(false), rl.rune_name(node.rune), g]
	out += "[color=#8C877D]%s[/color]" % rl.rune_identity(node.rune)
	var lines := []
	var locked := []
	for a in game.spec.runes[node.rune].abilities:
		if int(a.grade) > g:
			locked.append(T.t("grade_short", {"g": int(a.grade)}))
			continue
		var kids: Array = node.grafts.get(a.id, [])
		if kids.is_empty():
			continue
		var names := []
		for k in rl.sorted_kids(kids):
			names.append("%s G%d" % [rl.rune_name(k.rune), int(k.grade)])
		lines.append("[color=#7FE3F0]◆[/color] %s [color=#8C877D]←[/color] [color=#9FD3FF]%s[/color]" % [rl.ability_name(node.rune, a.id), ", ".join(names)])
	if not lines.is_empty():
		out += "\n" + "\n".join(lines.slice(0, 4))
		if lines.size() > 4:
			out += "\n[color=#8C877D]%s[/color]" % T.t("tip_more", {"n": lines.size() - 4})
	if not locked.is_empty():
		out += "\n[color=#6E6A78]◇ %s[/color]" % T.t("tip_locked", {"list": ", ".join(locked)})
	out += "\n[color=#7FE3F0]%s[/color]" % T.t("tip_inspect")
	return out


func show_tip(text: String, owner: Control) -> void:
	if text == "" or inspector.visible:
		return
	tip_owner = owner
	tip_text.text = text
	tip.visible = true
	tip.modulate.a = 0.0
	create_tween().tween_property(tip, "modulate:a", 1.0, 0.12)
	var vp := root.get_viewport_rect().size
	# never taller than the screen: the text scrolls inside (it is short by construction anyway)
	tip_text.custom_minimum_size = Vector2(312, 0)
	tip.reset_size()
	var max_h := vp.y * 0.6
	if tip.size.y > max_h:
		tip_text.fit_content = false
		tip_text.custom_minimum_size = Vector2(312, max_h - 28)
		tip.size = Vector2(tip.size.x, max_h)
	else:
		tip_text.fit_content = true
	var r := owner.get_global_rect()
	var p := Vector2(r.position.x - tip.size.x - 12, r.position.y)
	if p.x < 8:
		p.x = r.end.x + 12
	if p.x + tip.size.x > vp.x - 8:
		p.x = vp.x - 8 - tip.size.x
	p.y = clampf(p.y, 8, maxf(8.0, vp.y - tip.size.y - 8))
	tip.position = p.round()


func hide_tip(owner: Control) -> void:
	if tip_owner == owner:
		tip.visible = false
		tip_owner = null


# ------------------------------------------------------------------ UI sparks

func burst_at(p: Vector2, c := S.RUNE) -> void:
	for i in 18:
		var a := TAU * i / 18.0 + randf() * 0.3
		ui_sparks.append({"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(80, 220), "t": 0.0, "life": randf_range(0.35, 0.6), "c": c})


func _draw_fx() -> void:
	var spark := UISkin.tex("vfx_spark")
	for s in ui_sparks:
		var u: float = s.t / s.life
		var sz := 14.0 * (1.0 - u) + 4.0
		fx_layer.draw_texture_rect(spark, Rect2(s.p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(s.c, 1.0 - u))


# ------------------------------------------------------------------ refresh

func refresh() -> void:
	if game == null:
		return
	_dirty = false
	var sig := var_to_str([game.craft.base, game.craft.pending, game.craft.output, table.selected_ability, game.mana >= game.craft_fee()])
	if sig != _table_sig:
		_table_sig = sig
		table.rebuild()
	_struct_update()
	inspector.revalidate()
	var used := 0
	for i in game.INV_SIZE:
		inv_slots[i].set_node(game.inventory[i], i == sel_inv)
		if game.inventory[i] != null:
			used += 1
	inv_count.text = "%d / %d" % [used, game.INV_SIZE]
	inv_bar.value = float(used) / float(game.INV_SIZE)
	inv_bar.queue_redraw()
	inv_count.add_theme_color_override("font_color", S.BAD if used >= game.INV_SIZE else (S.GOLD if used >= game.INV_SIZE - 2 else S.TEXT_DIM))
	shop_count.text = T.t("inventory_count", {"n": used, "max": game.INV_SIZE})
	for rid in shop_prices:
		var c: int = game.rune_cost(rid)
		var base := int(game.spec.economy.rune_buy_g1_mana[game.spec.runes[rid].buy])
		shop_prices[rid].text = str(c)
		shop_prices[rid].add_theme_color_override("font_color", (S.MANA.lightened(0.3) if c <= base else S.GOLD) if game.mana >= c else S.BAD)
	var t = game.selected_tower
	tower_card.visible = t != null
	if t != null:
		sock_slot.set_node(t.rune)
		if t.rune != null:
			tower_name.text = "%s G%d" % [game.rl.rune_name(t.rune.rune), int(t.rune.grade)]
			tower_name.add_theme_color_override("font_color", RV.grade_color(int(t.rune.grade)).lerp(S.TRIM_LIGHT, 0.45))
			tower_info.text = ""
		else:
			tower_name.text = T.t("empty_tower")
			tower_name.add_theme_color_override("font_color", S.TRIM_LIGHT)
			tower_info.text = T.t("empty_tower_hint")
		take_rune_btn.disabled = t.rune == null
		tower_info.visible = tower_info.text != ""
		inspect_btn.disabled = t.rune == null
		sell_btn.text = T.t("sell_refund", {"n": game.economy.tower_refund(t)})
	build_btn.button_pressed = game.build_mode
	_update_live(0.0)


func _process(dt: float) -> void:
	if _dirty:
		refresh()
	if not root.get_viewport().gui_is_dragging() and drag_hint_owner != null:
		drag_hint_owner = null
		drag_hint = ""
	_update_live(dt)
	for s in ui_sparks.duplicate():
		s.t += dt
		s.p += s.v * dt
		s.v *= 0.92
		if s.t >= s.life:
			ui_sparks.erase(s)
	fx_layer.queue_redraw()


func _update_live(dt: float) -> void:
	if game == null or bars.is_empty():
		return
	shown_mana = lerpf(shown_mana, game.mana, clampf(dt * 8.0, 0.0, 1.0)) if dt > 0 else game.mana
	shown_stones = lerpf(shown_stones, float(game.stones), clampf(dt * 8.0, 0.0, 1.0)) if dt > 0 else float(game.stones)
	var hp = bars.hp
	hp.value = float(game.castle_hp) / float(game.castle_max)
	hp.text = "%d / %d" % [game.castle_hp, game.castle_max]
	var mana_goal := maxf(200.0, 100.0 * (game.wave + 2))
	bars.mana.value = clampf(shown_mana / mana_goal, 0.0, 1.0)
	bars.mana.text = "%d   +%.1f/s" % [roundi(shown_mana), game.economy.mana_rate()]
	bars.mana.shine += dt * 0.5
	bars.stone.value = clampf(shown_stones / float(game.tower_cost()), 0.0, 1.0)
	bars.stone.text = "%d ◆" % roundi(shown_stones)
	for k in bars:
		bars[k].queue_redraw()
	build_btn.text = T.t("build_tower_cost", {"n": game.tower_cost()})
	wave_lbl.text = ("W%d" % maxi(game.wave, 1)) if game.wave_state != "lost" else T.t("lost")
	var rem: int = game.remaining()
	left_lbl.text = str(rem) if game.wave_state != "build" else str(game.wave_plan(game.wave + 1).size())
	var building: bool = game.wave_state == "build"
	if building != next_row.visible:
		next_row.visible = building
		if building:
			next_row.modulate.a = 0.0
			create_tween().tween_property(next_row, "modulate:a", 1.0, 0.3)
	if building:
		next_lbl.text = T.t("remaining", {"s": ceili(game.countdown)})
	if game.wave_state != _last_wave_state:
		if game.wave_state == "spawning":
			show_banner(T.t("wave_banner", {"n": game.wave}))
		elif game.wave_state == "build" and game.wave > 0:
			show_banner(T.t("wave_cleared"), S.GOOD)
		elif game.wave_state == "lost":
			show_banner(T.t("castle_fell"), S.BAD)
		_last_wave_state = game.wave_state
	ctrl_btns[0].icon = UISkin.tex("icon_play" if game.paused else "icon_pause")
	for i in range(1, 4):
		var on: bool = not game.paused and is_equal_approx(game.speed, [1.0, 2.0, 3.0][i - 1])
		var b: Button = ctrl_btns[i]
		for k in ["font_color", "font_hover_color"]:
			b.add_theme_color_override(k, Color("#8A6420") if on else Color("#1E1D24"))
	if game.selected_tower != null and is_instance_valid(game.selected_tower):
		var st = game.selected_tower
		var mr: float = game.economy.tower_mana_rate(st)
		tower_dps.text = T.t("dps", {"n": "%.1f" % game.tower_dps(st)}) if st.rune != null else ""
		tower_mana.text = T.t("mana_rate", {"n": "%.1f" % mr}) if st.rune != null and mr >= 0.05 else ""
		tower_mana.visible = tower_mana.text != ""
	var mid: bool = game.wave_state in ["spawning", "fighting"]
	save_btn.disabled = mid
	save_btn.tooltip_text = T.t("save_between_waves") if mid else ""
	toast.text = game.message if game.message_t > 0.0 else ""
	toast.modulate.a = clampf(game.message_t, 0.0, 1.0)
