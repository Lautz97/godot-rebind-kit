## InputKey: a key, a button or an axis: what gets pressed, not what it's called (KeyLabel) nor how it's drawn
## (KeyCapRenderer). The keyboard counts by position (the code is a physical_keycode, which Godot names after the US
## QWERTY layout): on another keyboard the command stays in the same spot. It saves as data and turns back into an
## InputMap event.
class_name InputKey
extends RefCounted

enum Source { KEY, MOUSE, PAD_BUTTON, PAD_AXIS }

## The two families of a scheme: the keyboard brings the mouse along, the gamepad buttons and axes.
const KEYBOARD := &"keyboard"
const PAD := &"pad"
const SOURCE_NAMES := {Source.KEY: "key", Source.MOUSE: "mouse", Source.PAD_BUTTON: "pad_button", Source.PAD_AXIS: "pad_axis"}

var source: Source
## The key's position, the mouse or gamepad button, the axis.
var code: int
## For an axis, the direction (-1 or +1); 0 for everything else.
var direction: int = 0

func _init(key_source: Source, key_code: int, key_direction: int = 0) -> void:
	source = key_source
	code = key_code
	direction = key_direction

func is_pad() -> bool:
	return source == Source.PAD_BUTTON or source == Source.PAD_AXIS

func family() -> StringName:
	return PAD if is_pad() else KEYBOARD

func equals(other: InputKey) -> bool:
	return other != null and other.source == source and other.code == code and other.direction == direction

func to_data() -> Dictionary:
	var data := {"source": SOURCE_NAMES[source], "code": code}
	if source == Source.PAD_AXIS:
		data["direction"] = direction
	return data

## null if the data doesn't describe an input.
static func from_data(data: Variant) -> InputKey:
	if not data is Dictionary or not (data as Dictionary).has("code"):
		return null
	var found: Variant = SOURCE_NAMES.find_key(str((data as Dictionary).get("source", "")))
	if found == null:
		return null
	var key_source := found as Source
	var axis_direction := signi(int((data as Dictionary).get("direction", 0))) if key_source == Source.PAD_AXIS else 0
	return InputKey.new(key_source, int((data as Dictionary)["code"]), axis_direction)

## The input of an InputMap event; null if it isn't something you can bind (a mouse motion).
static func from_event(event: InputEvent) -> InputKey:
	if event is InputEventKey:
		var k := event as InputEventKey
		# A key written by letter (keycode) counts as its position on QWERTY: Godot numbers them the same.
		return InputKey.new(Source.KEY, k.physical_keycode if k.physical_keycode else k.keycode)
	if event is InputEventMouseButton:
		return InputKey.new(Source.MOUSE, (event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return InputKey.new(Source.PAD_BUTTON, (event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return InputKey.new(Source.PAD_AXIS, motion.axis, signi(roundi(motion.axis_value)))
	return null

## The event to put in the InputMap.
func to_event() -> InputEvent:
	match source:
		Source.KEY:
			var key := InputEventKey.new()
			key.physical_keycode = code as Key
			return key
		Source.MOUSE:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = code as MouseButton
			return mouse
		Source.PAD_BUTTON:
			var button := InputEventJoypadButton.new()
			button.button_index = code as JoyButton
			return button
	var motion := InputEventJoypadMotion.new()
	motion.axis = code as JoyAxis
	motion.axis_value = float(direction)
	return motion
