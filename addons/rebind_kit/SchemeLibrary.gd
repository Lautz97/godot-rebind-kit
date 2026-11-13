## SchemeLibrary: the schemes the player can choose and which one each device uses. Defaults are given by whoever
## creates it (in menu order); one custom scheme per owner (the keyboard, or a gamepad model by GUID), made from the
## scheme in use; every gamepad model remembers its scheme and its name. It saves as data; a state naming schemes that
## no longer exist falls back to the defaults.
class_name SchemeLibrary
extends RefCounted

## The owner of the keyboard's custom scheme (gamepads use their GUID).
const KEYBOARD_OWNER := "keyboard"
const CUSTOM_PREFIX := "custom_"

var _builtins: Array[ControlScheme] = []
## id -> ControlScheme, in creation order.
var _customs: Dictionary = {}
## Model GUID -> scheme id.
var _pads: Dictionary = {}
var _pad_names: Dictionary = {}
## Model GUID -> layout id (what is printed on its buttons), only when the player chose one: missing = automatic.
var _pad_layouts: Dictionary = {}
var _keyboard_id: StringName = &""
var _last_pad_id: StringName = &""

func _init(builtins: Array) -> void:
	_builtins.assign(builtins)
	_reset_choices()

func is_builtin(id: StringName) -> bool:
	return _builtins.any(func(s: ControlScheme) -> bool: return s.id == id)

func scheme(id: StringName) -> ControlScheme:
	for s in _builtins:
		if s.id == id:
			return s
	return _customs.get(id)

## The default `of` comes from: itself if it is one, else the one it was copied from, else the family's first.
func default_of(of: ControlScheme) -> ControlScheme:
	for id in [of.id, of.base_id]:
		if is_builtin(id):
			return scheme(id)
	for s in _builtins:
		if s.family == of.family:
			return s
	return of

## The commands `of` must keep an input for: those its default gives a primary. The others start empty somewhere (a
## keyboard command the gamepad doesn't need) and the player may leave them so.
func required_actions(of: ControlScheme, actions: Array[StringName]) -> Array[StringName]:
	var defaults := default_of(of)
	return actions.filter(func(a: StringName) -> bool: return defaults.key_at(a, ControlScheme.PRIMARY) != null)

## The family's defaults, then its custom schemes: the menu entries.
func schemes(family: StringName) -> Array[ControlScheme]:
	var out: Array[ControlScheme] = []
	for s in _builtins:
		if s.family == family:
			out.append(s)
	for s: ControlScheme in _customs.values():
		if s.family == family:
			out.append(s)
	return out

func keyboard() -> ControlScheme:
	return scheme(_keyboard_id)

func select_keyboard(id: StringName) -> void:
	var chosen := scheme(id)
	if chosen != null and chosen.family == InputKey.KEYBOARD:
		_keyboard_id = id

func last_pad() -> ControlScheme:
	return scheme(_last_pad_id)

## The scheme of gamepad model `guid`: the one it remembers, or the default `recognized` (the family recognized from
## the name, empty if not). null if the model is new and unrecognized: the player gets asked. `pad_title`, when given,
## is remembered as the gamepad's name.
func scheme_for_pad(guid: String, recognized: StringName, pad_title: String = "") -> ControlScheme:
	if not pad_title.is_empty():
		_pad_names[guid] = pad_title
	var found := scheme(_pads.get(guid, &""))
	if found == null and recognized != &"" and scheme(recognized) != null:
		found = scheme(recognized)
		_pads[guid] = recognized
	if found != null:
		_last_pad_id = found.id
	return found

func assign_pad(guid: String, id: StringName, pad_title: String) -> void:
	if scheme(id) == null:
		return
	_pads[guid] = id
	_pad_names[guid] = pad_title
	_last_pad_id = id

func pad_name(guid: String) -> String:
	return str(_pad_names.get(guid, ""))

## The layout chosen for gamepad model `guid`; empty for automatic (the game decides from the name).
func pad_layout(guid: String) -> StringName:
	return _pad_layouts.get(guid, &"")

## Empty `layout` goes back to automatic.
func set_pad_layout(guid: String, layout: StringName) -> void:
	if layout == &"":
		_pad_layouts.erase(guid)
	else:
		_pad_layouts[guid] = layout

## The custom scheme of `owner` (KEYBOARD_OWNER or a gamepad GUID); if missing it's made from the scheme in use (for a
## gamepad never set up, from the last gamepad scheme) and becomes the owner's.
func ensure_custom(owner: String, owner_title: String, family: StringName) -> ControlScheme:
	var id := StringName(CUSTOM_PREFIX + owner.validate_node_name())
	if not _customs.has(id):
		var from := keyboard() if family == InputKey.KEYBOARD else last_pad()
		var custom := from.copy(id, owner_title)
		_customs[id] = custom
	if family == InputKey.KEYBOARD:
		_keyboard_id = id
	else:
		assign_pad(owner, id, owner_title)
	return _customs[id]

## Stores a changed custom scheme (same id); defaults are never overwritten.
func store(custom: ControlScheme) -> void:
	if not is_builtin(custom.id):
		_customs[custom.id] = custom

func to_data() -> Dictionary:
	return {
		"customs": _customs.values().map(func(s: ControlScheme) -> Dictionary: return s.to_data()),
		"pads": _pads.duplicate(),
		"pad_names": _pad_names.duplicate(),
		"pad_layouts": _pad_layouts.duplicate(),
		"keyboard": String(_keyboard_id),
		"last_pad": String(_last_pad_id),
	}

## A saved state; whatever names missing schemes or can't be read falls back to the defaults.
func load_data(data: Dictionary) -> void:
	_customs.clear()
	_pads.clear()
	_pad_names.clear()
	_pad_layouts.clear()
	_reset_choices()
	var customs: Variant = data.get("customs", [])
	for entry: Variant in (customs if customs is Array else []):
		var custom := ControlScheme.from_data(entry) if entry is Dictionary else null
		if custom != null and not is_builtin(custom.id):
			_inherit_new_commands(custom)
			_customs[custom.id] = custom
	var pads: Variant = data.get("pads", {})
	for guid: Variant in (pads if pads is Dictionary else {}):
		var id := StringName(str(pads[guid]))
		if scheme(id) != null:
			_pads[str(guid)] = id
	var names: Variant = data.get("pad_names", {})
	for guid: Variant in (names if names is Dictionary else {}):
		_pad_names[str(guid)] = str(names[guid])
	var layouts: Variant = data.get("pad_layouts", {})
	for guid: Variant in (layouts if layouts is Dictionary else {}):
		set_pad_layout(str(guid), StringName(str(layouts[guid])))
	select_keyboard(StringName(str(data.get("keyboard", ""))))
	var last := scheme(StringName(str(data.get("last_pad", ""))))
	if last != null and last.family == InputKey.PAD:
		_last_pad_id = last.id

## A custom scheme saved before the game had some command takes that command's inputs from the scheme it was made
## from, instead of being left without (a new command with no input at all).
func _inherit_new_commands(custom: ControlScheme) -> void:
	var base := scheme(custom.base_id)
	if base == null:
		return
	var known := custom.actions()
	for action in base.actions():
		if action in known:
			continue
		for slot in ControlScheme.SLOTS:
			custom.set_key(action, slot, base.key_at(action, slot))

func _reset_choices() -> void:
	_keyboard_id = &""
	_last_pad_id = &""
	for s in _builtins:
		if s.family == InputKey.KEYBOARD and _keyboard_id == &"":
			_keyboard_id = s.id
		if s.family == InputKey.PAD and _last_pad_id == &"":
			_last_pad_id = s.id
