## PlayerJoin: while the game is taking players ("press a button to join"), the first press of each device says who
## comes next. It only reports the device; InputRemap decides whether it's free and makes the player.
class_name PlayerJoin
extends Node

## `keyboard`: the keyboard (or the mouse) pressed something; otherwise `pad` is the gamepad's device id.
signal device_pressed(keyboard: bool, pad: int)

var listening := false

func _input(event: InputEvent) -> void:
	handle(event)

func handle(event: InputEvent) -> void:
	if not listening or event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventMouseButton:
		device_pressed.emit(true, RemapPlayer.NO_PAD)
	elif event is InputEventJoypadButton:
		device_pressed.emit(false, event.device)
