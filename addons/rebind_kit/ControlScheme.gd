## ControlScheme: the inputs of one family (keyboard with mouse, or gamepad) for every command, two per command: the
## primary and the alternative, which can be empty. A default scheme comes from data or from the InputMap; a custom one
## is a copy of another (base_id says which). It saves as data: an unreadable input is skipped, the scheme stays.
class_name ControlScheme
extends RefCounted

const PRIMARY := 0
const ALTERNATIVE := 1
const SLOTS := 2

var id: StringName
var title: String
var family: StringName
## The scheme it was copied from; empty for a default.
var base_id: StringName
## command -> [primary, alternative], InputKey or null.
var _slots: Dictionary = {}

func _init(scheme_id: StringName, scheme_title: String, scheme_family: StringName, from_id: StringName = &"") -> void:
	id = scheme_id
	title = scheme_title
	family = scheme_family
	base_id = from_id

func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_slots.keys())
	return out

func key_at(action: StringName, slot: int) -> InputKey:
	return (_slots[action] as Array)[slot] if _slots.has(action) else null

func set_key(action: StringName, slot: int, key: InputKey) -> void:
	if not _slots.has(action):
		_slots[action] = [null, null]
	(_slots[action] as Array)[slot] = key

func clear(action: StringName, slot: int) -> void:
	set_key(action, slot, null)

## Who uses `key`: {"action", "slot"}, empty if nobody.
func slot_of(key: InputKey) -> Dictionary:
	for action: StringName in _slots:
		for slot in SLOTS:
			if key.equals(key_at(action, slot)):
				return {"action": action, "slot": slot}
	return {}

## Puts `b` where `a` was and vice versa, in every command (a scheme made from another with two inputs swapped).
func swap_keys(a: InputKey, b: InputKey) -> void:
	for action: StringName in _slots:
		for slot in SLOTS:
			var key := key_at(action, slot)
			if a.equals(key):
				set_key(action, slot, b)
			elif b.equals(key):
				set_key(action, slot, a)

func copy(new_id: StringName, new_title: String) -> ControlScheme:
	var out := ControlScheme.new(new_id, new_title, family, id)
	for action: StringName in _slots:
		for slot in SLOTS:
			out.set_key(action, slot, key_at(action, slot))
	return out

func same_keys(other: ControlScheme) -> bool:
	var all := actions()
	for action in other.actions():
		if action not in all:
			all.append(action)
	for action in all:
		for slot in SLOTS:
			var mine := key_at(action, slot)
			var theirs := other.key_at(action, slot)
			if (mine == null) != (theirs == null) or (mine != null and not mine.equals(theirs)):
				return false
	return true

func to_data() -> Dictionary:
	var slots := {}
	for action: StringName in _slots:
		var pair: Array = []
		for slot in SLOTS:
			var key := key_at(action, slot)
			pair.append(key.to_data() if key != null else null)
		slots[String(action)] = pair
	return {"id": String(id), "title": title, "family": String(family), "base_id": String(base_id), "slots": slots}

## null if id or family are missing.
static func from_data(data: Dictionary) -> ControlScheme:
	var scheme_family := StringName(str(data.get("family", "")))
	if not data.has("id") or scheme_family not in [InputKey.KEYBOARD, InputKey.PAD]:
		return null
	var scheme := ControlScheme.new(StringName(str(data["id"])), str(data.get("title", data["id"])), scheme_family,
		StringName(str(data.get("base_id", ""))))
	var slots: Variant = data.get("slots", {})
	if not slots is Dictionary:
		return scheme
	for action: String in slots:
		var pair: Variant = slots[action]
		if not pair is Array:
			continue
		for slot in mini((pair as Array).size(), SLOTS):
			var key := InputKey.from_data((pair as Array)[slot])
			if key != null and key.family() == scheme_family:
				scheme.set_key(StringName(action), slot, key)
	return scheme

## The `family` scheme currently in the InputMap for `actions`: the first two inputs of the family, in order.
static func from_input_map(scheme_id: StringName, scheme_title: String, scheme_family: StringName,
		scheme_actions: Array) -> ControlScheme:
	var scheme := ControlScheme.new(scheme_id, scheme_title, scheme_family)
	for action: StringName in scheme_actions:
		var slot := 0
		for event in InputMap.action_get_events(action):
			var key := InputKey.from_event(event)
			if key == null or key.family() != scheme_family or slot >= SLOTS:
				continue
			if scheme.slot_of(key).get("action", &"") == action:
				continue
			scheme.set_key(action, slot, key)
			slot += 1
		if slot == 0:
			scheme.set_key(action, PRIMARY, null)
	return scheme
