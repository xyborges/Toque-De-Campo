extends SceneTree
const FIXTURE=preload("res://tests/br_loot_network_fixture.gd")
var role:="client"
var game: BattleRoyaleGame
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func wait_for(test: Callable,label: String,seconds:=20.) -> bool:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000:
		if test.call(): return true
		await create_timer(.05).timeout
	failures.append("timeout "+label);return false
func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame
	game._enter_match_world();game.online=true;game.mode="pvp"
	if role=="late":
		if not await wait_for(func():return FileAccess.file_exists("res://work/br-loot-late-ready.json"),"late join gate",70.):quit(1);return
	var peer:=ENetMultiplayerPeer.new();var error: Error
	if role=="server":
		error=peer.create_server(39586,4)
		if error==OK: error=GameSecureTransport.server(peer)
	else:
		error=peer.create_client("127.0.0.1",39586)
		if error==OK: error=GameSecureTransport.client(peer,"localhost")
	if error!=OK:push_error("DTLS "+error_string(error));quit(1);return
	game.network_api.multiplayer_peer=peer
	if role!="server":
		await create_timer(100.).timeout;quit(1);return
	if await wait_for(func():return game.multiplayer.get_peers().size()==2,"two DTLS clients",50.): await scenario()
	NavalStorage.write_json("res://work/br-loot-network.json",{"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Headless server + three real clients over ENet/DTLS: indoor loot race, range/ray/life/round validation, private inventory, backpack/armor/optic replication, attached-optic weapon drop/transfer, forced QA observer baseline, winner and next-round unarmed spawn with server bots on full Afghan colliders/native navigation. QA bypasses account login, admission and movement; intermission/queue deadlines advanced after separate exact-timing validation. Production late admission is rejected and covered by br_queue_network."})
	print("BR_LOOT_NETWORK ",checks," ",failures)
	game._broadcast("qa_finish",[]);await create_timer(.4).timeout;peer.close();game.free();quit(0 if failures.is_empty() else 1)
func scenario() -> void:
	var ids:=game.multiplayer.get_peers()
	var map_script=preload("res://modes/battle_royale/map/afghan_map.gd")
	var house: Dictionary=map_script.building_layout()[0]
	var prefab: Node3D=load(map_script.LIB+map_script.BUILDINGS[int(house.variant)]+".tscn").instantiate()
	var transform:=Transform3D(Basis(Vector3.UP,house.yaw).scaled(house.scale),house.position)
	var local: Vector3=prefab.get_node("LootInterior").position
	var p: Vector3=transform*local
	var standing: Vector3=transform*(local+Vector3(.75,-.029,0.));prefab.free()
	for id in ids:
		var actor:=game._spawn_player(id,false,false,standing)
		actor.hp=100;actor.life_id=7;actor.set_process(false);actor.set_physics_process(false)
		game.br_inventory.add_player(id)
		game._broadcast("qa_actor",[id,standing])
	game.br_generation=3;game.phase="active";game.br_round.begin(Array(ids),game._now())
	await physics_frame;await physics_frame;await create_timer(.5).timeout
	var item:=game.br_inventory.add_loot({"kind":"weapon","weapon":"fal","magazine":9,"position":p})
	game._send_br_states()
	# Both clients race the same indoor item, using the normal pickup RPC.
	for id in ids: game.rpc_id(id,"qa_try","race",item,standing,100.)
	await wait_for(func():return game.acknowledgements.size()==2,"race acknowledgements")
	check(not game.br_inventory.world_loot.has(item),"indoor loot consumed")
	var owners:=0;var winner:=0
	for id in ids:
		if "fal" in game.br_inventory.snapshot(id).weapons:owners+=1;winner=id
	check(owners==1,"exactly one owner, no duplicate")
	if winner>0:check(game.players[winner].ammo.get("fal",0)==9,"magazine preserved on server actor")
	game._send_br_states()
	for id in ids: game.rpc_id(id,"qa_check","replica",item,id==winner,"fal")
	await wait_for(func():return game.acknowledgements.size()==4,"inventory and disappearance on both clients")
	for key in game.acknowledgements:check(not "FAIL:" in key,"client "+key)
	var id: int=ids[0];var actor: GamePlayer=game.players[id]
	for label in ["far","dead","old_life","old_round","wall"]:
		var test_item:=game.br_inventory.add_loot({"kind":"ammo","calibre":"9mm","amount":12,"position":p})
		actor.hp=0 if label=="dead" else 100
		actor.position=standing+Vector3(10,0,0) if label=="far" else standing
		var wall: StaticBody3D
		if label=="wall":
			wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0;game.world_root.add_child(wall)
			wall.position=(actor.camera_pivot.global_position+p+Vector3.UP*.15)*.5
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.35,1.,.35);shape.shape=box;wall.add_child(shape)
			await physics_frame;await physics_frame
		game.rpc_id(id,"qa_try",label,test_item,actor.position,actor.hp,6 if label=="old_life" else 7,2 if label=="old_round" else 3)
		await wait_for(func():return game.acknowledgements.has(str(id)+":"+label),label)
		check(game.br_inventory.world_loot.has(test_item),"reject "+label)
		if wall:wall.free()
		await create_timer(.3).timeout
	actor.hp=100.;actor.position=standing
	for peer_id in ids:game.players[peer_id].set_meta("br_generation",3)
	var owner: GamePlayer=game.players[winner]
	for kind in ["pack","vest","helmet"]:
		var equipment:=game.br_inventory.add_loot({"kind":kind,"level":3 if kind=="pack" else 2,"position":p})
		var label: String="equip_"+kind
		game.rpc_id(winner,"qa_operation",label,"pickup",{"id":equipment})
		await wait_for(func():return game.acknowledgements.has(str(winner)+":"+label),label)
		check(not game.br_inventory.world_loot.has(equipment),"equipment collected "+kind)
	check(game.br_inventory.snapshot(winner).capacity==180.,"server backpack capacity follows tier")
	for peer_id in ids:game.rpc_id(peer_id,"qa_check_gear","gear",winner,2,2,3)
	await wait_for(func():return game.acknowledgements.has(str(ids[0])+":gear") and game.acknowledgements.has(str(ids[1])+":gear"),"public gear on two clients")
	var scope_item:=game.br_inventory.add_loot({"kind":"optic","optic":"pso4x","amount":1,"position":p})
	game.rpc_id(winner,"qa_operation","take_optic","pickup",{"id":scope_item})
	await wait_for(func():return game.acknowledgements.has(str(winner)+":take_optic"),"optic pickup")
	await create_timer(.2).timeout
	game.rpc_id(winner,"qa_operation","attach_optic","optic",{"weapon":"fal","optic":"pso4x"})
	await wait_for(func():return game.acknowledgements.has(str(winner)+":attach_optic"),"optic attachment")
	check(game.players[winner].get_meta("weapon_optics",{}).get("fal","")=="pso4x" and game.br_inventory.snapshot(winner).optics.is_empty(),"optic equipped on authority without duplicated bag item")
	for peer_id in ids:game.rpc_id(peer_id,"qa_check_optic","attached",winner,"fal","pso4x")
	await wait_for(func():return game.acknowledgements.has(str(ids[0])+":attached") and game.acknowledgements.has(str(ids[1])+":attached"),"public optic on two clients")
	game.rpc_id(winner,"qa_operation","drop_fal","drop",{"weapon":"fal"})
	await wait_for(func():return game.acknowledgements.has(str(winner)+":drop_fal"),"drop weapon")
	check("fal" not in game.br_inventory.snapshot(winner).weapons,"drop revokes server ownership")
	var discarded: Dictionary={}
	for loot in game.br_inventory.nearby(owner.global_position):
		if loot.kind=="weapon" and loot.weapon=="fal":discarded=loot
	check(not discarded.is_empty() and int(discarded.get("magazine",0))==9 and str(discarded.get("optic",""))=="pso4x","dropped magazine and attached optic preserved over network")
	var recipient: int=ids[0] if ids[1]==winner else ids[1]
	if not discarded.is_empty():
		game.rpc_id(recipient,"qa_operation","take_fal","pickup",{"id":discarded.id})
		await wait_for(func():return game.acknowledgements.has(str(recipient)+":take_fal"),"other survivor takes dropped weapon")
		check("fal" in game.br_inventory.snapshot(recipient).weapons,"dropped weapon transfers to other client")
		for peer_id in ids:game.rpc_id(peer_id,"qa_check_optic","transferred",recipient,"fal","pso4x")
		await wait_for(func():return game.acknowledgements.has(str(ids[0])+":transferred") and game.acknowledgements.has(str(ids[1])+":transferred"),"attached optic transfers to other client")
	NavalStorage.write_json("res://work/br-loot-late-ready.json",{"ready":true})
	if await wait_for(func():return game.multiplayer.get_peers().size()==3,"third late client",35.):
		var late:=0
		for peer_id in game.multiplayer.get_peers():
			if peer_id not in ids:late=int(peer_id)
		var spectator:=game._spawn_player(late,false,false,standing);spectator.life_id=7;spectator.set_physics_process(false);spectator.set_process(false)
		game.br_inventory.add_player(late);game._stage_infantry(spectator)
		game._broadcast("qa_actor",[late,standing])
		for peer_id in ids:game.rpc_id(late,"qa_actor",peer_id,game.players[peer_id].global_position)
		game.rpc_id(late,"remote_infantry_staging",late,7,0.)
		game._send_br_baseline(late);game._push_inventory(spectator);game._send_br_states()
		game.rpc_id(late,"qa_check_gear","late_gear",winner,2,2,3)
		await wait_for(func():return game.acknowledgements.has(str(late)+":late_gear"),"late client restores visible equipment")
		game.rpc_id(late,"qa_check_optic","late_optic",recipient,"fal","pso4x")
		await wait_for(func():return game.acknowledgements.has(str(late)+":late_optic"),"late client restores attached optic")
		check(not game.br_round.is_alive(late) and spectator.hp==0,"forced QA observer remains staged; not a production late admission")
		var victim:=game.players[ids[0]] as GamePlayer
		game._apply_hit(ids[1],{"collider":victim.hit_regions.chest,"position":victim.global_position},1000.,"chest","fal",Vector3.RIGHT)
		check(game.phase=="finished" and game.br_round.winner==ids[1],"authoritative elimination finalizes winner")
		for peer_id in game.multiplayer.get_peers():game.rpc_id(peer_id,"qa_check_round","finished","finished",3,1,false)
		await wait_for(func():
			for peer_id in game.multiplayer.get_peers():
				if not game.acknowledgements.has(str(peer_id)+":finished"):return false
			return true,"finished result reaches all clients")
		# The separate deterministic clock suite checks the full 60 seconds.
		# Here advance only the deadline, retaining the actual network reset path.
		game.restart_at=game._now();game._step_br_authority(.01)
		check(game.phase=="waiting" and game.players.size()==12 and game.round_start_clock>game._now(),"results transition to new thirty-second queue with server bots")
		game.round_start_clock=game._now();game._step_br_authority(.01)
		check(game.phase=="active" and game.br_generation==4 and game.br_round.alive_ids().size()==12,"next round includes staged QA cohort and server bots")
		for peer_id in game.multiplayer.get_peers():game.rpc_id(peer_id,"qa_check_round","restarted","active",4,12,true)
		await wait_for(func():
			for peer_id in game.multiplayer.get_peers():
				if not game.acknowledgements.has(str(peer_id)+":restarted"):return false
			return true,"fresh unarmed round reaches all clients")
	for key in game.acknowledgements:check(not "FAIL:" in key,"replication "+key)
