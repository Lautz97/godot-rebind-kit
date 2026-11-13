## ChordDelivery: combinations need someone between the raw inputs and the game. The players' commands are left with no
## events in the InputMap; this node reads every raw input, asks each owning player's ChordResolver what starts and
## stops, and sends InputEventAction through Input.parse_input_event, so both is_action_pressed and _unhandled_input
## see the commands. Sticks and triggers count as pressed past AXIS_THRESHOLD; while a command on an axis is held its
## strength follows the stick. Raw inputs go on as they are (a LineEdit still gets its letters).
class_name ChordDelivery
extends InputDelivery

## How far a stick or trigger has to go to count as pressed.
const AXIS_THRESHOLD := 0.5

var _players: Array[RemapPlayer] = []
## Player index -> ChordResolver.
var _resolvers: Dictionary = {}

func supports_chords() -> bool:
	return true

func apply(players: Array[RemapPlayer], actions: Array[StringName]) -> void:
	_release_all()
	_players = players
	_resolvers.clear()
	for player in players:
		var bindings := {}
		for base in actions:
			var name := ensure_action(player, base)
			if not InputMap.has_action(name):
				continue
			InputMap.action_erase_events(name)
			var keys: Array[InputKey] = []
			for scheme in schemes_of(player):
				for slot in ControlScheme.SLOTS:
					var key := scheme.key_at(base, slot)
					if key != null and player.can_use(key):
						keys.append(key)
			bindings[name] = keys
		var resolver := ChordResolver.new()
		resolver.set_bindings(bindings)
		_resolvers[player.index] = resolver

func _input(event: InputEvent) -> void:
	handle(event)

## One raw input: the commands it starts or stops are sent.
func handle(event: InputEvent) -> void:
	if event is InputEventAction or event.is_echo():
		return
	for player in _players:
		if player.owns(event):
			_feed(_resolvers[player.index], event)

func _feed(resolver: ChordResolver, event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_feed_axis(resolver, event as InputEventJoypadMotion)
		return
	var key := InputKey.from_event(event)
	if key == null:
		return
	if event.is_pressed():
		_send(resolver.press(key), true, 1.0)
	else:
		_send(resolver.release(key), false, 0.0)

## A stick is two keys, one per direction: past the threshold one is pressed and the other released.
func _feed_axis(resolver: ChordResolver, motion: InputEventJoypadMotion) -> void:
	var value := motion.axis_value
	var pushed := signi(roundi(signf(value))) if absf(value) >= AXIS_THRESHOLD else 0
	for direction in [-1, 1]:
		var key := InputKey.new(InputKey.Source.PAD_AXIS, motion.axis, direction)
		if direction == pushed:
			var started := resolver.press(key)
			var held: Array[StringName] = resolver.actions_on(key)
			for action in started:
				held.erase(action)
			_send(started, true, absf(value))
			_send(held, true, absf(value))
		else:
			_send(resolver.release(key), false, 0.0)

func _send(actions: Array[StringName], pressed: bool, strength: float) -> void:
	for action in actions:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.strength = strength
		Input.parse_input_event(event)

func _release_all() -> void:
	for index: int in _resolvers:
		_send((_resolvers[index] as ChordResolver).held_actions(), false, 0.0)
