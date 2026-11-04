extends "res://tests/combat_153_network_fixture.gd"
func _network_port() -> int: return 39565
func _build_desert() -> void: DesertMap.build(world_root,not dedicated_pvp)
func find_spawn(id: int) -> Vector3: return DesertMap.spawn_pad(id)
