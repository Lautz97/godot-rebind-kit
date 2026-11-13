## KeyCapture: while listening, takes the next input of the chosen family (keyboard with mouse, or gamepad) before
## anyone else, so the pressed key doesn't also trigger its command. Listening can't be cancelled: any input gets bound,
## "back" included; inputs of the other family are swallowed. Releases, repeats and barely touched sticks don't count.
class_name KeyCapture
extends Node

signal captured(key: InputKey)

## How far a stick or trigger has to be pushed to count.
const AXIS_THRESHOLD := 0.6

var _family: StringName = &""

func listen(family: StringName) -> void:
	_family = family

func stop() -> void:
	_family = &""

func is_listening() -> bool:
	return _family != &""

func _input(event: InputEvent) -> void:
	if take(event):
		get_viewport().set_input_as_handled()

## true if the event belongs to the listening (taken, or of the other family): it must not go further.
func take(event: InputEvent) -> bool:
	if not is_listening() or not _is_press(event):
		return false
	var key := InputKey.from_event(event)
	if key == null:
		return false
	if key.family() != _family:
		return true
	stop()
	captured.emit(key)
	return true

static func _is_press(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	return event.is_pressed()
