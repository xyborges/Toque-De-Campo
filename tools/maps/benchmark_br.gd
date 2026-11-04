extends "res://modes/battle_royale/scripts/game.gd"
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:return
	super._input(event)
