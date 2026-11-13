## InputRemap: the plugin's facade. With the game's adapter it loads the saved schemes and hands them to the delivery
## (the InputMap, or ChordDelivery for combinations), watches gamepads connecting, opens the panel's drafts and saves
## them. One player by default; up to the adapter's max_players() local players, each with its own devices and custom
## schemes, joining through start_join() or assign(). Every method that takes a player works on player 1 when it's left
## out. Whatever shows keys listens to `changed`; whatever must ask for an unknown gamepad's scheme listens to
## `unknown_pad` (player 1's gamepads; the others start from the default).
class_name InputRemap
extends Node

signal changed()
signal unknown_pad(guid: String, pad_name: String)
## A player came in through start_join(): its commands are `player(index).action(base)`.
signal player_joined(index: int)

var adapter: RemapAdapter
var catalog: RemapCatalog
## Player 1's schemes.
var library: SchemeLibrary
var watcher: PadWatcher
var delivery: InputDelivery
var join: PlayerJoin

var _players: Array[RemapPlayer] = []
## The defaults, made once from the project's InputMap before anything changes it: every player starts from them.
var _builtins: Array[ControlScheme] = []
## The saved schemes of players 2 and later (index - 2), kept even while they aren't playing.
var _saved_players: Array = []
var _pad_info: Callable
## How many players took a device since start_join().
var _joined := 0

func _init(remap_adapter: RemapAdapter, pad_info: Callable = Callable()) -> void:
	adapter = remap_adapter
	catalog = RemapCatalog.new(adapter.catalog_data())
	_builtins = adapter.builtin_schemes(catalog.all_actions())
	library = SchemeLibrary.new(_builtins)
	_players.append(RemapPlayer.new(1, library))
	_pad_info = pad_info if pad_info.is_valid() else PadWatcher.input_pad_info
	watcher = PadWatcher.new(library, adapter.recognize_pad, _pad_info)
	watcher.library_for = _library_for_device
	watcher.name = "PadWatcher"
	delivery = adapter.delivery()
	delivery.name = "Delivery"
	join = PlayerJoin.new()
	join.name = "PlayerJoin"

func _ready() -> void:
	var state := adapter.load_state()
	library.load_data(state)
	var saved: Variant = state.get("players", [])
	_saved_players = (saved as Array).duplicate(true) if saved is Array else []
	add_child(delivery)
	delivery.apply(_players, catalog.all_actions())
	watcher.scheme_chosen.connect(_on_pad_scheme)
	watcher.unknown_pad.connect(_on_unknown_pad)
	add_child(watcher)
	join.device_pressed.connect(_on_device_pressed)
	add_child(join)

# --- Players ---------------------------------------------------------------------------------------------------

func player(index: int = 1) -> RemapPlayer:
	return _players[index - 1]

func player_count() -> int:
	return _players.size()

## Whether the panel may capture combinations.
func supports_chords() -> bool:
	return delivery.supports_chords()

## "Press a button to join": every player loses its devices, and the next devices pressed become players 1, 2... up
## to max_players(). Players who don't join again keep their schemes for next time.
func start_join() -> void:
	_joined = 0
	_players.resize(1)
	var first := player(1)
	first.keyboard = false
	first.mouse = false
	first.pad = RemapPlayer.NO_PAD
	join.listening = true
	_apply_and_save()

func stop_join() -> void:
	join.listening = false

## Gives player `index` its devices by hand (making the players up to it): the keyboard (the mouse goes to the first
## player with the keyboard) and a gamepad's device id, RemapPlayer.ANY_PAD or NO_PAD.
func assign(index: int, keyboard: bool, pad: int) -> void:
	while _players.size() < index:
		_add_player()
	var p := player(index)
	p.keyboard = keyboard
	p.pad = pad
	if pad >= 0:
		_take_pad(p, pad)
	_give_mouse()
	_apply_and_save()

func _on_device_pressed(keyboard: bool, pad: int) -> void:
	for p in _players.slice(0, _joined):
		if (keyboard and p.keyboard) or (not keyboard and p.pad == pad):
			return
	_joined += 1
	if _joined > _players.size():
		_add_player()
	var p := player(_joined)
	p.keyboard = keyboard
	p.pad = RemapPlayer.NO_PAD if keyboard else pad
	if not keyboard:
		_take_pad(p, pad)
	_give_mouse()
	if _joined >= adapter.max_players():
		join.listening = false
	_apply_and_save()
	player_joined.emit(_joined)

func _add_player() -> void:
	var index := _players.size() + 1
	var own := adapter.player_schemes(index)
	var lib := SchemeLibrary.new(own if not own.is_empty() else _builtins)
	if index - 2 < _saved_players.size() and _saved_players[index - 2] is Dictionary:
		lib.load_data(_saved_players[index - 2])
	var p := RemapPlayer.new(index, lib)
	p.keyboard = false
	p.mouse = false
	p.pad = RemapPlayer.NO_PAD
	_players.append(p)

## The gamepad `device` gets the scheme its model has for this player (or the recognized default).
func _take_pad(p: RemapPlayer, device: int) -> void:
	var info: Dictionary = _pad_info.call(device)
	p.pad_guid = str(info.get("guid", ""))
	p.pad_name = str(info.get("name", ""))
	p.library.scheme_for_pad(p.pad_guid, adapter.recognize_pad(p.pad_name), p.pad_name)

func _give_mouse() -> void:
	var given := false
	for p in _players:
		p.mouse = p.keyboard and not given
		given = given or p.mouse

## The player a gamepad answers: the one that owns it, else the one taking every gamepad.
func _pad_owner(device: int) -> RemapPlayer:
	for p in _players:
		if p.pad == device:
			return p
	for p in _players:
		if p.pad == RemapPlayer.ANY_PAD:
			return p
	return null

func _library_for_device(device: int) -> SchemeLibrary:
	var p := _pad_owner(device)
	return p.library if p != null else null

# --- Schemes ---------------------------------------------------------------------------------------------------

## The scheme in use for the family.
func active(family: StringName, index: int = 1) -> ControlScheme:
	return player(index).active(family)

## A draft of the player's scheme; on the keyboard it knows the other keyboard players, so their keys get swapped.
func draft(family: StringName, index: int = 1) -> RemapDraft:
	var p := player(index)
	var scheme := p.active(family)
	var neighbors := {}
	if family == InputKey.KEYBOARD:
		for other in _players:
			if other != p and other.keyboard:
				neighbors[other.index] = other.active(family)
	return RemapDraft.new(catalog, scheme, p.library.is_builtin(scheme.id),
		p.library.required_actions(scheme, catalog.all_actions()), neighbors)

## Saves the draft (false if commands are pending): a touched default becomes the owner's custom scheme, for this
## player and for any other keyboard player whose keys were swapped.
func save(remap_draft: RemapDraft, family: StringName, index: int = 1) -> bool:
	if not remap_draft.can_save():
		return false
	_store(player(index), family, remap_draft.scheme())
	var others := remap_draft.neighbor_schemes()
	for other: int in others:
		_store(player(other), InputKey.KEYBOARD, others[other])
	_apply_and_save()
	return true

## A changed copy of a default becomes the owner's custom scheme; a custom one is stored as it is.
func _store(p: RemapPlayer, family: StringName, edited: ControlScheme) -> void:
	if not p.library.is_builtin(edited.id):
		p.library.store(edited)
		return
	var custom := p.library.ensure_custom(_owner(p, family), _owner_title(p, family), family)
	var stored := edited.copy(custom.id, custom.title)
	stored.base_id = edited.id
	p.library.store(stored)

## The scheme picked from the menu for the family (the player's gamepad, for gamepads).
func select(family: StringName, id: StringName, index: int = 1) -> void:
	var p := player(index)
	if family == InputKey.KEYBOARD:
		p.library.select_keyboard(id)
	else:
		p.library.assign_pad(p.pad_guid, id, p.pad_name)
	_apply_and_save()

## The family's custom scheme, made from the scheme in use if missing (the menu's "Custom" entry).
func custom(family: StringName, index: int = 1) -> ControlScheme:
	var p := player(index)
	var scheme := p.library.ensure_custom(_owner(p, family), _owner_title(p, family), family)
	_apply_and_save()
	return scheme

## The layout chosen for gamepad model `guid` (what is printed on its buttons); empty for automatic.
func pad_layout(guid: String, index: int = 1) -> StringName:
	return player(index).library.pad_layout(guid)

## The layout of the player's gamepad, from the panel's menu (empty: automatic). Keys get redrawn through `changed`.
func set_pad_layout(layout: StringName, index: int = 1) -> void:
	var p := player(index)
	if p.pad_guid.is_empty():
		return
	p.library.set_pad_layout(p.pad_guid, layout)
	_save()
	changed.emit()

## Player 1's answer for a gamepad that wasn't recognized.
func choose_for_pad(guid: String, id: StringName, pad_name: String) -> void:
	var p := player(1)
	p.pad_guid = guid
	p.pad_name = pad_name
	p.library.assign_pad(guid, id, pad_name)
	_apply_and_save()

## A gamepad of player 1 connected and got its scheme (what PadWatcher reports; tests call it directly).
func on_pad_scheme(guid: String, scheme: ControlScheme) -> void:
	_on_pad_scheme(RemapPlayer.ANY_PAD, guid, scheme)

func _on_pad_scheme(device: int, guid: String, _scheme: ControlScheme) -> void:
	var p := _pad_owner(device)
	if p == null:
		return
	p.pad_guid = guid
	p.pad_name = p.library.pad_name(guid)
	_apply_and_save()

func _on_unknown_pad(device: int, guid: String, pad_name: String) -> void:
	var p := _pad_owner(device)
	if p == null:
		return
	p.pad_guid = guid
	p.pad_name = pad_name
	if p.index == 1:
		unknown_pad.emit(guid, pad_name)

func _owner(p: RemapPlayer, family: StringName) -> String:
	return SchemeLibrary.KEYBOARD_OWNER if family == InputKey.KEYBOARD or p.pad_guid.is_empty() else p.pad_guid

## A custom scheme's title is its gamepad's name (empty for the keyboard): the panel writes it in its own language.
func _owner_title(p: RemapPlayer, family: StringName) -> String:
	return "" if family == InputKey.KEYBOARD else p.pad_name

## A scheme's menu name: the default's title, or "Custom" with the gamepad's name.
func scheme_label(scheme: ControlScheme) -> String:
	if library.is_builtin(scheme.id):
		return adapter.text(scheme.title)
	return adapter.text("custom") if scheme.title.is_empty() else adapter.text("custom_of") % scheme.title

func _apply_and_save() -> void:
	delivery.apply(_players, catalog.all_actions())
	_save()
	changed.emit()

## Player 1's state as it always was; the other players' under "players", only once there have been some.
func _save() -> void:
	var data := library.to_data()
	for p in _players.slice(1):
		while _saved_players.size() < p.index - 1:
			_saved_players.append({})
		_saved_players[p.index - 2] = p.library.to_data()
	if not _saved_players.is_empty():
		data["players"] = _saved_players.duplicate(true)
	adapter.save_state(data)
