extends RefCounted
## Loads the HUD textures exported from Penpot (assets/ui/*.png, @2x; pulled by ui_design/pull_penpot_exports.sh)
## and builds StyleBoxes from them. Nothing here is drawn procedurally — Penpot is the design source.

const TexBox := preload("res://ui/tex_box.gd")

## 9-slice margins (1x design px) for each exported piece
const NINE := {
	"panel_9slice": Vector4(34, 34, 34, 34), "card_tower": Vector4(30, 30, 30, 30),
	"tab_idle": Vector4(16, 12, 16, 8), "tab_hover": Vector4(16, 12, 16, 8), "tab_active": Vector4(16, 12, 16, 8),
	"btn": Vector4(14, 10, 14, 12), "coin": Vector4(12, 10, 12, 12), "slot": Vector4(14, 14, 14, 14),
	"well": Vector4(10, 8, 10, 8), "chip": Vector4(10, 10, 10, 10), "bar": Vector4(6, 4, 6, 4),
}

static var _tex: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := ProjectSettings.globalize_path("res://assets/ui/%s.png" % name)
		var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		if img == null:
			push_warning("missing UI texture: " + name)
			img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		_tex[name] = ImageTexture.create_from_image(img)
	return _tex[name]


static func box(name: String, margins := Vector4(-1, -1, -1, -1), content := Vector4(-1, -1, -1, -1)) -> StyleBox:
	var m := margins
	if m.x < 0:
		var key := name
		for k in NINE:
			if name.begins_with(k):
				key = k
		m = NINE.get(key, Vector4(12, 12, 12, 12))
	return TexBox.new().setup(tex(name), m, content)


## Button skin from Penpot states: kind = "btn" | "btn_rune" | "btn_gold" | "btn_bad" | "coin"
static func button(b: Button, kind := "btn", font_col := Color("#1E1D24")) -> void:
	var states := {"normal": "normal", "hover": "hover", "pressed": "pressed", "hover_pressed": "pressed", "disabled": "disabled"}
	for st in states:
		var tname: String
		if kind == "coin":
			tname = "coin_%s" % {"normal": "normal", "hover": "hover", "pressed": "active", "disabled": "normal"}[states[st]]
		elif states[st] == "disabled":
			tname = "btn_disabled"
		else:
			tname = "%s_%s" % [kind, states[st]]
		var c := Vector4(14, 6, 14, 10) if kind != "coin" else Vector4(4, 4, 4, 6)
		b.add_theme_stylebox_override(st, box(tname, Vector4(-1, -1, -1, -1), c))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, font_col)
	b.add_theme_color_override("font_disabled_color", Color("#3E3C44"))
	b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.25))
	b.add_theme_constant_override("outline_size", 0)
