extends "res://scripts/main.gd"
func _network_port() -> int: return 39542
func _build_desert() -> void:
	_static_box(world_root,"Floor",Vector3(0,-.25,0),Vector3(200,.4,200),Color.GRAY)
func find_spawn(_id: int) -> Vector3: return Vector3(12+players.size()*6,0,0)
func gameplay_input_allowed() -> bool: return mode!="menu" and not ui_focus.blocked()
