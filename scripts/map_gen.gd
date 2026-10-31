extends RefCounted
## Pure deterministic data. North is +cell.y; rotations are CCW quarter turns.
const N := 1
const E := 2
const S := 4
const W := 8
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const BITS: Array[int] = [N, E, S, W]
const CANONICAL := {"grass": 0, "path_straight": 5, "path_corner": 3,
	"path_t": 7, "path_cross": 15, "path_end": 4}
const WATER := {"river_straight": 10, "river_corner": 3, "river_t": 11,
	"river_cross": 15, "river_end": 4}
const TREE_SMALL: Array[String] = ["deco_tree_box_small", "deco_tree_cubes_c"]
const TREE_MEDIUM: Array[String] = ["deco_tree_cubes_a", "deco_tree_cubes_b", "deco_tree_box_tall"]
const TREE_BIG: Array[String] = ["deco_tree_box_big", "deco_tree_round", "deco_tree_box_side"]
const VARIANTS: Array[String] = ["", "", "_warm", "_cool"]
const LARGE: Array[String] = ["deco_rock_outcrop", "deco_rock_block_a", "deco_rock_block_b",
	"deco_bush_block_a", "deco_bush_block_b", "deco_log_short", "deco_boulder_large"]
const ROCKS: Array[String] = ["deco_rock_outcrop", "deco_rock_block_a", "deco_rock_block_b",
	"deco_boulder_large", "deco_stone_pair"]
const SMALL: Array[String] = ["deco_bush_block_c", "deco_flower_clover_white",
	"deco_flower_clover_red", "deco_flower_clover_blue", "deco_rock_block_c", "deco_stone_pair", "deco_bush_single"]
const TINY: Array[String] = ["deco_grass_tiny", "deco_grass_tiny", "deco_grass_tiny",
	"deco_grass_tiny", "deco_flower_tiny_white", "deco_flower_tiny_yellow"]
const FOOTPRINTS := {
	"deco_boulder_large": Vector2i(18, 15), "deco_bush_block_a": Vector2i(19, 16),
	"deco_bush_block_b": Vector2i(24, 15), "deco_bush_block_c": Vector2i(14, 14),
	"deco_bush_single": Vector2i(11, 11), "deco_flower_clover_white": Vector2i(8, 8),
	"deco_flower_clover_red": Vector2i(8, 8), "deco_flower_clover_blue": Vector2i(8, 8),
	"deco_flower_tiny_white": Vector2i(3, 3), "deco_flower_tiny_yellow": Vector2i(3, 3),
	"deco_grass_tiny": Vector2i(5, 4), "deco_log_short": Vector2i(14, 5), "deco_reeds": Vector2i(7, 5),
	"deco_rock_block_a": Vector2i(26, 24), "deco_rock_block_b": Vector2i(22, 20),
	"deco_rock_block_c": Vector2i(36, 28), "deco_rock_mountain_a": Vector2i(44, 44),
	"deco_rock_mountain_b": Vector2i(42, 42), "deco_rock_outcrop": Vector2i(22, 22),
	"deco_stone_pair": Vector2i(13, 12), "deco_tree_box_big": Vector2i(44, 36),
	"deco_tree_box_side": Vector2i(31, 23), "deco_tree_box_small": Vector2i(13, 13),
	"deco_tree_box_tall": Vector2i(21, 21), "deco_tree_cubes_a": Vector2i(28, 34),
	"deco_tree_cubes_b": Vector2i(34, 32), "deco_tree_cubes_c": Vector2i(28, 29),
	"deco_tree_round": Vector2i(42, 42),
}
const MAX_ATTEMPTS := 512
const MAX_RUN_STEPS := 5


static func generate(seed: int, w: int = 22, h: int = 14, apron: int = 8) -> Dictionary:
	if w < 12 or h < 9 or apron < 0:
		push_error("v3 needs at least 12 x 9 and a nonnegative apron; infeasible layouts return {}.")
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var layout: Dictionary = {}
	for _attempt in range(MAX_ATTEMPTS):
		var path := _random_path(rng, w, h)
		if not _valid_path(path, w, h):
			continue
		layout = _terrain(path, w, h, apron, rng)
		if not layout.is_empty():
			break
	if layout.is_empty():
		# The deterministic S-curve remains available, but its terrain must fit too.
		var fallback := _fallback_path(w, h)
		if not fallback.is_empty():
			layout = _terrain(fallback, w, h, apron, rng)
	if layout.is_empty():
		push_error("No complete v3 layout for %d x %d." % [w, h])
		return {}
	var path: Array[Vector2i] = layout.path
	var river: Array[Vector2i] = layout.river
	var path_set := _cell_set(path)
	var river_set := _cell_set(river)
	var blocked_set := _cell_set(layout.blocked)
	var mountain_set := _cell_set(layout.mountains)
	var masks := _route_masks(path)
	masks[path[0]] |= W
	var waters := _route_masks(river)
	waters[river[0]] |= N
	waters[river[-1]] |= S
	var plateau_set: Dictionary = {}
	var stairs_set: Dictionary = {}
	for region: Dictionary in layout.plateaus:
		for cell in _rect_cells(region.rect):
			plateau_set[cell] = true
		stairs_set[region.stairs] = region.stairs_rot
	var tiles: Array[Dictionary] = []
	var apron_tiles: Array[Dictionary] = []
	var tile_lookup: Dictionary = {}
	var apron_path: Dictionary = {}
	var apron_water: Dictionary = {}
	for x in range(-apron, 0):
		apron_path[Vector2i(x, path[0].y)] = E | W
	var full_water := _route_masks(layout.full_river)
	full_water[layout.full_river[0]] |= N
	full_water[layout.full_river[-1]] |= S
	for cell: Vector2i in full_water:
		if not _inside(cell, w, h):
			apron_water[cell] = full_water[cell]
	for y in range(-apron, h + apron):
		for x in range(-apron, w + apron):
			var cell := Vector2i(x, y)
			var inside := _inside(cell, w, h)
			var land: int = masks.get(cell, 0) if inside else apron_path.get(cell, 0)
			var water: int = waters.get(cell, 0) if inside else apron_water.get(cell, 0)
			var tile := _tile_v2(cell, land, water, plateau_set.has(cell), stairs_set, rng)
			tile_lookup[cell] = tile
			if inside:
				tiles.append(tile)
			else:
				apron_tiles.append(tile)
	var props: Array[Dictionary] = []
	var apron_props: Array[Dictionary] = []
	var reserved: Dictionary = {}
	for cell: Vector2i in layout.mountains:
		var id := "deco_rock_mountain_a" if rng.randf() < 0.5 else "deco_rock_mountain_b"
		_place(cell, id, true, 0, props, reserved, rng)
	var hazards := path_set.duplicate()
	hazards.merge(river_set)
	hazards.merge(stairs_set)
	var all_hazards := hazards.duplicate()
	all_hazards.merge(apron_path)
	all_hazards.merge(apron_water)
	var noise := _noise_grid(rng, w + 2 * apron, h + 2 * apron)
	var coarse := _noise_grid(rng, (w + 2 * apron) / 2 + 1, (h + 2 * apron) / 2 + 1)
	var eligible: Array[Dictionary] = []
	var apron_eligible: Array[Dictionary] = []
	var open_count := 0
	for tile: Dictionary in tiles + apron_tiles:
		var cell: Vector2i = tile.cell
		var inside := _inside(cell, w, h)
		if tile.mask != 0 or tile.water != 0 or stairs_set.has(cell) or blocked_set.has(cell) or mountain_set.has(cell):
			continue
		if inside:
			open_count += 1
		if _near(cell, all_hazards, 1):
			continue
		var edge := cell.x <= 0 or cell.y <= 0 or cell.x >= w - 1 or cell.y >= h - 1
		var entry := {"cell": cell, "score": 0.72 * _value_noise(coarse, (cell + Vector2i(apron, apron)) / 2)
			+ 0.28 * _value_noise(noise, cell + Vector2i(apron, apron)) + (0.14 if edge else 0.0)}
		if inside:
			eligible.append(entry)
		else:
			apron_eligible.append(entry)
	_rank(eligible, w + 2 * apron)
	_rank(apron_eligible, w + 2 * apron)
	var large_set := mountain_set.duplicate()
	var forest_set: Dictionary = {}
	var plateau_trees: Dictionary = {}
	var forest_target := maxi(0, mini(roundi(eligible.size() * 0.42), open_count - 40))
	for entry: Dictionary in eligible:
		if forest_set.size() >= forest_target:
			break
		var cell: Vector2i = entry.cell
		var region_index := -1
		for i in range(layout.plateaus.size()):
			var rect: Rect2i = layout.plateaus[i].rect
			if rect.has_point(cell):
				region_index = i
				if int(plateau_trees.get(i, 0)) >= rect.get_area() / 2:
					region_index = -2
				break
		if region_index == -2:
			continue
		forest_set[cell] = true
		large_set[cell] = true
		if region_index >= 0:
			plateau_trees[region_index] = int(plateau_trees.get(region_index, 0)) + 1
	for i in range(ceili(apron_eligible.size() * 0.84)):
		var cell: Vector2i = apron_eligible[i].cell
		forest_set[cell] = true
	# Select the complete two-octave threshold mask before assigning sizes.
	# Distances cross the map/apron seam; beyond the expanded frame is non-forest.
	var depths := forest_depths(forest_set)
	for cell: Vector2i in forest_set:
		var target: Array[Dictionary] = props if _inside(cell, w, h) else apron_props
		_forest(cell, depths[cell], tile_lookup[cell].level, target, reserved, rng)
	var buildable: Array[Vector2i] = []
	var large_budget := maxi(0, open_count - (large_set.size() - mountain_set.size()) - 40)
	for tile: Dictionary in tiles + apron_tiles:
		var cell: Vector2i = tile.cell
		var inside := _inside(cell, w, h)
		var target: Array[Dictionary] = props if inside else apron_props
		if tile.water != 0:
			if tile.mask == 0 and tile.water in [N | S, E | W] and rng.randf() < 0.30:
				_place(cell, "deco_reeds", false, 0, target, reserved, rng, tile.water)
			continue
		if tile.mask != 0 or stairs_set.has(cell) or blocked_set.has(cell) or large_set.has(cell) or forest_set.has(cell):
			continue
		if inside:
			if tile.level == 0 and large_budget > 0 and not _near(cell, all_hazards, 1):
				var rocky := _near(cell, mountain_set, 2)
				if rng.randf() < (0.55 if rocky else (0.06 if _near(cell, forest_set, 1) else 0.0)):
					var ids: Array[String] = ROCKS if rocky else LARGE
					if _place(cell, ids[rng.randi_range(0, ids.size() - 1)], true, 0, target, reserved, rng):
						large_set[cell] = true
						large_budget -= 1
						continue
			buildable.append(cell)
		if rng.randf() < 0.35:
			var ids: Array[String] = SMALL if rng.randf() < 0.5 else TINY
			_place(cell, ids[rng.randi_range(0, ids.size() - 1)], false, tile.level, target, reserved, rng)
	var path_world: Array[Vector3] = []
	for cell in path:
		path_world.append(Vector3(cell.x * 2.0, 0.0, -cell.y * 2.0))
	return {"size": Vector2i(w, h), "apron": apron, "spawn": path[0], "castle": path[-1],
		"path": path, "path_world": path_world, "river": river, "bridge": layout.bridge,
		"plateaus": layout.plateaus, "mountains": layout.mountains, "tiles": tiles,
		"buildable": buildable, "blocked": layout.blocked, "props": props,
		"apron_tiles": apron_tiles, "apron_props": apron_props}


static func _terrain(path: Array[Vector2i], w: int, h: int, apron: int, rng: RandomNumberGenerator) -> Dictionary:
	var path_set := _cell_set(path)
	var masks := _route_masks(path)
	var crossings: Array[Vector2i] = []
	for cell in path:
		if cell.x >= 4 and cell.x <= w - 6 and masks[cell] == E | W:
			if masks.get(cell + Vector2i.LEFT, 0) == E | W and masks.get(cell + Vector2i.RIGHT, 0) == E | W:
				crossings.append(cell)
	if crossings.is_empty():
		return {}
	var bridge: Vector2i = crossings[rng.randi_range(0, crossings.size() - 1)]
	var blocked: Array[Vector2i] = []
	for y in range(path[-1].y - 1, path[-1].y + 2):
		for x in range(path[-1].x, path[-1].x + 2):
			blocked.append(Vector2i(x, y))
	var water := _river(bridge, path_set, _cell_set(blocked), w, h, apron, rng)
	if water.is_empty():
		return {}
	var river: Array[Vector2i] = water.river
	var forbidden := path_set.duplicate()
	forbidden.merge(_cell_set(river))
	var blocked_set := _cell_set(blocked)
	var plateaus: Array[Dictionary] = []
	var plateau_cells: Dictionary = {}
	var stairs_cells: Dictionary = {}
	var count := rng.randi_range(1, 2)
	for region_index in range(count):
		var options: Array[Dictionary] = []
		# Enumerate minimum-size candidates first. Larger sizes are drawn only
		# after choosing a valid origin, keeping the search small and bounded.
		for y in range(h - 1):
			for x in range(w - 1):
				var rect := Rect2i(x, y, 2, 2)
				if not _plateau_ok(rect, forbidden, blocked_set, plateau_cells, stairs_cells, path_set if region_index == 0 else {}):
					continue
				var stairs := _stairs_options(rect, forbidden, blocked_set, plateau_cells, stairs_cells, w, h)
				if not stairs.is_empty():
					options.append({"rect": rect, "stairs": stairs})
		if options.is_empty():
			if region_index == 0:
				return {}
			break
		var chosen: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var rect: Rect2i = chosen.rect
		var enlarged := Rect2i(rect.position, Vector2i(rng.randi_range(2, 4), rng.randi_range(2, 3)))
		if enlarged.end.x <= w and enlarged.end.y <= h and _plateau_ok(enlarged, forbidden, blocked_set, plateau_cells, stairs_cells, path_set if region_index == 0 else {}):
			var stairs := _stairs_options(enlarged, forbidden, blocked_set, plateau_cells, stairs_cells, w, h)
			if not stairs.is_empty():
				rect = enlarged
				chosen.stairs = stairs
		var stair: Dictionary = chosen.stairs[rng.randi_range(0, chosen.stairs.size() - 1)]
		plateaus.append({"rect": rect, "stairs": stair.cell, "stairs_rot": stair.rot})
		for cell in _rect_cells(rect):
			plateau_cells[cell] = true
		stairs_cells[stair.cell] = true
	var mountain_options: Array[Vector2i] = []
	var borders: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			if not _near(cell, forbidden, 1) and not blocked_set.has(cell) and not plateau_cells.has(cell) and not stairs_cells.has(cell):
				mountain_options.append(cell)
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					borders.append(cell)
	var available := _cell_set(mountain_options)
	var mountains: Array[Vector2i] = []
	var starts: Array[Vector2i] = borders if not borders.is_empty() else mountain_options
	for _attempt in range(32):
		if starts.is_empty():
			return {}
		mountains = [starts[rng.randi_range(0, starts.size() - 1)]]
		var target := rng.randi_range(2, 4)
		while mountains.size() < target:
			var frontier: Array[Vector2i] = []
			for cell in mountains:
				for step in DIRECTIONS:
					var next := cell + step
					if available.has(next) and next not in mountains and next not in frontier:
						frontier.append(next)
			if frontier.is_empty():
				break
			mountains.append(frontier[rng.randi_range(0, frontier.size() - 1)])
		if mountains.size() >= 2:
			var open_cells := w * h - path.size() - river.size() + 1 - (blocked.size() - 1) - plateaus.size() - mountains.size()
			if open_cells < 40:
				return {}
			return {"path": path, "river": river, "full_river": water.full_river, "bridge": bridge, "blocked": blocked,
				"plateaus": plateaus, "mountains": mountains}
	return {}


static func _plateau_ok(rect: Rect2i, forbidden: Dictionary, blocked: Dictionary, old: Dictionary, stairs: Dictionary, useful_route: Dictionary) -> bool:
	var near_route := false
	for cell in _rect_cells(rect):
		if forbidden.has(cell) or blocked.has(cell) or _near(cell, old, 1) or _near(cell, stairs, 1):
			return false
		for step in DIRECTIONS:
			if forbidden.has(cell + step):
				return false
		if not useful_route.is_empty() and _near(cell, useful_route, 2):
			near_route = true
	return useful_route.is_empty() or near_route


static func _stairs_options(rect: Rect2i, forbidden: Dictionary, blocked: Dictionary, old: Dictionary, stairs: Dictionary, w: int, h: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for cell in _rect_cells(rect):
		for step in DIRECTIONS:
			var low := cell - step
			if not _inside(low, w, h) or rect.has_point(low) or forbidden.has(low) or blocked.has(low) or stairs.has(low) or _near(low, old, 1) or seen.has(low):
				continue
			for rot in range(4):
				if rotate_mask(N, rot) == _step_bit(step):
					result.append({"cell": low, "rot": rot})
					seen[low] = true
	return result


static func _river(bridge: Vector2i, path: Dictionary, blocked: Dictionary, w: int, h: int, apron: int, rng: RandomNumberGenerator) -> Dictionary:
	# One continuous seeded 1-D value-noise field across the expanded frame.
	# Alternating extrema give the walk a left/right tendency, while changing
	# amplitudes and a slow centre drift avoid repeated identical zigzags.
	for _attempt in range(48):
		var profile := PackedFloat64Array()
		var centre := 0.0
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var wavelength := rng.randf_range(2.7, 3.8)
		var phase := rng.randf_range(0.0, wavelength)
		for _i in range(ceili((h + 2 * apron) / wavelength) + 3):
			centre = clampf(centre + rng.randf_range(-0.6, 0.6), -2.0, 2.0)
			profile.append(centre + side * rng.randf_range(0.9, 1.9))
			side *= -1.0
		var shifts: Dictionary = {}
		var current := roundi(_river_value(profile, (h + 2 * apron - 1 + phase) / wavelength))
		var parity := rng.randi_range(0, 1)
		var last_row := h + apron + 1
		for y in range(h + apron - 2, -apron, -1):
			# Hold both inner edge tiles and the bridge's three-cell N-S run.
			if y in [h, h - 1, 0, -1] or (y >= 0 and y < h and absi(y - bridge.y) <= 1):
				continue
			if posmod(y, 2) != parity or last_row - y < 2:
				continue
			var target := roundi(_river_value(profile, (y + apron + phase) / wavelength))
			var delta := clampi(target - current, -3, 3)
			if delta != 0:
				shifts[y] = delta
				current += delta
				last_row = y
		var bends := 0
		var reversals := 0
		var tendency := 0
		var x := bridge.x
		for y: int in shifts:
			if y > bridge.y:
				x -= int(shifts[y])
			if y > 0 and y < h - 1:
				bends += 1
				var direction := signi(shifts[y])
				if tendency != 0 and tendency != direction:
					reversals += 1
				tendency = direction
		if bends < 3 or bends > 6 or reversals < 2:
			continue
		var route: Array[Vector2i] = []
		var full: Array[Vector2i] = []
		var seen: Dictionary = {}
		var valid := true
		var min_x := w
		var max_x := 0
		for y in range(h + apron - 1, -apron - 1, -1):
			var row: Array[Vector2i] = [Vector2i(x, y)]
			var delta: int = shifts.get(y, 0)
			for _i in range(absi(delta)):
				x += signi(delta)
				row.append(Vector2i(x, y))
			for cell in row:
				if cell.x < 0 or cell.x >= w or blocked.has(cell) or (path.has(cell) and cell != bridge):
					valid = false
					break
				for step in DIRECTIONS:
					var next := cell + step
					if (path.has(next) and next != bridge and cell != bridge) or (seen.has(next) and (full.is_empty() or next != full[-1])):
						valid = false
				if not valid:
					break
				seen[cell] = true
				full.append(cell)
				if _inside(cell, w, h):
					route.append(cell)
					min_x = mini(min_x, cell.x)
					max_x = maxi(max_x, cell.x)
			if not valid:
				break
		if valid and seen.has(bridge) and max_x - min_x <= 8:
			var north_bends := 0
			var south_bends := 0
			for y: int in shifts:
				north_bends += int(y >= h)
				south_bends += int(y < 0)
			if apron >= 4 and (north_bends == 0 or south_bends == 0):
				continue
			return {"river": route, "full_river": full}
	return {}


static func _river_value(profile: PackedFloat64Array, t: float) -> float:
	var i := floori(t)
	var f := t - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(profile[i], profile[i + 1], f)


static func _tile_v2(cell: Vector2i, mask: int, water: int, plateau: bool, stairs: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id := "grass"
	var rot := 0
	if mask != 0 and water != 0:
		id = "bridge_crossing"
		rot = 1
	elif water != 0:
		id = "river_straight" if water in [5, 10] else "river_corner"
		for k in range(4):
			if rotate_mask(WATER[id], k) == water:
				rot = k
				break
	elif stairs.has(cell):
		id = "stairs_stone"
		rot = stairs[cell]
	elif plateau:
		id = "plateau_grass_l1"
		rot = rng.randi_range(0, 3)
	else:
		for candidate: String in CANONICAL:
			var found := false
			for k in range(4):
				if rotate_mask(CANONICAL[candidate], k) == mask:
					id = candidate
					rot = k
					found = true
					break
			if found:
				break
		if id == "path_straight" and rng.randf() < 0.25:
			id = "path_straight_specks"
	if posmod(cell.x + cell.y, 2) == 1:
		id += "_b"
	return {"cell": cell, "id": id, "rot": rot, "mask": mask, "water": water, "level": 1 if plateau else 0}


static func footprint(id: String, rot: int) -> Vector2i:
	var base := id.trim_suffix("_warm").trim_suffix("_cool")
	var foot: Vector2i = FOOTPRINTS[base]
	return foot if posmod(rot, 2) == 0 else Vector2i(foot.y, foot.x)


static func reservation(prop: Dictionary) -> Rect2i:
	if prop.id.begins_with("deco_tree_"):
		return Rect2i(prop.anchor + prop.foot / 2 - Vector2i(8, 8), Vector2i(16, 16))
	return Rect2i(prop.anchor, prop.foot).grow(2)


static func _place(cell: Vector2i, id: String, large: bool, level: int, output: Array[Dictionary], reserved: Dictionary, rng: RandomNumberGenerator, water: int = 0) -> bool:
	if reserved.has(cell):
		return false
	var rot := rng.randi_range(0, 3)
	var foot := footprint(id, rot)
	var anchor := (Vector2i(50, 50) - foot) / 2
	if water != 0:
		# Reeds retain the v2 12-voxel bank band, centred along and across it.
		var low_bank := rng.randf() < 0.5
		if water == E | W:
			anchor.y = (12 - foot.y) / 2 + (0 if low_bank else 38)
		else:
			anchor.x = (12 - foot.x) / 2 + (0 if low_bank else 38)
	var prop := {"cell": cell, "id": id, "rot": rot, "anchor": anchor, "foot": foot, "level": level, "large": large}
	output.append(prop)
	reserved[cell] = [reservation(prop)]
	return true


static func _forest(cell: Vector2i, depth: int, level: int, output: Array[Dictionary], reserved: Dictionary, rng: RandomNumberGenerator) -> void:
	var tier: Array[String] = TREE_SMALL if depth == 1 else (TREE_MEDIUM if depth == 2 else TREE_BIG)
	var id := tier[rng.randi_range(0, tier.size() - 1)] + VARIANTS[rng.randi_range(0, VARIANTS.size() - 1)]
	_place(cell, id, true, level, output, reserved, rng)


static func forest_depths(forest: Dictionary) -> Dictionary:
	# Multi-source eight-neighbour BFS: edge=1, every inward ring adds one.
	var depths: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in forest:
		var edge := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not forest.has(cell + Vector2i(dx, dy)):
					edge = true
		if edge:
			depths[cell] = 1
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var next := cell + Vector2i(dx, dy)
				if forest.has(next) and not depths.has(next):
					depths[next] = int(depths[cell]) + 1
					queue.append(next)
	return depths


static func _cell_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in cells:
		result[cell] = true
	return result


static func _route_masks(route: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for i in range(route.size()):
		var mask := 0
		if i > 0:
			mask |= _step_bit(route[i - 1] - route[i])
		if i + 1 < route.size():
			mask |= _step_bit(route[i + 1] - route[i])
		result[route[i]] = mask
	return result


static func _inside(cell: Vector2i, w: int, h: int) -> bool:
	return cell.x >= 0 and cell.x < w and cell.y >= 0 and cell.y < h


static func _near(cell: Vector2i, cells: Dictionary, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if cells.has(cell + Vector2i(dx, dy)):
				return true
	return false


static func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			result.append(Vector2i(x, y))
	return result


static func _rank(entries: Array[Dictionary], stride: int) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score == b.score:
			return a.cell.y * stride + a.cell.x < b.cell.y * stride + b.cell.x
		return a.score > b.score)


static func rotate_mask(mask: int, k: int) -> int:
	var order: Array[int] = [E, N, W, S]
	var result := 0
	for i in range(4):
		if mask & order[i]:
			result |= order[posmod(i + k, 4)]
	return result


static func _random_path(rng: RandomNumberGenerator, w: int, h: int) -> Array[Vector2i]:
	var east_distance := w - 3
	var run_count := rng.randi_range(ceili(east_distance / float(MAX_RUN_STEPS)), east_distance / 2)
	var path: Array[Vector2i] = [Vector2i(0, rng.randi_range(2, h - 3))]
	var remaining := east_distance
	for i in range(run_count):
		var after := run_count - i - 1
		var steps := rng.randi_range(maxi(2, remaining - after * MAX_RUN_STEPS), mini(MAX_RUN_STEPS, remaining - after * 2))
		_append_run(path, Vector2i.RIGHT, steps)
		remaining -= steps
		if after == 0:
			break
		var options: Array[int] = []
		for delta in range(-MAX_RUN_STEPS, MAX_RUN_STEPS + 1):
			if absi(delta) < 2:
				continue
			var y: int = path[-1].y + delta
			if y >= 1 and y <= h - 2:
				options.append(delta)
		if options.is_empty():
			return []
		var delta: int = options[rng.randi_range(0, options.size() - 1)]
		_append_run(path, Vector2i(0, signi(delta)), absi(delta))
	return path


static func _fallback_path(w: int, h: int) -> Array[Vector2i]:
	# Deterministic, simple S-curves: evenly spaced east runs, then vertical
	# runs bouncing between two interior bands. No RNG and no unbounded search.
	var east_distance := w - 3
	for run_count in range(ceili(east_distance / float(MAX_RUN_STEPS)), east_distance / 2 + 1):
		for start_y in range(2, h - 2):
			for initial_direction in [1, -1]:
				var path: Array[Vector2i] = [Vector2i(0, start_y)]
				var direction: int = initial_direction
				for i in range(run_count):
					var steps := east_distance / run_count + (1 if i < east_distance % run_count else 0)
					_append_run(path, Vector2i.RIGHT, steps)
					if i == run_count - 1:
						break
					var target_y := h - 3 if direction > 0 else 2
					var distance: int = absi(target_y - path[-1].y)
					if distance < 2:
						direction *= -1
						target_y = h - 3 if direction > 0 else 2
						distance = absi(target_y - path[-1].y)
					# Leave two steps for a following run, never a one-step jog.
					var vertical_steps := MAX_RUN_STEPS - 1 if distance == MAX_RUN_STEPS + 1 else mini(MAX_RUN_STEPS, distance)
					_append_run(path, Vector2i(0, direction), vertical_steps)
				if _valid_path(path, w, h):
					return path
	return []


static func _append_run(path: Array[Vector2i], step: Vector2i, count: int) -> void:
	for _i in range(count):
		path.append(path[-1] + step)


static func _valid_path(path: Array[Vector2i], w: int, h: int) -> bool:
	if path.size() < ceili(1.7 * w) or path.size() > floori(2.6 * w):
		return false
	if path[0].x != 0 or path[-1].x != w - 3:
		return false
	if path[0].y < 2 or path[0].y > h - 3 or path[-1].y < 2 or path[-1].y > h - 3:
		return false
	var seen: Dictionary = {}
	var min_y := h
	var max_y := 0
	for i in range(path.size()):
		var cell := path[i]
		if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h or seen.has(cell):
			return false
		if i > 0 and _step_bit(cell - path[i - 1]) == 0:
			return false
		for step in DIRECTIONS:
			if seen.has(cell + step) and (i == 0 or cell + step != path[i - 1]):
				return false
		seen[cell] = true
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	return max_y - min_y >= h - 5


static func _step_bit(step: Vector2i) -> int:
	for i in range(4):
		if step == DIRECTIONS[i]:
			return BITS[i]
	return 0




static func _noise_grid(rng: RandomNumberGenerator, w: int, h: int) -> Array[PackedFloat64Array]:
	var grid: Array[PackedFloat64Array] = []
	for _y in range(ceili(h / 4.0) + 1):
		var row := PackedFloat64Array()
		for _x in range(ceili(w / 4.0) + 1):
			row.append(rng.randf())
		grid.append(row)
	return grid


static func _value_noise(grid: Array[PackedFloat64Array], cell: Vector2i) -> float:
	var x := cell.x / 4
	var y := cell.y / 4
	var fx := (cell.x % 4) / 4.0
	var fy := (cell.y % 4) / 4.0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(grid[y][x], grid[y][x + 1], fx), lerpf(grid[y + 1][x], grid[y + 1][x + 1], fx), fy)
