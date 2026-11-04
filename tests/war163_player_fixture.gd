extends WarGame
func _network_port() -> int: return 39584
func _notice(id: int,message: String) -> void:
	if is_instance_valid(local_player) and local_player.peer_id==id: war_notice(message)
	else: super._notice(id,message)
