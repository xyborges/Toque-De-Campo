extends SceneTree
const Model=preload("res://tests/impact_breakage_model.gd")
var role:="server"
var port:=0

class Peer extends Node:
	var role: String
	var model=Model.new()
	var first:=0
	var second:=0
	var received: Dictionary={}
	func _ready() -> void:
		model.register(Vector2i.ZERO,[{"kind":"pole","position":Vector3(2,0,2)},{"kind":"thin","position":Vector3(5,0,2)}])
		print("PEER_READY ",role)
		if role!="server":
			multiplayer.connected_to_server.connect(func(): print("CONNECTED ",role);rpc_id(1,"join"))
			multiplayer.connection_failed.connect(func(): print("CONNECTION_FAILED ",role))
	@rpc("any_peer","call_remote","reliable")
	func join() -> void:
		if not multiplayer.is_server(): return
		var sender:=multiplayer.get_remote_sender_id()
		print("JOIN ",sender)
		if first==0:
			first=sender
			var event: Dictionary=model.impact(Vector2i.ZERO,0,30000.,3.,Vector3.RIGHT)
			rpc_id(first,"event_received",event)
			for blast_event: Dictionary in model.explosion(Vector3(5,0,2),200.,4.): rpc_id(first,"event_received",blast_event)
		elif second==0:
			second=sender;rpc_id(second,"snapshot_received",model.snapshot())
	@rpc("authority","call_remote","reliable")
	func event_received(event: Dictionary) -> void:
		if model.apply_event(event): rpc_id(1,"ack",model.broken.size())
	@rpc("authority","call_remote","reliable")
	func snapshot_received(events: Array) -> void:
		for event: Dictionary in events: model.apply_event(event)
		rpc_id(1,"ack",model.broken.size())
	@rpc("any_peer","call_remote","reliable")
	func ack(count: int) -> void:
		if not multiplayer.is_server(): return
		var sender:=multiplayer.get_remote_sender_id()
		print("ACK ",sender," ",count)
		received[sender]=count
		if sender==first and count==2:
			var marker:=FileAccess.open("res://work/impact-first-ready.txt",FileAccess.WRITE);marker.store_string("ready");marker.close()
		if first and second and int(received.get(first,0))==2 and int(received.get(second,0))==2:
			var f:=FileAccess.open("res://work/impact-breakage-network.json",FileAccess.WRITE)
			f.store_string(JSON.stringify({"server_count":model.broken.size(),"first_count":received[first],"late_count":received[second],"transport":"local ENet test, no DTLS","scope":"isolated model; not live WarGame"}));f.close()
			rpc_id(first,"finish");rpc_id(second,"finish")
			await get_tree().create_timer(.5).timeout;get_tree().quit()
	@rpc("authority","call_remote","reliable")
	func finish() -> void:
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port=int(arg.trim_prefix("--port="))
	setup.call_deferred()

func setup() -> void:
	print("SETUP ",role," ",port)
	if port<=0: quit(2);return
	var net:=ENetMultiplayerPeer.new()
	var result:=net.create_server(port,4) if role=="server" else net.create_client("127.0.0.1",port)
	if result!=OK: push_error("network test setup failed");quit(3);return
	root.multiplayer.multiplayer_peer=net
	var node:=Peer.new();node.name="BreakageTest";node.role=role;root.add_child(node)
	await create_timer(75).timeout
	push_error("network test timeout");quit(4)
