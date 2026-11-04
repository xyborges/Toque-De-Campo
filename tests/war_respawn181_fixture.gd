extends WarGame
var phase:=""
var reports: Dictionary={}
func _network_port() -> int: return 39592
@rpc("authority","call_remote","reliable")
func qa_phase(value: String) -> void: phase=value
@rpc("any_peer","call_remote","reliable")
func qa_report(key: String) -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()): reports[key]=true
