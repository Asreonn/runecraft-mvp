extends Control
## Crafting area (top of the Craft tab): the engraved magic circle with the base rune in the middle and one graft
## socket per ability of the base on the circle (locked abilities are shown sealed with their unlock grade), an
## output column on the right (output socket, Craft button with the fee, one status line). The circle slowly turns;
## conduits light up for pending donors; crafting plays the converge + flash animation.
## Sockets are square Penpot exports; nothing round is drawn behind them (the circle is the only round element).

const S := preload("res://ui/style.gd")
const Slot := preload("res://ui/slot.gd")
const UISkin := preload("res://ui/skin.gd")
const T := preload("res://ui/i18n.gd")

var game
var hud
var base_slot
var out_slot
var craft_btn: Button
var out_title: Label
var status: Label
var ab_slots: Array = []         # [{slot, ability, label, ang, locked}]
var selected_ability := ""
var spin := 0.0
var spin_speed := 0.18
var charge := 0.0                # 0..1 craft animation
var flash := 0.0
var sparks: Array = []
const CIRCLE_C := Vector2(112, 116)
const DISC_D := 226.0
const SLOT_R := 84.0
const AB := 46.0                 # ability socket size
const COL_X := 250.0             # output column


func _init(g, h) -> void:
	game = g
	hud = h
	custom_minimum_size = Vector2(388, 236)
	mouse_filter = Control.MOUSE_FILTER_PASS
	base_slot = Slot.new(game, "base", -1, Vector2(64, 64))
	base_slot.hint = "+"
	base_slot.can_drop = func(d): return d.src == "inv"
	base_slot.on_drop = func(d): game.craft_set_base(d.idx); _pop(base_slot)
	base_slot.on_click = func(_dbl):
		if hud.sel_inv >= 0:
			game.craft_set_base(hud.sel_inv); hud.sel_inv = -1; _pop(base_slot)
		hud.show_structure_of("base")
	base_slot.tooltip_fn = func(): return hud.tip_for(game.craft.base) if game.craft.base != null else T.t("tip_base_empty")
	base_slot.drop_hint = func(_d): return T.t("drop_set_base") if game.craft.base == null else T.t("drop_replace_base")
	add_child(base_slot)
	out_title = S.label(T.t("output"), 12, S.TEXT_MUTED, "bold")
	out_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(out_title)
	out_slot = Slot.new(game, "output", -1, Vector2(64, 64))
	out_slot.hint = "?"
	out_slot.on_click = func(_dbl): hud.show_structure_of("output")
	out_slot.tooltip_fn = func(): return hud.tip_for(game.craft.output) + ("\n[color=#8C877D]%s[/color]" % T.t("tip_output_take") if game.craft.output != null else "") if game.craft.output != null else T.t("tip_output_empty")
	add_child(out_slot)
	craft_btn = Button.new()
	UISkin.button(craft_btn, "btn_gold")
	craft_btn.add_theme_font_override("font", S.font("bold"))
	craft_btn.add_theme_font_size_override("font_size", 16)
	craft_btn.icon = UISkin.tex("icon_mana")
	craft_btn.expand_icon = true
	craft_btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	craft_btn.add_theme_constant_override("icon_max_width", 18)
	craft_btn.add_theme_constant_override("h_separation", 6)
	craft_btn.custom_minimum_size = Vector2(132, 42)
	craft_btn.pressed.connect(_craft)
	add_child(craft_btn)
	status = S.label("", 12, S.TEXT_MUTED, "medium")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)


func rebuild() -> void:
	for a in ab_slots:
		a.slot.queue_free()
		a.label.queue_free()
	ab_slots.clear()
	var b = game.craft.base
	base_slot.set_node(b)
	out_slot.set_node(game.craft.output)
	if b == null:
		selected_ability = ""
	else:
		var all: Array = game.spec.runes[b.rune].abilities
		var n := all.size()
		for i in n:
			var a: Dictionary = all[i]
			var locked: bool = int(a.grade) > int(b.grade)
			var ang := -PI * 0.5 + TAU * float(i) / maxf(n, 1)
			var s = Slot.new(game, "graft_add", i, Vector2(AB, AB))
			var existing: Array = b.grafts.get(a.id, [])
			var pend: Array = game.craft.pending.get(a.id, [])
			s.locked = locked
			s.stack_existing = existing.size()
			s.stack_pending = pend.size()
			s.set_node(pend.back() if not pend.is_empty() else (existing.back() if not existing.is_empty() else null), a.id == selected_ability)
			s.dim = pend.is_empty() and not existing.is_empty()
			s.hint = "" if locked else "+"
			s.can_drop = func(d): return not locked and d.src == "inv" and game.graft_check(a.id, d.node)[0]
			s.on_drop = func(d): game.craft_add(a.id, d.idx); selected_ability = a.id; _pop(s)
			s.on_click = func(_dbl):
				if locked:
					return
				if hud.sel_inv >= 0:
					game.craft_add(a.id, hud.sel_inv); hud.sel_inv = -1
				selected_ability = a.id if selected_ability != a.id else ""
				hud.show_structure_of("base", a.id)
			s.tooltip_fn = func(): return _slot_tip(a, locked)
			s.drop_hint = func(d):
				if locked:
					return T.t("drop_locked", {"g": int(a.grade)})
				var res: Array = game.graft_check(a.id, d.node) if d.src == "inv" else [false, []]
				return T.t("drop_graft", {"ability": game.rl.ability_name(b.rune, a.id)}) if res[0] else ("✗ " + (str(res[1][0]) if res[1].size() > 0 else T.t("incompatible")))
			add_child(s)
			var txt: String = game.rl.ability_name(b.rune, a.id)
			if locked:
				txt = T.t("grade_short", {"g": int(a.grade)})
			var l := S.label(txt, 11, S.TEXT_MUTED if locked else S.TEXT_DIM, "bold")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(92, 0)
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.add_theme_constant_override("outline_size", 4)
			l.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 0.9))
			add_child(l)
			ab_slots.append({"slot": s, "ability": a, "label": l, "ang": ang, "locked": locked})
	var fee: int = game.craft_fee()
	craft_btn.text = (T.t("craft") + "  %d" % fee) if fee > 0 else T.t("craft")
	craft_btn.icon = UISkin.tex("icon_mana") if fee > 0 else null
	var why := ""
	if game.craft.output != null:
		why = T.t("status_take_output")
	elif b == null:
		why = T.t("status_need_base")
	elif game.craft.pending.is_empty():
		why = T.t("status_need_graft")
	elif game.mana < fee:
		why = T.t("status_need_mana", {"n": fee})
	else:
		var k := 0
		for ab in game.craft.pending:
			k += game.craft.pending[ab].size()
		why = T.t("status_ready", {"n": k})
	status.text = why
	status.add_theme_color_override("font_color", S.BAD if game.mana < fee and b != null and not game.craft.pending.is_empty() else S.TEXT_MUTED)
	craft_btn.disabled = b == null or game.craft.pending.is_empty() or game.craft.output != null
	craft_btn.tooltip_text = why if craft_btn.disabled else ""
	_layout()
	queue_redraw()


func _slot_tip(a: Dictionary, locked: bool) -> String:
	var b = game.craft.base
	var t := "[b][color=#ECE6D6]%s[/color][/b]\n" % game.rl.ability_name(b.rune, a.id)
	if locked:
		return t + "[color=#8C877D]%s[/color]" % T.t("tip_ability_locked", {"g": int(a.grade)})
	t += "[color=#8C877D]%s[/color]\n" % game.rl.carrier_name(a.carrier)
	var existing: Array = b.grafts.get(a.id, [])
	var pend: Array = game.craft.pending.get(a.id, [])
	if existing.is_empty() and pend.is_empty():
		t += T.t("tip_ability_empty")
	for d in existing:
		t += "• %s G%d [color=#8C877D](%s)[/color]\n" % [game.rl.rune_name(d.rune), int(d.grade), T.t("grafted")]
	for d in pend:
		t += "• %s G%d [color=#9FD3FF](%s)[/color]\n" % [game.rl.rune_name(d.rune), int(d.grade), T.t("pending")]
	return t.strip_edges()


func _layout() -> void:
	base_slot.position = (CIRCLE_C - base_slot.size * 0.5).round()
	for a in ab_slots:
		var p: Vector2 = CIRCLE_C + Vector2(cos(a.ang), sin(a.ang)) * SLOT_R
		a.slot.position = (p - Vector2(AB, AB) * 0.5).round()
		# labels sit outside the socket: under it on the lower half, above it on the upper half
		var below: bool = sin(a.ang) > -0.2
		a.label.size = Vector2(92, 16)
		var lp := p + Vector2(-46, AB * 0.5 + 1.0 if below else -AB * 0.5 - 17.0)
		lp.x = clampf(lp.x, 0.0, COL_X - 96.0)
		a.label.position = lp.round()
	var cx := COL_X + 69.0
	out_title.position = Vector2(COL_X, 14)
	out_title.size = Vector2(138, 16)
	out_slot.position = Vector2(cx - 32, 34)
	craft_btn.position = Vector2(COL_X + 3, 112)
	craft_btn.size = Vector2(132, 42)
	status.position = Vector2(COL_X, 160)
	status.size = Vector2(138, 60)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _pop(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	c.scale = Vector2(1.18, 1.18)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _craft() -> void:
	if game.craft.base == null or game.craft.pending.is_empty():
		game.do_craft()
		return
	var fee: int = game.craft_fee()
	if game.mana < fee:
		game.do_craft()          # shows the message
		return
	# converge animation, then the real craft
	for a in ab_slots:
		if a.slot.stack_pending > 0:
			for k in 6:
				sparks.append({"from": a.slot.position + Vector2(AB, AB) * 0.5, "to": CIRCLE_C, "t": -k * 0.05, "c": _rune_col(a.slot.node)})
	charge = 0.001
	craft_btn.disabled = true
	var tw := create_tween()
	tw.tween_method(func(v): charge = v; spin_speed = 0.18 + v * 6.0, 0.0, 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		game.do_craft()
		flash = 1.0
		charge = 0.0
		spin_speed = 0.18
		for k in 10:
			sparks.append({"from": CIRCLE_C, "to": out_slot.position + Vector2(32, 32), "t": -k * 0.03, "c": S.RUNE})
		_pop(out_slot)
		hud.burst_at(out_slot.get_global_rect().get_center(), S.RUNE)
		hud.show_structure_of("output")
	)


func _rune_col(node) -> Color:
	if node == null:
		return S.TRIM_LIGHT
	return Color(game.rune_colors(node.rune).glow)


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	spin += dt * spin_speed
	flash = maxf(0.0, flash - dt * 2.0)
	for sp in sparks.duplicate():
		sp.t += dt * 1.6
		if sp.t >= 1.0:
			sparks.erase(sp)
	queue_redraw()


func _draw() -> void:
	var c := CIRCLE_C
	var pend := 0
	for a in ab_slots:
		pend += a.slot.stack_pending
	var glow: float = clampf(0.25 + 0.15 * pend + charge * 0.8 + flash, 0.0, 1.6)
	var rune := S.RUNE
	# engraved stone disc: Penpot export (rcui / craft_circle), slowly turning; its glyph light follows the charge
	draw_set_transform(c, spin * 0.35, Vector2.ONE)
	draw_texture_rect(UISkin.tex("craft_circle"), Rect2(Vector2(-DISC_D, -DISC_D) * 0.5, Vector2(DISC_D, DISC_D)), false, Color(1, 1, 1, 0.75 + 0.25 * minf(glow, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# conduits from the ability sockets to the centre (between the sockets, never through them)
	for a in ab_slots:
		if a.locked:
			continue
		var sp: Vector2 = a.slot.position + Vector2(AB, AB) * 0.5
		var has_p: bool = a.slot.stack_pending > 0
		var col := _rune_col(a.slot.node) if a.slot.node != null else Color(rune, 0.4)
		var p0 := sp.lerp(c, 0.36)
		var p1 := c.lerp(sp, 0.42)
		draw_line(p0, p1, Color(S.BEVEL_DARK, 0.9), 4.0, true)
		draw_line(p0, p1, Color(col, 0.25 + (0.5 if has_p else 0.0) + charge * 0.4), 2.0 if has_p else 1.0, true)
		if has_p:
			var u := fmod(spin * 2.0 + float(a.slot.index) * 0.3, 1.0)
			var q := p0.lerp(p1, u)
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color(col, 0.9))
	# chiselled arrow to the output column
	var ax := COL_X - 22.0
	var ay := 66.0
	var ac := Color(S.GOLD, 0.5 + 0.4 * glow) if game.craft.base != null else Color(S.TRIM_DARK, 0.9)
	var tri := PackedVector2Array([Vector2(ax + 18, ay), Vector2(ax + 9, ay - 7), Vector2(ax + 9, ay + 7)])
	draw_line(Vector2(ax - 8, ay + 1), Vector2(ax + 12, ay + 1), Color(0, 0, 0, 0.6), 4.0, true)
	draw_line(Vector2(ax - 8, ay), Vector2(ax + 12, ay), ac, 3.0, true)
	draw_colored_polygon(tri, ac)
	# crafting flash (only while the craft plays)
	if charge > 0.0 or flash > 0.0:
		draw_texture_rect(UISkin.tex("vfx_ring"), Rect2(c - Vector2(60, 60) * (1.0 + charge), Vector2(120, 120) * (1.0 + charge)), false, Color(rune, 0.5 * (charge + flash)))
	for sp in sparks:
		if sp.t < 0.0:
			continue
		var u: float = sp.t
		var p: Vector2 = (sp.from as Vector2).lerp(sp.to, u * u)
		var sz := 8.0 * (1.0 - u) + 3.0
		draw_texture_rect(UISkin.tex("vfx_spark"), Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(sp.c, 1.0 - u))
