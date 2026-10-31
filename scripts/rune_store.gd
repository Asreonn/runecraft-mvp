extends RefCounted
## Every operation that moves runes between the inventory, the craft table and towers.
## Rule: an operation either completes or changes nothing — runes are never lost or duplicated
## (a full inventory makes the operation fail with a message instead of dropping a rune).
## Items are rune node Dictionaries {rune, grade, grafts: {ability_id: [node...]}}.

var game


func _init(g) -> void:
	game = g


func _inv() -> Array:
	return game.inventory


func free_slots() -> int:
	var n := 0
	for x in _inv():
		if x == null:
			n += 1
	return n


func put(node) -> bool:
	var inv := _inv()
	for i in inv.size():
		if inv[i] == null:
			inv[i] = node
			return true
	return false


## Every top-level rune the player owns (inventory, craft table, outputs, towers).
func all_items() -> Array:
	var out := []
	for x in _inv():
		if x != null:
			out.append(x)
	var c: Dictionary = game.craft
	if c.base != null:
		out.append(c.base)
	for ab in c.pending:
		out.append_array(c.pending[ab])
	if c.output != null:
		out.append(c.output)
	for t in game.towers:
		if t.rune != null:
			out.append(t.rune)
	return out


func _full() -> bool:
	game.notify("Inventory is full — free a slot first.")
	return false


# ------------------------------------------------------------------ towers

## Put inventory rune `idx` into tower `t`; the tower's old rune takes the freed slot (always safe).
func socket(t, idx: int) -> bool:
	var inv := _inv()
	if t == null or idx < 0 or idx >= inv.size() or inv[idx] == null:
		return false
	var r = inv[idx]
	inv[idx] = t.rune
	t.set_rune(r)
	return true


## Put the craft output into tower `t`. The old tower rune needs a free inventory slot, otherwise nothing changes.
func socket_output(t) -> bool:
	if t == null or game.craft.output == null:
		return false
	var old = t.rune
	if old != null and free_slots() == 0:
		return _full()
	t.set_rune(game.craft.output)
	game.craft.output = null
	if old != null:
		put(old)
	return true


func unsocket(t) -> bool:
	if t == null or t.rune == null:
		return false
	if free_slots() == 0:
		return _full()
	put(t.rune)
	t.set_rune(null)
	return true


# ------------------------------------------------------------------ combine

func combine(a: int, b: int) -> bool:
	var inv := _inv()
	if a == b or a < 0 or b < 0 or a >= inv.size() or b >= inv.size():
		return false
	var ra = inv[a]
	var rb = inv[b]
	if ra == null or rb == null:
		return false
	if ra.rune != rb.rune or int(ra.grade) != int(rb.grade):
		game.notify("Combine needs two runes of the same type and grade.")
		return false
	if int(ra.grade) >= 5:
		game.notify("G5 is the highest grade.")
		return false
	var fee: int = game.combine_fee(int(ra.grade))
	if game.mana < fee:
		game.notify("Combining costs %d mana." % fee)
		return false
	game.mana -= fee
	var out := {"rune": ra.rune, "grade": int(ra.grade) + 1, "grafts": {}}
	for src in [ra, rb]:
		for ab in src.grafts:
			if not out.grafts.has(ab):
				out.grafts[ab] = []
			out.grafts[ab] += src.grafts[ab]
	inv[a] = out
	inv[b] = null
	game.notify("%s G%d forged." % [game.rl.rune_name(out.rune), out.grade])
	return true


# ------------------------------------------------------------------ craft table

func _table_items() -> Array:
	var out := []
	var c: Dictionary = game.craft
	if c.base != null:
		out.append(c.base)
	for ab in c.pending:
		out.append_array(c.pending[ab])
	return out


## Move inventory rune `idx` to the centre of the table. A previous base and its pending donors go back to the
## inventory; if they do not fit (counting the slot freed by the new base), nothing changes.
func set_base(idx: int) -> bool:
	var inv := _inv()
	if idx < 0 or idx >= inv.size() or inv[idx] == null:
		return false
	var back := _table_items()
	if back.size() > free_slots() + 1:
		return _full()
	var r = inv[idx]
	game.craft.base = null
	game.craft.pending = {}
	if back.size() <= free_slots():
		for x in back:               # returned runes take other free slots; the source slot just empties
			put(x)
		inv[idx] = null
	else:
		inv[idx] = null
		for x in back:
			put(x)
	game.craft.base = r
	return true


## Return the base and every pending donor to the inventory (all or nothing).
func clear_table() -> bool:
	var back := _table_items()
	if back.is_empty():
		return false
	if back.size() > free_slots():
		return _full()
	game.craft.base = null
	game.craft.pending = {}
	for x in back:
		put(x)
	return true


func add_pending(ability: String, idx: int) -> bool:
	var inv := _inv()
	if game.craft.base == null or idx < 0 or idx >= inv.size() or inv[idx] == null:
		return false
	var d = inv[idx]
	var res: Array = game.graft_check(ability, d)
	if not res[0]:
		game.notify("Graft rejected: " + (str(res[1][0]) if res[1].size() > 0 else "incompatible"))
		return false
	if not game.craft.pending.has(ability):
		game.craft.pending[ability] = []
	game.craft.pending[ability].append(d)
	inv[idx] = null
	return true


func remove_pending(ability: String, i: int) -> bool:
	var lst: Array = game.craft.pending.get(ability, [])
	if i < 0 or i >= lst.size():
		return false
	if free_slots() == 0:
		return _full()
	put(lst[i])
	lst.remove_at(i)
	if lst.is_empty():
		game.craft.pending.erase(ability)
	return true


## Ungraft: the donor (with its own sub-grafts) returns to the inventory; the fee paid for it is lost.
func ungraft(ability: String, i: int) -> bool:
	var b = game.craft.base
	if b == null:
		return false
	var lst: Array = b.grafts.get(ability, [])
	if i < 0 or i >= lst.size():
		return false
	if free_slots() == 0:
		return _full()
	put(lst[i])
	lst.remove_at(i)
	if lst.is_empty():
		b.grafts.erase(ability)
	game.notify("Graft removed — the rune is back, the fee is lost.")
	return true


func merged() -> Dictionary:
	var out: Dictionary = game.craft.base.duplicate(true)
	for ab in game.craft.pending:
		if not out.grafts.has(ab):
			out.grafts[ab] = []
		for d in game.craft.pending[ab]:
			out.grafts[ab].append(d.duplicate(true))
	return out


func craft() -> bool:
	var c: Dictionary = game.craft
	if c.base == null or c.pending.is_empty():
		game.notify("Needs a base rune and at least one graft.")
		return false
	if c.output != null:
		game.notify("Take the output rune first.")
		return false
	var fee: int = game.craft_fee()
	if game.mana < fee:
		game.notify("Graft fee: %d mana." % fee)
		return false
	game.mana -= fee
	c.output = merged()
	c.base = null
	c.pending = {}
	game.notify("Crafted — read the result on the output rune.")
	return true


func take_output() -> bool:
	if game.craft.output == null:
		return false
	if free_slots() == 0:
		return _full()
	put(game.craft.output)
	game.craft.output = null
	return true


## Drop the output into a specific empty inventory slot (drag & drop).
func output_to_slot(i: int) -> bool:
	var inv := _inv()
	if game.craft.output == null or i < 0 or i >= inv.size():
		return false
	if inv[i] != null:
		return take_output()
	inv[i] = game.craft.output
	game.craft.output = null
	return true
