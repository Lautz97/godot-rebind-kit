## InputRemap: the plugin's facade. With the game's adapter it loads the saved schemes and puts them into the
## InputMap, watches gamepads connecting, opens the panel's drafts and saves them. Whatever shows keys listens to
## `changed`; whatever must ask for an unknown gamepad's scheme listens to `unknown_pad`.
class_name InputRemap
extends Node

signal changed()
signal unknown_pad(guid: String, pad_name: String)

var adapter: RemapAdapter
var catalog: RemapCatalog
var library: SchemeLibrary
var watcher: PadWatcher
## The GUID of the last connected gamepad: the owner of the gamepad's custom scheme.
var current_pad := ""
var _current_pad_name := ""

func _init(remap_adapter: RemapAdapter, pad_info: Callable = Callable()) -> void:
	adapter = remap_adapter
	catalog = RemapCatalog.new(adapter.catalog_data())
	library = SchemeLibrary.new(adapter.builtin_schemes(catalog.all_actions()))
	watcher = PadWatcher.new(library, adapter.recognize_pad, pad_info)
	watcher.name = "PadWatcher"

func _ready() -> void:
	library.load_data(adapter.load_state())
	_apply_all()
	watcher.scheme_chosen.connect(on_pad_scheme)
	watcher.unknown_pad.connect(_on_unknown_pad)
	add_child(watcher)

## The scheme in use for the family.
func active(family: StringName) -> ControlScheme:
	return library.keyboard() if family == InputKey.KEYBOARD else library.last_pad()

func draft(family: StringName) -> RemapDraft:
	var scheme := active(family)
	return RemapDraft.new(catalog, scheme, library.is_builtin(scheme.id),
		library.required_actions(scheme, catalog.all_actions()))

## Saves the draft (false if commands are pending): a touched default becomes the owner's custom scheme.
func save(remap_draft: RemapDraft, family: StringName) -> bool:
	if not remap_draft.can_save():
		return false
	var edited := remap_draft.scheme()
	if remap_draft.forked():
		var custom := library.ensure_custom(_owner(family), _owner_title(family), family)
		var stored := edited.copy(custom.id, custom.title)
		stored.base_id = edited.base_id
		library.store(stored)
	else:
		library.store(edited)
	_apply_and_save()
	return true

## The scheme picked from the menu for the family (the connected gamepad, for gamepads).
func select(family: StringName, id: StringName) -> void:
	if family == InputKey.KEYBOARD:
		library.select_keyboard(id)
	else:
		library.assign_pad(current_pad, id, _current_pad_name)
	_apply_and_save()

## The family's custom scheme, made from the scheme in use if missing (the menu's "Custom" entry).
func custom(family: StringName) -> ControlScheme:
	var scheme := library.ensure_custom(_owner(family), _owner_title(family), family)
	_apply_and_save()
	return scheme

## The layout chosen for gamepad model `guid` (what is printed on its buttons); empty for automatic.
func pad_layout(guid: String) -> StringName:
	return library.pad_layout(guid)

## The layout of the connected gamepad, from the panel's menu (empty: automatic). Keys get redrawn through `changed`.
func set_pad_layout(layout: StringName) -> void:
	if current_pad.is_empty():
		return
	library.set_pad_layout(current_pad, layout)
	adapter.save_state(library.to_data())
	changed.emit()

## The player's answer for a gamepad that wasn't recognized.
func choose_for_pad(guid: String, id: StringName, pad_name: String) -> void:
	current_pad = guid
	_current_pad_name = pad_name
	library.assign_pad(guid, id, pad_name)
	_apply_and_save()

func on_pad_scheme(guid: String, scheme: ControlScheme) -> void:
	current_pad = guid
	_current_pad_name = library.pad_name(guid)
	SchemeApplier.apply(scheme, catalog.all_actions())
	adapter.save_state(library.to_data())
	changed.emit()

func _on_unknown_pad(guid: String, pad_name: String) -> void:
	current_pad = guid
	_current_pad_name = pad_name
	unknown_pad.emit(guid, pad_name)

func _owner(family: StringName) -> String:
	return SchemeLibrary.KEYBOARD_OWNER if family == InputKey.KEYBOARD or current_pad.is_empty() else current_pad

## A custom scheme's title is its gamepad's name (empty for the keyboard): the panel writes it in its own language.
func _owner_title(family: StringName) -> String:
	return "" if family == InputKey.KEYBOARD else _current_pad_name

## A scheme's menu name: the default's title, or "Custom" with the gamepad's name.
func scheme_label(scheme: ControlScheme) -> String:
	if library.is_builtin(scheme.id):
		return adapter.text(scheme.title)
	return adapter.text("custom") if scheme.title.is_empty() else adapter.text("custom_of") % scheme.title

func _apply_all() -> void:
	SchemeApplier.apply(library.keyboard(), catalog.all_actions())
	SchemeApplier.apply(library.last_pad(), catalog.all_actions())

func _apply_and_save() -> void:
	_apply_all()
	adapter.save_state(library.to_data())
	changed.emit()
