extends "res://scripts/main.gd"
var flash_enabled:=true
var traces_enabled:=true
func _spawn_npc(_index: int,_armed:=false) -> void: pass
func gameplay_input_allowed() -> bool: return mode!="menu" and not ui_focus.blocked()
func _muzzle_flash(at: Vector3) -> void:
	if flash_enabled: super._muzzle_flash(at)
func _step_projectiles(delta: float) -> void:
	super._step_projectiles(delta)
	if not traces_enabled:
		for shot: Dictionary in projectiles:
			if is_instance_valid(shot.node): shot.node.hide()
			if is_instance_valid(shot.trace): shot.trace.hide()
			if shot.has("visual") and not shot.visual.is_empty(): shot.visual.outline.hide()
