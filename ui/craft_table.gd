extends Control
## Minecraft-style crafting table with a runic magic circle:
##   base rune in the centre, one slot per open ability around it (a stack of donors),
##   an arrow to the output slot, "Craft" under it. The circle slowly turns; engraved marks
##   glow with the number of pending donors; crafting plays a converge + flash animation.

const S := preload("res://ui/style.gd")
const Slot := preload("res://ui/slot.gd")
const UISkin := preload("res://ui/skin.gd")

var game
var hud
var base_slot
var out_slot
var craft_btn: Button
var ab_slots: Array = []         # [{slot, ability, label}]
var selected_ability := ""
var spin := 0.0
var spin_speed := 0.18
var charge := 0.0                # 0..1 craft animation
var flash := 0.0
var sparks: Array = []
const CIRCLE_C := Vector2(136, 146)
const RING_R := 110.0
const SLOT_R := 94.0


func _init(g, h) -> void:
	game = g
	hud = h
	custom_minimum_size = Vector2(388, 304)
	mouse_filter = Control.MOUSE_FILTER_PASS
	base_slot = Slot.new(game, "base", -1, Vector2(76, 76))
	base_slot.hint = "Base"
	base_slot.can_drop = func(d): return d.src == "inv"
	base_slot.on_drop = func(d): game.craft_set_base(d.idx); _pop(base_slot)
	base_slot.on_click = func(_dbl):
		if hud.sel_inv >= 0:
			game.craft_set_base(hud.sel_inv); hud.sel_inv = -1; _pop(base_slot)
	base_slot.tooltip_fn = func(): return hud.tip_for(game.craft.base)
	base_slot.drop_hint = func(_d): return "Set as base" if game.craft.base == null else "Replace base"
	add_child(base_slot)
	out_slot = Slot.new(game, "output", -1, Vector2(76, 76))
	out_slot.hint = "?"
	out_slot.on_click = func(_dbl): game.take_output()
	out_slot.tooltip_fn = func(): return hud.tip_for(game.craft.output)
	add_child(out_slot)
	craft_btn = Button.new()
	craft_btn.text = "Craft"
	UISkin.button(craft_btn, "btn_gold")
	craft_btn.add_theme_font_override("font", S.font("bold"))
	craft_btn.add_theme_font_size_override("font_size", 15)
	craft_btn.custom_minimum_size = Vector2(110, 38)
	craft_btn.pressed.connect(_craft)
	add_child(craft_btn)


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
		var abs: Array = game.open_abilities(b)
		var n := abs.size()
		for i in n:
			var a: Dictionary = abs[i]
			var ang := -PI * 0.5 + TAU * float(i) / maxf(n, 1)
			if n == 1:
				ang = -PI * 0.5
			var s = Slot.new(game, "graft_add", i, Vector2(54, 54))
			var existing: Array = b.grafts.get(a.id, [])
			var pend: Array = game.craft.pending.get(a.id, [])
			s.stack_existing = existing.size()
			s.stack_pending = pend.size()
			s.set_node(pend.back() if not pend.is_empty() else (existing.back() if not existing.is_empty() else null), a.id == selected_ability)
			s.dim = pend.is_empty() and not existing.is_empty()
			s.hint = "+"
			s.can_drop = func(d): return d.src == "inv" and game.graft_check(a.id, d.node)[0]
			s.on_drop = func(d): game.craft_add(a.id, d.idx); selected_ability = a.id; _pop(s)
			s.on_click = func(_dbl):
				if hud.sel_inv >= 0:
					game.craft_add(a.id, hud.sel_inv); hud.sel_inv = -1
				selected_ability = a.id if selected_ability != a.id else ""
				hud.refresh()
			s.tooltip_fn = func(): return _slot_tip(a)
			s.drop_hint = func(d):
				var res: Array = game.graft_check(a.id, d.node) if d.src == "inv" else [false, []]
				return ("Graft → %s" % game.rl.ability_name(b.rune, a.id)) if res[0] else ("✗ " + (str(res[1][0]) if res[1].size() > 0 else "incompatible"))
			add_child(s)
			var l := S.label(game.rl.ability_name(b.rune, a.id), 11, S.TEXT_DIM, "bold")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(96, 0)
			add_child(l)
			ab_slots.append({"slot": s, "ability": a, "label": l, "ang": ang})
	var fee: int = game.craft_fee()
	craft_btn.text = ("Craft  %d" % fee) if fee > 0 else "Craft"
	craft_btn.disabled = b == null or game.craft.pending.is_empty() or game.craft.output != null
	_layout()
	queue_redraw()


func _slot_tip(a: Dictionary) -> String:
	var b = game.craft.base
	var t := "[b][color=#ECE6D6]%s[/color][/b] — %s\n" % [game.rl.ability_name(b.rune, a.id), game.rl.carrier_name(a.carrier)]
	var existing: Array = b.grafts.get(a.id, [])
	var pend: Array = game.craft.pending.get(a.id, [])
	if existing.is_empty() and pend.is_empty():
		t += "Empty. Drop a rune from the inventory."
	for d in existing:
		t += "• %s G%d [color=#8C877D](grafted)[/color]\n" % [game.rl.rune_name(d.rune), int(d.grade)]
	for d in pend:
		t += "• %s G%d [color=#9FD3FF](pending)[/color]\n" % [game.rl.rune_name(d.rune), int(d.grade)]
	t += "\n[color=#8C877D]Click: show / hide this slot's grafts[/color]"
	return t


func _layout() -> void:
	base_slot.position = CIRCLE_C - base_slot.size * 0.5
	for a in ab_slots:
		var p: Vector2 = CIRCLE_C + Vector2(cos(a.ang), sin(a.ang)) * SLOT_R
		a.slot.position = p - Vector2(27, 27)
		a.label.position = p + Vector2(-48, 26)
	out_slot.position = Vector2(340 - 38, CIRCLE_C.y - 64)
	craft_btn.position = Vector2(340 - 55, CIRCLE_C.y + 26)
	craft_btn.size = Vector2(110, 38)


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
				sparks.append({"from": a.slot.position + Vector2(27, 27), "to": CIRCLE_C, "t": -k * 0.05, "c": _rune_col(a.slot.node)})
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
			sparks.append({"from": CIRCLE_C, "to": out_slot.position + Vector2(38, 38), "t": -k * 0.03, "c": S.RUNE})
		_pop(out_slot)
		hud.burst_at(out_slot.get_global_rect().get_center(), S.RUNE)
	)


func _rune_col(node) -> Color:
	if node == null:
		return S.TRIM_LIGHT
	return Color(game.rune_colors(node.rune).glow)


func _process(dt: float) -> void:
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
	# engraved stone disc: Penpot export (rcui / craft_circle), slowly turning; the rune light pulses over it
	var dr := (RING_R + 22.0) * 2.0
	draw_set_transform(c, spin * 0.35, Vector2.ONE)
	draw_texture_rect(UISkin.tex("craft_circle"), Rect2(Vector2(-dr, -dr) * 0.5, Vector2(dr, dr)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(UISkin.tex("vfx_glow"), Rect2(c - Vector2(dr, dr) * 0.45, Vector2(dr, dr) * 0.9), false, Color(rune, 0.05 + 0.10 * glow))
	for rr in [RING_R + 12.0, RING_R - 12.0, 54.0]:
		draw_arc(c, rr, 0, TAU, 96, Color(rune, 0.06 + 0.2 * glow), 1.2, true)
	# conduits from ability slots to the centre
	for a in ab_slots:
		var sp: Vector2 = a.slot.position + Vector2(27, 27)
		var has_p: bool = a.slot.stack_pending > 0
		var col := _rune_col(a.slot.node) if a.slot.node != null else Color(rune, 0.4)
		draw_line(sp.lerp(c, 0.32), c.lerp(sp, 0.48), Color(S.BEVEL_DARK, 0.9), 4.0, true)
		draw_line(sp.lerp(c, 0.32), c.lerp(sp, 0.48), Color(col, 0.25 + (0.5 if has_p else 0.0) + charge * 0.4), 2.0 if has_p else 1.0, true)
		if has_p:
			var u := fmod(spin * 2.0 + float(a.slot.index) * 0.3, 1.0)
			draw_circle(sp.lerp(c, 0.32 + 0.2 * u), 2.5, Color(col, 0.9))
	# chiselled arrow to the output
	var ax := RING_R + c.x + 14.0
	var ay := c.y - 22.0
	var ac := Color(S.GOLD, 0.5 + 0.4 * glow) if game.craft.base != null else Color(S.TRIM_DARK, 0.9)
	var tri := PackedVector2Array([Vector2(ax + 22, ay), Vector2(ax + 13, ay - 7), Vector2(ax + 13, ay + 7)])
	draw_line(Vector2(ax - 4, ay + 1), Vector2(ax + 16, ay + 1), Color(0, 0, 0, 0.6), 4.0, true)
	draw_line(Vector2(ax - 4, ay), Vector2(ax + 16, ay), ac, 3.0, true)
	draw_colored_polygon(tri, ac)
	# core flash
	if charge > 0.0 or flash > 0.0:
		draw_circle(c, 40.0 + 30.0 * charge, Color(rune, 0.12 * (charge + flash)))
		draw_circle(c, 18.0 + 10.0 * flash, Color(0.9, 1.0, 1.0, 0.5 * flash))
	for sp in sparks:
		if sp.t < 0.0:
			continue
		var u: float = sp.t
		var p: Vector2 = (sp.from as Vector2).lerp(sp.to, u * u)
		draw_circle(p, 3.0 * (1.0 - u) + 1.0, Color(sp.c, 1.0 - u))
