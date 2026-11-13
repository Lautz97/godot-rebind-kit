## RemapPanel: the content of the controls window, made only of Godot Controls: whoever puts it in a window gives it
## theme and frame. Two tabs (keyboard and mouse, gamepad), the scheme menu, the COMMAND / PRIMARY / ALTERNATIVE table
## by group, listening for the new input and the form of swapped commands to confirm. It works on a draft (RemapDraft):
## it only saves with SAVE AND CLOSE, and not while a command is pending. Made for one family (`fixed_family`), it is a
## page of someone else's window: no tabs and no SAVE AND CLOSE, the host asks try_leave() before moving away. With
## several players the game picks whose schemes it shows: one player (listening only to that player's devices) or a
## tab per player (listening to the devices of the tab's player). With ChordDelivery a key can be a combination: held
## in order, closed when a key is released.
class_name RemapPanel
extends VBoxContainer

## The panel can close: saved or discarded.
signal closed()

const KEY_WIDTH := 150.0
## Combinations need room for up to four keys.
const CHORD_KEY_WIDTH := 230.0
const CLEAR_WIDTH := 40.0
## Every row is this tall, with or without a key drawing: rows don't jump between keyboard and gamepad.
const ROW_HEIGHT := 50.0
## Size of the key drawings in the buttons (the SVG is 24 high).
const KEY_SCALE := 1.15
const TABLE_HEIGHT := 440.0
const FAMILIES: Array[StringName] = [InputKey.KEYBOARD, InputKey.PAD]

## Colors given by the user: text, dim text, off text, group accent, warning (pending), alternate row background, lines.
var colors := {"text": Color.WHITE, "dim": Color(1, 1, 1, 0.6), "off": Color(1, 1, 1, 0.35), "accent": Color.CYAN,
	"warn": Color.YELLOW, "stripe": Color(1, 1, 1, 0.04), "line": Color(1, 1, 1, 0.15)}

var remap: InputRemap
## Asks for confirmation before a destructive action (back to defaults): (question, on_yes) -> void. Whoever hosts the
## panel shows it with its own dialogs; by default it just goes ahead.
var confirmer: Callable = func(_question: String, on_yes: Callable) -> void: on_yes.call()
## Is a gamepad connected? Listening can't be cancelled: without a gamepad the gamepad tab must not listen.
var pad_connected: Callable = func() -> bool: return not Input.get_connected_joypads().is_empty()
var capture: KeyCapture
var family: StringName = InputKey.KEYBOARD
## The player whose schemes are shown.
var player_index := 1
## The players the panel can show, one tab each when more than one.
var players: Array[int] = [1]
## The only family shown, when the panel is a page of a bigger window (empty: both, with tabs).
var fixed_family: StringName = &""
var draft: RemapDraft
## command -> [primary button, alternative button, clear button]
var rows: Dictionary = {}
## The slot listening: {"action", "slot"}, empty if none.
var listening: Dictionary = {}
## The gamepad layout menu (what is printed on the buttons): only in the gamepad tab, if the adapter has layouts.
var layouts: OptionButton

var _tabs: TabBar
var _player_tabs: TabBar
var _table_height: float = TABLE_HEIGHT
var _schemes: OptionButton
var _scheme_ids: Array[StringName] = []
var _device_label: Label
var _layout_label: Label
## The layout menu's ids, in order: the first is automatic (empty).
var _layout_ids: Array[StringName] = []
var _table: VBoxContainer
var _table_box: Control
var _form: VBoxContainer
var _form_rows: VBoxContainer
var _warning: Label
var _hint: Label
## What the confirmation form hides: while it's open, choices happen only there.
var _outside_form: Array[Control] = []

## `only_family`: one family, no tabs and no SAVE AND CLOSE (a page of the host's window). `table_height`: how tall the
## command table is. `shown_players`: the players whose schemes it shows (empty: player 1).
func _init(input_remap: InputRemap, panel_colors: Dictionary = {}, only_family: StringName = &"",
		table_height: float = TABLE_HEIGHT, shown_players: Array[int] = []) -> void:
	remap = input_remap
	if not shown_players.is_empty():
		players = shown_players.duplicate()
	player_index = players[0]
	fixed_family = only_family
	_table_height = table_height
	colors.merge(panel_colors, true)
	add_theme_constant_override("separation", 8)
	capture = KeyCapture.new()
	capture.name = "KeyCapture"
	add_child(capture)
	capture.captured.connect(_on_captured)
	_build()
	show_family(InputKey.KEYBOARD if fixed_family == &"" else fixed_family)

func _text(id: String) -> String:
	return remap.adapter.text(id)

# --- Commands (also for tests and gamepad navigation) -------------------------------------------------------------

func show_family(new_family: StringName) -> void:
	family = new_family
	_tabs.current_tab = FAMILIES.find(family)
	capture.stop()
	listening = {}
	draft = remap.draft(family, player_index)
	_fill_schemes()
	_fill_table()

## The other tab: this tab's changes are saved first; with a pending command the form opens and the tab stays.
func switch_family(new_family: StringName) -> void:
	if new_family == family:
		return
	if not draft.can_save():
		_tabs.set_current_tab.call_deferred(FAMILIES.find(family))
		_show_form(true)
		return
	if draft.is_dirty():
		remap.save(draft, family, player_index)
	show_family(new_family)

## Another player's tab: this player's changes are saved first, as when changing family.
func switch_player(index: int) -> void:
	if index == player_index:
		return
	if not draft.can_save():
		_player_tabs.set_current_tab.call_deferred(players.find(player_index))
		_show_form(true)
		return
	if draft.is_dirty():
		remap.save(draft, family, player_index)
	player_index = index
	_player_tabs.current_tab = players.find(index)
	show_family(family)

## Whether the open tab can listen: the keyboard is always there, the gamepad only when connected.
func can_listen() -> bool:
	var p := remap.player(player_index)
	if family == InputKey.KEYBOARD:
		return p.keyboard
	return p.has_family(InputKey.PAD) and pad_connected.call()

## Click (or A) on `action`'s `slot` key: listens for the next input until it comes (it can't be cancelled).
func press_key(action: StringName, slot: int) -> void:
	if not can_listen():
		return
	listening = {"action": action, "slot": slot}
	capture.listen(family, remap.player(player_index), remap.supports_chords())
	_fill_table()
	_focus_row(action, slot)

## Focus on the table's first key (for gamepad and keyboard).
func focus_first() -> void:
	var actions := remap.catalog.all_actions()
	if not actions.is_empty():
		_focus_row(actions[0])

## The × of a row: the alternative, or the primary of a command that may be left without input.
func clear_input(action: StringName) -> void:
	if draft.clear(action):
		_fill_table()

## SAVE AND CLOSE (or back): saves if possible, otherwise opens the form of pending commands.
func save_and_close() -> void:
	if try_leave():
		closed.emit()

## Whether the host may move away (another page, closing its window): never while listening; with a pending command
## the form opens and the answer is no; otherwise the changes are saved.
func try_leave() -> bool:
	if capture.is_listening():
		return false
	if not draft.can_save():
		_show_form(true)
		return false
	if draft.is_dirty():
		remap.save(draft, family, player_index)
	return true

## DISCARD CHANGES: as a page the table goes back to what is saved and stays; otherwise the panel closes.
func discard_and_close() -> void:
	draft.discard()
	if fixed_family == &"":
		closed.emit()
		return
	_show_form(false)
	show_family(family)

## "Keep": the swapped command keeps the input it has now.
func keep(action: StringName) -> void:
	draft.confirm(action)
	_refresh_form()

func reassign(action: StringName) -> void:
	_show_form(false)
	press_key(action, ControlScheme.PRIMARY)

func form_visible() -> bool:
	return _form.visible

## The scheme picked from the menu; the entry of a custom scheme that doesn't exist yet creates it from the one in use.
func select_scheme(index: int) -> void:
	if index >= _scheme_ids.size():
		remap.custom(family, player_index)
	else:
		remap.select(family, _scheme_ids[index], player_index)
	show_family(family)

## The layout picked from the menu, for the connected gamepad: the keys are redrawn with its names.
func select_layout(index: int) -> void:
	remap.set_pad_layout(_layout_ids[index], player_index)
	show_family(family)

## DEFAULTS: the tab's first default scheme, with confirmation (the custom one stays in the menu).
func reset_to_defaults() -> void:
	confirmer.call(_text("defaults_confirm"), func() -> void:
		var lib := remap.player(player_index).library
		var builtin: ControlScheme = lib.schemes(family).filter(
			func(s: ControlScheme) -> bool: return lib.is_builtin(s.id))[0]
		remap.select(family, builtin.id, player_index)
		show_family(family))

# --- Building ------------------------------------------------------------------------------------------------

func _build() -> void:
	_player_tabs = TabBar.new()
	# One player: no player tabs (and no player texts asked of the adapter).
	if players.size() > 1:
		for index in players:
			_player_tabs.add_tab(_text("player") % index)
		_player_tabs.tab_changed.connect(func(tab: int) -> void: switch_player(players[tab]))
		add_child(_player_tabs)
		_outside_form.append(_player_tabs)
	_tabs = TabBar.new()
	_tabs.add_tab(_text("tab_keyboard"))
	_tabs.add_tab(_text("tab_pad"))
	_tabs.tab_changed.connect(func(tab: int) -> void: switch_family(FAMILIES[tab]))
	add_child(_tabs)
	_tabs.visible = fixed_family == &""
	if _tabs.visible:
		_outside_form.append(_tabs)

	var scheme_row := HBoxContainer.new()
	scheme_row.add_theme_constant_override("separation", 12)
	add_child(scheme_row)
	scheme_row.add_child(_label(_text("scheme"), "dim", true))
	_schemes = OptionButton.new()
	_schemes.custom_minimum_size.x = 240
	_schemes.item_selected.connect(select_scheme)
	scheme_row.add_child(_schemes)
	_layout_label = _label(_text("pad_layout"), "dim", true)
	scheme_row.add_child(_layout_label)
	layouts = OptionButton.new()
	layouts.custom_minimum_size.x = 170
	layouts.item_selected.connect(select_layout)
	scheme_row.add_child(layouts)
	_device_label = _label("", "off", true)
	# A long gamepad name gets cut, it doesn't widen the panel.
	_device_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_device_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_device_label.custom_minimum_size.x = 40
	scheme_row.add_child(_device_label)
	_outside_form.append(scheme_row)

	_table_box = VBoxContainer.new()
	add_child(_table_box)
	_table_box.add_child(_header())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = _table_height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The focused row (the listening one too) stays in view.
	scroll.follow_focus = true
	_table_box.add_child(scroll)
	_table = VBoxContainer.new()
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.add_theme_constant_override("separation", 0)
	scroll.add_child(_table)

	_form = VBoxContainer.new()
	_form.visible = false
	_form.custom_minimum_size.y = _table_height
	_form.add_theme_constant_override("separation", 10)
	add_child(_form)
	_form.add_child(_label(_text("form_title"), "warn", false))
	var body := _label(_text("form_body"), "dim", false)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(body)
	_form_rows = VBoxContainer.new()
	_form.add_child(_form_rows)
	var form_actions := HBoxContainer.new()
	form_actions.alignment = BoxContainer.ALIGNMENT_END
	form_actions.add_theme_constant_override("separation", 8)
	_form.add_child(form_actions)
	form_actions.add_child(_button(_text("discard"), discard_and_close))
	form_actions.add_child(_button(_text("back"), _show_form.bind(false)))

	_hint = _label("", "dim", true)
	add_child(_hint)
	_outside_form.append(_hint)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	add_child(foot)
	_warning = _label("", "warn", true)
	_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_warning)
	foot.add_child(_button(_text("defaults"), reset_to_defaults))
	# As a page, the host's window has its own close button.
	if fixed_family == &"":
		var save := _button(_text("save"), save_and_close)
		save.theme_type_variation = &"ActionButton"
		foot.add_child(save)
	_outside_form.append(foot)

func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var command := _label("   " + _text("command"), "dim", true)
	command.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(command)
	for id in ["primary", "alternative"]:
		var l := _label(_text(id), "dim", true)
		l.custom_minimum_size.x = KEY_WIDTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = CLEAR_WIDTH
	row.add_child(spacer)
	var line := ColorRect.new()
	line.color = colors["line"]
	line.custom_minimum_size.y = 2
	var box := VBoxContainer.new()
	box.add_child(row)
	box.add_child(line)
	return box

func _fill_schemes() -> void:
	_schemes.clear()
	_scheme_ids.clear()
	var p := remap.player(player_index)
	var active := p.active(family)
	for scheme in p.library.schemes(family):
		_schemes.add_item(remap.scheme_label(scheme))
		_scheme_ids.append(scheme.id)
	# The entry that creates the custom scheme, if this tab doesn't have one yet (keyboard, or connected gamepad).
	var custom_id := StringName(SchemeLibrary.CUSTOM_PREFIX + (SchemeLibrary.KEYBOARD_OWNER if family == InputKey.KEYBOARD
		else p.pad_guid).validate_node_name())
	if p.library.scheme(custom_id) == null:
		_schemes.add_item(_text("custom"))
	_schemes.select(_scheme_ids.find(active.id))
	if family == InputKey.KEYBOARD:
		_device_label.text = ""
	else:
		var pad_name := p.library.pad_name(p.pad_guid)
		_device_label.text = _text("pad_connected") % pad_name if not pad_name.is_empty() else _text("no_pad")
	var hint := "hint_keyboard" if family == InputKey.KEYBOARD else "hint_pad"
	_hint.text = _text(hint.replace("hint_", "hint_chord_") if remap.supports_chords() else hint)
	_fill_layouts()

func _fill_layouts() -> void:
	var titles := remap.adapter.pad_layouts()
	layouts.visible = family == InputKey.PAD and not titles.is_empty()
	_layout_label.visible = layouts.visible
	layouts.clear()
	_layout_ids.assign([&""])
	layouts.add_item(_text("layout_auto"))
	for id: StringName in titles:
		_layout_ids.append(id)
		layouts.add_item(str(titles[id]))
	var p := remap.player(player_index)
	layouts.select(maxi(0, _layout_ids.find(p.library.pad_layout(p.pad_guid))))
	# The choice belongs to the connected gamepad model: with none there's nothing to choose for.
	layouts.disabled = p.pad_guid.is_empty()

func _fill_table() -> void:
	for child in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	rows.clear()
	var stripe := false
	for group in remap.catalog.group_ids():
		var head := _row_panel(Color(colors["line"], 0.35), false)
		head.add_child(_label(_text(remap.catalog.group_title(group)), "accent", true))
		for action in remap.catalog.actions_of(group):
			_add_row(action, stripe)
			stripe = not stripe
	var pending := draft.pending().size()
	_warning.text = _text("pending") % pending if pending > 0 else _neighbor_note()

func _add_row(action: StringName, stripe: bool) -> void:
	var pending := draft.pending().has(action)
	var back: Color = Color(colors["warn"], 0.12) if pending else (colors["stripe"] if stripe else Color.TRANSPARENT)
	var panel := _row_panel(back, pending)
	panel.custom_minimum_size.y = ROW_HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	names.add_child(_label(_text(remap.catalog.title_of(action)), "warn" if pending else "text", true))
	if pending:
		names.add_child(_label(_text("swapped"), "warn", true))
	var buttons: Array[Button] = []
	for slot in ControlScheme.SLOTS:
		var b := _key_button(draft.scheme().key_at(action, slot), listening == {"action": action, "slot": slot}, pending and slot == 0)
		b.pressed.connect(press_key.bind(action, slot))
		b.disabled = not can_listen()
		row.add_child(b)
		buttons.append(b)
	var clearable := draft.can_clear(action)
	var clear := _button("×" if clearable else "", clear_input.bind(action))
	clear.custom_minimum_size = Vector2(CLEAR_WIDTH, ROW_HEIGHT - 6)
	clear.disabled = not clearable
	clear.flat = not clearable
	clear.focus_mode = Control.FOCUS_ALL if clearable else Control.FOCUS_NONE
	row.add_child(clear)
	buttons.append(clear)
	rows[action] = buttons

## The other players' commands this draft moved, as a line under the table.
func _neighbor_note() -> String:
	var notes: Array[String] = []
	for swap: Dictionary in draft.neighbor_swaps():
		notes.append(_text("moved_to_player") % [swap["player"], _text(remap.catalog.title_of(swap["action"]))])
	return "  ".join(notes)

func _key_button(key: InputKey, is_listening: bool, pending: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CHORD_KEY_WIDTH if remap.supports_chords() else KEY_WIDTH, ROW_HEIGHT - 6)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 0)
	if is_listening:
		b.text = _text("listening_chord" if remap.supports_chords() else "listening")
		b.theme_type_variation = &"ActionButton"
	elif key == null:
		b.text = _text("empty")
		b.add_theme_color_override("font_color", colors["off"])
	elif key.is_chord():
		_chord_into(b, key, colors["warn"] if pending else colors["text"])
	else:
		var tex := remap.adapter.key_texture(key)
		if tex != null:
			b.icon = tex
			b.add_theme_color_override("icon_normal_color", colors["warn"] if pending else colors["text"])
			b.add_theme_color_override("icon_focus_color", colors["warn"] if pending else colors["text"])
			b.add_theme_color_override("icon_hover_color", colors["accent"])
		else:
			b.text = remap.adapter.key_name(key)
	return b

## A combination is drawn key by key, joined by "+", inside the button (an icon holds one texture only).
func _chord_into(button: Button, key: InputKey, tint: Color) -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var parts := key.sequence()
	for i in parts.size():
		if i > 0:
			var plus := _label("+", "dim", true)
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(plus)
		var tex := remap.adapter.key_texture(parts[i])
		if tex != null:
			var image := TextureRect.new()
			image.texture = tex
			image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			image.modulate = tint
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(image)
		else:
			var written := Label.new()
			written.text = remap.adapter.key_name(parts[i])
			written.add_theme_color_override("font_color", tint)
			written.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(written)

func _row_panel(back: Color, marked: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = back
	style.content_margin_left = 12
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.border_width_bottom = 1
	style.border_color = colors["line"]
	if marked:
		style.border_width_left = 3
		style.border_color = colors["warn"]
	panel.add_theme_stylebox_override("panel", style)
	_table.add_child(panel)
	return panel

func _label(text: String, color: String, caption: bool) -> Label:
	var l := Label.new()
	l.text = text
	if caption:
		l.theme_type_variation = &"CaptionLabel"
	l.add_theme_color_override("font_color", colors[color])
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b

# --- Listening and form ----------------------------------------------------------------------------------------

func _on_captured(key: InputKey) -> void:
	var target := listening
	listening = {}
	if not target.is_empty():
		draft.rebind(target["action"], target["slot"], key)
	_fill_table()
	_focus_row(target.get("action", &""), target.get("slot", 0))

## Focus is given later: the table was just rebuilt. By then the button may already have been replaced.
func _focus_row(action: StringName, slot: int = ControlScheme.PRIMARY) -> void:
	_grab_row_focus.call_deferred(action, slot)

func _grab_row_focus(action: StringName, slot: int) -> void:
	if not rows.has(action):
		return
	var button := rows[action][slot] as Button
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()

static func _grab_if_alive(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()

func _show_form(open: bool) -> void:
	_form.visible = open
	_table_box.visible = not open
	for control in _outside_form:
		control.visible = not open
	if open:
		_refresh_form()

func _refresh_form() -> void:
	for child in _form_rows.get_children():
		_form_rows.remove_child(child)
		child.queue_free()
	if draft.can_save():
		_show_form(false)
		_fill_table()
		return
	for action in draft.pending():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_form_rows.add_child(row)
		var name_label := _label(_text(remap.catalog.title_of(action)), "warn", false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_key_button(draft.scheme().key_at(action, ControlScheme.PRIMARY), false, true))
		var keep_button := _button(_text("keep"), keep.bind(action))
		keep_button.theme_type_variation = &"ActionButton"
		keep_button.disabled = draft.is_required(action) and draft.scheme().key_at(action, ControlScheme.PRIMARY) == null
		row.add_child(keep_button)
		row.add_child(_button(_text("reassign"), reassign.bind(action)))
	if is_inside_tree() and _form_rows.get_child_count() > 0:
		# Focus on the first KEEP (or REASSIGN): with a gamepad you choose right away.
		_grab_if_alive.call_deferred(_form_rows.get_child(0).get_child(2) as Button)
