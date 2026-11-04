extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func wait_for(test: Callable) -> bool:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<4000:
		if test.call():return true
		await process_frame
	return false
func run() -> void:
	var host:=Node.new();host.name="CacheHost";root.add_child(host)
	var guest:=Node.new();guest.name="CacheGuest";root.add_child(guest)
	var server_api:=SceneMultiplayer.new();var client_api:=SceneMultiplayer.new()
	set_multiplayer(server_api,host.get_path());set_multiplayer(client_api,guest.get_path())
	var server:=ENetMultiplayerPeer.new();check(server.create_server(0,2)==OK,"server starts")
	GameNetworkPeers.watch(server);GameNetworkPeers.watch(server)
	server_api.multiplayer_peer=server
	var port:=server.get_host().get_local_port()
	var stale_seen:=false
	for cycle in 8:
		var client:=ENetMultiplayerPeer.new();check(client.create_client("127.0.0.1",port,4)==OK,"client starts")
		GameNetworkPeers.watch(client);client_api.multiplayer_peer=client
		var id:=client.get_unique_id()
		check(await wait_for(func():return GameNetworkPeers.connected(server,id,4)!=null and GameNetworkPeers.connected(client,1,4)!=null),"cache populated by native connect signals")
		check(GameNetworkPeers.connected(server,id,256)==null,"insufficient channels rejected")
		check(GameNetworkPeers.connected(server,2147480000)==null,"unknown ID safe without native lookup")
		# ENet removes force-disconnected IDs without emitting SceneMultiplayer's
		# disconnected notification. The API still advertises the stale ID here.
		server.disconnect_peer(id,true)
		stale_seen=stale_seen or id in server_api.get_peers()
		for sample in 10:check(GameNetworkPeers.connected(server,id)==null,"removed native peer safe while scene list stale")
		check(not Dictionary(server.get_meta(GameNetworkPeers.CACHE)).has(id),"inactive cached reference released")
		client_api.multiplayer_peer=OfflineMultiplayerPeer.new();client.close()
		server_api.multiplayer_peer=OfflineMultiplayerPeer.new();server.close()
		if cycle<7:
			server=ENetMultiplayerPeer.new();check(server.create_server(0,2)==OK,"next server starts")
			GameNetworkPeers.watch(server);server_api.multiplayer_peer=server;port=server.get_host().get_local_port()
	check(stale_seen,"reproduced scene/native stale-ID disagreement")
	check(GameNetworkPeers.connected(server,1)==null,"closed transport safe")
	set_multiplayer(null,host.get_path());set_multiplayer(null,guest.get_path());host.free();guest.free()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"stale_id_reproduced":stale_seen,"scope":"Eight raw loopback ENet connect/force-disconnect cycles; reproduces stale SceneMultiplayer IDs and checks safe native peer cache, channel filtering, unknown/closed IDs and reference cleanup. DTLS tested by separate network suites."}
	NavalStorage.write_json("res://work/network-peer-cache1102.json",report);print("NETWORK_PEER_CACHE1102 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
