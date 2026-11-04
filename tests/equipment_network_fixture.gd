extends "res://tests/war_network_fixture.gd"
var clients: Dictionary={}
var records: Dictionary={}
func _network_port() -> int: return 39629
@rpc("any_peer","call_remote","reliable")
func qa_register(label: String) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and members.has(id) and label in ["first","late"]: clients[label]=id
@rpc("any_peer","call_remote","reliable")
func qa_result(token: String,data: Dictionary) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and members.has(id): records[str(id)+":"+token]=data
