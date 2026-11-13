## RemapDraft: the panel's changes before they are saved. An input already used by a command active at the same time
## (same catalog scope) is swapped, and that command stays pending until it's confirmed or rebound: nothing saves while
## a command is pending. Across different scopes the same input sits on two commands. Required commands (whoever
## creates the draft says which) always keep a primary; the others may be left with no input. Opened on a default
## scheme, the first change works on a copy (forked): whoever saves turns it into a custom scheme. Combinations follow
## ChordRules: a key that opens a combination clashes with a command on that key alone, so every command it clashes with
## is moved (the first takes the old input, the others are left empty) and stays pending. Other players who share the
## keyboard (`neighbors`) can't use the same input either: the other player's command takes the old input, no
## confirmation needed, and whoever saves stores their schemes too (`neighbor_schemes`).
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
## Player index -> that player's keyboard scheme, as opened.
var _neighbors: Dictionary = {}
## Player index -> the copy changed by a swap.
var _neighbor_changes: Dictionary = {}
## {"player", "action"} of every neighbor's command moved by this draft.
var _neighbor_swaps: Array[Dictionary] = []

## `required`: the commands that can't be left without a primary; null for all of them. `neighbors`: player index ->
## the keyboard scheme of each other player sharing the keyboard.
func _init(catalog: RemapCatalog, scheme: ControlScheme, builtin: bool, required: Variant = null,
		neighbors: Dictionary = {}) -> void:
	_catalog = catalog
	_original = scheme
	_builtin = builtin
	_neighbors = neighbors
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

## Player index -> the scheme of that player changed by a swap: to be stored with this one.
func neighbor_schemes() -> Dictionary:
	return _neighbor_changes.duplicate()

## {"player", "action"} of the other players' commands that took a swapped input.
func neighbor_swaps() -> Array[Dictionary]:
	return _neighbor_swaps.duplicate()

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
	_working.set_key(action, slot, null)
	var holders := _holders_in_group(key, action)
	var give: InputKey = old
	for holder: Dictionary in holders:
		var other: StringName = holder["action"]
		_working.set_key(other, holder["slot"], give)
		give = null
		if other != action:
			swapped.append(other)
			if not _pending.has(other):
				_pending.append(other)
	if holders.is_empty():
		_swap_with_neighbor(key, action, old)
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
	_neighbor_changes.clear()
	_neighbor_swaps.clear()

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

## Whose inputs clash with `key` among the commands active together with `action` (itself included), in order:
## [{"action", "slot"}].
func _holders_in_group(key: InputKey, action: StringName) -> Array[Dictionary]:
	return _holders_in(_working, key, action, true)

func _holders_in(scheme: ControlScheme, key: InputKey, action: StringName, mine_first: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var others := _catalog.conflicting(action)
	# The same command first: swapping between primary and alternative needs no confirmation.
	others.erase(action)
	if mine_first:
		others.push_front(action)
	else:
		others.append(action)
	for other in others:
		for slot in ControlScheme.SLOTS:
			if ChordRules.clashes(key, scheme.key_at(other, slot)):
				out.append({"action": other, "slot": slot})
	return out

## Another player on the keyboard holding a clashing input gets `old` in its place.
func _swap_with_neighbor(key: InputKey, action: StringName, old: InputKey) -> void:
	if key.family() != InputKey.KEYBOARD:
		return
	for player: int in _neighbors:
		var scheme: ControlScheme = _neighbor_changes.get(player, _neighbors[player])
		var holders := _holders_in(scheme, key, action, false)
		if holders.is_empty():
			continue
		if not _neighbor_changes.has(player):
			scheme = scheme.copy(scheme.id, scheme.title)
			scheme.base_id = (_neighbors[player] as ControlScheme).base_id
			_neighbor_changes[player] = scheme
		var give: InputKey = old
		for holder: Dictionary in holders:
			scheme.set_key(holder["action"], holder["slot"], give)
			give = null
			_neighbor_swaps.append({"player": player, "action": holder["action"]})
