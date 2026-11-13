## KeyLabel: the on-screen name of a keyboard key, from its position. It asks the system for the letter printed at
## that spot on the real keyboard (on AZERTY, where QWERTY has Q there's an A); without a layout (headless, or a system
## that doesn't say) QWERTY applies. A character is written as is, other keys with Godot's name in uppercase. Mouse and
## gamepad names come from the adapter.
class_name KeyLabel
extends RefCounted

static func keyboard(physical_code: int) -> String:
	var shown := KEY_NONE as int
	# The headless display server doesn't know the keyboard (and says so with an error).
	if DisplayServer.get_name() != "headless":
		shown = DisplayServer.keyboard_get_label_from_physical(physical_code as Key)
	if shown == KEY_NONE:
		shown = physical_code
	# Below KEY_SPECIAL the code is the character itself.
	if shown < KEY_SPECIAL and shown > 32:
		return String.chr(shown).to_upper()
	return OS.get_keycode_string(shown as Key).to_upper()
