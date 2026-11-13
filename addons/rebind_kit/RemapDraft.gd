## RemapDraft: the panel's changes before they are saved. An input already used by a command active at the same time
## (same catalog scope) is swapped, and that command stays pending until it's confirmed or rebound: nothing saves while
## a command is pending. Across different scopes the same input sits on two commands. Required commands (whoever
## creates the draft says which) always keep a primary; the others may be left with no input. Opened on a default
## scheme, the first change works on a copy (forked): whoever saves turns it into a custom scheme.
class_name RemapDraft
extends RefCounted

var _catalog: RemapCatalog
var _original: ControlScheme
var _builtin: bool
var _working: ControlScheme
var _forked := false
var _dirty := false
var _pending: Array[StringName] = []
var _required: Array[StringName] = []

## `required`: the commands that can't be left without a primary; null for all of them.
func _init(catalog: RemapCatalog, scheme: ControlScheme, builtin: bool, required: Variant = null) -> void:
	_catalog = catalog
	_original = scheme
	_builtin = builtin
	if required is Array:
		_required.assign(required)
	else:
		_required = catalog.all_actions()
	discard()

func is_required(action: StringName) -> bool:
	return _required.has(action)

## The scheme as it would be saved right now.
func scheme() -> ControlScheme:
	return _working

func original() -> ControlScheme:
	return _original

func forked() -> bool:
	return _forked

func is_dirty() -> bool:
	return _dirty

func pending() -> Array[StringName]:
	return _pending.duplicate()

func can_save() -> bool:
	return _pending.is_empty()

## An input of the scheme's family.
func accepts(key: InputKey) -> bool:
	return key != null and key.family() == _working.family

## Puts `key` in `slot` of `action`; returns the commands that gave up the input (pending). An input of the other
## family changes nothing.
func rebind(action: StringName, slot: int, key: InputKey) -> Array[StringName]:
	var swapped: Array[StringName] = []
	if not accepts(key):
		return swapped
	var old := _working.key_at(action, slot)
	if key.equals(old):
		_settle(action)
		return swapped
	_fork()
	var holder := _holder_in_group(key, action)
	if not holder.is_empty():
		var other: StringName = holder["action"]
		_working.set_key(other, holder["slot"], old)
		if other != action:
			swapped.append(other)
			if not _pending.has(other):
				_pending.append(other)
	_working.set_key(action, slot, key)
	_settle(action)
	_dirty = true
	return swapped

## The swapped command keeps the input it has now; a required one not if its primary was left empty.
func confirm(action: StringName) -> bool:
	if is_required(action) and _working.key_at(action, ControlScheme.PRIMARY) == null:
		return false
	_pending.erase(action)
	return true

## Something to remove: the alternative, or the primary of a command that isn't required.
func can_clear(action: StringName) -> bool:
	return _clearable_slot(action) >= 0

## Removes the alternative, or else the primary of a command that isn't required.
func clear(action: StringName) -> bool:
	var slot := _clearable_slot(action)
	if slot < 0:
		return false
	_fork()
	_working.clear(action, slot)
	_dirty = true
	return true

func _clearable_slot(action: StringName) -> int:
	if _working.key_at(action, ControlScheme.ALTERNATIVE) != null:
		return ControlScheme.ALTERNATIVE
	if not is_required(action) and _working.key_at(action, ControlScheme.PRIMARY) != null:
		return ControlScheme.PRIMARY
	return -1

## Everything goes back to how it was when opened.
func discard() -> void:
	_working = _original
	_forked = false
	_dirty = false
	_pending.clear()

## A command rebound by hand is no longer pending, if it has a primary again.
func _settle(action: StringName) -> void:
	if _pending.has(action) and _working.key_at(action, ControlScheme.PRIMARY) != null:
		_pending.erase(action)

func _fork() -> void:
	if _working != _original:
		return
	_working = _original.copy(_original.id, _original.title)
	_working.base_id = _original.base_id
	if _builtin:
		_working.base_id = _original.id
		_forked = true

## Who uses `key` among the commands active together with `action` (itself included): {"action", "slot"} or empty.
func _holder_in_group(key: InputKey, action: StringName) -> Dictionary:
	var others := _catalog.conflicting(action)
	# The same command first: swapping between primary and alternative needs no confirmation.
	others.erase(action)
	others.push_front(action)
	for other in others:
		for slot in ControlScheme.SLOTS:
			if key.equals(_working.key_at(other, slot)):
				return {"action": other, "slot": slot}
	return {}
