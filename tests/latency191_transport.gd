extends SceneTree
const SERVER_PORT := 39651
const PROXY_PORT := 39652
const CONTROL_PORT := 39653
var server: ENetMultiplayerPeer
var client: ENetMultiplayerPeer
var proxy_control: PacketPeerUDP
var manager: WarVehicles
var sources: Dictionary = {}
var receivers: Dictionary = {}
var raw_sequences: Dictionary = {}
var accepted_sequences: Dictionary = {}
var delivery_ms: Array[float] = []
var target_id := 0
var running := false
var checks := 0
var failures: Array[String] = []
var raw_packets := 0
var rejected_old := 0
var maximum_payload_bytes := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func _process(_delta: float) -> bool:
	if not running: return false
	server.poll();client.poll()
	while server.get_available_packet_count()>0: server.get_packet()
	while client.get_available_packet_count()>0:
		var packet := client.get_packet()
		var envelope: Dictionary = bytes_to_var(packet)
		if str(envelope.get("kind",""))!="vehicle": continue
		var state: Dictionary = envelope.state
		var id := str(state.id)
		if not receivers.has(id): continue
		raw_packets+=1
		raw_sequences[id].append(int(state.get("sequence",0)))
		delivery_ms.append((Time.get_ticks_usec()-int(envelope.at))*.001)
		var actor := receivers[id] as WarVehicle
		var before := actor.received_state_sequence
		actor.receive(state)
		if actor.received_state_sequence>before: accepted_sequences[id].append(actor.received_state_sequence)
		else: rejected_old+=1
	return false

func wait_for(test: Callable, label: String, seconds := 3.) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	failures.append(label);print("TIMEOUT "+label)
	return false

func profile(value: String) -> bool:
	while proxy_control.get_available_packet_count()>0: proxy_control.get_packet()
	proxy_control.put_packet(value.to_utf8_buffer())
	return await wait_for(func():return proxy_control.get_available_packet_count()>0,"proxy profile acknowledgement",1.)

func send_state(state: Dictionary) -> void:
	var packet := var_to_bytes({"kind":"vehicle","state":state,"at":Time.get_ticks_usec()})
	maximum_payload_bytes=maxi(maximum_payload_bytes,packet.size())
	server.set_target_peer(target_id)
	server.put_packet(packet)
	server.get_host().flush()

func send_current(id: String) -> Dictionary:
	var state := manager._vehicle_snapshot_for_send(sources[id])
	if not state.is_empty(): send_state(state)
	return state

func both_sequence(value: int) -> bool:
	for actor: WarVehicle in receivers.values():
		if actor.received_state_sequence!=value: return false
	return true

func run() -> void:
	Engine.max_fps=240
	manager=load("res://tests/latency191_manager_fixture.gd").new();root.add_child(manager)
	for index in 2:
		var id := "latency_vehicle_"+str(index)
		var source := load("res://tests/latency191_vehicle_fixture.gd").new() as WarVehicle
		var receiver := load("res://tests/latency191_vehicle_fixture.gd").new() as WarVehicle
		source.vehicle_id=id;receiver.vehicle_id=id
		source.kind="guarani" if index==0 else "t90";receiver.kind=source.kind
		root.add_child(source);root.add_child(receiver)
		source.position=Vector3(index*20,0,0);source.seats_revision=1;source.control_epoch=1;source.seats={0:70+index};source.driver=70+index
		sources[id]=source;receivers[id]=receiver;raw_sequences[id]=[];accepted_sequences[id]=[]
	proxy_control=PacketPeerUDP.new()
	if proxy_control.bind(0,"127.0.0.1")!=OK: failures.append("local control bind failed");finish();return
	proxy_control.set_dest_address("127.0.0.1",CONTROL_PORT)
	server=ENetMultiplayerPeer.new();server.set_bind_ip("127.0.0.1")
	server.peer_connected.connect(func(id: int):target_id=id)
	if server.create_server(SERVER_PORT,1)!=OK or GameSecureTransport.server(server)!=OK:
		failures.append("DTLS server setup failed");finish();return
	client=ENetMultiplayerPeer.new()
	if client.create_client("127.0.0.1",PROXY_PORT)!=OK or GameSecureTransport.client(client,"127.0.0.1")!=OK:
		failures.append("DTLS client setup failed");finish();return
	server.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	running=true
	if not await wait_for(func():return target_id>0 and client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"encrypted peers connect through UDP proxy",8.): finish();return
	check(true,"two real ENet peers connect through pinned DTLS on loopback")
	await profile("normal")
	for id in sources: send_current(str(id))
	check(await wait_for(func():return both_sequence(1),"both initial vehicle states"),"independent vehicles accept sequence one")
	await profile("reorder")
	for source: WarVehicle in sources.values(): source.position.x+=10.;send_current(source.vehicle_id)
	await create_timer(.10).timeout
	for source: WarVehicle in sources.values(): source.position.x+=1.;send_current(source.vehicle_id)
	check(await wait_for(func():return both_sequence(3),"newer poses arrive before delayed poses"),"newer states of both vehicles arrive without cross-entity ordering")
	await create_timer(.30).timeout
	var reordered := true
	for id in receivers:
		var seen: Array = raw_sequences[id]
		reordered=reordered and seen.has(2) and seen.has(3) and seen.find(3)<seen.find(2)
		var actor := receivers[id] as WarVehicle
		reordered=reordered and actor.destination==sources[id].global_position and actor.received_state_sequence==3
	check(reordered,"proxy reorders encrypted old packets after newer packets and the real receiver keeps the newer pose")
	await profile("drop")
	var final_sent_usec := Time.get_ticks_usec()
	for source: WarVehicle in sources.values(): source.position.x+=20.;send_current(source.vehicle_id)
	await create_timer(.30).timeout
	check(both_sequence(3),"dropping the final pose leaves the previous state until a heartbeat")
	var before_heartbeat := true
	for source: WarVehicle in sources.values(): before_heartbeat=before_heartbeat and manager._vehicle_snapshot_for_send(source).is_empty()
	check(before_heartbeat,"unchanged vehicles do not send before the configured 500ms heartbeat")
	await create_timer(.25).timeout
	for id in sources: send_current(str(id))
	check(await wait_for(func():return both_sequence(5),"heartbeat repairs both final poses"),"the real factory heartbeat repairs two stopped vehicles after the final datagrams are lost")
	var repair_ms := (Time.get_ticks_usec()-final_sent_usec)*.001
	var final_repaired := true
	for id in receivers:
		final_repaired=final_repaired and not raw_sequences[id].has(4) and receivers[id].destination==sources[id].global_position
	check(final_repaired and repair_ms<1000.,"the last lost state recovers within one second and was not delivered as its original packet")
	await profile("normal")
	var destruction: Dictionary = {}
	for source: WarVehicle in sources.values():
		source.destroyed=true;source.hp=0.;source.clear_seats()
		destruction[source.vehicle_id]=send_current(source.vehicle_id)
	check(await wait_for(func():return both_sequence(6),"destruction states"),"destroyed lifecycle states arrive through DTLS")
	var old_revision_did_not_poison := true
	for id in receivers:
		var stale: Dictionary = destruction[id].duplicate(true)
		stale.seats_revision=1;stale.sequence=10000;stale.hp=999.;stale.destroyed=false
		send_state(stale)
	await create_timer(.08).timeout
	for actor: WarVehicle in receivers.values(): old_revision_did_not_poison=old_revision_did_not_poison and actor.destroyed and actor.hp==0. and actor.received_state_sequence==6
	check(old_revision_did_not_poison,"an old seat generation cannot poison sequence state or resurrect a destroyed vehicle")
	for source: WarVehicle in sources.values():
		source.destroyed=false;source.hp=650.;source.position.x=5.;source.clear_seats();send_current(source.vehicle_id)
	check(await wait_for(func():return both_sequence(7),"respawn states"),"respawn accepts the monotonic sequence after occupancy generation changes")
	for id in destruction: send_state(destruction[id])
	await create_timer(.08).timeout
	var lifespan_safe := true
	for actor: WarVehicle in receivers.values(): lifespan_safe=lifespan_safe and not actor.destroyed and actor.hp==650. and actor.destination.x==5. and actor.received_state_sequence==7
	check(lifespan_safe,"a late destruction packet cannot roll back a respawned vehicle")
	for id in destruction:
		var legacy: Dictionary = destruction[id].duplicate(true)
		legacy.erase("sequence");legacy.seats_revision=3;legacy.position=Vector3(-900,0,0)
		send_state(legacy)
	await create_timer(.08).timeout
	check(both_sequence(7) and receivers.values()[0].destination.x==5. and receivers.values()[1].destination.x==5.,"sequence-zero legacy payloads cannot bypass established ordering")
	check(rejected_old>=6,"stale packets actually traversed the encrypted transport and reached the receiver")
	finish({"repair_ms":repair_ms})

func finish(extra: Dictionary = {}) -> void:
	running=false
	if client: client.close()
	if server: server.close()
	if proxy_control: proxy_control.close()
	var result := {"checks":checks,"failures":failures,"dtls":true,"loopback_only":true,"real_udp_proxy":true,"vehicles":2,"raw_packets":raw_packets,"rejected_old":rejected_old,"raw_sequences":raw_sequences,"accepted_sequences":accepted_sequences,"delivery_ms":preload("res://scripts/network_diagnostics.gd").stats(delivery_ms),"maximum_variant_payload_bytes":maximum_payload_bytes,"factory":"WarVehicles._vehicle_snapshot_for_send","receiver":"WarVehicle.receive"}
	result.merge(extra)
	NavalStorage.write_json("res://tests/latency191-transport-results.json",result);print(JSON.stringify(result))
	for source: WarVehicle in sources.values(): source.queue_free()
	for actor: WarVehicle in receivers.values(): actor.queue_free()
	if manager: manager.queue_free()
	quit(0 if failures.is_empty() else 1)
