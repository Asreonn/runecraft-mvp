extends "res://tests/run_all.gd"
## UI interaction + layout checks, run with a real renderer and a real window size:
##   gamescope --backend headless -w W -h H -- godot --path . --resolution WxH --script res://tests/ui/run_ui.gd -- [--lang tr] [--shots DIR]
## Mouse input is synthesized and pushed through the viewport's normal input path (hover, press, motion with the
## button held → Godot's own drag & drop, release, right-click, keys), so the GUI code paths are the ones a player
## hits. It is not a human with a mouse: feel, timing and pointer precision are not covered.

var shots := ""
var lang := "en"
var _shot_n := 0
var _last := Vector2.ZERO


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--shots" and i + 1 < a.size():
			shots = a[i + 1]
		if a[i] == "--lang" and i + 1 < a.size():
			lang = a[i + 1]
	_ui_run.call_deferred()


func _ui_run() -> void:
	var g = await fresh_game()
	if g == null:
		_done()
		return
	if lang != "en":
		# relaunch-free language switch for the test: rebuild the HUD with the other locale
		g.settings["lang"] = lang
		g.rl.set_locale("res://scripts/locale/%s.json" % lang)
		preload("res://ui/i18n.gd").load_lang(lang)
		g.hud.queue_free()
		await process_frame
		g.hud = load("res://ui/hud.gd").new()
		g.add_child(g.hud)
		g.hud.setup(g)
	await _wait(0.8)                                  # intro tweens
	var vp: Vector2 = g.hud.root.get_viewport_rect().size
	context = "ui[%dx%d %s]" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y, lang]
	print("UI canvas %s  window %s" % [vp, DisplayServer.window_get_size()])
	await _layout_checks(g, vp)
	await _drag_checks(g)
	await _inspector_checks(g, vp)
	await _tree_checks(g)
	_done()


func _done() -> void:
	print("%d/%d checks passed" % [passed, checks])
	for f in failures:
		print(f)
	quit(0 if passed == checks else 1)


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	_shot_n += 1
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [shots, _shot_n, name])


# ------------------------------------------------------------------ synthetic mouse

func _move(p: Vector2, held := false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	e.relative = p - _last                  # Godot accumulates this against the drag threshold
	e.velocity = e.relative * 60.0
	_last = p
	root.push_input(e, true)
	await process_frame


func _button(p: Vector2, idx: int, pressed: bool, dbl := false) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = idx
	e.pressed = pressed
	e.double_click = dbl
	e.button_mask = (MOUSE_BUTTON_MASK_LEFT if idx == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(e, true)
	await process_frame


func _click(p: Vector2, idx := MOUSE_BUTTON_LEFT) -> void:
	await _move(p)
	await _button(p, idx, true)
	await _button(p, idx, false)
	await process_frame


func _drag(a: Vector2, b: Vector2) -> void:
	await _move(a)
	await _button(a, MOUSE_BUTTON_LEFT, true)
	for k in range(1, 13):
		await _move(a.lerp(b, k / 12.0), true)
	await _move(b, true)
	await _button(b, MOUSE_BUTTON_LEFT, false)
	await process_frame
	await process_frame


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	root.push_input(e)
	await process_frame


func _c(ctrl: Control) -> Vector2:
	return ctrl.get_global_rect().get_center()


# ------------------------------------------------------------------ layout

func _inside(r: Rect2, box: Rect2) -> bool:
	return box.grow(1.0).encloses(r)


## Every visible control under `holder` stays inside it (catches text / layout overflow in any language).
func _overflow(holder: Control) -> Array:
	var bad := []
	var box := holder.get_global_rect().grow(2.0)
	var stack: Array = [holder]
	while not stack.is_empty():
		var c = stack.pop_back()
		for ch in c.get_children():
			if ch is Control and ch.is_visible_in_tree():
				var r: Rect2 = ch.get_global_rect()
				if r.size.x > 0.5 and r.size.y > 0.5 and not box.encloses(r):
					bad.append("%s %s" % [ch.get_class(), r])
				stack.append(ch)
	return bad


func _deep() -> Dictionary:
	return node("fire", 3, {"fire_hit": [node("electric", 3, {"chain": [node("ice", 2), node("poison", 1, {"poison_tick": [node("blood")]})]}),
		node("water", 3, {"push": [node("blood")]}), node("stone", 2)],
		"burn": [node("mana", 3), node("stone", 2, {"armor_shred": [node("light")]}), node("light", 2), node("ice", 1)],
		"fire_trail": [node("ice", 3, {"freeze": [node("electric", 2)]}), node("golem"), node("hive", 2), node("meteor", 1)]})


func _layout_checks(g, vp: Vector2) -> void:
	var screen := Rect2(Vector2.ZERO, vp)
	var hud = g.hud
	# a full inventory and a deep table rune: worst case for the Craft tab
	for i in g.INV_SIZE:
		g.inventory[i] = node(["fire", "ice", "electric", "water", "golem", "mana"][i % 6], 1 + i % 5)
	g.craft.base = _deep()
	g.craft.pending = {"fire_hit": [node("stone")]}
	hud.show_structure_of("base")
	g.changed.emit()
	await _wait(0.3)
	var off := 0
	for s in hud.inv_slots:
		if not _inside(s.get_global_rect(), screen):
			off += 1
	check(off == 0, "all 24 inventory slots on screen", "%d off-screen" % off)
	var order_ok: bool = hud.table.get_global_rect().end.y <= hud.struct_tree.get_global_rect().position.y + 1 \
		and hud.struct_tree.get_global_rect().end.y <= hud.struct_cap.get_global_rect().position.y + 1 \
		and hud.struct_cap.get_global_rect().end.y <= hud.inv_grid.get_global_rect().position.y + 1
	check(order_ok, "Craft tab order: crafting → structure → inventory, no overlap")
	check(hud.struct_tree.size.y >= 120.0, "structure area keeps a usable height", str(hud.struct_tree.size))
	check(hud.struct_tree.overlaps() == 0, "compact tree: no overlapping nodes", str(hud.struct_tree.overlaps()))
	check(hud.struct_tree.out_of_bounds() == 0, "compact tree: nodes inside its area", str(hud.struct_tree.out_of_bounds()))
	var panel: Control = hud.root.get_node("RightPanel")
	check(_inside(panel.get_global_rect(), screen), "right panel on screen")
	var ov := _overflow(hud.pages["craft"])
	check(ov.is_empty(), "craft page: nothing overflows the panel", str(ov.slice(0, 3)))
	# tower card with a long rune (biggest numbers / name) stays inside the card and the screen
	var t = build(g)
	t.set_rune(_deep())
	g.select_tower(t)
	g.changed.emit()
	await _wait(0.2)
	check(_inside(hud.tower_card.get_global_rect(), screen), "tower card on screen")
	var ovc := _overflow(hud.tower_card)
	check(ovc.is_empty(), "tower card: nothing overflows", str(ovc.slice(0, 3)))
	await _shot("craft_full")
	# tooltip near every corner of the panel / screen: always fully on screen
	var big := _deep()
	for s in [hud.inv_slots[0], hud.inv_slots[23], hud.sock_slot, hud.table.base_slot]:
		hud.show_tip(hud.tip_for(big), s)
		await process_frame
		check(_inside(hud.tip.get_global_rect(), screen), "tooltip on screen for %s" % s.kind, str(hud.tip.get_global_rect()))
		check(not hud.tip.get_global_rect().intersects(s.get_global_rect().grow(-2)), "tooltip does not cover its own slot (%s)" % s.kind)
	await _shot("tooltip")
	hud.hide_tip(hud.tip_owner)
	# shop and menu pages fit too (long localized strings)
	for tab in ["shop", "menu"]:
		hud.select_tab(tab, false)
		if tab == "menu":
			hud.settings_box.visible = true
		await _wait(0.1)
		var o := _overflow(hud.pages[tab])
		check(o.is_empty(), "%s page: nothing overflows" % tab, str(o.slice(0, 3)))
		await _shot(tab)
	hud.settings_box.visible = false
	hud.select_tab("craft", false)
	g.sell_tower(t)
	g.craft.base = null
	g.craft.pending = {}
	for i in g.INV_SIZE:
		g.inventory[i] = null
	g.changed.emit()
	await _wait(0.2)


# ------------------------------------------------------------------ drag & drop

func _drag_checks(g) -> void:
	var hud = g.hud
	g.inventory[0] = node("ice", 3)
	g.inventory[1] = node("electric", 2)
	g.inventory[2] = node("stone", 1)
	g.inventory[3] = node("golem", 1)
	g.inventory[4] = node("fire", 1)
	g.inventory[5] = node("fire", 1)
	g.changed.emit()
	await _wait(0.1)
	# hover → tooltip; leave → gone
	await _move(_c(hud.inv_slots[0]))
	await _wait(0.1)
	check(hud.tip.visible and hud.tip_owner == hud.inv_slots[0], "hovering a rune shows its tooltip")
	await _move(Vector2(40, 600))
	check(not hud.tip.visible, "leaving the slot hides the tooltip")
	# drag inventory → base socket
	await _drag(_c(hud.inv_slots[0]), _c(hud.table.base_slot))
	check(g.craft.base != null and g.craft.base.rune == "ice" and g.inventory[0] == null, "drag inventory → base sets the table rune")
	await _wait(0.1)
	# drag a compatible donor onto an ability socket
	var ab_freeze = null
	var ab_locked = null
	for a in hud.table.ab_slots:
		if a.ability.id == "freeze":
			ab_freeze = a.slot
		if a.locked and ab_locked == null:
			ab_locked = a.slot
	check(ab_freeze != null and ab_locked != null, "Ice G3 shows open and locked ability sockets")
	if ab_freeze == null or ab_locked == null:
		return
	await _drag(_c(hud.inv_slots[1]), _c(ab_freeze))
	check(g.craft.pending.get("freeze", []).size() == 1 and g.inventory[1] == null, "drag donor → ability socket queues a pending graft")
	await _wait(0.1)
	for a in hud.table.ab_slots:                       # the table rebuilt its sockets after the drop
		if a.locked:
			ab_locked = a.slot
			break
	# a drop on a locked socket changes nothing, and the socket shows the invalid state while hovered
	var before := var_to_str([g.inventory, g.craft])
	await _move(_c(hud.inv_slots[2]))
	await _button(_c(hud.inv_slots[2]), MOUSE_BUTTON_LEFT, true)
	for k in range(1, 13):
		await _move(_c(hud.inv_slots[2]).lerp(_c(ab_locked), k / 12.0), true)
	await _wait(0.15)
	await _move(_c(ab_locked), true)
	check(ab_locked.bad_t > 0.05, "locked socket shows the red 'cannot drop' state under a drag", str(ab_locked.bad_t))
	await _shot("drag_locked")
	await _button(_c(ab_locked), MOUSE_BUTTON_LEFT, false)
	await process_frame
	check(var_to_str([g.inventory, g.craft]) == before, "drop on a locked ability socket changes nothing")
	# combine by dropping equal runes onto each other
	await _drag(_c(hud.inv_slots[4]), _c(hud.inv_slots[5]))
	check(g.inventory[5] != null and int(g.inventory[5].grade) == 2 and g.inventory[4] == null, "drop equal runes → combine to G2")
	# swap by dropping on an occupied different rune
	var a3 = g.inventory[3]
	var a2 = g.inventory[2]
	await _drag(_c(hud.inv_slots[3]), _c(hud.inv_slots[2]))
	check(is_same(g.inventory[2], a3) and is_same(g.inventory[3], a2), "drop on a different rune swaps")
	# take a pending donor back with the structure plaque button
	hud.show_structure_of("base", "freeze")
	await _wait(0.1)
	var it = hud.struct_tree.root_item
	var pend_item = null
	for ab in it.kids:
		if ab.ability == "freeze" and not ab.kids.is_empty():
			pend_item = ab.kids[0]
	check(pend_item != null and pend_item.pending, "pending donor appears in the structure tree as pending")
	if pend_item != null:
		await _click(hud.struct_tree.node_center(pend_item))
		check(hud.struct_act.visible, "picking a pending donor offers 'take back'")
		await _click(_c(hud.struct_act))
		check(g.craft.pending.is_empty(), "take back removes the pending donor")
	# double-click an inventory rune with a tower selected → socket it
	var t = build(g)
	g.select_tower(t)
	await process_frame
	await _move(_c(hud.inv_slots[5]))
	await _button(_c(hud.inv_slots[5]), MOUSE_BUTTON_LEFT, true, true)
	await _button(_c(hud.inv_slots[5]), MOUSE_BUTTON_LEFT, false)
	check(t.rune != null and t.rune.rune == "fire", "double-click with a tower selected sockets the rune")
	g.sell_tower(t)
	g.craft_clear()
	g.changed.emit()
	await _wait(0.1)


# ------------------------------------------------------------------ inspector

func _inspector_checks(g, vp: Vector2) -> void:
	var hud = g.hud
	var ins = hud.inspector
	var screen := Rect2(Vector2.ZERO, vp)
	g.inventory[6] = _deep()
	g.changed.emit()
	await process_frame
	# right-click opens it, tooltip goes away, panel fits the screen, the full tree does not overlap
	await _move(_c(hud.inv_slots[6]))
	await _wait(0.05)
	await _click(_c(hud.inv_slots[6]), MOUSE_BUTTON_RIGHT)
	await _wait(0.3)
	check(ins.visible and is_same(ins.node, g.inventory[6]), "right-click opens the inspector on that rune")
	check(not hud.tip.visible, "the tooltip is hidden while the inspector is open")
	check(_inside(ins.panel.get_global_rect(), screen), "inspector panel on screen", str(ins.panel.get_global_rect()))
	check(ins.tree.overlaps() == 0, "inspector tree: no overlapping nodes", str(ins.tree.overlaps()))
	check(ins.tree.out_of_bounds() == 0, "inspector tree: nodes inside its area", str(ins.tree.out_of_bounds()))
	var deep_count := 0
	for it in ins.tree.all_items():
		if it.kind == "rune":
			deep_count += 1
	check(deep_count == g.rl.node_size(g.inventory[6]), "inspector shows every rune of the recipe", "%d vs %d" % [deep_count, g.rl.node_size(g.inventory[6])])
	await _shot("inspector")
	# picking a nested donor shows its contribution text
	var nested = null
	for it in ins.tree.all_items():
		if it.kind == "rune" and it.depth == 2:
			nested = it
			break
	if nested != null:
		await _click(ins.tree.node_center(nested))
		check(ins.picked_item == nested and ins.detail.get_parsed_text().contains(g.rl.rune_name(nested.rune)), "clicking a nested donor shows its details")
		await _shot("inspector_nested")
	# world is blocked: B does not enter build mode, a click in the world does not reach the game
	var bm: bool = g.build_mode
	await _key(KEY_B)
	check(g.build_mode == bm, "hotkey B is swallowed while the inspector is open")
	# a click inside the panel keeps it open
	await _click(ins.panel.get_global_rect().position + Vector2(40, ins.panel.size.y - 30))
	check(ins.visible, "clicking inside the panel keeps it open")
	# Esc closes
	await _key(KEY_ESCAPE)
	check(not ins.visible, "Esc closes the inspector")
	# click outside closes, and that click does not switch tabs underneath
	hud.inspect(g.inventory[6])
	await _wait(0.2)
	await _click(_c(hud.tabs["shop"]))
	check(not ins.visible and hud.current_tab == "craft", "a click outside closes it and does not reach the tab underneath")
	# rune consumed by a combine → closes
	g.inventory[7] = node("water", 2)
	g.inventory[8] = node("water", 2)
	g.changed.emit()
	hud.inspect(g.inventory[7])
	await _wait(0.1)
	g.combine(8, 7)
	await _wait(0.1)
	check(not ins.visible, "inspector closes when its rune is consumed")
	# tower: rune swapped → follows; rune removed → closes; tower sold → closes
	var t = build(g)
	t.set_rune(node("fire", 2))
	g.select_tower(t)
	g.changed.emit()
	await _wait(0.1)
	await _click(_c(hud.inspect_btn))
	await _wait(0.2)
	check(ins.visible and is_same(ins.node, t.rune), "Inspect on the tower card opens the tower's rune")
	g.inventory[9] = node("electric", 3)
	g.socket(t, 9)
	await _wait(0.1)
	check(ins.visible and ins.node.rune == "electric", "rune swapped on the tower → inspector follows the new rune")
	g.unsocket(t)
	await _wait(0.1)
	check(not ins.visible, "rune removed from the tower → inspector closes")
	g.socket(t, g.inventory.find(g.inventory.filter(func(x): return x != null and x.rune == "electric")[0]))
	hud.inspect(t.rune, {"kind": "tower", "tower": t})
	await _wait(0.1)
	g.sell_tower(t)
	await _wait(0.1)
	check(not ins.visible, "tower sold → inspector closes")
	# in-place edit of the shown rune (ungraft on the table) rebuilds the view
	g.craft_clear()
	var host := node("ice", 3, {"freeze": [node("electric", 2)]})
	g.inventory[10] = host
	g.craft_set_base(10)
	hud.inspect(g.craft.base)
	await _wait(0.1)
	var before: int = ins.tree.all_items().size()
	g.craft_ungraft("freeze", 0)
	await _wait(0.1)
	check(ins.visible and ins.tree.all_items().size() < before, "ungraft on the shown rune refreshes the inspector tree")
	# save / load while open → closes (the loaded game owns new rune objects)
	g.craft_clear()
	g.wave_state = "build"
	var path := ProjectSettings.globalize_path("res://tests/artifacts/ui_save.json")
	g.save_game(path)
	hud.inspect(g.inventory[6])
	await _wait(0.1)
	g.load_game(path)
	await _wait(0.3)
	var hud2 = g.hud if is_instance_valid(g) else null
	check(hud2 == null or not hud2.inspector.visible or not is_same(hud2.inspector.node, _deep()), "load while inspecting never leaves a stale rune on screen")
	if is_instance_valid(g) and is_instance_valid(g.hud):
		check(not g.hud.inspector.visible, "inspector closed after load")


# ------------------------------------------------------------------ compact tree interactions

func _tree_checks(g) -> void:
	if not is_instance_valid(g):
		return
	var hud = g.hud
	g.craft_clear()
	g.inventory[11] = node("ice", 3, {"freeze": [node("electric", 3, {"chain": [node("poison")]})], "chill": [node("water", 2)]})
	g.craft_set_base(11)
	hud.show_structure_of("base")
	await _wait(0.2)
	var root_it = hud.struct_tree.root_item
	var freeze = null
	for ab in root_it.kids:
		if ab.ability == "freeze":
			freeze = ab
	await _click(hud.struct_tree.node_center(freeze))
	check(hud.struct_pick == freeze, "clicking an ability node picks it")
	check(hud.struct_cap.get_parsed_text().contains(g.rl.ability_name("ice", "freeze")), "the caption describes the picked ability")
	await _move(hud.struct_tree.node_center(freeze.kids[0]))
	await process_frame
	check(hud.struct_cap.get_parsed_text().contains(g.rl.rune_name("electric")), "hovering a donor previews it in the caption")
	await _move(Vector2(40, 600))
	check(hud.struct_cap.get_parsed_text().contains(g.rl.ability_name("ice", "freeze")), "leaving returns the caption to the picked node")
	await _shot("structure_pick")
	# Details opens the inspector on the same rune
	await _click(_c(hud.details_btn))
	await _wait(0.2)
	check(hud.inspector.visible and is_same(hud.inspector.node, g.craft.base), "Details opens the inspector for the shown rune")
	await _key(KEY_ESCAPE)
