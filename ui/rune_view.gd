extends RefCounted
## Data model behind the rune tree (craft tab) and the floating inspector: one item per rune node and per ability,
## built from the same compiled program the combat runs, so what is shown is what the tower does.
## Item: {kind: "rune"|"ability", node, rune, grade, ability, path, depth, state, ops: [text], rejected: [text],
##        kids: [item], pending: bool, locked_at: int}
## state — rune: "root" | "active" (contributes here) | "off" (nothing carried) | "pending" (not crafted yet)
##       — ability: "active" (has donors) | "empty" | "locked"

const T := preload("res://ui/i18n.gd")


## pending: {ability_id: [node]} donors that are on the table but not crafted (shown, never compiled → no preview).
static func build(game, node: Dictionary, pending := {}) -> Dictionary:
	var rl = game.rl
	var c: Dictionary = rl.compile_recipe(node)
	var by_path := {}
	for o in rl.walk(c.get("ops", [])):
		var p: String = o.uid.rsplit(".", true, 2)[0]
		if not by_path.has(p):
			by_path[p] = []
		by_path[p].append(o)
	var rej := {}
	for x in c.get("rejected", []):
		if not rej.has(x.path):
			rej[x.path] = []
		rej[x.path].append(x)
	var root := _rune_item(game, node, "r", 0, by_path, rej)
	root.state = "root"
	root.trail = []
	_abilities(game, root, by_path, rej, pending)
	return root


static func _rune_item(game, n: Dictionary, path: String, depth: int, by_path: Dictionary, rej: Dictionary) -> Dictionary:
	var rl = game.rl
	var ops := []
	for o in by_path.get(path, []):
		if int(o.depth) == depth:
			ops.append({"text": rl.op_text(o), "family": o.family, "element": str(o.params.get("element", o.params.get("status", "")))})
	var bad := []
	for x in rej.get(path, []):
		bad.append(T.t("not_carried", {"what": rl.family_name(x.family), "why": x.reason}))
	return {"kind": "rune", "node": n, "rune": n.rune, "grade": int(n.grade), "path": path, "depth": depth,
		"state": "active" if not ops.is_empty() else "off", "ops": ops, "rejected": bad, "kids": [], "pending": false}


static func _abilities(game, it: Dictionary, by_path: Dictionary, rej: Dictionary, pending := {}) -> void:
	var rl = game.rl
	var n: Dictionary = it.node
	for a in game.spec.runes[n.rune].abilities:
		var kids: Array = rl.sorted_kids(n.grafts.get(a.id, []))
		var pend: Array = pending.get(a.id, []) if it.depth == 0 else []
		var locked: bool = int(a.grade) > int(n.grade)
		if it.depth > 0 and kids.is_empty():
			continue                                # nested runes only show the abilities that carry grafts
		var ab := {"kind": "ability", "rune": n.rune, "ability": a.id, "carrier": a.carrier, "depth": it.depth,
			"trail": it.get("trail", []) + ["%s G%d" % [rl.rune_name(n.rune), int(n.grade)]],
			"path": it.path, "kids": [], "locked_at": int(a.grade), "node": n, "grade": int(n.grade),
			"state": "locked" if locked else ("active" if not (kids.is_empty() and pend.is_empty()) else "empty")}
		for i in kids.size():
			var kp := "%s.%s%d" % [it.path, a.id, i]
			var d := _rune_item(game, kids[i], kp, it.depth + 1, by_path, rej)
			d.trail = ab.trail + [rl.ability_name(n.rune, a.id)]
			_abilities(game, d, by_path, rej)
			ab.kids.append(d)
		for p in pend:
			ab.kids.append({"kind": "rune", "node": p, "rune": p.rune, "grade": int(p.grade), "path": "", "depth": it.depth + 1,
				"trail": ab.trail + [rl.ability_name(n.rune, a.id)],
				"state": "pending", "ops": [], "rejected": [], "kids": [], "pending": true})
		it.kids.append(ab)


## Number of rune nodes under an item (for "+N" on collapsed branches).
static func count_runes(it: Dictionary) -> int:
	var n := 0
	for k in it.kids:
		n += (1 if k.kind == "rune" else 0) + count_runes(k)
	return n


static func grade_color(g: int) -> Color:
	return [Color("#9AA0AC"), Color("#5FD35A"), Color("#3FA2FF"), Color("#B266FF"), Color("#FFB02E")][clampi(g, 1, 5) - 1]


static func _hex(c: Color) -> String:
	return c.to_html(false)


## BBCode for the detail plaque (inspector) and the caption under the compact tree. Short lines, no metadata.
static func describe(game, it, with_trail := false) -> String:
	if it == null:
		return ""
	if with_trail and not it.get("trail", []).is_empty():
		return "[font_size=12][color=#8C877D]%s ›[/color][/font_size]\n" % " › ".join(it.trail) + describe(game, it, false)
	var rl = game.rl
	var t := ""
	if it.kind == "ability":
		var name: String = rl.ability_name(it.rune, it.ability)
		t += "[b][color=#ECE6D6]%s[/color][/b]  [color=#8C877D]%s[/color]\n" % [name, rl.carrier_name(it.carrier)]
		if it.state == "locked":
			return t + "[color=#8C877D]%s[/color]" % T.t("ability_locked_at", {"g": it.locked_at})
		t += "[color=#C4BEB0]%s[/color]\n" % rl.ability_desc(it.rune, it.ability, int(it.grade))
		if it.kids.is_empty():
			return t + "\n[color=#8C877D]%s[/color]" % T.t("ability_no_donors")
		t += "\n"
		for d in it.kids:
			t += _donor_lines(game, d)
		return t.strip_edges()
	# rune
	var head := "[b][color=#%s]%s G%d[/color][/b]" % [_hex(grade_color(it.grade).lerp(Color("#ECE6D6"), 0.4)), rl.rune_name(it.rune), it.grade]
	if it.depth == 0:
		t += head + "\n[color=#8C877D]%s[/color]\n\n" % rl.rune_identity(it.rune)
		for ab in it.kids:
			var an: String = rl.ability_name(it.rune, ab.ability)
			if ab.state == "locked":
				t += "[color=#6E6A78]◇ %s — %s[/color]\n" % [an, T.t("grade_short", {"g": ab.locked_at})]
			elif ab.kids.is_empty():
				t += "[color=#C4BEB0]◆ %s[/color]\n" % an
			else:
				var names := []
				for d in ab.kids:
					names.append("%s G%d" % [rl.rune_name(d.rune), d.grade])
				t += "[color=#7FE3F0]◆[/color] [color=#ECE6D6]%s[/color] [color=#8C877D]←[/color] [color=#9FD3FF]%s[/color]\n" % [an, ", ".join(names)]
		return t.strip_edges()
	return (_donor_lines(game, it)).strip_edges()


static func _donor_lines(game, d: Dictionary) -> String:
	var rl = game.rl
	var t := "[b][color=#%s]%s G%d[/color][/b]\n" % [_hex(grade_color(d.grade).lerp(Color("#ECE6D6"), 0.4)), rl.rune_name(d.rune), d.grade]
	if d.pending:
		return t + "   [color=#9FD3FF]%s[/color]\n\n" % T.t("pending_effect_after_craft")
	if d.ops.is_empty() and d.rejected.is_empty():
		t += "   [color=#8C877D]%s[/color]\n" % T.t("no_effect_here")
	for o in d.ops:
		t += "   [color=#7FE3F0]▸[/color] %s\n" % o.text
	for x in d.rejected:
		t += "   [color=#F06A5A]✗ %s[/color]\n" % x
	var nested := []
	for ab in d.kids:
		var names := []
		for k in ab.kids:
			names.append("%s G%d" % [rl.rune_name(k.rune), k.grade])
		nested.append("%s ← %s" % [rl.ability_name(d.rune, ab.ability), ", ".join(names)])
	if not nested.is_empty():
		t += "   [color=#8C877D]%s[/color]\n" % "; ".join(nested)
	return t + "\n"
