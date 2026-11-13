## InputMapDelivery: the players' schemes go into Godot's InputMap, one event per input, and Godot does the rest. A
## player with one gamepad gets its events for that device only; a combination can't go into the InputMap and is
## skipped (with this delivery the panel never captures one).
class_name InputMapDelivery
extends InputDelivery

func apply(players: Array[RemapPlayer], actions: Array[StringName]) -> void:
	for player in players:
		for scheme in schemes_of(player):
			SchemeApplier.apply(scheme, actions, player)
