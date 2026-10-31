extends RefCounted
## UI strings. They live in the "ui" section of scripts/locale/<lang>.json, next to the rune texts, so one locale
## file carries the whole game. Placeholders are named: "{n} mana". A missing key shows the key itself (visible in
## captures), never crashes.

static var _ui: Dictionary = {}
static var lang := ""


static func load_lang(code: String) -> void:
	var path := "res://scripts/locale/%s.json" % code
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if data is Dictionary and data.get("ui") is Dictionary:
		_ui = data.ui
		lang = code


static func t(key: String, vals: Dictionary = {}) -> String:
	if _ui.is_empty():
		load_lang("en")
	var s: String = str(_ui.get(key, key))
	for k in vals:
		s = s.replace("{%s}" % k, str(vals[k]))
	return s


static func has(key: String) -> bool:
	return _ui.has(key)
