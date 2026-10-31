extends RefCounted
## Deterministic, data-driven port of the supplied Python rune resolver.
## Dictionaries and arrays intentionally retain insertion order and shared op references.

var locale_id: String = "tr"
var _locale: Dictionary = {}
var _locale_reference: Dictionary = {}
var locale_keys_used: Dictionary = {}
var _verb_keys: Dictionary = {"": "default"}

var spec: Dictionary
var _token := RegEx.new()
var _node_token := RegEx.new()
var _whitespace := RegEx.new()
var _nonprintable := RegEx.new()

func _init(spec_path: String = "") -> void:
	set_locale(get_script().resource_path.get_base_dir().path_join("locale/tr.json"))
	if spec_path.is_empty():
		spec_path = get_script().resource_path.get_base_dir().path_join("data/rune_mechanics_v1.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	assert(data is Dictionary, _t("spec_load", {"path": spec_path}))
	spec = data
	for rid in spec.runes:
		var r: Dictionary = spec.runes[rid]
		r.id = rid
		r.ability_by_id = {}
		for a in r.abilities:
			r.ability_by_id[a.id] = a
	for cid in spec.carriers:
		_verb_keys[spec.carriers[cid].chain_verb] = "carrier." + cid
	for rid in spec.runes:
		for ability in spec.runes[rid].abilities:
			if not ability.get("chain_verb", "").is_empty():
				_verb_keys[ability.chain_verb] = "ability." + rid + "." + ability.id
	_token.compile("[a-z_]+\\p{Nd}|[a-z_]+|[{}\\[\\]:,]")
	_node_token.compile("^([a-z_]+)(\\p{Nd})$")
	# Python's Unicode str whitespace includes U+001C..001F, unlike PCRE's \\s.
	_whitespace.compile("[\\x{0009}-\\x{000d}\\x{001c}-\\x{0020}\\x{0085}\\x{00a0}\\x{1680}\\x{2000}-\\x{200a}\\x{2028}\\x{2029}\\x{202f}\\x{205f}\\x{3000}]+")
	_nonprintable.compile("[\\p{C}\\p{Z}]")

func _error(code: String, message: String) -> Dictionary:
	return {"error": {"code": code, "message": _t("error", {"code": code, "message": message})}}

func _repr(value: Variant) -> String:
	if value == null:
		return "None"
	var s: String = str(value)
	var quote := '"' if s.contains("'") and not s.contains('"') else "'"
	var out := quote
	for ch in s:
		match ch:
			"\\": out += "\\\\"
			"\n": out += "\\n"
			"\r": out += "\\r"
			"\t": out += "\\t"
			_:
				if ch == quote:
					out += "\\" + ch
				elif ch != " " and _nonprintable.search(ch) != null:
					var cp := ch.unicode_at(0)
					if cp <= 0xff:
						out += "\\x%02x" % cp
					elif cp <= 0xffff:
						out += "\\u%04x" % cp
					else:
						out += "\\U%08x" % cp
				else:
					out += ch
	return out + quote

func parse(text: String) -> Dictionary:
	var toks: Array = []
	for m in _token.search_all(text):
		toks.append(m.get_string())
	if "".join(toks) != _whitespace.sub(text, "", true):
		return _error("syntax", _t("parse_unparsable", {"text": _repr(text)}))
	# Parser state belongs to this call, never to the reusable library instance.
	var ctx := {"toks": toks, "pos": 0, "text": text, "error": {}}
	var root := _parse_node(ctx)
	if not ctx.error.is_empty():
		return ctx.error
	if ctx.pos != toks.size():
		return _error("syntax", _t("parse_trailing", {"text": _repr(text)}))
	var checked := validate(root)
	return checked if checked.has("error") else root

func _peek(ctx: Dictionary) -> Variant:
	return ctx.toks[ctx.pos] if ctx.pos < ctx.toks.size() else null

func _take(ctx: Dictionary, expect: Variant = null) -> Variant:
	var t = _peek(ctx)
	if t == null or (expect != null and t != expect):
		if ctx.error.is_empty():
			ctx.error = _error("syntax", _t("parse_expected", {"expect": _repr(expect), "pos": ctx.pos, "text": _repr(ctx.text)}))
		return null
	ctx.pos += 1
	return t

func _decimal_digit(ch: String) -> int:
	# Every Unicode Nd block is a run of ten. Mathematical styled digits
	# comprise five adjacent blocks. This handles Python's Unicode \\d/int.
	var cp := ch.unicode_at(0)
	var first := cp
	var digit_re := RegEx.new()
	digit_re.compile("^\\p{Nd}$")
	while first > 0 and digit_re.search(String.chr(first - 1)) != null:
		first -= 1
	return (cp - first) % 10

func _parse_node(ctx: Dictionary) -> Dictionary:
	var t = _take(ctx)
	if not ctx.error.is_empty():
		return {}
	var m := _node_token.search(t)
	if m == null:
		ctx.error = _error("syntax", _t("parse_node", {"token": _repr(t)}))
		return {}
	var rid := m.get_string(1)
	var g := _decimal_digit(m.get_string(2))
	if not spec.runes.has(rid):
		ctx.error = _error("unknown_rune", rid)
		return {}
	if g < 1 or g > 5:
		ctx.error = _error("bad_grade", t)
		return {}
	var n := {"rune": rid, "grade": g, "grafts": {}}
	if _peek(ctx) == "{":
		_take(ctx, "{")
		while _peek(ctx) != "}":
			var ab = _take(ctx)
			_take(ctx, ":")
			_take(ctx, "[")
			if not ctx.error.is_empty():
				return {}
			var kids: Array = []
			while _peek(ctx) != "]":
				var child := _parse_node(ctx)
				if not ctx.error.is_empty():
					return {}
				kids.append(child)
				if _peek(ctx) == ",":
					_take(ctx, ",")
			_take(ctx, "]")
			if not n.grafts.has(ab):
				n.grafts[ab] = []
			n.grafts[ab].append_array(kids)
			if _peek(ctx) == ",":
				_take(ctx, ",")
		_take(ctx, "}")
	return n

## {} means valid; errors use the same envelope as parse().
func validate(n: Dictionary) -> Dictionary:
	var r: Dictionary = spec.runes[n.rune]
	for ab in n.grafts:
		var a = r.ability_by_id.get(ab)
		if a == null:
			return _error("unknown_ability", _t("unknown_ability", {"rune": n.rune, "ability": _repr(ab)}))
		if a.grade > n.grade:
			return _error("locked_on_receiver", _t("locked_receiver", {"rune": rune_name(n.rune), "grade": n.grade, "ability": ability_name(n.rune, a.id), "unlock": gde(a.grade)}))
		for k in n.grafts[ab]:
			var checked := validate(k)
			if checked.has("error"):
				return checked
	return {}

func canonical(n: Dictionary) -> String:
	var parts: Array[String] = []
	for a in spec.runes[n.rune].abilities:
		var kids: Array = n.grafts.get(a.id, [])
		if not kids.is_empty():
			var names: Array[String] = []
			for k in sorted_kids(kids):
				names.append(canonical(k))
			parts.append("%s:[%s]" % [a.id, ",".join(names)])
	var base := "%s%d" % [n.rune, n.grade]
	return base + ("{" + ",".join(parts) + "}" if not parts.is_empty() else "")

func sorted_kids(kids: Array) -> Array:
	# Python's sorted is stable. Godot sort_custom is not, so decorate with
	# the original index after the exact (order, -grade, canonical) key.
	var decorated: Array = []
	for i in range(kids.size()):
		var k: Dictionary = kids[i]
		decorated.append([spec.runes[k.rune].order, -k.grade, canonical(k), i, k])
	decorated.sort_custom(func(a: Array, b: Array) -> bool:
		for i in range(4):
			if a[i] != b[i]:
				return a[i] < b[i]
		return false
	)
	var out: Array = []
	for entry in decorated:
		out.append(entry[4])
	return out

func node_size(n: Dictionary) -> int:
	var size := 1
	for kids in n.grafts.values():
		for child in kids:
			size += node_size(child)
	return size

func node_depth(n: Dictionary) -> int:
	var deepest := 0
	for kids in n.grafts.values():
		for child in kids:
			deepest = maxi(deepest, node_depth(child))
	return deepest + 1

func grade_stats(rune_id: Variant, g: int) -> Dictionary:
	var rune: Dictionary = spec.runes[rune_id] if rune_id is String else rune_id
	var out: Dictionary = {}
	for k in range(1, g + 1):
		out.merge(rune.grades.get(str(k), {}), true)
	return out

func _resolve(v: Variant, stats: Dictionary) -> Variant:
	if v is String and v.begins_with("$"):
		return stats.get(v.substr(1), 0)
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			out[k] = _resolve(v[k], stats)
		return out
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_resolve(x, stats))
		return out
	return v

func _scale(params: Dictionary, depth: int) -> Dictionary:
	var c: Dictionary = spec.coefficients
	var kd := pow(c.depth_damage, depth)
	var kc := pow(c.depth_control, depth)
	var out: Dictionary = {}
	for k in params:
		var v = params[k]
		if v is int or v is float:
			if k in c.damage_params:
				v = v * kd
			elif k in c.control_params:
				v = v * kc
		elif k == "native" and v is Array:
			var native_ops: Array = []
			for o in v:
				native_ops.append(_scale(o, depth))
			v = native_ops
		out[k] = v
	return out

func compile_recipe(text_or_node: Variant) -> Dictionary:
	var root: Dictionary = parse(text_or_node) if text_or_node is String else text_or_node
	if root.has("error"):
		return root
	var rejected: Array = []
	var notes: Array = []
	var ops := _compile_node(root, 0, 1.0, "", "", "r", rejected, notes)
	if ops.is_empty():
		return _error("empty", canonical(root))
	return {"canonical": canonical(root), "ops": ops, "rejected": rejected, "notes": notes, "root": root}

func _compile_node(n: Dictionary, depth: int, coef: float, carrier: String,
		verb: String, path: String, rejected: Array, notes: Array) -> Array:
	var r: Dictionary = spec.runes[n.rune]
	var stats := grade_stats(r, n.grade)
	var open_abs: Array = []
	var locked: Array = []
	for a in r.abilities:
		if a.grade <= n.grade:
			open_abs.append(a)
		else:
			locked.append(a)
	if depth > 0 and not locked.is_empty():
		var nxt: Dictionary = locked[0]
		notes.append({"path": path, "text": _t("compile_locked", {"rune": rune_name(n.rune), "grade": n.grade, "ability": ability_name(n.rune, nxt.id), "unlock": gde(nxt.grade)})})
	var built: Dictionary = {}
	var order: Array = []
	for a in open_abs:
		for key in a.ops:
			if not built.has(key):
				var d: Dictionary = r.ops[key]
				var raw := d.duplicate()
				raw.erase("family")
				var params := _scale(_resolve(raw, stats), depth)
				if depth > 0 and d.family == "Damage":
					params.amount = params.amount * coef
				var op := {"uid": "%s.%s%d.%s" % [path, n.rune, n.grade, key],
					"family": d.family, "params": params, "rune": n.rune,
					"grade": n.grade, "depth": depth, "abilities": [], "slots": {},
					"slot_meta": {}, "carrier": carrier, "verb": verb}
				built[key] = op
				order.append(op)
			built[key].abilities.append(a.id)
	var out: Array = []
	var kept: Dictionary = {}
	for op in order:
		if depth > 0:
			var reason: String = _text("never_exported", op.family) if spec.never_exported.has(op.family) else ""
			if reason.is_empty() and op.family not in spec.carriers[carrier].allows:
				reason = _t("incompatible", {"family": family_name(op.family), "carrier": carrier_name(carrier)})
			if not reason.is_empty():
				rejected.append({"path": path, "donor": _t("rune_grade", {"rune": rune_name(n.rune), "grade": n.grade}), "family": op.family, "reason": reason})
				continue
		out.append(op)
		# UID membership is equivalent to Python's id(o) membership: one dict
		# per op key is built, and both arrays retain that very same dictionary.
		kept[op.uid] = true
	for a in open_abs:
		var kids: Array = n.grafts.get(a.id, [])
		if kids.is_empty():
			continue
		var car: String = a.carrier
		var ccoef: float = spec.carriers[car].coef
		var cverb: String = a.get("chain_verb", "")
		if cverb.is_empty():
			cverb = spec.carriers[car].chain_verb
		var children: Array = []
		var ordered := sorted_kids(kids)
		for i in range(ordered.size()):
			children.append_array(_compile_node(ordered[i], depth + 1,
				ccoef if a.slot != "event" or depth == 0 else coef,
				car, cverb, "%s.%s%d" % [path, a.id, i], rejected, notes))
		_diminish(children, depth + 1)
		if a.slot == "event":
			out.append_array(children)
		else:
			var host_ops: Array = []
			for key in a.ops:
				if kept.has(built[key].uid):
					host_ops.append(built[key])
			if host_ops.is_empty():
				continue
			# The reference selects the LAST kept op (despite its earlier comment).
			var tgt: Dictionary = host_ops[-1]
			if not tgt.slots.has(a.slot):
				tgt.slots[a.slot] = []
			tgt.slots[a.slot].append_array(children)
			tgt.slot_meta[a.slot] = {"carrier": car, "ability": a.id, "verb": cverb}
	return out

func _diminish(ops: Array, depth: int) -> void:
	var mult: Array = spec.coefficients.sibling_same_damage
	var by_el: Dictionary = {}
	for o in ops:
		if o.family == "Damage" and o.depth == depth:
			var el: String = o.params.element
			if not by_el.has(el):
				by_el[el] = []
			by_el[el].append(o)
	for lst in by_el.values():
		lst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.params.amount != b.params.amount:
				return a.params.amount > b.params.amount
			return a.uid < b.uid
		)
		for i in range(lst.size()):
			lst[i].params.amount *= mult[mini(i, mult.size() - 1)]

## Preorder traversal, following slot INSERTION order (serialization sorts slots).
func walk(ops: Array) -> Array:
	var out: Array = []
	for o in ops:
		out.append(o)
		for kids in o.slots.values():
			out.append_array(walk(kids))
	return out

func check_graft(host_recipe: String, ability: String, donor_recipe: String) -> Array:
	var host := parse(host_recipe)
	var donor := parse(donor_recipe)
	if host.has("error"):
		return [false, [host.error.message]]
	if donor.has("error"):
		return [false, [donor.error.message]]
	var r: Dictionary = spec.runes[host.rune]
	var a = r.ability_by_id.get(ability)
	if a == null:
		return [false, [_t("graft_unknown", {"ability": ability})]]
	if a.grade > host.grade:
		return [false, [_t("graft_locked", {"ability": ability_name(host.rune, a.id), "rune": rune_name(host.rune), "unlock": gde(a.grade)})]]
	var c := compile_recipe({"rune": host.rune, "grade": host.grade, "grafts": {ability: [donor]}})
	var donor_ops: Array = []
	for o in walk(c.ops):
		if o.depth == 1:
			donor_ops.append(o)
	var reasons: Array[String] = []
	for x in c.rejected:
		reasons.append(_t("graft_reason", {"prefix": _t("incompatible_prefix") if donor_ops.is_empty() else "", "reason": x.reason}))
	if donor_ops.is_empty() and reasons.is_empty():
		reasons.append(_t("incompatible_word"))
	return [not donor_ops.is_empty(), reasons]

# Godot's printf-style fixed precision uses binary64 -> decimal rounding,
# ties to even, just like Python format/round. Do NOT multiply then round:
# multiplication can erase which side of a decimal halfway point x was on.
func _fixed(x: float, digits: int) -> String:
	return ("%%.%df" % digits) % x

func _round(x: Variant) -> Variant:
	if x is float:
		return float(_fixed(x, 3))
	if x is Dictionary:
		var out: Dictionary = {}
		for k in x:
			out[k] = _round(x[k])
		return out
	if x is Array:
		var out: Array = []
		for v in x:
			out.append(_round(v))
		return out
	return x

func _op_json(o: Dictionary) -> Dictionary:
	var slots: Dictionary = {}
	var keys: Array = o.slots.keys()
	keys.sort()
	for k in keys:
		var children: Array = []
		for child in o.slots[k]:
			children.append(_op_json(child))
		slots[k] = children
	return {"uid": o.uid, "family": o.family, "params": _round(o.params),
		"src": "%s%d" % [o.rune, o.grade], "depth": o.depth,
		"abilities": o.abilities.duplicate(), "carrier": o.carrier, "slots": slots}

func to_json(compiled: Dictionary) -> Dictionary:
	if compiled.has("error"):
		return compiled.duplicate(true)
	var ops: Array = []
	for o in compiled.ops:
		ops.append(_op_json(o))
	return {"canonical": compiled.canonical, "ops": ops,
		"rejected": compiled.rejected.duplicate(true), "notes": compiled.notes.duplicate(true)}

func gde(g: int) -> String:
	return _t("grade_early" if g <= 2 else "grade_late", {"grade": g})

func _f(x: float) -> String:
	var nearest := float(_fixed(x, 0))
	var s := _fixed(x, 1) if absf(x - nearest) > 1e-6 else str(int(nearest))
	return s.replace(".", _locale.decimal)

func _pct(x: float) -> String:
	return _f(x * 100)

func op_text(o: Dictionary) -> String:
	var p: Dictionary = o.params
	match o.family:
		"Damage":
			return _t("op_damage", {"amount": _f(p.amount), "element": element_name(p.element)})
		"ApplyStatus":
			match p.status:
				"burn":
					var t := _t("op_burn", {"dps": _f(p.dps), "dur": _f(p.dur)})
					if p.get("trail_dps", 0):
						t += _t("op_trail", {"dps": _f(p.trail_dps), "dur": _f(p.trail_dur)})
					return t
				"slow":
					return _t("op_slow", {"pct": _pct(p.pct), "dur": _f(p.dur)})
				"cold":
					var t := _t("op_cold", {"threshold": _f(p.threshold), "freeze": _f(p.freeze)})
					if p.get("shards", 0):
						t += _t("op_shards", {"shards": _f(p.shards), "damage": _f(p.shard_dmg)})
					if p.get("nova_r", 0):
						t += _t("op_nova", {"radius": _f(p.nova_r)})
					return t
				"charge":
					return _t("op_charge", {"max": _f(p.max), "burst": _f(p.burst), "stun": _f(p.stun)})
				"poison":
					var t := _t("op_poison", {"dps": _f(p.dps), "dur": _f(p.dur)})
					if p.get("max_stacks", 1) > 1:
						t += _t("op_stacks", {"stacks": _f(p.max_stacks)})
					if p.get("heal_supp", 0):
						t += _t("op_heal_supp", {"pct": _pct(p.heal_supp)})
					if p.get("contagion", 0):
						t += _t("op_contagion", {"pct": _pct(p.contagion)})
					return t
				"wet":
					return _t("op_wet", {"dur": _f(p.dur)})
				"shred":
					return _t("op_shred", {"pct": _pct(p.pct), "dur": _f(p.dur)})
				"blind":
					return _t("op_blind", {"dur": _f(p.dur)})
				"lit":
					return _t("op_lit", {"pct": _pct(p.pct), "dur": _f(p.dur)})
				"mana_mark":
					var t := _t("op_mana_mark", {"dur": _f(p.dur), "radius": _f(p.r), "pct": _pct(p.mark_pct)})
					if p.get("crystal", 0):
						t += _t("op_crystal", {"count": _f(p.crystal)})
					return t
				"stun":
					return _t("op_stun", {"dur": _f(p.dur)})
				"bleed":
					var t := _t("op_bleed", {"damage": _f(p.per_tile), "dur": _f(p.dur)})
					if p.get("max_int", 1) > 1:
						t += _t("op_intensity", {"max": _f(p.max_int)})
					if p.get("rupture", 0):
						t += _t("op_rupture", {"damage": _f(p.rupture)})
					return t
			return _text("status_ops", p.status) if _locale.status_ops.has(p.status) else p.status
		"ForceMove":
			return _t("op_push", {"distance": _f(p.dist)})
		"ManaSiphon":
			return _t("op_siphon", {"pct": _pct(p.siphon)})
		"ChainTransfer":
			return _t("op_chain", {"verb": _verb_text(o.verb), "hops": _f(p.hops), "power": _f(p.power)})
		"Pierce":
			return _t("op_pierce", {"count": _f(p.n), "power": _f(p.power)})
		"AreaImpact":
			return _t("op_area", {"radius": _f(p.r), "pct": _pct(p.frac)})
		"SpawnFragments":
			return _t("op_fragments", {"count": _f(p.n), "pct": _pct(p.frac)})
		"MultiImpact":
			return _t("op_meteors", {"count": _f(p.n), "pct": _pct(p.frac)})
		"CreateGroundField":
			var native_texts: Array[String] = []
			for x in p.get("native", []):
				native_texts.append(op_text({"family": x.family, "params": x, "rune": o.rune, "grade": o.grade, "depth": o.depth, "verb": ""}))
			var kind: String = _t("lava_pool") if p.kind == "lava_pool" else p.kind
			return _t("op_field", {"kind": kind, "dur": _f(p.dur), "effects": ", ".join(native_texts)})
		"ModifyIncomingDamage":
			return _t("op_armor", {"pct": _pct(p.pct)})
	return _text("family_ops", o.family) if _locale.family_ops.has(o.family) else o.family

func describe(text_or_compiled: Variant) -> String:
	var c: Dictionary
	if text_or_compiled is Dictionary and text_or_compiled.has("ops"):
		c = text_or_compiled
	else:
		c = compile_recipe(text_or_compiled)
	if c.has("error"):
		return c.error.message
	var n: Dictionary = c.root
	var r: Dictionary = spec.runes[n.rune]
	var by_path: Dictionary = {}
	for o in walk(c.ops):
		# Python uid.rsplit('.', 2)[0]; rune and op key are the last two parts.
		var parts: PackedStringArray = o.uid.rsplit(".", true, 2)
		var path: String = parts[0]
		if not by_path.has(path):
			by_path[path] = []
		by_path[path].append(o)
	var rej: Dictionary = {}
	for x in c.rejected:
		if not rej.has(x.path):
			rej[x.path] = []
		rej[x.path].append(x)
	var notes: Dictionary = {}
	for x in c.notes:
		notes[x.path] = x.text
	var title := _t("rune_grade", {"rune": rune_name(n.rune), "grade": n.grade})
	if node_size(n) > 1:
		title += _t("title_grafts", {"count": node_size(n) - 1, "depth": node_depth(n) - 1})
	var lines: Array[String] = [title]
	for a in r.abilities:
		if a.grade > n.grade:
			lines.append(_t("ability_locked", {"ability": ability_name(n.rune, a.id), "unlock": gde(a.grade)}))
			continue
		lines.append(_t("ability_line", {"ability": ability_name(n.rune, a.id), "desc": ability_desc(n.rune, a.id, n.grade)}))
		lines.append_array(_kid_lines(n, a, "r", 0, by_path, rej, notes))
	return "\n".join(lines)

func _tmpl(r: Dictionary, g: int) -> Dictionary:
	var t: Dictionary = {}
	var stats := grade_stats(r, g)
	for k in stats:
		var v = stats[k]
		var numeric: bool = v is int or v is float or v is bool
		t[k] = _f(float(v)) if numeric else v
		if numeric:
			t[k + "_pct"] = _pct(float(v))
	return t

func _format_template(template: String, values: Dictionary) -> String:
	# Missing fields are '?' in the reference's _Default.format_map.
	var re := RegEx.new()
	re.compile("\\{([^{}]+)\\}")
	var out := ""
	var pos := 0
	for m in re.search_all(template):
		out += template.substr(pos, m.get_start() - pos)
		out += str(values.get(m.get_string(1), "?"))
		pos = m.get_end()
	return out + template.substr(pos)

func _kid_lines(n: Dictionary, a: Dictionary, path: String, depth: int,
		by_path: Dictionary, rej: Dictionary, notes: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var kids: Array = sorted_kids(n.grafts.get(a.id, []))
	var car: String = carrier_name(a.carrier)
	var ind := "    ".repeat(depth + 1)
	for i in range(kids.size()):
		var k: Dictionary = kids[i]
		var kp := "%s.%s%d" % [path, a.id, i]
		var kr: Dictionary = spec.runes[k.rune]
		var own: Array[String] = []
		for o in by_path.get(kp, []):
			if o.depth == depth + 1:
				own.append(op_text(o))
		var body := "; ".join(own) if not own.is_empty() else _t("no_contribution")
		out.append(_t("kid_line", {"indent": ind, "rune": rune_name(k.rune), "grade": k.grade, "carrier": car, "body": body}))
		for x in rej.get(kp, []):
			out.append(_t("rejected_line", {"indent": ind, "family": family_name(x.family), "reason": x.reason}))
		if notes.has(kp):
			out.append(ind + "    " + notes[kp])
		for ka in kr.abilities:
			if ka.grade <= k.grade and not k.grafts.get(ka.id, []).is_empty():
				out.append(_t("nested_heading", {"indent": ind, "rune": rune_name(k.rune), "ability": ability_name(k.rune, ka.id)}))
				out.append_array(_kid_lines(k, ka, kp, depth + 1, by_path, rej, notes))
	return out

func rune_value(rune_id: String, grade: int) -> float:
	var e: Dictionary = spec.economy
	var v: float = e.rune_buy_g1_mana[spec.runes[rune_id].buy]
	for k in range(2, grade + 1):
		v = 2 * v + e.combine.fee_mana_per_target_grade_minus_1 * (k - 1)
	return v

func graft_fee(n: int) -> float:
	return 20 * pow(1.3, n - 2)

func _build_cost(n: Dictionary) -> Array:
	var runes := rune_value(n.rune, n.grade)
	var fees := 0.0
	var size := 1
	var steps := 0
	for a in spec.runes[n.rune].abilities:
		for k in sorted_kids(n.grafts.get(a.id, [])):
			var child := _build_cost(k)
			runes += child[0]
			fees += child[1]
			size += child[2]
			steps += child[3] + 1
			fees += graft_fee(size)
	return [runes, fees, size, steps]

func cost(text_or_node: Variant) -> Dictionary:
	var root: Dictionary = parse(text_or_node) if text_or_node is String else text_or_node
	if root.has("error"):
		return root
	var values := _build_cost(root)
	return {"runes_mana": int(_fixed(values[0], 0)),
		"graft_fees_mana": int(_fixed(values[1], 0)),
		"total_mana": int(_fixed(values[0] + values[1], 0)), "mana_stone": 0,
		"nodes": values[2], "graft_steps": values[3],
		"note": _t("cost_note")}

## Locale files use named {field} placeholders; literal percent signs need no escaping.
## Failure preserves the active locale. The packaged Turkish table defines the schema.
func set_locale(path: String) -> Error:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		if not _locale.is_empty():
			push_error(_t("locale_load", {"path": path}))
		return ERR_PARSE_ERROR
	if not _locale_reference.is_empty() and not _same_locale_schema(_locale_reference, data):
		push_error(_t("locale_invalid", {"path": path}))
		return ERR_INVALID_DATA
	if not data.has("locale_id") or not data.has("decimal"):
		return ERR_INVALID_DATA
	_locale = data
	locale_id = data.locale_id
	locale_keys_used["locale_id"] = true
	locale_keys_used["decimal"] = true
	if _locale_reference.is_empty():
		_locale_reference = data.duplicate(true)
	return OK

func _fields(text: String) -> Array[String]:
	var fields: Array[String] = []
	var re: RegEx = RegEx.new()
	re.compile("\\{([^{}]+)\\}")
	for m in re.search_all(text):
		fields.append(m.get_string(1))
	fields.sort()
	return fields

func _same_locale_schema(reference: Variant, candidate: Variant) -> bool:
	if reference is Dictionary:
		if not candidate is Dictionary or reference.size() != candidate.size():
			return false
		for key in reference:
			if not candidate.has(key) or not _same_locale_schema(reference[key], candidate[key]):
				return false
		return true
	return candidate is String and _fields(reference) == _fields(candidate)

func _lookup(parts: Array) -> String:
	var value: Variant = _locale
	for part in parts:
		assert(value is Dictionary and value.has(part))
		value = value[part]
	assert(value is String)
	locale_keys_used[".".join(parts)] = true
	return value

func _text(section: String, key: String) -> String:
	return _lookup([section, key])

func _t(key: String, values: Dictionary = {}) -> String:
	return _format_template(_text("templates", key), values)

func rune_name(rune_id: String) -> String:
	return _lookup(["runes", rune_id, "name"])

func rune_identity(rune_id: String) -> String:
	return _lookup(["runes", rune_id, "identity"])

func ability_name(rune_id: String, ability_id: String) -> String:
	return _lookup(["runes", rune_id, "abilities", ability_id, "name"])

func ability_desc(rune_id: String, ability_id: String, grade: int) -> String:
	return _format_template(_lookup(["runes", rune_id, "abilities", ability_id, "desc"]), _tmpl(spec.runes[rune_id], grade))

func carrier_name(carrier_id: String) -> String:
	return _text("carriers", carrier_id)

func element_name(element: String) -> String:
	return _text("elements", element)

func status_name(status: String) -> String:
	return _text("statuses", status)

func family_name(family: String) -> String:
	return _text("families", family)

func grade_unlock_text(grade: int) -> String:
	return gde(grade)

func _verb_text(verb_key: String) -> String:
	# Raw Turkish verb values are opaque compiler keys, never display text.
	assert(_verb_keys.has(verb_key))
	return _text("verbs", _verb_keys[verb_key])
