extends "res://scripts/main.gd"
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:return
	super._input(event)
func gameplay_input_allowed() -> bool:return mode!="menu" and not ui_focus.blocked()
