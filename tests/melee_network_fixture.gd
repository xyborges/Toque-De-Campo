extends "res://scripts/main.gd"

func _network_port() -> int: return 39262
func _build_desert() -> void:
	_static_box(world_root,"Floor",Vector3(0,-0.15,0),Vector3(100,0.3,100),Color.GRAY)
func gameplay_input_allowed() -> bool: return mode != "menu" and not ui_focus.blocked()
func _spawn_player(id: int, local: bool, npc := false, position := Vector3.ZERO) -> GamePlayer:
	return super._spawn_player(id,local,npc,Vector3.ZERO if id == 1 else Vector3(-0.1,0,-1.5))
