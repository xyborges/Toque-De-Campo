extends SceneTree
var failures: Array[String]=[]
var checks:=0
const PHASE:="res://work/security182/wire-phase.txt"
const MARKER:="TDC_PRIVATE_RPC_MARKER_182_6ae8b98e"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func phase(value: String) -> void:
	var file:=FileAccess.open(PHASE,FileAccess.WRITE);file.store_string(value);file.close()
func pump(server: ENetMultiplayerPeer,client: ENetMultiplayerPeer,seconds: float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		server.poll()
		if client.get_host()!=null: client.poll()
		await process_frame
func run() -> void:
	Engine.max_fps=120
	phase("encrypted")
	var server:=ENetMultiplayerPeer.new();var client:=ENetMultiplayerPeer.new()
	check(server.create_server(39597,4)==OK and GameSecureTransport.server(server)==OK,"DTLS server loads its private certificate")
	check(client.create_client("127.0.0.1",39598)==OK and GameSecureTransport.client(client,"127.0.0.1")==OK,"client enables certificate-validated DTLS before first poll")
	await pump(server,client,1.8)
	check(client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"trusted DTLS peer connects through the UDP capture proxy")
	if client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
		client.set_target_peer(1);client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE;client.put_packet(MARKER.to_utf8_buffer())
		await pump(server,client,.6)
		check(server.get_available_packet_count()>0,"encrypted application packet arrives")
		if server.get_available_packet_count()>0: check(server.get_packet().get_string_from_utf8()==MARKER,"server decrypts the original application message")
	phase("untrusted")
	client.close();server.close();await create_timer(.1).timeout
	server=ENetMultiplayerPeer.new();client=ENetMultiplayerPeer.new()
	server.create_server(39597,4);GameSecureTransport.server(server)
	client.create_client("127.0.0.1",39598)
	var wrong:=X509Certificate.new();wrong.load("res://work/security182/wrong.crt")
	client.get_host().dtls_client_setup("127.0.0.1",TLSOptions.client(wrong))
	await pump(server,client,2.0)
	check(client.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED,"client refuses a server certificate signed by an untrusted CA")
	client.close();server.close();await create_timer(.1).timeout
	phase("plaintext")
	server=ENetMultiplayerPeer.new();client=ENetMultiplayerPeer.new()
	server.create_server(39597,4);GameSecureTransport.server(server)
	client.create_client("127.0.0.1",39598)
	await pump(server,client,1.6)
	check(client.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED,"DTLS server refuses an unencrypted ENet client")
	client.close();server.close();await create_timer(.1).timeout
	phase("encrypted")
	server=ENetMultiplayerPeer.new();client=ENetMultiplayerPeer.new()
	server.create_server(39597,4);GameSecureTransport.server(server)
	client.create_client("127.0.0.1",39598);GameSecureTransport.client(client,"127.0.0.1")
	await pump(server,client,1.2)
	check(client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"trusted client reconnects after both negative cases through the same live proxy")
	client.close();server.close();phase("finished")
	var guard:=GameNetworkGuard.new()
	var position:=Vector3.ZERO
	for i in 1000:
		var answer:=guard.movement(55,1,i+1,position,position+Vector3.RIGHT*100,12.0,10.0)
		if answer.accepted: position=answer.position
	check(position.length()<=1.251,"one thousand simultaneous position messages cannot accumulate movement tolerance")
	guard.clear();position=Vector3.ZERO
	for i in 40:
		var answer:=guard.movement(55,1,i+1,position,position+Vector3.RIGHT*.434,12.0,10.0+i*.05)
		position=answer.position
	check(absf(position.x-17.36)<.01,"normal twenty-hertz sprint updates remain unrestricted")
	check(not guard.movement(55,1,40,position,position+Vector3.RIGHT,12.0,12.0).accepted,"replayed or reordered position sequences are rejected")
	var allowed:=0
	for i in 1000:
		if guard.allow(55,"shot",25,8,20.0): allowed+=1
	check(allowed==8,"RPC flood is bounded by the burst budget")
	guard.forget(55);check(guard.rates.is_empty() and guard.motion.is_empty(),"disconnect clears rate and movement records")
	NavalStorage.write_json("res://work/security182/transport-results.json",{"checks":checks,"failures":failures,"negative_certificate_errors_expected":true})
	print("SECURITY182 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
