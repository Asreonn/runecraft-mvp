extends SceneTree

func _initialize() -> void:
	var library = load("res://scripts/rune_lib.gd").new("res://data/rune_mechanics_v1.json")
	var pairs := [
		["fire3{fire_hit:[water1]}", "fire_hit", "ice2{ice_hit:[stone1]}"],
		["fire3", "fire_hit", "stone1"], ["fire3", "burn", "poison1"],
		["fire3", "fire_trail", "stone1"], ["ice2", "ice_hit", "stone1"],
		["water3", "water_hit", "stone1"]]
	var failed := false
	for pair in pairs:
		var result = library.check_graft(pair[0], pair[1], pair[2])
		print("FIXTURE ", pair, " ", result)
		failed = failed or not result[0]
	quit(1 if failed else 0)
