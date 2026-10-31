extends PanelContainer
## Rune inspector: the full graft tree of one rune as a collapsible tree, so recipes with many / nested donors
## stay readable. Root = the main rune; under it every ability (open, or locked with its unlock grade); under an
## ability every donor rune with what it contributes there (compiled op texts), anything that was not carried
## (✗ + reason), and — nested — the donor's own grafted abilities. Built from the same compiled program the
## combat uses, so the view is reproducible for any recipe.
## Open with: right-click a rune slot, or "Inspect" on the tower card.

const S := preload("res://ui/style.gd")
const UISkin := preload("res://ui/skin.gd")

var game
var tree: Tree
var title: Label
var summary: Label
var node = null


func _init(g) -> void:
	game = g
	add_theme_stylebox_override("panel", UISkin.box("chip_rune", Vector4(-1, -1, -1, -1), Vector4(16, 12, 16, 14)))
	custom_minimum_size = Vector2(660, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var h := HBoxContainer.new()
	title = S.label("", 20, S.TRIM_LIGHT, "head")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.add_theme_color_override("font_color", S.TEXT_DIM)
	close.pressed.connect(hide_inspector)
	h.add_child(close)
	v.add_child(h)
	summary = S.label("", 12, S.TEXT_MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(628, 0)      # a width bound keeps the wrapped label's height sane
	v.add_child(summary)
	tree = Tree.new()
	tree.hide_root = false
	tree.custom_minimum_size = Vector2(628, 520)
	tree.add_theme_font_override("font", S.font("body"))
	tree.add_theme_font_size_override("font_size", 13)
	tree.add_theme_color_override("font_color", S.TEXT_DIM)
	tree.add_theme_color_override("font_selected_color", Color.WHITE)
	tree.add_theme_constant_override("v_separation", 4)
	tree.add_theme_constant_override("item_margin", 18)
	var empty := StyleBoxEmpty.new()
	tree.add_theme_stylebox_override("panel", empty)
	tree.add_theme_stylebox_override("focus", empty)
	v.add_child(tree)
	var hint := S.label("Click a ▸ to fold / unfold. Grade pips show G1–G5; ✗ = not carried, ◇ = locked.", 11, S.TEXT_MUTED)
	v.add_child(hint)


func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		hide_inspector()
		get_viewport().set_input_as_handled()


func hide_inspector() -> void:
	visible = false
	node = null


func show_rune(n) -> void:
	if n == null:
		return
	node = n
	var rl = game.rl
	var c: Dictionary = rl.compile_recipe(n)
	var by_path := {}
	for o in rl.walk(c.ops):
		var path: String = o.uid.rsplit(".", true, 2)[0]
		if not by_path.has(path):
			by_path[path] = []
		by_path[path].append(o)
	var rej := {}
	for x in c.rejected:
		if not rej.has(x.path):
			rej[x.path] = []
		rej[x.path].append(x)
	var n_size: int = rl.node_size(n)
	title.text = "%s G%d" % [rl.rune_name(n.rune), int(n.grade)]
	summary.text = "%s\n%d rune%s in this recipe · graft depth %d · value ≈ %d mana" % [rl.rune_identity(n.rune), n_size,
		"" if n_size == 1 else "s", rl.node_depth(n) - 1, roundi(rl.cost(n).total_mana)]
	tree.clear()
	var root := tree.create_item()
	root.set_text(0, "%s G%d" % [rl.rune_name(n.rune), int(n.grade)])
	root.set_icon(0, UISkin.tex("rune_%s_g%d" % [n.rune, int(n.grade)]))
	root.set_icon_max_width(0, 28)
	root.set_custom_color(0, S.TRIM_LIGHT)
	_abilities(root, n, "r", 0, by_path, rej, true)
	visible = true
	size = get_combined_minimum_size()
	var vp := get_viewport_rect().size
	position = Vector2(roundf(vp.x - 470 - size.x - 24), roundf(clampf((vp.y - size.y) * 0.5, 16, vp.y - size.y - 16)))


func _abilities(parent: TreeItem, n: Dictionary, path: String, depth: int, by_path: Dictionary, rej: Dictionary, all: bool) -> void:
	var rl = game.rl
	for a in game.spec.runes[n.rune].abilities:
		var kids: Array = rl.sorted_kids(n.grafts.get(a.id, []))
		if not all and kids.is_empty():
			continue
		var it := tree.create_item(parent)
		if int(a.grade) > int(n.grade):
			it.set_text(0, "◇ %s — unlocks %s" % [rl.ability_name(n.rune, a.id), rl.grade_unlock_text(int(a.grade))])
			it.set_custom_color(0, S.TEXT_MUTED)
			continue
		var cnt := "" if kids.is_empty() else "   [%d donor%s]" % [kids.size(), "" if kids.size() == 1 else "s"]
		it.set_text(0, "%s  ·  %s%s" % [rl.ability_name(n.rune, a.id), rl.carrier_name(a.carrier), cnt])
		it.set_custom_color(0, S.TEXT if not kids.is_empty() else S.TEXT_DIM)
		it.set_tooltip_text(0, rl.ability_desc(n.rune, a.id, int(n.grade)))
		for i in kids.size():
			var k: Dictionary = kids[i]
			var kp := "%s.%s%d" % [path, a.id, i]
			var di := tree.create_item(it)
			di.set_icon(0, UISkin.tex("rune_%s_g%d" % [k.rune, int(k.grade)]))
			di.set_icon_max_width(0, 22)
			var own := []
			for o in by_path.get(kp, []):
				if int(o.depth) == depth + 1:
					own.append(rl.op_text(o))
			di.set_text(0, "%s G%d — %s" % [rl.rune_name(k.rune), int(k.grade), "; ".join(own) if not own.is_empty() else "no contribution here"])
			di.set_custom_color(0, Color("#9FD3FF") if not own.is_empty() else S.TEXT_MUTED)
			di.set_tooltip_text(0, di.get_text(0))       # long contribution lists: full text on hover
			for x in rej.get(kp, []):
				var ri := tree.create_item(di)
				ri.set_text(0, "✗ %s not carried: %s" % [rl.family_name(x.family) if rl.has_method("family_name") else x.family, x.reason])
				ri.set_custom_color(0, S.BAD)
			_abilities(di, k, kp, depth + 1, by_path, rej, false)
			di.collapsed = depth >= 1
