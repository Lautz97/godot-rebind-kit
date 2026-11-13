## RemapCatalog: which commands can be changed, in which group and with which title, in the order the panel shows
## them. It comes from the game's data (the adapter):
## {"groups": [{"id", "title", "scope", "actions": [{"id", "title", "shares"}]}]}.
## The scope says which commands are active together (two groups can share one; without it, it's the group): an input
## can't sit on two commands of the same scope, and GLOBAL_SCOPE is active alongside everything. Titles are whatever the
## game gives (the adapter can translate them). `shares` lists the commands of the same scope that may sit on the same
## input anyway (a click and a held drag on the same mouse button); it works both ways. Broken data: empty catalog.
class_name RemapCatalog
extends RefCounted

const GLOBAL_SCOPE := &"global"

var _groups: Array[StringName] = []
var _group_titles: Dictionary = {}
## group -> commands, in order.
var _actions: Dictionary = {}
var _group_of: Dictionary = {}
var _titles: Dictionary = {}
## group -> scope.
var _scopes: Dictionary = {}
## command -> commands it may share an input with.
var _shares: Dictionary = {}

func _init(data: Dictionary) -> void:
	var groups: Variant = data.get("groups", [])
	if not groups is Array:
		return
	for group: Variant in groups:
		if not group is Dictionary or not (group as Dictionary).has("id"):
			continue
		var group_id := StringName(str(group["id"]))
		_groups.append(group_id)
		_group_titles[group_id] = str(group.get("title", group_id))
		_scopes[group_id] = StringName(str(group.get("scope", group_id)))
		var list: Array[StringName] = []
		var actions: Variant = group.get("actions", [])
		for action: Variant in (actions if actions is Array else []):
			if not action is Dictionary or not (action as Dictionary).has("id"):
				continue
			var action_id := StringName(str(action["id"]))
			list.append(action_id)
			_group_of[action_id] = group_id
			_titles[action_id] = str(action.get("title", action_id))
			var shares: Variant = action.get("shares", [])
			for other: Variant in (shares if shares is Array else []):
				_share(action_id, StringName(str(other)))
				_share(StringName(str(other)), action_id)
		_actions[group_id] = list

func group_ids() -> Array[StringName]:
	return _groups.duplicate()

func group_title(group: StringName) -> String:
	return str(_group_titles.get(group, group))

func actions_of(group: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(_actions.get(group, []))
	return list

func all_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for group in _groups:
		out.append_array(actions_of(group))
	return out

## Empty if the command isn't in the catalog.
func group_of(action: StringName) -> StringName:
	return _group_of.get(action, &"")

func title_of(action: StringName) -> String:
	return str(_titles.get(action, action))

func scope_of(action: StringName) -> StringName:
	return _scopes.get(group_of(action), &"")

## Two commands active together: the same input would trigger both.
func conflicts(a: StringName, b: StringName) -> bool:
	if a != b and (_shares.get(a, []) as Array).has(b):
		return false
	var sa := scope_of(a)
	var sb := scope_of(b)
	if sa == &"" or sb == &"":
		return a == b
	return sa == sb or sa == GLOBAL_SCOPE or sb == GLOBAL_SCOPE

## The commands active together with `action`, itself included.
func conflicting(action: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for other in all_actions():
		if conflicts(action, other):
			out.append(other)
	if out.is_empty():
		out.append(action)
	return out

func _share(action: StringName, other: StringName) -> void:
	if not _shares.has(action):
		_shares[action] = []
	(_shares[action] as Array).append(other)
