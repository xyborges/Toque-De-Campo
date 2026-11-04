extends "res://scripts/main.gd"
var phase:=""
var reports: Dictionary={}
func _network_port() -> int: return 39591
func _ready() -> void:
	set_meta("test_mode",true);super._ready()
	# The local-only harness has no account service. The exported build does
	# not include this fixture; production authentication is tested separately.
	if multiplayer.is_server(): dedicated_pvp=false
@rpc("authority","call_remote","reliable")
func qa_phase(value: String) -> void: phase=value
@rpc("any_peer","call_remote","reliable")
func qa_report(value: String) -> void:
	if multiplayer.is_server() and players.has(multiplayer.get_remote_sender_id()): reports[value]=true
