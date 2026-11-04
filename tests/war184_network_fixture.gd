extends "res://tests/war_network_fixture.gd"
func _network_port() -> int: return 39594
func _build_desert() -> void:
	super._build_desert()
	var p:=WarRules.BASES[0]+Vector3(0,0,30)
	for i in 3: _static_box(world_root,"QAStair"+str(i),p+Vector3(0,(i+1)*.1,-2.5-i),Vector3(4,(i+1)*.2,1),Color.GRAY)
	_static_box(world_root,"QAUpperLanding",p+Vector3(0,.3,-5.5),Vector3(4,.6,2),Color.GRAY)
@rpc("authority","call_remote","reliable")
func qa_pose(id: int,point: Vector3,yaw_value: float,pitch_value: float) -> void:
	super.qa_pose(id,point,yaw_value,pitch_value)
	var actor:=players.get(id) as WarPlayer
	if is_instance_valid(actor): actor.set_meta("fixture_freeze",true)
@rpc("any_peer","call_remote","unreliable")
func server_player_state(pos: Vector3,new_yaw: float,new_pitch: float,weapon: String,crouched: bool,aim_level:=0,life:=1,sequence:=0,lean_value:=0.0) -> void:
	var actor:=players.get(multiplayer.get_remote_sender_id()) as WarPlayer
	if is_instance_valid(actor) and actor.get_meta("fixture_freeze",false):
		actor.yaw=new_yaw;actor.pitch=new_pitch;actor.rotation.y=new_yaw
		return
	super.server_player_state(pos,new_yaw,new_pitch,weapon,crouched,aim_level,life,sequence,lean_value)
