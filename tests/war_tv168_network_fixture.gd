extends "res://tests/war_network_fixture.gd"
func _network_port() -> int: return 39586
@rpc("any_peer","call_remote","reliable")
func qa_tv_report(key: String,data: Dictionary) -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()) and var_to_bytes(data).size()<2000: reports[key]=data
