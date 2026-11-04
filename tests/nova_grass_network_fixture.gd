extends "res://tests/war_network_fixture.gd"

# QA transport only. World creation, joining, deployment, snapshots and peer
# cleanup still use WarGame. These RPCs observe state; they never set poses.
var grass_clients: Dictionary={}
var grass_reports: Dictionary={}
var grass_request: Dictionary={}
var grass_command:=""

func _ready() -> void:
	set_meta("nova_grama_preview",true)
	super._ready()

func _network_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grass-port="): return int(arg.trim_prefix("--grass-port="))
	return 39569

@rpc("any_peer","call_remote","reliable")
func qa_grass_register(label: String) -> void:
	var sender:=multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and members.has(sender) and label in ["first","late"]:
		grass_clients[label]=sender

@rpc("any_peer","call_remote","reliable")
func qa_grass_report(token: String,data: Dictionary) -> void:
	var sender:=multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and members.has(sender):
		grass_reports[str(sender)+":"+token]=data.duplicate(true)

@rpc("authority","call_remote","reliable")
func qa_grass_snapshot(token: String,expected: Dictionary,heights: Array) -> void:
	grass_request={"token":token,"expected":expected,"heights":heights}

@rpc("authority","call_remote","reliable")
func qa_grass_command(value: String) -> void:
	grass_command=value

func grass_authority_snapshot(token: String,targets: Array) -> void:
	var expected: Dictionary={}
	for id: Variant in grass_clients.values():
		var actor:=players.get(id) as WarPlayer
		if is_instance_valid(actor):
			expected[str(id)]={"position":actor.global_position,"life":actor.life_id,"team":actor.war_team,"deployed":actor.deployed,"head":actor.avatar_parts.head.global_position,"legs":actor.avatar_parts.leg_l.scale.y}
	var heights: Array=[]
	for point in [Vector2(-150,-650),Vector2(-80,-155),Vector2(-500,500),Vector2(1000,-700)]:
		heights.append({"point":point,"height":WarTerrain.height_at(point.x,point.y)})
	for id: int in targets: rpc_id(id,"qa_grass_snapshot",token,expected,heights)
