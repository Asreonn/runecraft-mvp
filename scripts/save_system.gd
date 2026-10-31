extends RefCounted
const T := preload("res://ui/i18n.gd")
## Save / load. A save holds everything the player owns and the economy state; the map is regenerated from its
## seed. Saving is only allowed between waves (build phase), so a load always resumes at a clean "next wave"
## point — no wave can be skipped or replayed for extra resources. `serialize()` itself works at any time: during
## a wave it records the last completed wave (the interrupted wave would be played again).
## Format version 2; version 1 files (first MVP release) are read too. Corrupt / unknown / incomplete files are
## rejected without touching the running game.

const VERSION := 2
const REQUIRED := ["seed", "wave", "mana", "stones", "castle_hp", "inventory", "towers"]

var game


func _init(g) -> void:
	game = g


func serialize() -> Dictionary:
	var tw := []
	for t in game.towers:
		tw.append({"cell": [t.cell.x, t.cell.y], "rune": t.rune, "paid": int(t.get_meta("paid", 0))})
	var mid_wave: bool = game.wave_state in ["spawning", "fighting"]
	return {"version": VERSION, "game": "runecraft-mvp", "seed": game.seed_value,
		"wave": game.wave - 1 if mid_wave else game.wave,
		"mana": game.mana, "stones": game.stones, "castle_hp": game.castle_hp,
		"countdown": game.countdown if not mid_wave else 20.0,
		"inventory": game.inventory.duplicate(true), "towers": tw, "craft": game.craft.duplicate(true),
		"economy": game.economy.serialize()}


## Returns "" when `d` is a loadable save, otherwise the reason.
func check(d) -> String:
	if not d is Dictionary:
		return "not a save file"
	var v := int(d.get("version", 0))
	if v < 1 or v > VERSION:
		return "unsupported save version %s" % str(d.get("version", "?"))
	for k in REQUIRED:
		if not d.has(k):
			return "missing '%s'" % k
	if not d.inventory is Array or not d.towers is Array:
		return "damaged inventory or towers"
	for node in _all_nodes(d):
		if not _node_ok(node):
			return "unknown rune data"
	return ""


func _all_nodes(d: Dictionary) -> Array:
	var out := []
	for x in d.inventory:
		if x != null:
			out.append(x)
	for t in d.towers:
		if t is Dictionary and t.get("rune") != null:
			out.append(t.rune)
	var c = d.get("craft", {})
	if c is Dictionary:
		for k in ["base", "output"]:
			if c.get(k) != null:
				out.append(c[k])
		var p = c.get("pending", {})
		if p is Dictionary:
			for ab in p:
				out.append_array(p[ab] if p[ab] is Array else [])
	return out


func _node_ok(n) -> bool:
	if not n is Dictionary or not game.spec.runes.has(str(n.get("rune", ""))):
		return false
	var g := int(n.get("grade", 0))
	if g < 1 or g > 5 or not n.get("grafts", {}) is Dictionary:
		return false
	var abil := {}
	for a in game.spec.runes[n.rune].abilities:
		abil[a.id] = true
	for ab in n.grafts:
		if not abil.has(ab) or not n.grafts[ab] is Array:
			return false
		for k in n.grafts[ab]:
			if not _node_ok(k):
				return false
	return true


## JSON turns every number into a float; rune grades must be ints again.
static func ints(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = int(v[k]) if k == "grade" and v[k] != null else ints(v[k])
		return o
	if v is Array:
		return v.map(func(x): return ints(x))
	return v


func save(path: String) -> bool:
	if game.wave_state in ["spawning", "fighting"]:
		game.notify(T.t("save_between_waves"))
		return false
	if game.wave_state == "lost":
		game.notify(T.t("msg_nothing_to_save"))
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		game.notify(T.t("msg_save_failed"))
		return false
	f.store_string(JSON.stringify(serialize()))
	f.close()
	game.notify(T.t("msg_saved", {"n": game.wave}))
	return true


## Reads and validates `path`. Returns the save Dictionary (grades as ints) or null; never changes the game.
func read(path: String):
	if not FileAccess.file_exists(path):
		game.notify(T.t("msg_no_save"))
		return null
	var js := JSON.new()                      # quiet parse: a corrupt file is a normal, reported case
	var d = js.data if js.parse(FileAccess.get_file_as_string(path)) == OK else null
	var why := check(d)
	if why != "":
		game.notify(T.t("msg_load_failed", {"why": why}))
		return null
	return ints(d)


## Apply a checked save to a freshly built game (same seed). Towers whose cell is no longer buildable (older map
## generator) move to the nearest buildable cell; a rune that cannot be placed anywhere goes to the inventory.
func restore(d: Dictionary) -> bool:
	if check(d) != "":
		return false
	game.wave = int(d.wave)
	game.mana = float(d.mana)
	game.stones = int(d.stones)
	game.castle_hp = int(d.castle_hp)
	for i in game.INV_SIZE:
		game.inventory[i] = d.inventory[i] if i < d.inventory.size() else null
	var c = d.get("craft", {})
	game.craft = {"base": c.get("base"), "pending": c.get("pending", {}) if c.get("pending") is Dictionary else {}, "output": c.get("output")}
	game.economy.restore(d.get("economy", {}))
	for t in d.towers:
		var want := Vector2i(int(t.cell[0]), int(t.cell[1]))
		var cell = want if game.wb.buildable.has(want) else _nearest_buildable(want)
		if cell == null:
			if t.rune != null and not game.inv_put(t.rune):
				game.craft.output = t.rune if game.craft.output == null else game.craft.output
			continue
		var paid := int(t.get("paid", game.economy.tower_cost(game.towers.size())))
		var tw = game.place_tower(cell, paid)
		if t.rune != null:
			tw.set_rune(t.rune)
	game.build_mode = false
	game.wave_state = "build"
	game.countdown = float(d.get("countdown", 20.0))      # restored too: reloading must not refill the early-call bonus
	game.selected_tower = null
	game.notify(T.t("msg_loaded", {"n": game.wave + 1}))
	game.changed.emit()
	return true


func _nearest_buildable(c: Vector2i):
	var best = null
	var bd := 1e9
	for k in game.wb.buildable:
		var d: float = Vector2(k - c).length()
		if d < bd:
			bd = d
			best = k
	return best
