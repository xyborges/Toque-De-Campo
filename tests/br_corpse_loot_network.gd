extends SceneTree
const FIXTURE=preload("res://tests/br_corpse_loot_network_fixture.gd")
var role:="server"
var game: BattleRoyaleGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func wait_for(test: Callable,label: String,seconds:=15.) -> bool:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000:
		if test.call():return true
		await create_timer(.05).timeout
	failures.append("timeout "+label);return false
func check_clients(ids: Array,key: String,label: String,helmet: bool,vest: bool,pack: bool,settled:=false) -> void:
	for id in ids:game.rpc_id(id,"qa_corpse_check",label,key,helmet,vest,pack,settled)
	await wait_for(func():
		for id in ids:
			if not game.corpse_acks.has(str(id)+":"+label):return false
		return true,label)
	for id in ids:
		var result: Dictionary=game.corpse_acks.get(str(id)+":"+label,{"ok":false})
		check(bool(result.ok),"client "+label+" "+str(id)+" "+str(result.get("detail","")))
func request(id: int,label: String,action: String,data: Dictionary) -> void:
	game.rpc_id(id,"qa_corpse_operation",label,action,data)
	await wait_for(func():return game.corpse_acks.has(str(id)+":"+label),label)
	await create_timer(.2).timeout
func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game);await process_frame
	game.flat_world();game.online=true
	var peer:=ENetMultiplayerPeer.new();var error: Error
	if role=="server":error=peer.create_server(39588,4)
	else:error=peer.create_client("127.0.0.1",39588,4)
	if error==OK:error=GameSecureTransport.server(peer) if role=="server" else GameSecureTransport.client(peer,"localhost")
	if error!=OK:push_error("DTLS "+error_string(error));quit(1);return
	game.network_api.multiplayer_peer=peer
	if role!="server":await create_timer(90.).timeout;quit(1);return
	game.multiplayer.peer_disconnected.connect(game._peer_disconnected)
	if await wait_for(func():return game.multiplayer.get_peers().size()==2,"two DTLS clients",30.):await scenario()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Headless server and two ENet/DTLS clients, actual damage/death, looting persistent corpse gear with replacement part identities, stale revision, authoritative settle transforms, disconnected former owner, empty body and round cleanup. Flat physical fixture; account login/motion bypassed; no FPS claim."}
	NavalStorage.write_json("res://work/br-corpse-loot-network.json",report);print("BR_CORPSE_LOOT_NETWORK ",JSON.stringify(report))
	game._broadcast("qa_finish",[]);await create_timer(.2).timeout;peer.close();game.leave_match();await create_timer(.05).timeout;game.free();await physics_frame;await physics_frame;await process_frame;quit(0 if failures.is_empty() else 1)
func scenario() -> void:
	var ids:=Array(game.multiplayer.get_peers());ids.sort();var victim_id:=int(ids[0]);var looter_id:=int(ids[1])
	for id in ids+[100000]:
		var at:=Vector3(1.0 if id==looter_id else 0.,0,0.)
		if id==100000:at=Vector3(12,0,12)
		var actor:=game._spawn_player(id,false,false,at) as BRPlayer
		actor.set_physics_process(false);actor.set_process(false);actor.life_id=9;actor.hp=100.;actor.br_bot=id==100000;actor.set_meta("br_generation",4)
		game.br_inventory.add_player(id);game._broadcast("qa_corpse_actor",[id,at,id==100000])
	game.br_generation=4;game.phase="active";game.br_round.begin(ids+[100000],game._now())
	for kind in ["vest","helmet","pack"]:
		var item:={"kind":kind,"level":3 if kind=="pack" else 2,"position":Vector3.ZERO}
		check(game.br_inventory.pickup(victim_id,game.br_inventory.add_loot(item),Vector3.ZERO).ok,"victim obtains "+kind)
	game.br_inventory.pickup(looter_id,game.br_inventory.add_loot({"kind":"vest","level":1,"position":Vector3.ZERO}),Vector3.ZERO)
	for id in ids:game._apply_backpack(game.players[id])
	await physics_frame;await physics_frame;await create_timer(.4).timeout
	var victim: GamePlayer=game.players[victim_id]
	game._apply_hit(looter_id,{"collider":victim.hit_regions.legL,"position":victim.global_position},1000.,"legL","fal",Vector3.RIGHT)
	var key:=game._corpse_key(victim)
	check(victim.hp==0. and game.phase=="active" and game.corpses.has(key),"actual death creates persistent corpse without ending round")
	var record: Dictionary=game.corpses.get(key,{})
	if record.is_empty():return
	var loot_id:=int(record.loot_id);var original: Dictionary=game._corpse_packet(record)
	check(game.br_inventory.world_loot[loot_id].get("corpse_key","")==key,"body container is linked to corpse identity")
	await check_clients(ids,key,"death",true,true,true)
	# Too far is rejected without changing original gear visibility.
	var looter: GamePlayer=game.players[looter_id];looter.global_position=Vector3(20,0,0)
	check(not game._br_action(looter_id,"pickup",{"id":loot_id,"part":record.gear.helmet},looter.life_id,4),"distant corpse interaction rejected")
	looter.global_position=Vector3(1,0,0)
	await request(looter_id,"helmet","pickup",{"id":loot_id,"part":record.gear.helmet})
	check(game.br_inventory.snapshot(looter_id).protection.helmet.level==2,"looter receives actual helmet")
	await check_clients(ids,key,"helmet_removed",false,true,true)
	var original_vest:=int(record.gear.vest)
	await request(looter_id,"vest","pickup",{"id":loot_id,"part":original_vest})
	var new_vest:=-1
	for part: Dictionary in game.br_inventory.world_loot[loot_id].contents:
		if part.kind=="vest" and int(part.level)==1:new_vest=int(part.part_id)
	check(new_vest>0 and new_vest!=original_vest and game.br_inventory.snapshot(looter_id).protection.vest.level==2,"vest upgrade leaves replaced lower tier with new identity")
	await check_clients(ids,key,"vest_removed",false,false,true)
	await request(looter_id,"pack","pickup",{"id":loot_id,"part":record.gear.pack})
	check(game.br_inventory.snapshot(looter_id).backpack==3,"looter receives backpack")
	await check_clients(ids,key,"pack_removed",false,false,false)
	# Replay an authority packet from before looting: monotonic revision wins.
	for id in ids:game.rpc_id(id,"br_corpse_state",original)
	await check_clients(ids,key,"stale_ignored",false,false,false)
	game.clock_offset+=6.5;game._settle_corpses()
	check(record.settled and not record.transforms.is_empty() and game.br_inventory.world_loot[loot_id].position==record.position,"server settles body and moves container to authoritative corpse location")
	await check_clients(ids,key,"settled",false,false,false,true)
	game.rpc_id(victim_id,"qa_corpse_disconnect")
	await wait_for(func():return not game.players.has(victim_id),"former owner disconnect")
	check(game.corpses.has(key) and is_instance_valid(game.corpse_roots.get(key)),"corpse persists after former owner's disconnect")
	await check_clients([looter_id],key,"after_disconnect",false,false,false,true)
	# Give the remaining lower-tier vest back by removing looter's worn one,
	# then collect the final corpse item and verify the visible body remains.
	await request(looter_id,"drop_vest","drop_protection",{"kind":"vest"})
	looter.global_position=record.position+Vector3(1,0,0)
	await request(looter_id,"empty_container","pickup",{"id":loot_id,"part":new_vest})
	check(not game.br_inventory.world_loot.has(loot_id) and game.corpses.has(key),"empty corpse container disappears while body persists")
	await check_clients([looter_id],key,"empty_body",false,false,false,true)
	# A fatal chest hit exhausts vest durability before the living mesh refresh.
	# The server record and remote corpse must reflect only surviving loot.
	var bot:=game.players[100000] as BRPlayer
	for kind in ["vest","helmet","pack"]:
		var gear:={"kind":kind,"level":3 if kind=="pack" else 2,"position":bot.global_position}
		game.br_inventory.pickup(100000,game.br_inventory.add_loot(gear),bot.global_position)
	game._apply_backpack(bot);await create_timer(.2).timeout
	game._apply_hit(looter_id,{"collider":bot.hit_regions.chest,"position":bot.global_position},1000.,"chest","fal",Vector3.RIGHT)
	var broken_key:=game._corpse_key(bot);var broken_record: Dictionary=game.corpses.get(broken_key,{})
	check(bot.hp==0. and not broken_record.is_empty() and int(broken_record.get("levels",{}).get("vest",-1))==0 and not broken_record.get("gear",{}).has("vest"),"fatal chest hit omits destroyed armor from corpse loot and baseline")
	if not broken_record.is_empty():await check_clients([looter_id],broken_key,"fatal_broken_vest",true,false,true)
	game.rpc_id(looter_id,"qa_corpse_cleanup","cleared")
	await wait_for(func():return game.corpse_acks.has(str(looter_id)+":cleared"),"client corpse cleanup")
	check(bool(game.corpse_acks.get(str(looter_id)+":cleared",{}).get("ok",false)),"client round cleanup removes corpse and metadata")
	game._clear_br_round();await process_frame
	check(game.corpses.is_empty() and game.corpse_roots.is_empty() and get_nodes_in_group("death_ragdolls").is_empty(),"server round cleanup removes all persistent bodies")
