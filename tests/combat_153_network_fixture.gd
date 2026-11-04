extends "res://scripts/main.gd"
var phase:=""
var reports: Dictionary={}
func _network_port() -> int: return 39563
func _central_pvp() -> bool: return false
func _build_desert() -> void: _static_box(world_root,"Floor",Vector3(0,-.2,0),Vector3(200,.3,200),Color.GRAY)
func find_spawn(_id: int) -> Vector3: return Vector3(players.size()*8,0,8)
func waiting_for_pvp() -> bool: return online and mode=="pvp" and players.size()<2
func gameplay_input_allowed() -> bool: return mode!="menu" and not waiting_for_pvp() and not ui_focus.blocked()
@rpc("authority","call_remote","reliable")
func qa_phase(value: String) -> void: phase=value
@rpc("any_peer","call_remote","reliable")
func qa_report(label: String,data: Dictionary) -> void:
	if multiplayer.is_server(): reports[label]=data
@rpc("any_peer","call_remote","reliable")
func server_join_request(nickname: String,appearance: Dictionary,_ticket: Dictionary={},_pem:="",_proof:=PackedByteArray()) -> void:
	# Authentication is covered against Ubuntu separately; this local fixture
	# isolates the unchanged real ENet gameplay transport from account services.
	var id:=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or players.has(id): return
	pvp_challenges.erase(id)
	var actor:=_spawn_player(id,false,false,find_spawn(id));actor.name=nickname
	_configure_loadout(actor,appearance.get("loadout",actor.owned),true)
	for other: GamePlayer in players.values():
		rpc_id(id,"remote_add_player",other.peer_id,other.name,{},other.global_position)
		_send_player_baseline(id,other)
	_broadcast("remote_add_player",[id,nickname,{},actor.global_position])
	rpc_id(id,"remote_wallet",0,actor.owned);sync_inventory(actor)
