## FileRemapAdapter: a ready-to-use RemapAdapter. The command catalog comes from a Dictionary or a JSON file, the
## defaults are the project's InputMap, the player's choices are saved to a JSON file, and every input gets a drawn key
## made from a font (Godot's default one if none is given). Gamepad buttons use the Xbox names.
class_name FileRemapAdapter
extends RemapAdapter

const DEFAULT_SAVE_PATH := "user://rebind_kit.json"
## How large the keys are drawn in the panel buttons.
const KEY_SCALE := 1.3
## Gamepad names by Godot's (SDL) button index: the layout of an Xbox pad.
const PAD_BUTTONS := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "VIEW", 5: "GUIDE", 6: "MENU", 7: "LS", 8: "RS", 9: "LB", 10: "RB",
	11: "UP", 12: "DOWN", 13: "LEFT", 14: "RIGHT", 15: "SHARE",
}
## Gamepad axes: a stick has one name per direction, a trigger one name.
const PAD_AXES := {
	0: {-1: "LS LEFT", 1: "LS RIGHT"}, 1: {-1: "LS UP", 1: "LS DOWN"},
	2: {-1: "RS LEFT", 1: "RS RIGHT"}, 3: {-1: "RS UP", 1: "RS DOWN"},
	4: {1: "LT", -1: "LT"}, 5: {1: "RT", -1: "RT"},
}
const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "WHEEL UP", MOUSE_BUTTON_WHEEL_DOWN: "WHEEL DOWN",
}

var save_path: String
var _catalog: Dictionary = {}
var _renderer: KeyCapRenderer

## `catalog`: the RemapCatalog data as a Dictionary, or the path of a JSON file holding it.
func _init(catalog: Variant, path: String = DEFAULT_SAVE_PATH, font: Font = null) -> void:
	save_path = path
	_catalog = catalog if catalog is Dictionary else _read_json(str(catalog))
	_renderer = KeyCapRenderer.new(font if font != null else ThemeDB.fallback_font, "")

func catalog_data() -> Dictionary:
	return _catalog

func load_state() -> Dictionary:
	return _read_json(save_path)

func save_state(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("[rebind_kit] can't write %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))

func key_texture(key: InputKey) -> Texture2D:
	var name := key_name(key)
	var shape := KeyCapRenderer.SHAPE_BUTTON if key.is_pad() else KeyCapRenderer.SHAPE_KEY
	return _renderer.texture("%s:%s" % [InputKey.SOURCE_NAMES[key.source], name], name, shape, KEY_SCALE)

func key_name(key: InputKey) -> String:
	match key.source:
		InputKey.Source.KEY:
			return KeyLabel.keyboard(key.code)
		InputKey.Source.MOUSE:
			return str(MOUSE_BUTTONS.get(key.code, "MOUSE %d" % key.code))
		InputKey.Source.PAD_BUTTON:
			return str(PAD_BUTTONS.get(key.code, "BUTTON %d" % key.code))
	var axis: Dictionary = PAD_AXES.get(key.code, {})
	return str(axis.get(key.direction, "AXIS %d" % key.code))

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# A JSON instance reports a broken file without printing an engine error: a broken save just starts over.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("[rebind_kit] can't read %s: starting from the defaults" % path)
		return {}
	return json.data if json.data is Dictionary else {}
