extends "res://scripts/main.gd"

func _network_port() -> int:
	var role: String = get_meta("role","server")
	return 39122 if role == "server" else (39123 if role == "shooter" else 39124)

func _build_desert() -> void:
	_static_box(world_root,"Floor",Vector3(0,-0.25,0),Vector3(200,0.4,200),Color.GRAY)

# Headless transport tests inject focus; desktop focus is tested in the rendered fixture.
func gameplay_input_allowed() -> bool:
	return mode != "menu" and not ui_focus.blocked()

var joining_name := ""

@rpc("any_peer","call_remote","reliable")
func server_join_request(nickname: String, appearance: Dictionary, ticket: Dictionary = {}, public_pem := "", proof := PackedByteArray()) -> void:
	joining_name = nickname
	super.server_join_request(nickname,appearance,ticket,public_pem,proof)
	joining_name = ""

func _spawn_player(id: int, local: bool, npc := false, position := Vector3.ZERO) -> GamePlayer:
	if local:
		var role: String = get_meta("role","server")
		position = Vector3(10,0,0) if role == "server" else Vector3(0,0,15 if role == "shooter" else -15)
	elif multiplayer.is_server() and not joining_name.is_empty():
		position = Vector3(0,0,15 if joining_name == "Atirador" else -15)
	return super._spawn_player(id,local,npc,position)

func _peer_disconnected(id: int) -> void:
	print("NET_DIAGNOSTIC disconnected role=",get_meta("role","?")," id=",id," local=",multiplayer.get_unique_id()," peers=",multiplayer.get_peers()," ms=",Time.get_ticks_msec())
	super._peer_disconnected(id)

func _server_disconnected() -> void:
	print("NET_DIAGNOSTIC server_disconnected role=",get_meta("role","?")," ms=",Time.get_ticks_msec())
	super._server_disconnected()

func _connected_to_server() -> void:
	print("NET_DIAGNOSTIC connected role=",get_meta("role","?")," local=",multiplayer.get_unique_id()," ms=",Time.get_ticks_msec())
	super._connected_to_server()
