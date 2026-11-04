extends "res://tests/war_network_fixture.gd"
var drop_next_respawn:=false
func _network_port() -> int: return 39606
@rpc("authority","call_remote","reliable")
func remote_player_respawn(id: int,pos: Vector3,life: int) -> void:
	if drop_next_respawn and is_instance_valid(local_player) and id==local_player.peer_id:
		drop_next_respawn=false;print("QA_DROP_RESPAWN_PRESENTATION ",life);return
	super.remote_player_respawn(id,pos,life)
@rpc("authority","call_remote","reliable")
func qa_pose(id: int,point: Vector3,yaw_value: float,pitch_value: float) -> void:
	super.qa_pose(id,point,yaw_value,pitch_value)
	var actor:=players.get(id) as WarPlayer
	if is_instance_valid(actor): actor.set_meta("fixture_freeze",true)
@rpc("any_peer","call_remote","unreliable")
func server_player_state(pos: Vector3,yaw_value: float,pitch_value: float,weapon: String,crouched: bool,aim_level:=0,life:=1,sequence:=0,lean_value:=0.0) -> void:
	var actor:=players.get(multiplayer.get_remote_sender_id()) as WarPlayer
	if is_instance_valid(actor) and actor.get_meta("fixture_freeze",false):
		actor.yaw=yaw_value;actor.pitch=pitch_value;actor.rotation.y=yaw_value;return
	super.server_player_state(pos,yaw_value,pitch_value,weapon,crouched,aim_level,life,sequence,lean_value)
