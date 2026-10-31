extends SceneTree
## One-off check: a version-1 save (first public release format) loads into the current game.
func _initialize() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var game = scene
	var cell: Vector2i = game.wb.buildable.keys()[5]
	var v1 := {"version": 1, "seed": game.seed_value, "wave": 3, "mana": 321.5, "stones": 17, "castle_hp": 15,
		"inventory": [{"rune": "fire", "grade": 2.0, "grafts": {}}, null, {"rune": "ice", "grade": 3.0, "grafts": {"chill": [{"rune": "poison", "grade": 1.0, "grafts": {}}]}}],
		"towers": [{"cell": [cell.x, cell.y], "rune": {"rune": "mana", "grade": 3.0, "grafts": {}}}],
		"craft": {"base": null, "pending": {}, "output": {"rune": "water", "grade": 1.0, "grafts": {}}}}
	var path := "user://v1_check.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	var ok: bool = game.load_game(path)
	await process_frame
	var t = game.towers[0] if game.towers.size() > 0 else null
	var checks := [ok, game.wave == 3, absf(game.mana - 321.5) < 0.5, game.stones == 17, game.castle_hp == 15,
		game.towers.size() == 1, t != null and t.cell == cell and t.rune.rune == "mana" and int(t.rune.grade) == 3,
		game.inventory[2] != null and game.inventory[2].grafts.chill[0].rune == "poison" and typeof(game.inventory[2].grade) == TYPE_INT,
		game.craft.output != null and game.craft.output.rune == "water", game.wave_state == "build"]
	print("V1SAVE ", checks, " -> ", "PASS" if not false in checks else "FAIL")
	quit()
