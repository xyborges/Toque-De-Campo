extends WarGame
var phase:=""
var reports: Dictionary={}
func _network_port() -> int: return 39569
func gameplay_input_allowed() -> bool:
	return join_ready and is_instance_valid(local_player) and local_player.deployed and local_player.hp>0 and not ui_focus.blocked()
@rpc("authority","call_remote","reliable")
func qa_phase(value: String) -> void: phase=value
@rpc("any_peer","call_remote","reliable")
func qa_report(key: String) -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()): reports[key]=true
@rpc("authority","call_remote","reliable")
func qa_pose(id: int,point: Vector3,yaw_value: float,pitch_value: float) -> void:
	var actor:=players.get(id) as WarPlayer
	if not is_instance_valid(actor): return
	actor.position=point;actor.velocity=Vector3.ZERO;actor.network_target=point
	actor.yaw=yaw_value;actor.rotation.y=yaw_value;actor.pitch=pitch_value;actor.network_yaw=yaw_value;actor.network_pitch=pitch_value
	actor.camera_pivot.rotation.x=pitch_value;actor._animate_walk();actor._update_view()
