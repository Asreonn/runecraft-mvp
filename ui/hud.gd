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
var detail_box: VBoxContainer
var desc: RichTextLabel
var desc_title: Label
var inv_grid: GridContainer
var inv_title: Label
var inv_slots: Array = []
var sel_inv := -1
var build_btn: Button
var shop_count: Label
var settings_box: VBoxContainer
var veil: ColorRect
# tower card
var tower_card: Control
var sock_slot
var tower_name: Label
var tower_info: Label
var tower_dps: Label
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
	next_lbl = S.label("Remaining 20s", 14, S.TEXT, "bold")
	rh.add_child(next_lbl)
	rc.add_child(rh)
	next_row.add_child(rc)
	start_btn = _btn("Start now ▸", "btn_rune", Vector2(124, 38), "", func(): game.start_wave())
	start_btn.add_theme_font_size_override("font_size", 14)
	next_row.add_child(start_btn)


func _right_panel() -> void:
	var holder := Control.new()
	holder.name = "RightPanel"
	holder.position = Vector2(PANEL_X, 16)
	holder.size = Vector2(PANEL_W, 1048)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("slide", Vector2(48, 0))
	root.add_child(holder)
	var panel := _tex_rect("panel_right", Vector2(PANEL_W, 1008))
	panel.position = Vector2(0, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(panel)
	var group := ButtonGroup.new()
	var i := 0
	for k in [["craft", "Craft", "craft"], ["shop", "Shop", "shop"], ["menu", "Menu", "menu"]]:
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
	v.position = content.position
	v.size = content.size
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _craft_page(content: Rect2) -> Control:
	var v := _page(content)
	v.add_child(_title("RUNE TABLE"))
	table = CraftTable.new(game, self)
	v.add_child(table)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 4)
	v.add_child(detail_box)
	var df := PanelContainer.new()
	df.add_theme_stylebox_override("panel", UISkin.box("chip", Vector4(-1, -1, -1, -1), Vector4(12, 8, 12, 8)))
	df.custom_minimum_size = Vector2(0, 150)
	var dv := VBoxContainer.new()
	desc_title = S.label("", 12, Color("#9C98A6"), "bold")
	dv.add_child(desc_title)
	desc = RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.scroll_active = true
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_override("normal_font", S.font("body"))
	desc.add_theme_font_override("bold_font", S.font("bold"))
	desc.add_theme_font_size_override("normal_font_size", 13)
	desc.add_theme_font_size_override("bold_font_size", 13)
	desc.add_theme_color_override("default_color", S.TEXT_DIM)
	dv.add_child(desc)
	df.add_child(dv)
	v.add_child(df)
	inv_title = _title("INVENTORY", 15)
	v.add_child(inv_title)
	inv_grid = GridContainer.new()
	inv_grid.columns = 6
	inv_grid.add_theme_constant_override("h_separation", 8)
	inv_grid.add_theme_constant_override("v_separation", 8)
	for i in game.INV_SIZE:
		var sl = Slot.new(game, "inv", i, Vector2(58, 58))
		sl.can_drop = func(d): return d.src in ["inv", "output", "socket", "pending", "base"]
		sl.on_drop = func(d): _drop_on_inv(i, d)
		sl.on_click = func(dbl): _click_inv(i, dbl)
		sl.drop_hint = func(d): return _inv_hint(i, d)
		sl.tooltip_fn = func(): return tip_for(game.inventory[i]) + ("\n[color=#8C877D]Drop the same rune on it to combine · double-click: tower / table[/color]" if game.inventory[i] != null else "")
		inv_slots.append(sl)
		inv_grid.add_child(sl)
	v.add_child(inv_grid)
	return v


func _shop_page(content: Rect2) -> Control:
	var v := _page(content)
	v.add_child(_title("BUILD"))
	build_btn = _btn("Build tower", "btn_rune", Vector2(0, 56), "tower", func(): game.toggle_build())
	build_btn.toggle_mode = true
	build_btn.add_theme_font_size_override("font_size", 17)
	v.add_child(build_btn)
	var hint := S.label("Towers cost mana stones (dropped by enemies). Hotkey B · Shift keeps building.", 12, S.TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 10); v.add_child(gap)
	v.add_child(_title("RUNES"))
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
			game.buy_rune(rid)
			if Input.is_key_pressed(KEY_SHIFT):
				game.buy_rune(rid)
			_pop(sl)
			burst_at(sl.get_global_rect().get_center(), S.MANA)
		sl.tooltip_fn = func(): return "[b][color=#ECE6D6]%s[/color][/b] — %d mana\n%s\n[color=#8C877D]Click: buy · Shift+click: buy 2[/color]" % [game.rl.rune_name(rid), game.rune_cost(rid), game.rl.rune_identity(rid)]
		cell.add_child(sl)
		var ch := HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_theme_constant_override("separation", 3)
		ch.add_child(_icon("mana", 14))
		ch.add_child(S.label(str(game.rune_cost(rid)), 13, S.MANA.lightened(0.3), "bold"))
		cell.add_child(ch)
		grid.add_child(cell)
	v.add_child(grid)
	shop_count = S.label("", 13, S.TEXT_DIM, "bold")
	v.add_child(shop_count)
	return v


func _menu_page(content: Rect2) -> Control:
	var v := _page(content)
	v.add_child(_title("PAUSED", 22))
	v.add_child(_btn("Resume", "btn_rune", Vector2(0, 52), "play", func(): select_tab("craft")))
	v.add_child(_btn("Settings", "btn", Vector2(0, 52), "gear", func(): settings_box.visible = not settings_box.visible))
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 6)
	settings_box.visible = false
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UISkin.box("chip", Vector4(-1, -1, -1, -1), Vector4(14, 10, 14, 10)))
	sp.add_child(settings_box)
	v.add_child(sp)
	settings_box.add_child(_toggle("Damage numbers", "numbers"))
	settings_box.add_child(_toggle("Fullscreen", "fullscreen"))
	settings_box.add_child(_toggle("Edge scrolling", "edge_pan"))
	var sh := HBoxContainer.new()
	sh.add_child(S.label("Camera speed", 14, S.TEXT, "medium"))
	var sl := HSlider.new()
	sl.min_value = 0.5; sl.max_value = 2.0; sl.step = 0.05
	sl.value = float(game.settings.get("cam_speed", 1.0))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(160, 24)
	sl.value_changed.connect(func(x): game.apply_setting("cam_speed", x))
	sh.add_child(sl)
	settings_box.add_child(sh)
	var lang := S.label("Language: English (more coming)", 13, S.TEXT_MUTED)
	settings_box.add_child(lang)
	v.add_child(_btn("Save game", "btn", Vector2(0, 52), "save", func(): game.save_game()))
	v.add_child(_btn("Load game", "btn", Vector2(0, 52), "load", func(): game.load_game()))
	v.add_child(_btn("Quit", "btn_bad", Vector2(0, 52), "exit", func(): get_tree().quit()))
	var keys := S.label("Camera: WASD / arrows · wheel zoom · middle-drag · Q/E rotate\nSpace pause · 1/2/3 speed · B build · N next wave", 12, S.TEXT_MUTED)
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
			p.position.x = PAD + 18
			var tw := create_tween().set_parallel(true)
			tw.tween_property(p, "modulate:a", 1.0, 0.16)
			tw.tween_property(p, "position:x", float(PAD), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	tower_card = Control.new()
	tower_card.position = Vector2(16, 912)
	tower_card.size = Vector2(364, 152)
	root.add_child(tower_card)
	var bg := _tex_rect("card_tower", Vector2(364, 152))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	tower_card.add_child(bg)
	var h := HBoxContainer.new()
	h.position = Vector2(22, 22)
	h.size = Vector2(320, 108)
	h.add_theme_constant_override("separation", 12)
	tower_card.add_child(h)
	sock_slot = Slot.new(game, "socket", -1, Vector2(76, 76))
	sock_slot.hint = "Rune"
	sock_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sock_slot.can_drop = func(d): return d.src in ["inv", "output"] and game.selected_tower != null
	sock_slot.on_drop = func(d):
		if d.src == "output":
			game.socket_output(game.selected_tower)
			return
		game.socket(game.selected_tower, d.idx)
		_pop(sock_slot)
	sock_slot.drop_hint = func(_d): return "Socket" if game.selected_tower and game.selected_tower.rune == null else "Swap"
	sock_slot.tooltip_fn = func(): return tip_for(game.selected_tower.rune if game.selected_tower else null)
	h.add_child(sock_slot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	var nh := HBoxContainer.new()
	tower_name = S.label("", 18, S.TRIM_LIGHT, "head")
	tower_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tower_dps = S.label("", 13, S.GOLD, "bold")
	nh.add_child(tower_name); nh.add_child(tower_dps)
	v.add_child(nh)
	tower_info = S.label("", 12, S.TEXT_MUTED)
	tower_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tower_info.custom_minimum_size = Vector2(220, 34)
	v.add_child(tower_info)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 6)
	take_rune_btn = _btn("Remove rune", "btn", Vector2(110, 36), "", func(): game.unsocket(game.selected_tower))
	take_rune_btn.add_theme_font_size_override("font_size", 13)
	sell_btn = _btn("Sell", "btn_bad", Vector2(100, 36), "", func(): game.sell_tower(game.selected_tower))
	sell_btn.add_theme_font_size_override("font_size", 13)
	bh.add_child(take_rune_btn); bh.add_child(sell_btn)
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
	tip.add_theme_stylebox_override("panel", UISkin.box("chip_rune", Vector4(-1, -1, -1, -1), Vector4(14, 12, 14, 12)))
	tip.custom_minimum_size = Vector2(380, 0)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = true
	tip_text.custom_minimum_size = Vector2(352, 0)
	tip_text.add_theme_font_override("normal_font", S.font("body"))
	tip_text.add_theme_font_override("bold_font", S.font("bold"))
	tip_text.add_theme_font_size_override("normal_font_size", 13)
	tip_text.add_theme_font_size_override("bold_font_size", 14)
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
			if game.inventory[i] == null:
				game.inventory[i] = game.craft.output
				game.craft.output = null
				game.changed.emit()
			else:
				game.take_output()
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
				return "Combine → G%d  (%d mana)" % [int(a.grade) + 1, game.combine_fee(int(a.grade))] if int(a.grade) < 5 else "G5 is the maximum"
			return "Swap" if here != null else "Move"
		"output":
			return "Take into inventory"
		"socket":
			return "Take off the tower"
		"base":
			return "Clear the table"
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
	refresh()


func _detail_strip() -> void:
	for ch in detail_box.get_children():
		ch.queue_free()
	var b = game.craft.base
	var ab: String = table.selected_ability
	if b == null:
		var l := S.label("Drop a rune in the centre of the circle; its open abilities become graft slots.", 12, S.TEXT_MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(l)
		return
	if ab == "":
		var l := S.label("Click a slot to list that ability's grafts here.", 12, S.TEXT_MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(l)
		return
	var a: Dictionary = _ab(b.rune, ab)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UISkin.box("chip", Vector4(-1, -1, -1, -1), Vector4(10, 6, 10, 6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var lv := VBoxContainer.new()
	lv.custom_minimum_size = Vector2(120, 0)
	lv.add_theme_constant_override("separation", -2)
	lv.add_child(S.label(game.rl.ability_name(b.rune, ab), 13, S.TEXT, "bold"))
	lv.add_child(S.label(game.rl.carrier_name(a.carrier), 11, S.TEXT_MUTED))
	h.add_child(lv)
	var existing: Array = b.grafts.get(ab, [])
	for k in existing.size():
		var s = Slot.new(game, "graft", k, Vector2(40, 40))
		s.set_node(existing[k])
		var kk := k
		s.on_click = func(_dbl): game.craft_ungraft(ab, kk)
		s.tooltip_fn = func(): return tip_for(existing[kk]) + "\n[color=#F06A5A]Click: remove — the rune returns, the fee is lost[/color]"
		h.add_child(s)
	var pend: Array = game.craft.pending.get(ab, [])
	for k in pend.size():
		var s = Slot.new(game, "pending", k, Vector2(40, 40))
		s.set_node(pend[k], true)
		var kk := k
		s.on_click = func(_dbl): game.craft_remove_pending(ab, kk)
		s.tooltip_fn = func(): return tip_for(pend[kk]) + "\n[color=#9FD3FF]Pending — applied by Craft. Click: take back[/color]"
		h.add_child(s)
	if existing.is_empty() and pend.is_empty():
		h.add_child(S.label("empty", 12, S.TEXT_MUTED))
	row.add_child(h)
	detail_box.add_child(row)


func _ab(rid: String, ab: String) -> Dictionary:
	for a in game.spec.runes[rid].abilities:
		if a.id == ab:
			return a
	return {}


# ------------------------------------------------------------------ tooltip

func tip_for(node) -> String:
	if node == null:
		return ""
	var txt: String = game.describe(node)
	var lines := txt.split("\n")
	var out := "[b][color=#ECE6D6]%s[/color][/b]\n" % lines[0]
	for i in range(1, lines.size()):
		var ln := lines[i]
		var t := ln.strip_edges()
		if t.begins_with("✗"):
			out += "[color=#B07A6A]%s[/color]\n" % ln
		elif t.begins_with("🔒"):
			out += "[color=#7E7A86]%s[/color]\n" % ln.replace("🔒", "◇")
		elif t.begins_with("↳"):
			out += "[color=#9FD3FF]%s[/color]\n" % ln
		else:
			out += ln + "\n"
	out += "[color=#8C877D]Value ≈ %d mana[/color]" % roundi(game.rl.cost(node).total_mana)
	return out


func show_tip(text: String, owner: Control) -> void:
	if text == "":
		return
	tip_owner = owner
	tip_text.text = text
	tip.visible = true
	tip.modulate.a = 0.0
	create_tween().tween_property(tip, "modulate:a", 1.0, 0.12)
	tip.reset_size()
	var r := owner.get_global_rect()
	var vp := root.get_viewport_rect().size
	var p := Vector2(r.position.x - tip.size.x - 12, r.position.y)
	if p.x < 8:
		p.x = r.end.x + 12
	p.y = clampf(p.y, 8, vp.y - tip.size.y - 8)
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
		_detail_strip()
	if game.craft.output != null:
		desc_title.text = "OUTPUT RUNE"
		desc.text = tip_for(game.craft.output)
	elif game.craft.base != null:
		desc_title.text = "BASE RUNE (current)"
		desc.text = tip_for(game.craft.base)
	else:
		desc_title.text = "DESCRIPTION"
		desc.text = "[color=#8C877D]After crafting, the output rune's description appears here. There is no preview before crafting.[/color]"
	var used := 0
	for i in game.INV_SIZE:
		inv_slots[i].set_node(game.inventory[i], i == sel_inv)
		if game.inventory[i] != null:
			used += 1
	inv_title.text = "INVENTORY  %d / %d" % [used, game.INV_SIZE]
	shop_count.text = "Inventory  %d / %d" % [used, game.INV_SIZE]
	var t = game.selected_tower
	tower_card.visible = t != null
	if t != null:
		sock_slot.set_node(t.rune)
		if t.rune != null:
			tower_name.text = "%s G%d" % [game.rl.rune_name(t.rune.rune), int(t.rune.grade)]
			tower_info.text = game.rl.rune_identity(t.rune.rune)
		else:
			tower_name.text = "Empty tower"
			tower_info.text = "Drag a rune from the inventory onto the tower or this socket."
		take_rune_btn.disabled = t.rune == null
		sell_btn.text = "Sell  +%d ◆" % int((4 + 2 * (game.towers.size() - 1)) * 0.5)
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
	bars.mana.text = "%d   +%d/s" % [roundi(shown_mana), int(game.mana_regen)]
	bars.mana.shine += dt * 0.5
	bars.stone.value = clampf(shown_stones / float(game.tower_cost()), 0.0, 1.0)
	bars.stone.text = "%d ◆" % roundi(shown_stones)
	for k in bars:
		bars[k].queue_redraw()
	build_btn.text = "Build tower    ◆ %d    [B]" % game.tower_cost()
	wave_lbl.text = ("W%d" % maxi(game.wave, 1)) if game.wave_state != "lost" else "LOST"
	var rem: int = game.remaining()
	left_lbl.text = str(rem) if game.wave_state != "build" else str(game.wave_plan(game.wave + 1).size())
	var building: bool = game.wave_state == "build"
	if building != next_row.visible:
		next_row.visible = building
		if building:
			next_row.modulate.a = 0.0
			create_tween().tween_property(next_row, "modulate:a", 1.0, 0.3)
	if building:
		next_lbl.text = "Remaining  %ds" % ceili(game.countdown)
	if game.wave_state != _last_wave_state:
		if game.wave_state == "spawning":
			show_banner("WAVE %d" % game.wave)
		elif game.wave_state == "build" and game.wave > 0:
			show_banner("Wave cleared", S.GOOD)
		elif game.wave_state == "lost":
			show_banner("THE CASTLE FELL", S.BAD)
		_last_wave_state = game.wave_state
	ctrl_btns[0].icon = UISkin.tex("icon_play" if game.paused else "icon_pause")
	for i in range(1, 4):
		var on: bool = not game.paused and is_equal_approx(game.speed, [1.0, 2.0, 3.0][i - 1])
		var b: Button = ctrl_btns[i]
		for k in ["font_color", "font_hover_color"]:
			b.add_theme_color_override(k, Color("#8A6420") if on else Color("#1E1D24"))
	if game.selected_tower != null and is_instance_valid(game.selected_tower):
		tower_dps.text = ("%.1f DPS" % game.tower_dps(game.selected_tower)) if game.selected_tower.rune != null else ""
	toast.text = game.message if game.message_t > 0.0 else ""
	toast.modulate.a = clampf(game.message_t, 0.0, 1.0)
