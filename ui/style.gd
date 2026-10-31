extends RefCounted
## Shared UI palette, runtime font cache and label factory for the Penpot-based HUD.

const BEVEL_DARK := Color("#141418")
const TRIM_LIGHT := Color("#ECE6D6")
const TRIM_DARK := Color("#5A5A62")
const RUNE := Color("#7FE3F0")           # glowing groove / rune light
const TEXT := Color("#F1EBDD")
const TEXT_DIM := Color("#C4BEB0")
const TEXT_MUTED := Color("#8C877D")
const MANA := Color("#5CB9FF")
const GOOD := Color("#8ED45E")
const BAD := Color("#F06A5A")
const GOLD := Color("#F2C14E")


static var _fonts: Dictionary = {}


static func font(kind := "body") -> Font:
	if kind == "head" and not _fonts.has(kind):
		var base := FontFile.new()
		base.load_dynamic_font(ProjectSettings.globalize_path("res://fonts/Cinzel-Variable.ttf"))   # OFL, carved-stone capitals
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_fonts[kind] = fv
	if not _fonts.has(kind):
		var path: String = {"head": "res://fonts/NotoSerifDisplay-Bold.ttf", "bold": "res://fonts/NotoSans-Bold.ttf",
			"medium": "res://fonts/NotoSans-Medium.ttf"}.get(kind, "res://fonts/NotoSans-Regular.ttf")
		var f := FontFile.new()
		f.load_dynamic_font(ProjectSettings.globalize_path(path))   # runtime load: no editor import needed
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[kind] = f
	return _fonts[kind]


static func label(text: String, size := 16, c := TEXT, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


