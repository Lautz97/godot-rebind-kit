## Rebind Kit example: three actions, the ready-made FileRemapAdapter and the rebinding panel. Run this scene, open the
## panel, change a key, then press it: the label shows which action fired. Choices are saved to
## user://rebind_kit_example.json and come back the next time you run it.
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

func _ready() -> void:
	_add_default_actions()
	# InputRemap reads the defaults from the InputMap when it is created: the actions must exist first.
	remap = InputRemap.new(FileRemapAdapter.new(CATALOG, save_path))
	add_child(remap)
	_build()

func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			_pressed.text = "Pressed: %s" % action

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
	_pressed = Label.new()
	_pressed.text = "Press Jump, Fire or Crouch"
	box.add_child(_pressed)
	_window = PanelContainer.new()
	_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_window.custom_minimum_size = Vector2(680, 0)
	_window.visible = false
	add_child(_window)

func _open_panel() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = RemapPanel.new(remap)
	_panel.closed.connect(func() -> void: _window.visible = false)
	_window.add_child(_panel)
	_window.visible = true
	_panel.focus_first()
