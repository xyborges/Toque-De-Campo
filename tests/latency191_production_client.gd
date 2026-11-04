extends WarGame
var tracking := false
var snapshot_arrivals: Array[float] = []
var pose_arrivals: Dictionary = {}

# Observe the current operation RPC without changing gameplay.
@rpc("authority","call_remote","unreliable")
func war_snapshot(time: float,left: float,remaining: Array,objectives_state: Dictionary,ended: bool,victor: int,climate:=0,restart_remaining:=60.,generation: int=-1) -> void:
	super.war_snapshot(time,left,remaining,objectives_state,ended,victor,climate,restart_remaining,generation)
	if tracking: snapshot_arrivals.append(Time.get_ticks_usec()*.001)

@rpc("authority","call_remote", "unreliable")
func remote_player_state(id: int, pos: Vector3, new_yaw: float, new_pitch: float, weapon: String, hp_value: float, is_crouched: bool, life := 1, kill_count := 0, death_count := 0, aim_level := 0,state_lean:=0.0,state_sequence:=0) -> void:
	super.remote_player_state(id,pos,new_yaw,new_pitch,weapon,hp_value,is_crouched,life,kill_count,death_count,aim_level,state_lean,state_sequence)
	if tracking and id!=multiplayer.get_unique_id():
		if not pose_arrivals.has(id): pose_arrivals[id]=[]
		pose_arrivals[id].append(Time.get_ticks_usec()*.001)
