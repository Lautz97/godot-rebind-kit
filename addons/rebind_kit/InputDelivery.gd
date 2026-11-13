## InputDelivery: how the players' schemes become commands the game sees. InputMapDelivery puts them in Godot's
## InputMap (single keys only, nothing runs while playing); ChordDelivery reads the raw inputs and sends the commands
## itself, which is what combinations need. The adapter picks one (RemapAdapter.delivery()); InputRemap adds it as a
## child and calls apply() whenever the schemes or the players change.
class_name InputDelivery
extends Node

## Whether the panel may capture combinations.
func supports_chords() -> bool:
	return false

## Puts the schemes of `players` in place for the catalog's commands.
func apply(_players: Array[RemapPlayer], _actions: Array[StringName]) -> void:
	pass

## The schemes of a player's families: the active scheme where the player has the family, an empty one where not
## (its inputs get removed).
static func schemes_of(player: RemapPlayer) -> Array[ControlScheme]:
	var out: Array[ControlScheme] = []
	for family: StringName in [InputKey.KEYBOARD, InputKey.PAD]:
		out.append(player.active(family) if player.has_family(family) else ControlScheme.new(&"", "", family))
	return out

## Player 2 and later need their own commands in the InputMap, with the dead zone of player 1's.
static func ensure_action(player: RemapPlayer, base: StringName) -> StringName:
	var name := player.action(base)
	if not InputMap.has_action(name) and InputMap.has_action(base):
		InputMap.add_action(name, InputMap.action_get_deadzone(base))
	return name
