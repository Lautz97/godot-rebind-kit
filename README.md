<img src="media/icon.png" width="96" align="right" alt="Rebind Kit icon">

# Rebind Kit

Player-facing key and gamepad remapping for Godot 4.6, built on the project's `InputMap`.

![The rebinding panel: combinations and two players](media/panel.png)

- **Schemes per device**: a keyboard scheme and a gamepad scheme, each with its defaults (taken from the `InputMap` or
  from your data) and a custom scheme created the first time the player changes something. Every gamepad model
  remembers its scheme; a new model can reuse the custom scheme made for another one.
- **Two inputs per command**: primary and alternative. The alternative can be cleared, the primary never.
- **Conflicts that make sense**: commands are grouped by *scope* (the commands active at the same time). Picking an input
  already used in the same scope swaps the two, and the other command is flagged until the player confirms or rebinds
  it. Different scopes can share an input, and so can commands that list each other in `shares` (a click and a held
  drag on the same mouse button). Commands with a primary in the default scheme keep one; the others may be left empty.
- **Keyboard by position**: bindings use `physical_keycode`, so on an AZERTY keyboard WASD stays where it is, and the
  keycap shows the letter actually printed there.
- **Any key gets a drawing**: keycaps and gamepad buttons are drawn at runtime from any font's outlines, so you don't
  need an image per letter. Your own special drawings (Tab, Enter, sticks...) win over the generated ones.
- **Combinations of up to 4 keys**, on the keyboard and on the gamepad (Ctrl+Shift+S, Q+E+R, LB+RB+X). Keys are held
  in order and the last one fires. A key that opens a combination is only a prefix: while it's held, commands that don't
  continue it stay silent (hold Shift and Space no longer jumps; Shift then 1 uses the item).
- **Local multiplayer**: up to N players on one computer, joining with the first key or button they press. Every
  player has its own devices, its own commands (`jump`, `jump_p2`...) and its own custom schemes; players sharing the
  keyboard never share a key.
- **A ready rebinding panel** (`RemapPanel`): player and device tabs, scheme menu, a command table, listening for the
  new input or combination, and the form for swapped commands. Plain Godot Controls: it follows your theme.

## Screenshots

| A prefix moves what it clashes with | Player 2's gamepad combinations |
|---|---|
| ![Shift became a command: Fire waits for confirmation](media/swap.png) | ![Player 2, gamepad tab](media/pad.png) |

This repository is also a Godot project: open it and run it to try the example scene.

## Install

From the editor: *AssetLib* tab, search **Rebind Kit**, download and install (only `addons/rebind_kit/` is installed).
By hand: copy `addons/rebind_kit/` into your project and enable **Rebind Kit** in *Project Settings > Plugins* (the plugin adds
nothing to the editor: you use its classes from code).

Try `addons/rebind_kit/example/remap_example.tscn`: three actions, the ready adapter with combinations and two
players, JOIN and the panel.

## Quick start

```gdscript
# 1. Describe the commands the player can change. Groups are shown as sections of the table; a group's scope says
#    which commands are active together (without a scope, the group is its own scope; "global" clashes with all).
const CATALOG := {"groups": [
	{"id": "gameplay", "title": "Gameplay", "actions": [
		{"id": "jump", "title": "Jump"}, {"id": "fire", "title": "Fire"}]},
	{"id": "menus", "title": "Menus", "actions": [{"id": "ui_back", "title": "Back"}]},
]}

# 2. Create the remapper once, early (an autoload is a good place). It reads the defaults from the InputMap, so the
#    actions must exist by then. It loads the saved choices and applies them to the InputMap.
var remap := InputRemap.new(FileRemapAdapter.new(CATALOG))   # saves to user://rebind_kit.json
add_child(remap)

# 3. Show the panel when the player opens the controls screen.
var panel := RemapPanel.new(remap)
panel.closed.connect(panel.queue_free)
some_window.add_child(panel)
```

From then on `InputMap` holds the player's bindings: the rest of your game keeps using `is_action_pressed` as usual.

## Combinations

```gdscript
var adapter := FileRemapAdapter.new(CATALOG)
adapter.chords = true          # ChordDelivery instead of the InputMap
var remap := InputRemap.new(adapter)
```

With combinations the plugin sits between the raw input and your game: `ChordDelivery` leaves the commands with no
events in the `InputMap`, reads every key and button, and sends `InputEventAction`s. `is_action_pressed`,
`get_action_strength` and `_unhandled_input` keep working; sticks and triggers count as pressed past
`ChordDelivery.AXIS_THRESHOLD`, and their strength follows the stick while held.

Rules, checked by the panel among the commands of a scope:

- the order counts: Q+E+R and E+Q+R are two different combinations;
- a key that opens a combination can't be a command by itself, and a combination can't stop where a longer one goes
  on (with Q+E+R there's no Q+E). Picking one moves the commands it clashes with, which wait for confirmation;
- while a prefix is held, only what continues it fires. Keys that open nothing don't get in the way: hold W and Space
  still jumps.

In code, `InputKey.chord([shift, one])` makes a combination; `key.prefixes` are the keys held first and
`key.sequence()` all of them in order. A single key saves exactly as before.

## Local multiplayer

```gdscript
var adapter := FileRemapAdapter.new(CATALOG)
adapter.players = 2
var remap := InputRemap.new(adapter)
add_child(remap)
remap.player_joined.connect(func(index: int) -> void: print("player %d is in" % index))
remap.start_join()              # the next device pressed is player 1, the one after player 2...
```

- `remap.player(n).action(&"jump")` is the command of player `n` (`jump`, `jump_p2`, `jump_p3`...): the plugin
  creates the copies in the `InputMap` with the same dead zone.
- `remap.assign(n, keyboard, pad)` sets a player's devices by hand: the keyboard (the mouse goes to the first player
  with it) and a gamepad device id, `RemapPlayer.ANY_PAD` or `RemapPlayer.NO_PAD`.
- Every player has its own custom schemes (the defaults are shared; `player_schemes(index)` in the adapter can give
  player 2 its own, say the arrows). They are saved under `"players"`; a single player saves as before.
- Players on the same keyboard can't share a key: picking a key of another player gives that player your old one, and
  the panel says so under the table.
- `RemapPanel.new(remap, colors, family, table_height, [1, 2])` shows a tab per player and listens to the devices of
  the open tab's player; `[2]` shows player 2 only and listens only to player 2's devices.
- With one player and `ANY_PAD` (the default) every gamepad answers player 1, as in a single-player game.

## Your own adapter

`InputRemap` asks everything about your game to a `RemapAdapter`. `FileRemapAdapter` covers the common case; extend
`RemapAdapter` (or `FileRemapAdapter`) to change any part:

| Method | What it gives |
|---|---|
| `catalog_data()` | the command catalog (format above) |
| `builtin_schemes(actions)` | the default schemes, in menu order (`ControlScheme.from_input_map`, `swap_keys`...) |
| `recognize_pad(name)` | the default scheme id for a gamepad name, or `&""` to ask the player |
| `load_state()` / `save_state(data)` | where the player's choices live (a file, your settings system...) |
| `text(id)` | every text of the panel (`RemapAdapter.TEXTS`) and the catalog titles: translate here |
| `key_texture(key)` / `key_name(key)` | how an input is drawn and named |
| `delivery()` | `InputMapDelivery` (single keys, the default) or `ChordDelivery` (combinations) |
| `max_players()` / `player_schemes(index)` | how many players can join, and a player's own defaults |

`pad_layouts()` (id -> title) adds a **layout** menu to the gamepad tab: what is printed on the buttons, chosen per
gamepad model and separate from the scheme. Read the choice with `InputRemap.pad_layout(guid)` (empty: automatic) to
name the buttons your way.

Signals on `InputRemap`: `changed` (bindings changed: refresh any on-screen key hints), `unknown_pad(guid, name)`
(a gamepad of player 1 nobody recognized: ask the player and answer with `choose_for_pad(guid, scheme_id, name)`;
other players start from the default) and `player_joined(index)`.

## Panel

`RemapPanel.new(remap, colors)` takes an optional color dictionary (`text`, `dim`, `off`, `accent`, `warn`, `stripe`,
`line`). Set `confirmer` to show the "back to defaults" confirmation with your own dialog, and call `save_and_close()`
when the player presses your back button. Listening for a new input can't be cancelled: whatever the player presses
next is bound, so the gamepad tab only listens while a gamepad is connected.

`RemapPanel.new(remap, colors, family, table_height)` makes a panel for one family only, to use as a page of your own
window: no tabs and no SAVE AND CLOSE. Before moving away (another page, closing) ask `try_leave()`: it saves, or opens
the form of swapped commands and answers no.

## Keycaps

`KeyCapRenderer.new(font, special_dir)` draws `texture(id, label, shape, scale)`: shape `key` (keyboard keycap) or
`button` (gamepad dodecagon), white, to be tinted by whoever shows it. A file `special_dir/<slug(id)>.svg` replaces the
generated drawing. At scale 1 the texture also gets a resource path (`path_of(id)`), so rich text can show it with
`[img]`. Letters are always uppercase.

## Limits

- `ChordDelivery` doesn't repeat held keys (`InputEventAction` has no echo): a menu that scrolls while an arrow is held
  needs its own repeat.
- Within one player, two gamepads of the same model are the same gamepad (Godot identifies the model by GUID); two
  players with the same model each keep their own scheme.
- One gamepad per player.
- `FileRemapAdapter` names gamepad buttons the Xbox way.
- The classes are global (`class_name`): `ChordDelivery`, `ChordResolver`, `ChordRules`, `ControlScheme`,
  `FileRemapAdapter`, `InputDelivery`, `InputKey`, `InputMapDelivery`, `InputRemap`, `KeyCapRenderer`, `KeyCapture`,
  `KeyLabel`, `PadWatcher`, `PlayerJoin`, `RemapAdapter`, `RemapCatalog`, `RemapDraft`, `RemapPanel`, `RemapPlayer`,
  `SchemeApplier`, `SchemeLibrary`. If your project already has one of these names, rename yours or the plugin's.

## License

MIT, see `LICENSE`. Made for [Protocol Breach](https://lautz97.itch.io/protocol-breach) by Lautz97.
