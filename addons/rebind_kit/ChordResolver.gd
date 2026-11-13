## ChordResolver: which commands start and stop while one player presses and releases inputs. A key that opens a
## combination (a prefix) does nothing by itself; while it's held only what continues its combination can fire, and
## the rest is silent. Keys that open nothing don't get in the way (holding W, Space still jumps). Commands already
## held when a prefix goes down stay held. No nodes and no Input: whoever owns it feeds the presses and acts on the
## answers.
class_name ChordResolver
extends RefCounted

## command -> its inputs (single keys or combinations).
var _bindings: Dictionary = {}
## The prefix keys held now, in the order they were pressed.
var _opened: Array[InputKey] = []
var _held: Array[InputKey] = []
## command -> the sequence that fired it, for as long as it stays pressed.
var _active: Dictionary = {}

## `bindings`: command -> Array of InputKey. Whatever is held is forgotten.
func set_bindings(bindings: Dictionary) -> void:
	_bindings = bindings
	reset()

func reset() -> void:
	_opened.clear()
	_held.clear()
	_active.clear()

## The commands that start with this press (empty if it's a prefix, is silenced or opens nothing).
func press(key: InputKey) -> Array[StringName]:
	var started: Array[StringName] = []
	if _index_of(_held, key) >= 0:
		return started
	_held.append(key)
	var tried: Array[InputKey] = _opened.duplicate()
	tried.append(key)
	var opens := false
	for action: StringName in _bindings:
		for bound: InputKey in _bindings[action]:
			var sequence := bound.sequence()
			if _same(sequence, tried):
				if not _active.has(action):
					_active[action] = sequence
					started.append(action)
			elif sequence.size() > tried.size() and ChordRules.starts_with(sequence, tried):
				opens = true
	if opens:
		_opened = tried
	return started

## The commands that stop with this release: those whose keys included it.
func release(key: InputKey) -> Array[StringName]:
	var stopped: Array[StringName] = []
	var at := _index_of(_held, key)
	if at < 0:
		return stopped
	_held.remove_at(at)
	var opened_at := _index_of(_opened, key)
	if opened_at >= 0:
		_opened = _opened.slice(0, opened_at)
	for action: StringName in _active.keys():
		if _index_of(_active[action], key) >= 0:
			_active.erase(action)
			stopped.append(action)
	return stopped

## The held commands that `key` closed (to follow a stick's strength while it stays pushed).
func actions_on(key: InputKey) -> Array[StringName]:
	var out: Array[StringName] = []
	for action: StringName in _active:
		var sequence: Array = _active[action]
		if (sequence[sequence.size() - 1] as InputKey).equals(key):
			out.append(action)
	return out

func held_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_active.keys())
	return out

static func _index_of(keys: Array, key: InputKey) -> int:
	for i in keys.size():
		if (keys[i] as InputKey).equals(key):
			return i
	return -1

static func _same(a: Array[InputKey], b: Array[InputKey]) -> bool:
	return a.size() == b.size() and ChordRules.starts_with(a, b)
