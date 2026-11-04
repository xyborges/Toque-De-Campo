extends SceneTree

# Isolated ENet test. This is NOT the WarGame protocol or a DTLS test.
const Model=preload("res://tests/pole_fracture_model.gd")
var role:="server"
var port:=0

class Peer extends Node:
	var role: String
	var model=Model.new()
	var first:=0
	var late:=0
	var reports: Dictionary={}
	var duplicate_rejected:=false
	var request_rejected:=false
	var client_local_rejected:=false
	var completed:=false
	var events_seen:=0
	var first_event: Dictionary={}
	var cell:=Vector2i.ZERO

	func _ready() -> void:
		model.authoritative=role=="server"
		if not model.register(cell,[Vector3(2,1,2),Vector3(5,1,2),Vector3(8,1,2)]):
			push_error("pole fixture registration failed");get_tree().quit(1);return
		if role!="server":
			multiplayer.connected_to_server.connect(func():
				client_local_rejected=model.shot(cell,2,1000.,Vector3(8,3,2),Vector3.RIGHT).is_empty() and model.broken.is_empty()
				rpc_id(1,"join");rpc_id(1,"untrusted_shot",cell,2))
			multiplayer.connection_failed.connect(func(): push_error("pole fixture connection failed");get_tree().quit(2))

	func heights() -> Array:
		var values: Array=[]
		for event: Dictionary in model.snapshot(): values.append(int(event.height_cm))
		values.sort();return values

	@rpc("any_peer","call_remote","reliable")
	func join() -> void:
		if not multiplayer.is_server(): return
		var sender:=multiplayer.get_remote_sender_id()
		if first==0:
			first=sender
			var low: Dictionary=model.shot(cell,0,120.,Vector3(2,2.5,2),Vector3.RIGHT)
			var high: Dictionary=model.shot(cell,1,120.,Vector3(5,7.2,2),Vector3.LEFT)
			if low.is_empty() or high.is_empty(): push_error("authority failed to break poles");get_tree().quit(3);return
			first_event=low
			rpc_id(sender,"event_received",low)
			rpc_id(sender,"event_received",high)
			rpc_id(sender,"event_received",low)
		elif late==0:
			late=sender
			rpc_id(sender,"snapshot_received",model.snapshot())
			rpc_id(sender,"event_received",first_event)

	@rpc("any_peer","call_remote","reliable")
	func untrusted_shot(target_cell: Vector2i,target_index: int) -> void:
		if not multiplayer.is_server(): return
		var sender:=multiplayer.get_remote_sender_id()
		# A client may not directly mutate destruction state. A production
		# implementation would validate the server's own collision and weapon.
		var rejected: bool=sender!=1 and target_cell==cell and target_index==2 and not model.broken.has(model.key(cell,2))
		rpc_id(sender,"request_result",rejected)

	@rpc("authority","call_remote","reliable")
	func request_result(rejected: bool) -> void:
		request_rejected=rejected
		maybe_ack()

	@rpc("authority","call_remote","reliable")
	func event_received(event: Dictionary) -> void:
		events_seen+=1
		if not model.apply_event(event): duplicate_rejected=true
		maybe_ack()

	@rpc("authority","call_remote","reliable")
	func snapshot_received(events: Array) -> void:
		for event: Dictionary in events:
			if not model.apply_event(event): push_error("late snapshot rejected");get_tree().quit(4);return
		maybe_ack()

	func maybe_ack() -> void:
		if role=="server" or completed: return
		if heights()!=[150,620] or not duplicate_rejected or not request_rejected or not client_local_rejected: return
		completed=true
		if role=="first":
			var file:=FileAccess.open("res://work/pole-fracture-first-ready.txt",FileAccess.WRITE)
			if file==null: push_error("cannot create first-client marker");get_tree().quit(5);return
			file.store_string("ready");file.close()
		rpc_id(1,"ack",{"heights":heights(),"duplicates_rejected":duplicate_rejected,"untrusted_rejected":request_rejected,"local_damage_rejected":client_local_rejected,"count":model.broken.size()})

	@rpc("any_peer","call_remote","reliable")
	func ack(report: Dictionary) -> void:
		if not multiplayer.is_server(): return
		var sender:=multiplayer.get_remote_sender_id()
		if sender!=first and sender!=late: return
		reports[sender]=report
		if first==0 or late==0 or not reports.has(first) or not reports.has(late): return
		var valid: bool=heights()==[150,620] and not model.broken.has(model.key(cell,2))
		for id in [first,late]:
			var peer_report: Dictionary=reports[id]
			valid=valid and peer_report.heights==[150,620] and int(peer_report.count)==2 and bool(peer_report.duplicates_rejected) and bool(peer_report.untrusted_rejected) and bool(peer_report.local_damage_rejected)
		var file:=FileAccess.open("res://work/pole-fracture-network.json",FileAccess.WRITE)
		if file==null: push_error("cannot write pole network report");get_tree().quit(6);return
		file.store_string(JSON.stringify({"ok":valid,"server_heights_cm":heights(),"first":reports[first],"late":reports[late],"scope":"isolated headless model; ENet over loopback; no DTLS, no WarGame"}));file.close()
		if not valid: push_error("pole peers diverged");get_tree().quit(7);return
		rpc_id(first,"finish");rpc_id(late,"finish")
		await get_tree().create_timer(.5).timeout;get_tree().quit()

	@rpc("authority","call_remote","reliable")
	func finish() -> void:
		await get_tree().create_timer(.5).timeout
		get_tree().quit()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--port="): port=int(arg.trim_prefix("--port="))
	setup.call_deferred()

func setup() -> void:
	if port<=0 or role not in ["server","first","late"]: quit(2);return
	var net:=ENetMultiplayerPeer.new()
	var result:=net.create_server(port,4) if role=="server" else net.create_client("127.0.0.1",port)
	if result!=OK: push_error("pole network setup failed");quit(3);return
	root.multiplayer.multiplayer_peer=net
	var node:=Peer.new();node.name="PoleTest";node.role=role;root.add_child(node)
	await create_timer(75).timeout
	push_error("pole network timeout");quit(4)
