extends "res://tests/war_network_fixture.gd"
func _network_port() -> int: return 39579

@rpc("any_peer","call_remote","unreliable_ordered")
func server_player_state(pos: Vector3,new_yaw: float,new_pitch: float,weapon: String,crouched: bool,aim_level:=0,life:=1,sequence:=0,lean_value:=0.0) -> void:
	# This harness alone teleports clients between unrelated scenarios. Ignore
	# their pre-teleport datagrams until the reliable qa_pose has been applied.
	var actor:=players.get(multiplayer.get_remote_sender_id()) as WarPlayer
	if is_instance_valid(actor) and actor.has_meta("fixture_warp_point"):
		if pos.distance_to(actor.get_meta("fixture_warp_point"))>3: return
		actor.remove_meta("fixture_warp_point")
	super.server_player_state(pos,new_yaw,new_pitch,weapon,crouched,aim_level,life,sequence,lean_value)
