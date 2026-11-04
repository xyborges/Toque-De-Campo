extends SceneTree
const FIXTURE=preload("res://tests/br_optic_duel_fixture.gd")
var role:="server"
var game: BattleRoyaleGame
var failures: Array[String]=[]
var checks:=0
var observations: Array=[]
var ids: Array=[]

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
		await create_timer(.04).timeout
	failures.append("timeout "+label);return false
func command(id: int,label: String,action: String,data: Dictionary={}) -> Dictionary:
	game.rpc_id(id,"duel_command",label,action,data)
	await wait_for(func():return game.duel_reports.has(str(id)+":"+label),label)
	var report: Dictionary=game.duel_reports.get(str(id)+":"+label,{})
	observations.append({"id":id,"label":label,"data":report});return report
func stable(report: Dictionary,label: String,optic_expected:=true) -> void:
	check(bool(report.get("main_own",false)),label+" own main camera remains selected")
	check(int(report.get("viewports",-1))<=1 and int(report.get("remote_viewports",-1))==0,label+" no duplicate or remote optical viewport")
	if optic_expected:
		check(bool(report.get("active",false)) and float(report.get("camera_delta",99.))<.001,label+" live optical camera follows actual camera")
		var lens: Array=report.get("lens_local",[])
		check(lens.size()==3 and absf(float(lens[0]))<.004 and absf(float(lens[1]))<.004 and float(lens[2])<-.08,label+" lens stays centred")
		check(float(report.get("barrel_error",99.))>=0 and float(report.get("barrel_error",99.))<.003,label+" real barrel matches visible projectile origin")

func run() -> void:
	if role!="server":
		root.title="BR — duelo óptico "+role;root.content_scale_size=Vector2i(960,640);DisplayServer.window_set_size(Vector2i(960,640));Engine.max_fps=45
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game);await process_frame
	game.flat_world();game.online=true;game.mode="pvp";game.third_person=false
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	var peer:=ENetMultiplayerPeer.new();var error: Error
	if role=="server":
		error=peer.create_server(39589,2)
		if error==OK:error=GameSecureTransport.server(peer)
	else:
		error=peer.create_client("127.0.0.1",39589,4)
		if error==OK:error=GameSecureTransport.client(peer,"localhost")
	if error!=OK:push_error("Duelo DTLS "+error_string(error));quit(1);return
	game.network_api.multiplayer_peer=peer
	if role!="server":await create_timer(120.).timeout;quit(1);return
	if await wait_for(func():return game.multiplayer.get_peers().size()==2,"two graphical clients",30.):
		ids=Array(game.multiplayer.get_peers());ids.sort();await scenario()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Headless server and two graphical ENet/DTLS clients. BR fire prediction, ballistic damage, optics on FAL, AK and sniper, recoil, accessory swaps, iron sights, reload, death and spectator. Flat local QA arena."}
	NavalStorage.write_json("res://work/br-optic-duel.json",report);print("BR_OPTIC_DUEL ",checks," ",failures)
	game._broadcast("duel_finish",[]);await create_timer(2.7).timeout;game.leave_match();await create_timer(.1).timeout;game.free();quit(0 if failures.is_empty() else 1)

func scenario() -> void:
	var pairs:=[["fal","prism4x","ak","pso4x"],["fal","pso4x","ak","prism4x"],["ak","prism4x","fal","pso4x"],["ak","pso4x","fal","prism4x"],["sniper","precision8x","fal","hensoldt4x"],["sniper","hensoldt4x","ak","precision8x"]]
	for stage in pairs.size():
		var spec: Array=pairs[stage];var prefix:="stage%d:"%stage
		game.duel_stage(stage+10,ids);game._broadcast("duel_stage",[stage+10,ids]);await create_timer(.3).timeout
		var posture: int=[0,1,2,0,1,2][stage]
		game.duel_posture(posture);game._broadcast("duel_posture",[posture]);await create_timer(.3).timeout
		for index in ids.size():
			var id:=int(ids[index]);var actor:=game.players[id] as BRPlayer;var weapon:=str(spec[index*2]);var optic:=str(spec[index*2+1]);var other:=game.players[ids[1-index]] as GamePlayer
			for item in [{"kind":"weapon","weapon":weapon,"magazine":4},{"kind":"ammo","calibre":BRInventory.calibre_for(weapon),"amount":40},{"kind":"optic","optic":"prism4x"},{"kind":"optic","optic":"pso4x"},{"kind":"optic","optic":"precision8x"},{"kind":"optic","optic":"hensoldt4x"},{"kind":"vest","level":3},{"kind":"helmet","level":3}]:
				item.position=actor.global_position;var loot:=game.br_inventory.add_loot(item);game.br_inventory.pickup(id,loot,actor.global_position)
			game.br_inventory.equip_optic(id,weapon,optic);game._apply_backpack(actor);game._equip_server(actor,weapon);game._duel_pose(actor,other)
		await physics_frame;await physics_frame;await create_timer(.4).timeout
		for id in ids:
			var aimed:=await command(id,prefix+"aim","aim");stable(aimed,prefix+str(id)+" aim")
			var look:=await command(id,prefix+"look","look");stable(look,prefix+str(id)+" look");check(look.get("image_changed",false),prefix+" image updates while camera moves")
		for id in ids:
			var other: GamePlayer=game.players[ids[1] if id==ids[0] else ids[0]];var hp:=other.hp;var shooter: GamePlayer=game.players[id];var before:=int(shooter.ammo[shooter.weapon_id])
			var fired:=await command(id,prefix+"fire","fire");stable(fired,prefix+str(id)+" shot/recoil")
			await wait_for(func():return other.hp<hp,prefix+" ballistic hit "+str(id),3.)
			check(other.hp<hp and other.hp>0,prefix+" live opponent takes real ballistic damage")
			check(int(shooter.ammo[shooter.weapon_id])==before-1,prefix+" server accepts exactly one shot")
		for id in ids:
			var actor:=game.players[id] as GamePlayer;var previous:=str(actor.get_meta("weapon_optics",{}).get(actor.weapon_id,""));var replacement:="pso4x" if previous=="prism4x" else "prism4x"
			var swapped:=await command(id,prefix+"swap","optic",{"optic":replacement});stable(swapped,prefix+str(id)+" swapped");check(str(swapped.get("optic",""))==replacement,prefix+" equipped second scope model during duel")
			var iron:=await command(id,prefix+"iron","optic",{"optic":""});stable(iron,prefix+str(id)+" irons",false);check(not iron.get("active",true),prefix+" iron sights stop optical viewport")
			var reattach:=await command(id,prefix+"reattach","optic",{"optic":replacement});stable(reattach,prefix+str(id)+" reattach")
		for id in ids:
			var reload:=await command(id,prefix+"reload","reload")
			check(float(reload.get("reload",0.))>0 and not reload.get("active",true) and reload.get("reload_shot_blocked",false),prefix+" reload blocks shot and optical renderer")
		await wait_for(func():
			for id in ids:
				if game.players[id].reload_left>0:return false
			return true,prefix+" real reload completes",8.)
		for id in ids:
			var resumed:=await command(id,prefix+"resumed","aim");stable(resumed,prefix+str(id)+" after reload");check(int(resumed.get("ammo",0))>=int(game.players[id].weapon_spec(game.players[id].weapon_id).mag)-1,prefix+" replicated reload fills magazine")
		if stage==0:
			for id in ids:await command(id,prefix+"capture","capture",{"name":"scoped"})
		var killer:=int(ids[stage%2]);var victim:=int(ids[1-stage%2]);var victim_actor:=game.players[victim] as GamePlayer
		for burst in 6:
			if victim_actor.hp<=0:break
			var killed:=await command(killer,prefix+"fatal%d"%burst,"fire")
			if victim_actor.hp>0:stable(killed,prefix+" final burst")
			await create_timer(.3).timeout
		await wait_for(func():return victim_actor.hp<=0,prefix+" elimination",3.)
		check(victim_actor.hp<=0 and game.br_round.winner==killer,prefix+" real scoped shot determines winner")
		var dead:=await command(victim,prefix+"death","death")
		check(dead.get("hp",100.)<=0 and not dead.get("active",true) and dead.get("dead_shot_blocked",false),prefix+" death stops own scope and firing")
		check(dead.get("spectator_current",false),prefix+" camera transitions to spectator")
		var spectated:=await command(victim,prefix+"spectator","spectator_fpp")
		check(spectated.get("spectator_current",false) and not spectated.get("active",true),prefix+" spectator FPP does not inherit scope viewport")
