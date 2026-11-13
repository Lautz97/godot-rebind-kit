## RemapPlayer: one local player. Its devices (the keyboard, the mouse, one gamepad or every gamepad), its own schemes
## (a SchemeLibrary: the defaults are everyone's, the custom ones its own) and the names of its commands in the InputMap:
## player 1 uses the game's names, the others get a suffix (jump -> jump_p2).
class_name RemapPlayer
extends RefCounted

## Every gamepad answers this player: the single-player case.
const ANY_PAD := -1
const NO_PAD := -2

var index: int
var library: SchemeLibrary
var keyboard := true
## The mouse belongs to one player only, among those with the keyboard.
var mouse := true
## The gamepad's device id, ANY_PAD or NO_PAD.
var pad := ANY_PAD
## The model (GUID) and name of the gamepad in use: the owner of the gamepad's custom scheme. Empty: none yet.
var pad_guid := ""
var pad_name := ""

func _init(player_index: int, player_library: SchemeLibrary) -> void:
	index = player_index
	library = player_library

## The InputMap name of command `base` for this player.
func action(base: StringName) -> StringName:
	return base if index == 1 else StringName("%s_p%d" % [base, index])

## The scheme in use for the family.
func active(family: StringName) -> ControlScheme:
	return library.keyboard() if family == InputKey.KEYBOARD else library.last_pad()

## Whether the family is among this player's devices.
func has_family(family: StringName) -> bool:
	return keyboard if family == InputKey.KEYBOARD else pad != NO_PAD

## Whether `event` comes from one of this player's devices.
func owns(event: InputEvent) -> bool:
	if event is InputEventKey:
		return keyboard
	if event is InputEventMouseButton:
		return keyboard and mouse
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return pad == ANY_PAD or (pad >= 0 and event.device == pad)
	return false

## Whether `key` may be bound for this player (the mouse only for whoever has it).
func can_use(key: InputKey) -> bool:
	if not has_family(key.family()):
		return false
	return mouse or key.sequence().all(func(part: InputKey) -> bool: return part.source != InputKey.Source.MOUSE)
