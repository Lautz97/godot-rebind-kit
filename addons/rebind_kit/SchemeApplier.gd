## SchemeApplier: puts a scheme into the InputMap. For every listed command it removes the inputs of the scheme's
## family and adds its own, primary then alternative; the other family's inputs stay. A command that already has those
## inputs, in that order, is left alone: the default scheme leaves the project's InputMap as it is. A command the
## InputMap doesn't have is skipped with a warning: the scheme comes from a save, the game may have changed. For a
## `player`, the commands get its names, its gamepad's device and, if it hasn't the mouse, no mouse buttons; a
## combination is skipped (the InputMap can't hold it).
class_name SchemeApplier
extends RefCounted

static func apply(scheme: ControlScheme, actions: Array, player: RemapPlayer = null) -> void:
	for base: StringName in actions:
		var action := base if player == null else InputDelivery.ensure_action(player, base)
		if not InputMap.has_action(action):
			push_warning("[rebind_kit] command with no InputMap action: %s" % action)
			continue
		var wanted: Array[InputKey] = []
		for slot in ControlScheme.SLOTS:
			var key := scheme.key_at(base, slot)
			if key != null and not key.is_chord() and (player == null or player.can_use(key)):
				wanted.append(key)
		var current: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			var key := InputKey.from_event(event)
			if key != null and key.family() == scheme.family:
				current.append(event)
		if _same(current, wanted, player):
			continue
		for event in current:
			InputMap.action_erase_event(action, event)
		for key in wanted:
			InputMap.action_add_event(action, _event_for(key, player))

## A player with its own gamepad listens to that device only; the others keep Godot's default device.
static func _event_for(key: InputKey, player: RemapPlayer) -> InputEvent:
	var event := key.to_event()
	if player != null and key.is_pad() and player.pad >= 0:
		event.device = player.pad
	return event

static func _same(events: Array[InputEvent], keys: Array[InputKey], player: RemapPlayer) -> bool:
	if events.size() != keys.size():
		return false
	for i in keys.size():
		if not keys[i].equals(InputKey.from_event(events[i])):
			return false
		# The device counts only for a player with its own gamepad: the project's events (every device) stay as they are.
		if player != null and player.pad >= 0 and keys[i].is_pad() and events[i].device != player.pad:
			return false
	return true
