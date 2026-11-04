extends "res://scripts/main.gd"
# This component suite controls deaths and lives directly; full deployment is
# exercised by deployment170_ui and the actual ENet deployment suite.
func defer_respawn_selection(_actor: GamePlayer) -> bool: return false
func _central_pvp() -> bool: return true
func find_spawn(_id: int) -> Vector3: return Vector3(0,0,8)
func _build_desert() -> void:
	_static_box(world_root,"Ground",Vector3(0,-.20,0),Vector3(200,.30,200),Color.GRAY)
