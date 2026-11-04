extends SceneTree
const FIXTURE=preload("res://tests/br_queue_network_fixture.gd")
var checks:=0
var failures: Array[String]=[]
var server: BattleRoyaleGame
var clients: Array[BattleRoyaleGame]=[]
var branches: Array[Node]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func wait_for(test: Callable,label: String,seconds:=15.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.02).timeout
	check(false,"timeout "+label);return false
func game_node(label: String) -> BattleRoyaleGame:
	var branch:=Node.new();branch.name=label;root.add_child(branch);branches.append(branch)
	var game:=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);branch.add_child(game)
	game.flat_world();game.phase="waiting";game.online=true;game.mode="pvp";game.dedicated_pvp=false
	return game
func begin_client(label: String) -> BattleRoyaleGame:
	var game:=game_node(label);clients.append(game)
	var peer:=ENetMultiplayerPeer.new();var error:=peer.create_client("127.0.0.1",39591,4)
	if error==OK:error=GameSecureTransport.client(peer,"localhost")
	check(error==OK,"DTLS client connects "+label)
	game.network_api.connected_to_server.connect(func():
		var id:=game.multiplayer.get_unique_id()
		game._stage_infantry(game._spawn_player(id,true,false,Vector3.ZERO))
		game.rpc_id(1,"server_join_request",label,game._appearance_payload())
	)
	game.network_api.multiplayer_peer=peer
	return game
func verify_clients(label: String,phase: String,humans: int,bots: int,remaining: float) -> void:
	server._send_br_states()
	for game in clients:
		var id:=game.multiplayer.get_unique_id()
		if server.players.has(id):server.rpc_id(id,"qa_queue_check",label,phase,humans,bots,remaining)
	await wait_for(func():
		for id in server._human_ids():
			if not server.acknowledgements.has(str(id)+":"+label):return false
		return true,label+" client snapshots")
	for key in server.acknowledgements:
		if str(key).ends_with(label):check(not str(key).contains("FAIL:"),"replicated queue "+str(key))
func detach(game: BattleRoyaleGame) -> void:
	var peer:=game.network_api.multiplayer_peer
	game.network_api.multiplayer_peer=OfflineMultiplayerPeer.new()
	GameNetworkShutdown.retire(game,peer)
func run() -> void:
	server=game_node("Server")
	var peer:=ENetMultiplayerPeer.new();var error:=peer.create_server(39591,12)
	if error==OK:error=GameSecureTransport.server(peer)
	check(error==OK,"DTLS server binds")
	server.network_api.peer_disconnected.connect(server._peer_disconnected)
	server.network_api.multiplayer_peer=peer
	var alpha:=begin_client("Alpha")
	if await wait_for(func():return server._human_ids().size()==1,"first real join RPC"):
		check(server.phase=="waiting" and server.players.size()==29,"first human gets 28 server bots")
		check(server._human_ids().size()==1 and server._queue_roster(0).filter(func(item):return item.bot).size()==28,"first human plus 28 server bots")
		check(is_equal_approx(server.round_start_clock,130.),"first real join starts exact thirty-second deadline")
		await verify_clients("first","waiting",1,28,30.)
	server.test_clock=110.
	var bravo:=begin_client("Bravo")
	if await wait_for(func():return server._human_ids().size()==2,"second real join RPC"):
		check(server.players.size()==30 and server._queue_roster(0).filter(func(item):return item.bot).size()==28,"second human retains 28 bots")
		check(is_equal_approx(server.round_start_clock,130.),"second join does not extend queue deadline")
		await verify_clients("second","waiting",2,28,20.)
	server.test_clock=120.
	var charlie:=begin_client("Charlie");charlie.hold_ready=true
	await wait_for(func():return server._human_ids().size()==3,"third real join before cutoff")
	await wait_for(func():return not charlie.ready_request.is_empty(),"third client receives baseline before ready gate")
	check(server.players.size()==31 and not server.sync_ready.get(charlie.multiplayer.get_unique_id(),false),"third human present and visibly synchronizing")
	server.test_clock=129.99;server._step_br_authority(.001)
	check(server.phase=="waiting","round does not start before cutoff")
	server.test_clock=130.;server._step_br_authority(.001)
	check(server.phase=="waiting","readiness barrier prevents start with unfinished third client")
	check(server._state_for(1).roster.any(func(row):return row.name=="Charlie" and row.status=="Sincronizando"),"roster exposes synchronization status")
	charlie.release_ready()
	await wait_for(func():return bool(server.sync_ready.get(charlie.multiplayer.get_unique_id(),false)),"third authenticated ready acknowledgement")
	server._step_br_authority(.001)
	check(server.phase=="active" and server.br_round.participants.size()==31,"ready cohort starts with 3 humans plus 28 bots")
	await verify_clients("active","active",3,28,0.)
	var healed_id:=alpha.multiplayer.get_unique_id()
	server.players[healed_id].hp=40.;server.br_inventory.members[healed_id].medkits=1;server._push_inventory(server.players[healed_id])
	server.rpc_id(healed_id,"qa_heal_closed","heal_closed")
	await wait_for(func():return server.heal_pending.has(healed_id),"real client medkit request")
	check(server.heal_pending.has(healed_id),"medkit stays scheduled after client closes backpack")
	var healed: GamePlayer=server.players[healed_id]
	server._server_accept_shot(healed_id,1,healed.life_id-1,healed.camera_pivot.global_position,Vector3.FORWARD,"fists",0)
	check(server.heal_pending.has(healed_id),"rejected stale shot cannot cancel a medkit")
	server.test_clock=134.1;server._step_br_authority(.001);server._send_br_states()
	await create_timer(.3).timeout
	server.rpc_id(healed_id,"qa_heal_check","heal_complete")
	await wait_for(func():return server.acknowledgements.has(str(healed_id)+":heal_complete") or server.acknowledgements.has(str(healed_id)+":FAIL:heal_complete"),"client gradual healing with backpack closed")
	check(server.acknowledgements.has(str(healed_id)+":heal_complete"),"gradual health and closed backpack replicated to actual client")
	var original_ids:=server.players.keys().duplicate();var before_inventory:=server.br_inventory.members.size()
	var late:=begin_client("Late")
	if await wait_for(func():return late.queue_closed_received,"late RPC rejection"):
		var late_id:=late.multiplayer.get_unique_id()
		check(not server.players.has(late_id) and not server.br_inventory.members.has(late_id),"late client never receives server actor or inventory")
		check(server.players.keys()==original_ids and server.br_inventory.members.size()==before_inventory,"late attempt leaves current match unchanged")
		check(server.phase=="active" and server._human_ids().size()==3,"existing players continue active match")
	await create_timer(.7).timeout
	for game in [alpha,bravo,charlie]:
		var id: int=game.multiplayer.get_unique_id();var label:="leave"+str(id)
		server.rpc_id(id,"qa_prepare_leave",label)
		await wait_for(func():return server.acknowledgements.has(str(id)+":"+label),"client ready to detach")
		detach(game)
		await wait_for(func():return not server.players.has(id),"actual disconnect handled")
		await create_timer(2.2).timeout
	await wait_for(func():return server._human_ids().is_empty(),"last humans disconnected")
	check(server.phase=="cancelled" and server.players.is_empty(),"last human disconnect cancels room and removes bots")
	check(server.round_start_clock<0. and server.restart_at<0.,"cancelled room has no autonomous countdown/restart")
	for game in clients:
		if game.network_api.multiplayer_peer is ENetMultiplayerPeer:detach(game)
	await create_timer(2.2).timeout
	peer.close();server.network_api.multiplayer_peer=OfflineMultiplayerPeer.new()
	for branch in branches:branch.queue_free()
	await process_frame;await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"teardown_notes":"The validated run emitted native mbedTLS -30464/-0x7700 messages while closing DTLS after reliable leave acknowledgements and 2.2-second graceful retirement. No script/RPC errors; not a clean-native-log claim.","scope":"One real ENet/DTLS server plus three independent client SceneMultiplayer branches; production join RPC, 30-second queue clock, bot replacement, roster replication, active late-join rejection before actor/inventory, continued match and last-human cancellation. Flat collision fixture and deterministic clock; account auth intentionally bypassed here and covered separately by broker proof test."}
	var file:=FileAccess.open("res://work/br-queue-network.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_QUEUE_NETWORK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
