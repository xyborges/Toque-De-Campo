extends SceneTree
const FIXTURE=preload("res://tests/br_modular_network_fixture.gd")
var role:="client"
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
func wait_for(test: Callable,label: String,seconds:=20.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.02).timeout
	check(false,"timeout "+label);return false
func command(id: int,label: String,action: String,data: Dictionary,life:=7,generation:=3) -> void:
	game.rpc_id(id,"qa_modular_command",label,action,data,life,generation)
	await wait_for(func():return game.acknowledgements.has(str(id)+":"+label),label)
	await create_timer(.18).timeout
func uid(id: int,attachment: String) -> int:
	for item: Dictionary in game.br_inventory.snapshot(id).get("accessory_items",[]):
		if str(item.id)==attachment:return int(item.uid)
	return -1
func config(id: int) -> Dictionary:return game.br_inventory.snapshot(id).get("weapon_attachments",{}).duplicate(true)
func installed(id: int,weapon: String) -> String:return str(config(id).get(weapon,{}).get("optic_top",{}).get("id",""))
func grant(id: int,item: Dictionary,label: String) -> void:
	var record:=item.duplicate(true);record.position=game.players[id].global_position+Vector3(.4,.02,0)
	var loot:=game.br_inventory.add_loot(record);check(loot>0,"valid loot "+label)
	await command(id,label,"pickup",{"id":loot})
	check(not game.br_inventory.world_loot.has(loot),"real pickup RPC "+label)
func verify(label: String,owner: int,bag_count: int=-1) -> void:
	var expected:=config(owner)
	game._send_br_states()
	for id in game.multiplayer.get_peers():game.rpc_id(id,"qa_modular_check",label,owner,expected,bag_count)
	await wait_for(func():
		for id in game.multiplayer.get_peers():
			if not game.acknowledgements.has(str(id)+":"+label):return false
		return true,label+" public/private snapshots")
	for key in game.acknowledgements:
		if str(key).ends_with(label):check(not str(key).contains("FAIL:"),"replication "+str(key))
func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game);await process_frame
	game.flat_world();game.online=true;game.mode="pvp";game.phase="active"
	var peer:=ENetMultiplayerPeer.new();var error: Error
	if role=="server":error=peer.create_server(39592,2)
	else:error=peer.create_client("127.0.0.1",39592,4)
	if error==OK:error=GameSecureTransport.server(peer) if role=="server" else GameSecureTransport.client(peer,"localhost")
	if error!=OK:push_error("DTLS "+error_string(error));quit(1);return
	game.network_api.multiplayer_peer=peer
	if role!="server":await create_timer(120.).timeout;quit(1);return
	if await wait_for(func():return game.multiplayer.get_peers().size()==2,"two DTLS clients",30.):await scenario()
	for key in game.acknowledgements:check(not "FAIL:" in str(key),"all client acknowledgements "+str(key))
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"teardown_notes":"Validated run passed all gameplay assertions without script/RPC errors. Two native mbedTLS -30464 messages appeared while closing acknowledged DTLS clients; this is not a clean-native-log claim.","scope":"Headless server and two real ENet/DTLS clients; generic attachment install/swap/remove/drop APIs, actor/life/round/reload validation, bag-instance privacy, remote rebuild baseline, attached-weapon transfer and corpse pickup. Flat collision fixture; account auth/matchmaking covered separately, no production late admission."}
	var file:=FileAccess.open("res://work/br-modular-network.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_MODULAR_NETWORK ",JSON.stringify(report))
	game._broadcast("qa_modular_finish",[])
	await wait_for(func():return game.acknowledgements.has(str(game.multiplayer.get_peers()[0])+":finishing") and game.acknowledgements.has(str(game.multiplayer.get_peers()[1])+":finishing"),"finish acknowledgements")
	await create_timer(6.).timeout;game.online=false;game.voice.shutdown();peer.close();game.free();quit(0 if failures.is_empty() else 1)
func scenario() -> void:
	var ids:=game.multiplayer.get_peers();var owner: int=ids[0];var other: int=ids[1]
	for index in 2:
		var id: int=ids[index];var point:=Vector3(index*1.5,0,0)
		var actor:=game._spawn_player(id,false,false,point);actor.hp=100.;actor.life_id=7;actor.set_physics_process(false);actor.set_process(false);actor.set_meta("br_generation",3)
		game.br_inventory.add_player(id);game._broadcast("qa_actor",[id,point])
	var dummy:=game._spawn_player(100000,false,false,Vector3(20,0,20)) as BRPlayer
	dummy.br_bot=true;dummy.life_id=7;dummy.hp=100.;dummy.set_physics_process(false);dummy.set_process(false);game.br_inventory.add_player(100000);game._broadcast("qa_actor",[100000,dummy.global_position])
	game.br_generation=3;game.br_round.begin([owner,other,100000],game._now());await physics_frame;await physics_frame;await create_timer(.3).timeout
	await grant(owner,{"kind":"weapon","weapon":"fal","magazine":9},"fal")
	await grant(owner,{"kind":"weapon","weapon":"ak","magazine":12},"ak")
	await grant(other,{"kind":"weapon","weapon":"glock","magazine":7},"glock")
	await grant(owner,{"kind":"attachment","attachment":"prism4x","amount":1},"prism")
	await grant(owner,{"kind":"attachment","attachment":"pso4x","amount":1},"pso")
	await command(owner,"install_fal","attachment",{"weapon":"fal","socket":"optic_top","attachment":"prism4x","uid":uid(owner,"prism4x")})
	check(installed(owner,"fal")=="prism4x","canonical FAL installation accepted")
	await verify("fal_public",owner,1)
	await command(owner,"install_ak","attachment",{"weapon":"ak","socket":"optic_top","attachment":"pso4x","uid":uid(owner,"pso4x")})
	check(installed(owner,"ak")=="pso4x","canonical AK installation accepted")
	await verify("both_public",owner,0)
	await grant(owner,{"kind":"attachment","attachment":"prism4x","amount":1},"spare")
	var actor: GamePlayer=game.players[owner]
	for label in ["foreign","wrong_socket","forged_uid","old_life","old_round","dead","reload"]:
		var before:=JSON.stringify(game.br_inventory.snapshot(owner));var before_public: Dictionary=actor.get_meta("weapon_attachments",{}).duplicate(true)
		var data:={"weapon":"sniper" if label=="foreign" else "fal","socket":"magazine" if label=="wrong_socket" else "optic_top","attachment":"prism4x","uid":999999 if label=="forged_uid" else uid(owner,"prism4x"),"position":0.}
		if label=="dead":actor.hp=0.
		if label=="reload":actor.reload_left=2.;actor.reload_weapon="fal"
		await command(owner,label,"raw_attachment",data,6 if label=="old_life" else 7,2 if label=="old_round" else 3)
		check(JSON.stringify(game.br_inventory.snapshot(owner))==before and actor.get_meta("weapon_attachments",{})==before_public,"reject "+label+" atomically")
		actor.hp=100.;actor.cancel_reload()
	await command(owner,"remove_ak","attachment",{"weapon":"ak","socket":"optic_top","attachment":""})
	check(installed(owner,"ak")=="" and uid(owner,"pso4x")>0,"removal returns actual bag instance")
	await command(owner,"swap_fal","attachment",{"weapon":"fal","socket":"optic_top","attachment":"pso4x","uid":uid(owner,"pso4x")})
	check(installed(owner,"fal")=="pso4x" and game.br_inventory.snapshot(owner).accessories.get("prism4x",0)==2,"swap returns previous module without duplication")
	await verify("swapped",owner,2)
	await command(owner,"remove_fal","attachment",{"weapon":"fal","socket":"optic_top","attachment":""})
	check(installed(owner,"fal")=="" and uid(owner,"pso4x")>0,"second removal returns previous optic")
	await command(owner,"drop_accessory","drop_attachment",{"attachment":"prism4x","uid":uid(owner,"prism4x")})
	var loose: Dictionary={}
	for item: Dictionary in game.br_inventory.nearby(actor.global_position):
		if item.kind=="attachment" and item.get("attachment","")=="prism4x":loose=item;break
	check(not loose.is_empty(),"specific bag instance drops to world")
	if not loose.is_empty():await command(other,"take_accessory","pickup",{"id":loose.id})
	var other_before:=JSON.stringify(game.br_inventory.snapshot(other))
	await command(other,"incompatible","attachment",{"weapon":"glock","socket":"optic_top","attachment":"prism4x","uid":uid(other,"prism4x")})
	check(JSON.stringify(game.br_inventory.snapshot(other))==other_before,"incompatible owned Glock rejects optic without consuming item")
	await command(owner,"reinstall_fal","attachment",{"weapon":"fal","socket":"optic_top","attachment":"pso4x","uid":uid(owner,"pso4x")})
	await command(owner,"drop_weapon","drop",{"weapon":"fal"})
	var dropped: Dictionary={}
	for item: Dictionary in game.br_inventory.nearby(actor.global_position):
		if item.kind=="weapon" and item.weapon=="fal":dropped=item;break
	check(not dropped.is_empty() and int(dropped.get("magazine",0))==9 and dropped.get("weapon_attachments",{}).get("optic_top",{}).get("id","")=="pso4x","weapon drop preserves canonical configuration and magazine")
	if not dropped.is_empty():await command(other,"take_weapon","pickup",{"id":dropped.id})
	check(installed(other,"fal")=="pso4x" and "fal" not in game.br_inventory.snapshot(owner).weapons,"attached weapon transfers ownership")
	await command(other,"equip_transfer","equip",{"weapon":"fal"})
	await verify("transferred",other,1)
	game.rpc_id(owner,"qa_rebuild_attachment_actor","rebuild",other,game.players[other].global_position)
	await wait_for(func():return game.acknowledgements.has(str(owner)+":rebuild"),"remote observer rebuilt")
	game._send_br_baseline(owner);await verify("rebuilt_baseline",other,1)
	var victim: GamePlayer=game.players[other]
	game._apply_hit(owner,{"collider":victim.hit_regions.chest,"position":victim.global_position},1000.,"chest","fal",Vector3.RIGHT)
	await physics_frame;await physics_frame
	var corpse: Dictionary={};var part: Dictionary={}
	for item: Dictionary in game.br_inventory.world_loot.values():
		if item.kind!="container":continue
		for content: Dictionary in item.contents:
			if content.kind=="weapon" and content.weapon=="fal":corpse=item;part=content;break
	check(not part.is_empty() and part.get("weapon_attachments",{}).get("optic_top",{}).get("id","")=="pso4x","corpse container preserves weapon attachment state")
	if not part.is_empty():await command(owner,"take_corpse_weapon","pickup",{"id":corpse.id,"part":part.part_id})
	check(installed(owner,"fal")=="pso4x","corpse pickup restores complete configuration to recipient")
	await command(owner,"equip_corpse","equip",{"weapon":"fal"})
	await verify("corpse_transfer",owner,1)
