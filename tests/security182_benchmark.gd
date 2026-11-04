extends SceneTree
const CLIENTS:=12
var results: Array[Dictionary]=[]
var server: ENetMultiplayerPeer
var clients: Array[ENetMultiplayerPeer]=[]
var peer_ids: Array[int]=[]
var rtts: Array[float]=[]
var sent_bytes:=0
var received:=0
var input_clock:=0.0
var snapshot_clock:=0.0
var network_work:=0.0
var snapshot:=PackedByteArray()
var input_packet:=PackedByteArray()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	Engine.max_fps=240
	snapshot.resize(900);snapshot.fill(45);snapshot[0]=1
	input_packet.resize(96);input_packet.fill(73);input_packet[0]=2
	for encrypted in [false,true,true,false]:
		server=ENetMultiplayerPeer.new();peer_ids.clear();clients.clear()
		server.peer_connected.connect(func(id: int):peer_ids.append(id))
		if server.create_server(0,CLIENTS)!=OK: quit(1);return
		if encrypted and GameSecureTransport.server(server)!=OK: quit(1);return
		var begun:=Time.get_ticks_usec()
		for i in CLIENTS:
			var client:=ENetMultiplayerPeer.new()
			if client.create_client("127.0.0.1",server.get_host().get_local_port())!=OK: quit(1);return
			if encrypted and GameSecureTransport.client(client,"127.0.0.1")!=OK: quit(1);return
			client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
			clients.append(client)
		var until:=Time.get_ticks_msec()+10000
		while peer_ids.size()<CLIENTS and Time.get_ticks_msec()<until:
			server.poll()
			for client in clients: client.poll()
			await process_frame
		if peer_ids.size()!=CLIENTS: push_error("Benchmark did not connect twelve clients");quit(1);return
		var handshake_ms:=(Time.get_ticks_usec()-begun)*.001
		server.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		input_clock=0;snapshot_clock=0
		var warm:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-warm<1500000:
			step();await process_frame
		rtts.clear();network_work=0;received=0;sent_bytes=0
		var start:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-start<8000000:
			var work_at:=Time.get_ticks_usec();step();network_work+=(Time.get_ticks_usec()-work_at)*.001
			await process_frame
		var seconds:=(Time.get_ticks_usec()-start)*.000001
		rtts.sort()
		var mean_rtt:=0.0
		for value in rtts: mean_rtt+=value
		mean_rtt/=maxi(1,rtts.size())
		var row: Dictionary={"dtls":encrypted,"clients":CLIENTS,"seconds":seconds,"handshake_ms_all_clients":handshake_ms,"network_work_ms_per_second":network_work/seconds,"application_bytes_sent_per_second":sent_bytes/seconds,"packets_received":received,"rtt_samples":rtts.size(),"rtt_mean_ms":mean_rtt,"rtt_p95_ms":rtts[mini(rtts.size()-1,int(rtts.size()*.95))] if not rtts.is_empty() else 0}
		results.append(row);print(JSON.stringify(row))
		for client in clients: client.close()
		server.close();await create_timer(.25).timeout
	NavalStorage.write_json("res://work/security182/dtls-benchmark.json",{"cases":results,"note":"Loopback, twelve real ENet clients and one server in one headless process, 240 Hz polling. Per client: 20 input/echo messages per second and 60 snapshots of 900 bytes per second. Network work includes scripting, ENet and DTLS; not a gameplay FPS benchmark."})
	quit(0)
func step() -> void:
	var at:=Time.get_ticks_usec()*.000001
	server.poll()
	while server.get_available_packet_count()>0:
		var sender:=server.get_packet_peer();var packet:=server.get_packet();received+=1
		if packet.size()==96 and packet[0]==2:
			server.set_target_peer(sender);server.put_packet(packet);sent_bytes+=packet.size()
	if at>=snapshot_clock:
		snapshot_clock=at+1.0/30.0
		for id in peer_ids:
			server.set_target_peer(id)
			for i in 2: server.put_packet(snapshot);sent_bytes+=snapshot.size()
	for client in clients:
		client.poll()
		while client.get_available_packet_count()>0:
			var packet:=client.get_packet();received+=1
			if packet.size()==96 and packet[0]==2: rtts.append((Time.get_ticks_usec()-int(packet.decode_u64(1)))*.001)
	if at>=input_clock:
		input_clock=at+.05
		input_packet.encode_u64(1,Time.get_ticks_usec())
		for client in clients:
			client.set_target_peer(1);client.put_packet(input_packet);sent_bytes+=input_packet.size()
