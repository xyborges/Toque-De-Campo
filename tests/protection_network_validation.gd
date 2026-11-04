extends SceneTree
var checks:=0
var errors: Array[String]=[]
var branches: Array[Node]=[]
var games: Array[Node]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func wait_for(test: Callable,seconds:=10.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		if test.call():return true
		await process_frame
	return false
func endpoint(label: String,peer: ENetMultiplayerPeer) -> Node:
	GameNetworkPeers.watch(peer)
	var branch:=Node.new();branch.name=label;root.add_child(branch);branches.append(branch)
	var api:=SceneMultiplayer.new();set_multiplayer(api,branch.get_path());api.multiplayer_peer=peer
	var game: Node=load("res://tests/protection_network_fixture.gd").new();game.name="Game";branch.add_child(game);games.append(game);return game
func run() -> void:
	var server:=ENetMultiplayerPeer.new();var port:=38881;var error:=server.create_server(port,2)
	check(error==OK,"local authority listens")
	if error!=OK:quit(1);return
	var authority:=endpoint("Authority",server)
	for index in 2:
		var peer:=ENetMultiplayerPeer.new();check(peer.create_client("127.0.0.1",port)==OK,"observer connects");endpoint("Observer"+str(index),peer)
	check(await wait_for(func():return authority.multiplayer.get_peers().size()==2),"two ENet observers ready")
	var actor: GamePlayer=authority.players[7];actor.infantry_protection.deploy(actor);authority._protection_changed(actor)
	check(await wait_for(func():return games[1].players[7].infantry_protection.enabled and games[2].players[7].infantry_protection.enabled),"production RPC delivers baseline to both observers")
	var intact:=actor.infantry_protection.snapshot()
	actor.take_damage(100.,"chest");actor.take_damage(100.,"chest")
	check(await wait_for(func():return games[1].players[7].infantry_protection.gear.vest.level==0 and games[2].players[7].infantry_protection.gear.vest.level==0),"both clients receive armor break")
	for index in [1,2]:
		var remote: GamePlayer=games[index].players[7]
		for mesh in remote.body_root.find_children("*","MeshInstance3D",true,false):
			if str(mesh.get_meta("protection_slot",""))=="vest":check(not mesh.visible,"observer hides broken vest")
	# Send an old but otherwise valid authority packet over the actual RPC.
	authority._broadcast("remote_protection_state",[7,42,intact,""])
	await create_timer(.15).timeout
	for index in [1,2]:check(games[index].players[7].infantry_protection.gear.vest.level==0,"old snapshot cannot re-equip broken vest")
	for game in games:
		var target: GamePlayer=game.players[7];target.life_id=43
	actor.infantry_protection.deploy(actor);authority._protection_changed(actor)
	check(await wait_for(func():return games[1].players[7].infantry_protection.life==43 and games[2].players[7].infantry_protection.life==43),"new-life protection reaches both clients")
	authority._broadcast("remote_protection_state",[7,42,intact,"vest"]);await create_timer(.15).timeout
	for index in [1,2]:check(games[index].players[7].infantry_protection.gear.vest.durability==60.,"previous-life packet cannot damage or stack respawn armor")
	print("PROTECTION_NETWORK_VALIDATION ",JSON.stringify({"checks":checks,"errors":errors,"ok":errors.is_empty(),"scope":"production protection RPC through ENet authority and two independent SceneMultiplayer clients; controlled life transition; no performance claim"}))
	for branch in branches:branch.multiplayer.multiplayer_peer.close();branch.queue_free()
	await process_frame;quit(0 if errors.is_empty() else 1)
