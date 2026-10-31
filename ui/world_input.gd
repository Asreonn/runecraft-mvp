extends Control
## Full-screen catcher under the HUD panels: clicks on the map (build / select tower) and
## drops of runes onto towers.

var game


func _gui_input(ev: InputEvent) -> void:
	if _gui_input_cam(ev):
		accept_event()
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var c = game.mouse_cell()
			if c != null:
				if game.build_mode:
					game.try_build(c)
				else:
					game.select_tower(game.tower_at_cell(c))
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			game.build_mode = false
			game.select_tower(null)
			accept_event()


func _can_drop_data(_p: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("src", "") in ["inv", "output"]):
		return false
	var c = game.mouse_cell()
	var t = game.tower_at_cell(c) if c != null else null
	game.drop_tower = t
	if t == null:
		game.hud.set_drag_hint(self, "", false)
		return false
	var name: String = game.rl.rune_name(data.node.rune)
	game.hud.set_drag_hint(self, ("Socket into tower: %s G%d" % [name, int(data.node.grade)]) if t.rune == null else "Swap (old rune → inventory)", true)
	return true


func _drop_data(_p: Vector2, data: Variant) -> void:
	var t = game.tower_at_cell(game.mouse_cell())
	game.drop_tower = null
	if t != null:
		game.select_tower(t)
		if data.src == "output":
			game.socket_output(t)
		else:
			game.socket(t, data.idx)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and game != null:
		game.drop_tower = null
		game.hud.clear_drag_hint(self)


func _gui_input_cam(ev: InputEvent) -> bool:
	return game.cam_rig != null and game.cam_rig.handle_input(ev)
