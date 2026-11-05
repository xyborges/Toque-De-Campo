extends WarGame
class NoLocomotion extends WarLocomotion:
	func advance(_actor: GamePlayer,_delta: float) -> void: pass
	func pose_body(_actor: GamePlayer) -> void: pass
	func pose_weapon(_actor: GamePlayer) -> void: pass

func _new_player() -> GamePlayer:
	var actor:=super._new_player() as WarPlayer
	if "--bench-disable-locomotion" in OS.get_cmdline_user_args(): actor.locomotion=NoLocomotion.new()
	return actor

var simulated_hits:=0
var benchmark_ready: Dictionary={}
var benchmark_begun:=false
func _build_desert() -> void:
	if "--bench-light-peers" in OS.get_cmdline_user_args() and DisplayServer.get_name()=="headless" and not dedicated_pvp:
		# Network load agents need their local firing/movement surface, not
		# another copy of all map colliders. Authority and the renderer keep
		# the full playable world; no production gameplay path is changed.
		var tiles: Array[Vector2i]=[]
		for z in range(14,18):
			for x in range(14,18): tiles.append(Vector2i(x,z))
		WarTerrain.build(world_root,false,tiles)
	else: super._build_desert()
func _ready() -> void:
	super._ready()
	print("BENCH_ROOT_READY server=",dedicated_pvp," testing=",testing," online=",online," status=",status_label.text)
	get_tree().create_timer(5).timeout.connect(func(): print("BENCH_TRANSPORT server=",dedicated_pvp," peers=",multiplayer.get_peers()," status=",status_label.text," notice=",last_notice))
func _connected_to_server() -> void:
	print("BENCH_CONNECTED_BEGIN ",Time.get_ticks_msec())
	super._connected_to_server()
	print("BENCH_CONNECTED_END ",Time.get_ticks_msec()," peers=",multiplayer.get_peers()," status=",status_label.text)
func _appearance_payload() -> Dictionary:
	var value:=super._appearance_payload()
	print("BENCH_JOIN_PAYLOAD ",value.get("war_protocol")," testing=",testing)
	return value
@rpc("any_peer","call_remote","reliable")
func server_join_request(nickname: String,appearance: Dictionary,ticket: Dictionary={},public_pem:="",proof:=PackedByteArray()) -> void:
	print("BENCH_JOIN_RECEIVED version=",appearance.get("war_protocol")," authority=",WarRules.PROTOCOL," testing=",testing)
	super.server_join_request(nickname,appearance,ticket,public_pem,proof)
@rpc("any_peer","call_remote","reliable")
func bench_ready() -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()): benchmark_ready[multiplayer.get_remote_sender_id()]=true
@rpc("authority","call_remote","reliable")
func bench_begin() -> void:
	benchmark_begun=true
	if "--bench-fixed-daylight" in OS.get_cmdline_user_args():
		for node in world_root.find_children("*","Node",true,false):
			if node is GameDayNight: node.set_process(false);node.apply_time(0,true)
func gameplay_input_allowed() -> bool:
	return join_ready and is_instance_valid(local_player) and local_player.deployed and local_player.hp>0 and not ui_focus.blocked()
func _battle_active() -> bool: return not members.is_empty() and not match_ended
func _server_accept_shot(id: int,sequence: int,life: int,origin: Vector3,direction: Vector3,weapon: String,aim_level := -1,zero_range:=0) -> void:
	var previous:=dedicated_pvp
	if players.size()==1: dedicated_pvp=false
	super._server_accept_shot(id,sequence,life,origin,direction,weapon,aim_level,zero_range)
	dedicated_pvp=previous
func _apply_hit(_owner_id: int,_hit: Dictionary,_damage: float,_region := "chest",_weapon := "fal",_direction := Vector3.ZERO) -> void:
	# Test-only immortality keeps all twelve clients firing throughout a
	# comparable timed load. Combat damage is covered by the integration tests.
	simulated_hits+=1
