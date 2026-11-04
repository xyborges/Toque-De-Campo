extends "res://modes/battle_royale/matchmaking/router.gd"
class_name BRMatchBroker
const POOL=preload("res://modes/battle_royale/matchmaking/room_pool.gd")
var pool:=POOL.new()
var tick:=0.
var stopping:=false
var health_clock:=0.

func start_listening(port: int=PORT,version: int=PROTOCOL,limit: int=4) -> Error:
	if server_mode:return ERR_ALREADY_IN_USE
	protocol=version
	limit=int(BRRoomRegistry.argument("--br-max-rooms",str(limit)))
	var folder:=NavalStorage.folder().path_join("br-matches")
	pool.configure(folder,clampi(limit,1,16),_launch_room,OS.is_process_running,OS.kill)
	transport=ENetMultiplayerPeer.new()
	# Godot 4.7's ENet server max_channels argument also changes bandwidth;
	# leave it at the unlimited default, as the shared game transport does.
	var error:=transport.create_server(port,64)
	if error==OK:error=GameSecureTransport.server(transport)
	if error!=OK:transport=null;return error
	server_mode=true;network_api.multiplayer_peer=transport
	_publish_health()
	print("BR_MATCH_BROKER_READY ",port," rooms=",pool.max_rooms," ports=3020-3035")
	return OK

func _process(delta: float) -> void:
	super._process(delta)
	if not server_mode:return
	tick+=delta
	if tick<.25:return
	tick=0.;pool.pump(Time.get_unix_time_from_system())
	health_clock+=.25
	if health_clock>=1.:health_clock=0.;_publish_health()
	for id in requests.keys():
		var result: Dictionary=pool.result(str(requests[id].account),Time.get_unix_time_from_system())
		if not bool(result.get("pending",false)):_respond(int(id),result)

func _publish_health() -> void:
	var humans:=0
	for room: Dictionary in pool.rooms.values():humans+=int(room.status.get("humans",0))
	# Reservations count too: do not restart a broker between admission and
	# the first child heartbeat. Bots do not prevent an empty-server update.
	NavalStorage.write_json(NavalStorage.folder().path_join("br-broker-status.json"),{"connections":humans+pool.assignments.size(),"humans":humans,"rooms":pool.rooms.size(),"updated":Time.get_unix_time_from_system()})

func _on_authenticated(id: int,account: String) -> void:
	var result:=pool.request(account,Time.get_unix_time_from_system(),str(requests.get(id,{}).get("name","Jogador")))
	if not bool(result.get("ok",false)):_respond(id,result)

func _on_cancel(account: String,undelivered_only: bool) -> void:pool.cancel(account,undelivered_only)

func _launch_room(port: int,id: String,folder: String) -> int:
	var arguments:=PackedStringArray(["--headless","--max-fps","60","--log-file",folder.path_join("room.log")])
	if OS.has_feature("editor"):
		arguments.append_array(PackedStringArray(["--path",ProjectSettings.globalize_path("res://")]))
	# Exported runtimes open their adjacent PCK automatically. Explicit path
	# overrides are deliberately disabled in the protected server template.
	arguments.append("--")
	for arg in OS.get_cmdline_user_args():
		for prefix in ["--accounts-service-token=","--game-tls-cert=","--game-tls-key=","--game-tls-ca=","--game-tls-host="]:
			if arg.begins_with(prefix):arguments.append(arg)
	arguments.append_array(PackedStringArray(["--br-room","--br-port="+str(port),"--br-room-id="+id,"--br-room-dir="+folder,"--naval-data="+folder]))
	return OS.create_process(OS.get_executable_path(),arguments,false)

func _exit_tree() -> void:
	if not stopping:stopping=true;pool.shutdown()
	super._exit_tree()
