extends "res://scripts/main.gd"
func _spawn_npc(_index: int,_armed:=false) -> void: pass
func _central_pvp() -> bool: return false
func gameplay_input_allowed() -> bool:
	return mode!="menu" and not waiting_for_pvp() and not ui_focus.blocked() and not (is_instance_valid(domination) and domination.blocked())
