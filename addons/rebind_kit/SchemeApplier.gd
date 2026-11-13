## SchemeApplier: puts a scheme into the InputMap. For every listed command it removes the inputs of the scheme's
## family and adds its own, primary then alternative; the other family's inputs stay. A command that already has those
## inputs, in that order, is left alone: the default scheme leaves the project's InputMap as it is. A command the
## InputMap doesn't have is skipped with a warning: the scheme comes from a save, the game may have changed.
class_name SchemeApplier
extends RefCounted

static func apply(scheme: ControlScheme, actions: Array) -> void:
	for action: StringName in actions:
		if not InputMap.has_action(action):
			push_warning("[rebind_kit] command with no InputMap action: %s" % action)
			continue
		var wanted: Array[InputKey] = []
		for slot in ControlScheme.SLOTS:
			var key := scheme.key_at(action, slot)
			if key != null:
				wanted.append(key)
		var current: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			var key := InputKey.from_event(event)
			if key != null and key.family() == scheme.family:
				current.append(event)
		if _same(current, wanted):
			continue
		for event in current:
			InputMap.action_erase_event(action, event)
		for key in wanted:
			InputMap.action_add_event(action, key.to_event())

static func _same(events: Array[InputEvent], keys: Array[InputKey]) -> bool:
	if events.size() != keys.size():
		return false
	for i in keys.size():
		if not keys[i].equals(InputKey.from_event(events[i])):
			return false
	return true
