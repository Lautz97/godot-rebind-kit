## KeyCapture: while listening, takes the next input of the chosen family (keyboard with mouse, or gamepad) before
## anyone else, so the pressed key doesn't also trigger its command. Listening can't be cancelled: any input gets bound,
## "back" included; inputs of the other family, and of other players' devices, are swallowed. Repeats and barely touched
## sticks don't count. With combinations the keys pressed are collected in order, and the first one released (or the
## fourth one pressed) closes the combination; without, the first press is the input.
class_name KeyCapture
extends Node

signal captured(key: InputKey)

## How far a stick or trigger has to be pushed to count.
const AXIS_THRESHOLD := 0.6

var _family: StringName = &""
var _player: RemapPlayer = null
var _chords := false
## The keys held so far, in order (combinations only).
var _held: Array[InputKey] = []

## `player`: listen only to that player's devices (null: any). `chords`: collect a combination.
func listen(family: StringName, player: RemapPlayer = null, chords: bool = false) -> void:
	_family = family
	_player = player
	_chords = chords
	_held.clear()

func stop() -> void:
	_family = &""
	_held.clear()

func is_listening() -> bool:
	return _family != &""

func _input(event: InputEvent) -> void:
	if take(event):
		get_viewport().set_input_as_handled()

## true if the event belongs to the listening (taken, or of the other family): it must not go further.
func take(event: InputEvent) -> bool:
	if not is_listening():
		return false
	var key := InputKey.from_event(event)
	if key == null:
		return false
	if key.family() != _family or (_player != null and not _player.owns(event)):
		return _is_press(event) or not _held.is_empty()
	if _chords:
		return _take_chord(event, key)
	if not _is_press(event):
		return false
	_finish(key)
	return true

func _take_chord(event: InputEvent, key: InputKey) -> bool:
	if _is_press(event):
		if not _held.any(func(held: InputKey) -> bool: return held.equals(key)):
			_held.append(key)
		if _held.size() >= InputKey.MAX_KEYS:
			_finish(InputKey.chord(_held))
		return true
	if _is_release_of_held(event, key):
		_finish(InputKey.chord(_held))
		return true
	return not _held.is_empty()

func _finish(key: InputKey) -> void:
	stop()
	captured.emit(key)

## A key, button or stick direction among those held going back up.
func _is_release_of_held(event: InputEvent, key: InputKey) -> bool:
	if _held.is_empty():
		return false
	if event is InputEventJoypadMotion:
		return _held.any(func(held: InputKey) -> bool:
			return held.source == InputKey.Source.PAD_AXIS and held.code == key.code)
	return not event.is_pressed() and _held.any(func(held: InputKey) -> bool: return held.equals(key))

static func _is_press(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	return event.is_pressed()
