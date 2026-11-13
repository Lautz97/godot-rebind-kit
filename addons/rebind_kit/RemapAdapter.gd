## RemapAdapter: what the plugin asks of the game using it. The game extends it and passes it to InputRemap: the
## command list, the default schemes, gamepad recognition, where to save. The plugin knows nothing about the game:
## everything goes through here. The base methods are those of a game with no data; FileRemapAdapter is ready to use.
class_name RemapAdapter
extends RefCounted

## {"groups": [{"id", "title", "scope", "actions": [{"id", "title"}]}]}, as RemapCatalog reads it.
func catalog_data() -> Dictionary:
	return {}

## The default schemes, in menu order; `actions` are the catalog's commands.
func builtin_schemes(actions: Array) -> Array[ControlScheme]:
	var out: Array[ControlScheme] = [ControlScheme.from_input_map(&"default_keyboard", "Default", InputKey.KEYBOARD, actions),
		ControlScheme.from_input_map(&"default_pad", "Default", InputKey.PAD, actions)]
	return out

## The defaults of player `index` (2 and later), if they differ from player 1's (the second player on the keyboard
## starting from the arrows); empty: the same as player 1.
func player_schemes(_index: int) -> Array[ControlScheme]:
	return []

## How the schemes reach the game: InputMapDelivery (single keys, Godot does the rest) or ChordDelivery (combinations).
func delivery() -> InputDelivery:
	return InputMapDelivery.new()

## How many local players can join (start_join); 1 for a single-player game.
func max_players() -> int:
	return 1

## A gamepad's default scheme from its name; empty if not recognized (the player gets asked).
func recognize_pad(_pad_name: String) -> StringName:
	return &""

## The gamepad layouts the player can pick (what is printed on the buttons), id -> title, in menu order. Empty: the
## panel shows no layout menu. The game reads the choice with InputRemap.pad_layout(guid) to name the buttons.
func pad_layouts() -> Dictionary:
	return {}

func load_state() -> Dictionary:
	return {}

func save_state(_data: Dictionary) -> void:
	pass

# --- For the panel (RemapPanel) ---------------------------------------------------------------------------------

## The panel's texts: `id` is a TEXTS entry or a catalog title. A game can translate them here.
const TEXTS := {
	"tab_keyboard": "KEYBOARD AND MOUSE", "tab_pad": "GAMEPAD", "scheme": "SCHEME", "command": "COMMAND",
	"primary": "PRIMARY", "alternative": "ALTERNATIVE", "listening": "PRESS A KEY...", "empty": "—",
	"custom": "Custom", "custom_of": "Custom (%s)", "swapped": "swapped: confirm it", "pending": "%d to confirm before saving",
	"defaults": "DEFAULTS", "defaults_confirm": "Back to the default keys for this tab?", "save": "SAVE AND CLOSE",
	"form_title": "Swapped commands to confirm", "form_body": "A new key moved another one. Keep the key it has now or pick one yourself.",
	"keep": "KEEP", "reassign": "REASSIGN", "back": "BACK TO THE TABLE", "discard": "DISCARD CHANGES",
	"hint_keyboard": "Click or ENTER on a key, then press the new one: any key you press is assigned",
	"hint_pad": "A on a button, then press the new one: any button you press is assigned",
	"pad_connected": "gamepad: %s", "no_pad": "no gamepad connected",
	"pad_layout": "LAYOUT", "layout_auto": "Automatic",
	"player": "PLAYER %d", "listening_chord": "HOLD THE KEYS...",
	"hint_chord_keyboard": "Click or ENTER on a key, then hold up to 4 keys in order and release: the combination is assigned",
	"hint_chord_pad": "A on a button, then hold up to 4 buttons in order and release: the combination is assigned",
	"moved_to_player": "Moved to player %d: %s",
}

func text(id: String) -> String:
	return str(TEXTS.get(id, id))

## The drawing of an input for the panel; null if the game has none (the name is written instead).
func key_texture(_key: InputKey) -> Texture2D:
	return null

## The name of an input, where there's no drawing.
func key_name(key: InputKey) -> String:
	return KeyLabel.keyboard(key.code) if key.source == InputKey.Source.KEY else "%s %d" % [InputKey.SOURCE_NAMES[key.source], key.code]
