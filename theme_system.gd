class_name ThemeSystem
extends RefCounted

const THEMES_PATH: String = "res://themes.json"

var themes: Array = []
var index: int = 0

func _init() -> void:
	_load_themes()

func _load_themes() -> void:
	if FileAccess.file_exists(THEMES_PATH):
		var file: FileAccess = FileAccess.open(THEMES_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				var loaded: Variant = parsed.get("themes", [])
				if loaded is Array and not loaded.is_empty():
					themes = loaded
	if themes.is_empty():
		push_error("No APS Racer themes loaded.")

func count() -> int:
	return themes.size()

func current() -> Dictionary:
	if themes.is_empty():
		return {}
	return Dictionary(themes[index])

func set_theme(next_index: int) -> Dictionary:
	if themes.is_empty():
		return {}
	index = posmod(next_index, themes.size())
	return current()

func cycle(direction: int = 1) -> Dictionary:
	return set_theme(index + direction)

func name() -> String:
	return String(current().get("name", "Theme"))

func id() -> String:
	return String(current().get("id", ""))

func value(key: String, fallback: Variant = null) -> Variant:
	return current().get(key, fallback)

func colour(key: String, fallback: Color = Color.WHITE) -> Color:
	var palette: Dictionary = Dictionary(current().get("palette", {}))
	if not palette.has(key):
		return fallback
	return Color(String(palette[key]))

func effect_mode() -> String:
	return String(current().get("effect_mode", "dust"))
