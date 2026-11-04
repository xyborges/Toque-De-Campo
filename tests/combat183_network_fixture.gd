extends "res://scripts/main.gd"
var phase:=""
var reports: Dictionary={}
func _network_port() -> int: return 39593
func _central_pvp() -> bool: return false
func _ready() -> void:
	set_meta("test_mode",true);super._ready()
	if multiplayer.is_server(): dedicated_pvp=false
func gameplay_input_allowed() -> bool:
	return mode!="menu" and not waiting_for_pvp() and not ui_focus.blocked() and not (is_instance_valid(domination) and domination.blocked())
@rpc("authority","call_remote","reliable")
func qa_phase(value: String) -> void: phase=value
@rpc("any_peer","call_remote","reliable")
func qa_report(value: String) -> void:
	if multiplayer.is_server() and players.has(multiplayer.get_remote_sender_id()): reports[value]=true
