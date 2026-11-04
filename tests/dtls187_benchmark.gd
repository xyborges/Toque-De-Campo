extends SceneTree
# Local transport microbenchmark only: no accounts or game data. The
# unencrypted control case binds strictly to loopback and is never published.
var server: ENetMultiplayerPeer
var client: ENetMultiplayerPeer
var results: Dictionary={}
var samples: Array[float]=[]
var next_send:=0
var sent:=0
var arrived:=0
var running:=false
var cpu_usec:=0
func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	if not running: return false
	var start:=Time.get_ticks_usec()
	server.poll();client.poll()
	while server.get_available_packet_count()>0:
		var sender:=server.get_packet_peer();var packet:=server.get_packet()
		server.set_target_peer(sender);server.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE;server.put_packet(packet)
	while client.get_available_packet_count()>0:
		var packet:=client.get_packet()
		if packet.size()==256:
			arrived+=1
			if arrived>50: samples.append((Time.get_ticks_usec()-packet.decode_u64(0))*.001)
	if client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_usec()>next_send and sent<650:
		var packet:=PackedByteArray();packet.resize(256);packet.encode_u64(0,Time.get_ticks_usec())
		client.set_target_peer(1);client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE;client.put_packet(packet)
		sent+=1;next_send=Time.get_ticks_usec()+5000
	cpu_usec+=Time.get_ticks_usec()-start
	return false
func run() -> void:
	for secure in [false,true]:
		server=ENetMultiplayerPeer.new();server.set_bind_ip("127.0.0.1")
		if server.create_server(39615,2)!=OK: quit(1);return
		if secure and GameSecureTransport.server(server)!=OK: quit(1);return
		client=ENetMultiplayerPeer.new();client.create_client("127.0.0.1",39615)
		if secure and GameSecureTransport.client(client,"127.0.0.1")!=OK: quit(1);return
		samples.clear();next_send=0;sent=0;arrived=0;cpu_usec=0;running=true
		var until:=Time.get_ticks_msec()+10000
		while Time.get_ticks_msec()<until and arrived<650: await process_frame
		running=false
		var sorted:=samples.duplicate();sorted.sort();var sum:=0.
		for value in sorted: sum+=value
		results["dtls" if secure else "plain_loopback_control"]={"sent":sent,"received":arrived,"n":sorted.size(),"mean_ms":sum/maxi(1,sorted.size()),"p95_ms":sorted[mini(sorted.size()-1,int(sorted.size()*.95))] if not sorted.is_empty() else -1,"poll_cpu_ms_per_exchange":cpu_usec*.001/maxi(1,arrived)}
		server.close();client.close();await create_timer(.1).timeout
	NavalStorage.write_json("res://tests/dtls187-results.json",results);print(JSON.stringify(results))
	quit(0 if results.dtls.received==650 and results.plain_loopback_control.received==650 else 1)
