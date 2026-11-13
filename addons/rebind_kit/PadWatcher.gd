## PadWatcher: when a gamepad connects, finds its scheme. A model seen before gets its own back; a new one whose name
## is recognized (the adapter's `recognize` function, empty if not) takes that scheme without asking; one that isn't
## recognized is reported with unknown_pad, and whoever listens asks the player. With several players each gamepad is
## looked up in its owner's schemes (`library_for`); a gamepad nobody owns is ignored.
class_name PadWatcher
extends Node

signal scheme_chosen(device: int, guid: String, scheme: ControlScheme)
signal unknown_pad(device: int, guid: String, pad_name: String)

## device -> the SchemeLibrary of the player owning it, or null. By default, the one given at creation.
var library_for: Callable

var _library: SchemeLibrary
var _recognize: Callable
## device -> {"guid", "name"}; by default it asks Input (tests pass their own).
var _pad_info: Callable

func _init(library: SchemeLibrary, recognize: Callable, pad_info: Callable = Callable()) -> void:
	_library = library
	_recognize = recognize
	_pad_info = pad_info if pad_info.is_valid() else input_pad_info
	library_for = func(_device: int) -> SchemeLibrary: return _library

func _ready() -> void:
	Input.joy_connection_changed.connect(on_connection_changed)
	for device in Input.get_connected_joypads():
		on_connection_changed(device, true)

func on_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		return
	var library: SchemeLibrary = library_for.call(device)
	if library == null:
		return
	var info: Dictionary = _pad_info.call(device)
	var guid := str(info.get("guid", ""))
	var pad_name := str(info.get("name", ""))
	var scheme := library.scheme_for_pad(guid, _recognize.call(pad_name), pad_name)
	if scheme == null:
		unknown_pad.emit(device, guid, pad_name)
	else:
		scheme_chosen.emit(device, guid, scheme)

## A gamepad that isn't connected (assigned ahead of time) has no name yet: asking Input would print an engine error.
static func input_pad_info(device: int) -> Dictionary:
	if device not in Input.get_connected_joypads():
		return {}
	return {"guid": Input.get_joy_guid(device), "name": Input.get_joy_name(device)}
