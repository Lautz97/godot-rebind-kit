## Rebind Kit example: three actions, the ready-made FileRemapAdapter with combinations and two local players, and the
## rebinding panel. Run this scene, press JOIN and then a key or a gamepad button per player, open the panel, bind a
## combination (hold Shift, press 1, release), then press it: the label shows which player's action fired. Choices are
## saved to user://rebind_kit_example.json and come back the next time you run it.
extends Control

const ACTIONS := {
	&"example_jump": [KEY_SPACE, JOY_BUTTON_A],
	&"example_fire": [KEY_J, JOY_BUTTON_X],
	&"example_crouch": [KEY_C, JOY_BUTTON_B],
}
const CATALOG := {"groups": [
	{"id": "play", "title": "Gameplay", "actions": [
		{"id": "example_jump", "title": "Jump"}, {"id": "example_fire", "title": "Fire"}]},
	{"id": "move", "title": "Movement", "scope": "play", "actions": [{"id": "example_crouch", "title": "Crouch"}]},
]}

## Where the player's choices are saved.
@export var save_path := "user://rebind_kit_example.json"

var remap: InputRemap
var _panel: RemapPanel
var _window: PanelContainer
var _pressed: Label
var _players: Label

func _ready() -> void:
	_add_default_actions()
	# InputRemap reads the defaults from the InputMap when it is created: the actions must exist first.
	var adapter := FileRemapAdapter.new(CATALOG, save_path)
	adapter.chords = true
	adapter.players = 2
	remap = InputRemap.new(adapter)
	add_child(remap)
	remap.player_joined.connect(func(_index: int) -> void: _show_players())
	_build()
	_show_players()

func _unhandled_input(event: InputEvent) -> void:
	for index in range(1, remap.player_count() + 1):
		for action: StringName in ACTIONS:
			if event.is_action_pressed(remap.player(index).action(action)):
				_pressed.text = "Player %d: %s" % [index, action]

## The project would define these in Project Settings > Input Map; the example creates them so it runs anywhere.
func _add_default_actions() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = ACTIONS[action][0]
		InputMap.action_add_event(action, key)
		var button := InputEventJoypadButton.new()
		button.button_index = ACTIONS[action][1]
		InputMap.action_add_event(action, button)

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.position = Vector2(24, 24)
	add_child(box)
	var open := Button.new()
	open.text = "CONTROLS"
	open.pressed.connect(_open_panel)
	box.add_child(open)
	var join := Button.new()
	join.text = "JOIN"
	join.pressed.connect(_start_join)
	box.add_child(join)
	_players = Label.new()
	box.add_child(_players)
	_pressed = Label.new()
	_pressed.text = "Press Jump, Fire or Crouch"
	box.add_child(_pressed)
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(760, 0)
	# On the right, so the labels on the left stay readable while the panel is open.
	_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_window.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_window.visible = false
	add_child(_window)

## The button press that started joining is over before the next press: that one picks player 1's device.
func _start_join() -> void:
	remap.start_join()
	_players.text = "Press a key or a gamepad button to join (up to 2 players)"

func _show_players() -> void:
	var parts: Array[String] = []
	for index in range(1, remap.player_count() + 1):
		var p := remap.player(index)
		var devices: Array[String] = []
		if p.keyboard:
			devices.append("keyboard")
		if p.pad == RemapPlayer.ANY_PAD:
			devices.append("any gamepad")
		elif p.pad >= 0:
			devices.append("gamepad %d" % p.pad)
		parts.append("Player %d: %s" % [index, ", ".join(devices) if not devices.is_empty() else "waiting"])
	_players.text = "   ".join(parts)

func _open_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	var shown: Array[int] = []
	for index in range(1, remap.player_count() + 1):
		shown.append(index)
	_panel = RemapPanel.new(remap, {}, &"", RemapPanel.TABLE_HEIGHT, shown)
	_panel.closed.connect(func() -> void: _window.visible = false)
	_window.add_child(_panel)
	_window.visible = true
	_panel.focus_first()
