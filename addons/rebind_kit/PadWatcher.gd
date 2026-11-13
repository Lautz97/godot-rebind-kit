## PadWatcher: when a gamepad connects, finds its scheme. A model seen before gets its own back; a new one whose name
## is recognized (the adapter's `recognize` function, empty if not) takes that scheme without asking; one that isn't
## recognized is reported with unknown_pad, and whoever listens asks the player.
class_name PadWatcher
extends Node

signal scheme_chosen(guid: String, scheme: ControlScheme)
signal unknown_pad(guid: String, pad_name: String)

var _library: SchemeLibrary
var _recognize: Callable
## device -> {"guid", "name"}; by default it asks Input (tests pass their own).
var _pad_info: Callable

func _init(library: SchemeLibrary, recognize: Callable, pad_info: Callable = Callable()) -> void:
	_library = library
	_recognize = recognize
	_pad_info = pad_info if pad_info.is_valid() else _input_pad_info

func _ready() -> void:
	Input.joy_connection_changed.connect(on_connection_changed)
	for device in Input.get_connected_joypads():
		on_connection_changed(device, true)

func on_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		return
	var info: Dictionary = _pad_info.call(device)
	var guid := str(info.get("guid", ""))
	var pad_name := str(info.get("name", ""))
	var scheme := _library.scheme_for_pad(guid, _recognize.call(pad_name), pad_name)
	if scheme == null:
		unknown_pad.emit(guid, pad_name)
	else:
		scheme_chosen.emit(guid, scheme)

static func _input_pad_info(device: int) -> Dictionary:
	return {"guid": Input.get_joy_guid(device), "name": Input.get_joy_name(device)}
