extends SceneTree
var game: Node3D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func tick(actor: GamePlayer,seconds: float) -> void:
	for step in ceili(seconds*60): actor._physics_process(1./60.)
func prepare(actor: GamePlayer) -> void:
	actor.cancel_reload();actor.hp=100;actor.weapon_id="fal";actor.ammo={"fal":12,"glock":4,"sniper":1};actor.reserves={"fal":180,"glock":60,"sniper":25}
	actor.owned=["broom","squeegee","axe","glock","fal","sniper"];actor.loadout=actor.owned.duplicate();actor.grenade_selected=false;actor.grenade_prime_pending=false;actor.grenade_held_id="";actor.grenade_throw_left=0;actor.grenade_aiming=false;actor.grenades=2
	actor._refresh_weapon()
func run() -> void:
	game=load("res://scripts/main.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="sandbox";game._enter_match_world();game.set_physics_process(false)
	game._static_box(game.world_root,"Floor",Vector3(0,-.25,0),Vector3(100,.4,100),Color.GRAY)
	var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as GamePlayer;actor.set_physics_process(false);prepare(actor)
	await physics_frame;await physics_frame
	game._server_reload(1,"fal");tick(actor,2.)
	check(actor.reload_total==6 and absf(actor.reload_left-4)<.02,"FAL keeps the six-second full animation with four seconds remaining")
	game._equip_server(actor,"glock")
	check(actor.reload_weapon.is_empty() and absf(float(actor.paused_reloads.fal.left)-4)<.02,"switching to Glock pauses FAL progress per weapon")
	check(actor.ammo.fal==12 and actor.reserves.fal==180,"pausing transfers no ammunition")
	tick(actor,3.)
	check(absf(float(actor.paused_reloads.fal.left)-4)<.02 and actor.ammo.fal==12,"a holstered reload never advances in the background")
	game._server_reload(1,"glock");tick(actor,1.)
	game._equip_server(actor,"axe")
	check(actor.paused_reloads.size()==2 and absf(float(actor.paused_reloads.glock.left)-3)<.02,"two guns keep independent paused progress")
	game._equip_server(actor,"fal")
	check(actor.reload_weapon=="fal" and actor.reload_total==6 and absf(actor.reload_left-4)<.02,"re-equipping FAL automatically resumes the remaining time")
	check(not actor.paused_reloads.has("fal") and actor.paused_reloads.has("glock"),"resuming one weapon preserves the other paused reload")
	var before: int=actor.ammo.fal;actor.fire_cooldown=0;actor.fire()
	check(actor.ammo.fal==before,"resumed reload blocks firing")
	tick(actor,3.8)
	check(actor.ammo.fal==12 and actor.reload_left>0,"resumed FAL cannot fill before its remaining four seconds")
	tick(actor,.3)
	check(actor.ammo.fal==30 and actor.reserves.fal==162 and actor.reload_weapon.is_empty(),"completion transfers exactly eighteen rounds once")
	actor.complete_reload()
	check(actor.ammo.fal==30 and actor.reserves.fal==162,"duplicate completion cannot consume reserve or refill again")
	game._equip_server(actor,"glock");tick(actor,3.1)
	check(actor.ammo.glock==12 and actor.reserves.glock==52 and actor.reload_total==0,"Glock resumes its own three seconds and consumes only eight reserve rounds")
	prepare(actor);actor.reserves.fal=3;game._server_reload(1,"fal");tick(actor,1);game._equip_server(actor,"axe");game._equip_server(actor,"fal");tick(actor,5.1)
	check(actor.ammo.fal==15 and actor.reserves.fal==0,"resumed reload respects limited reserve")
	prepare(actor);game._server_reload(1,"fal");tick(actor,2);actor.equip_grenade()
	check(actor.grenade_selected and actor.reload_weapon.is_empty() and absf(float(actor.paused_reloads.fal.left)-4)<.02,"equipping an unarmed grenade pauses the current rifle")
	check(game.grenades_system.prime(actor,actor.life_id,100),"grenade can be primed while the rifle reload is paused")
	check(actor.paused_reloads.has("fal") and absf(float(actor.paused_reloads.fal.left)-4)<.02,"arming and replicated grenade preparation preserve paused progress")
	game.grenades_system.reset_round();actor.grenade_held_id="";actor.grenade_selected=false;actor.grenade_prime_pending=false;actor.grenade_throw_left=0
	game._equip_server(actor,"fal")
	check(actor.reload_weapon=="fal" and absf(actor.reload_left-4)<.02,"returning from grenade to the same selected rifle resumes reload")
	prepare(actor);game._server_reload(1,"fal");tick(actor,1);game._equip_server(actor,"glock");game._server_reload(1,"glock");tick(actor,1)
	actor.take_damage(1000,"chest",2)
	check(actor.hp==0 and actor.reload_weapon.is_empty() and actor.paused_reloads.is_empty(),"death clears every active and paused weapon reload")
	actor.respawn()
	check(actor.paused_reloads.is_empty() and actor.reload_weapon.is_empty(),"new life cannot inherit reload progress")
	prepare(actor);game._server_reload(1,"fal");tick(actor,1);game._equip_server(actor,"glock")
	var saved:=actor.paused_reloads.duplicate(true);var life:=actor.life_id
	game.remote_inventory(1,actor.ammo,actor.reserves,0,"",0,0,saved,life,100)
	check(actor.paused_reloads.has("fal") and actor.authoritative_reload_revision==100,"inventory replication restores paused state and its authoritative revision")
	game.remote_inventory(1,{"fal":0},actor.reserves,0,"fal",6,6,{},life,99)
	check(actor.weapon_id=="glock" and actor.ammo.fal==12 and actor.reload_weapon.is_empty(),"older inventory revision cannot replace paused progress or ammunition")
	game.remote_inventory(1,{"fal":0},actor.reserves,0,"fal",6,6,{},life-1,101)
	check(actor.ammo.fal==12 and actor.paused_reloads.has("fal"),"inventory from an old life is rejected")
	actor.cancel_reload();actor.authoritative_reload_revision=-1;actor.weapon_id="fal"
	game.remote_inventory(1,actor.ammo,actor.reserves,0,"fal",2.5,6,{},life,102)
	check(actor.reload_weapon=="fal" and actor.reload_total==6 and actor.reload_left==2.5,"late active-state snapshot retains full duration and remaining progress")
	game.queue_free();await process_frame;await process_frame
	# The War child uses the same state machine, with launcher/vehicle resets.
	game=WarGame.new();game.set_meta("war_host",true);game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game);game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	for id in [701,702]:
		var member:=game._spawn_player(id,false,false,WarTerrain.point(-560 if id==701 else 560,0)) as WarPlayer;member.set_physics_process(false)
		game.members[id]={"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
		game._deploy(id,0 if id==701 else 1,"antitank","fal",WarRules.launcher_for_team(0 if id==701 else 1),"base")
	var war_actor:=game.players[701] as WarPlayer;war_actor.ammo.fal=10
	game._server_reload(701,"fal");tick(war_actor,2);war_actor.set_gadget(true,"stinger")
	check(war_actor.reload_weapon.is_empty() and war_actor.paused_reloads.has("fal"),"War launcher selection pauses the shared rifle reload")
	var paused_before:=float(war_actor.paused_reloads.fal.left);war_actor.start_reload();game._server_reload(701,"fal")
	check(war_actor.reload_weapon.is_empty() and is_equal_approx(float(war_actor.paused_reloads.fal.left),paused_before),"reload requests with an equipped launcher cannot restart or advance the paused rifle")
	war_actor.set_gadget(false,"stinger")
	check(war_actor.reload_weapon=="fal" and absf(war_actor.reload_left-4)<.02,"returning from the launcher resumes the shared rifle progress")
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	war_actor.position=WarTerrain.point(vehicle.position.x-3.9,vehicle.position.z)+Vector3.UP*.2
	await physics_frame;await physics_frame
	game.vehicle_system.command_for(701,"enter",{"id":vehicle.vehicle_id})
	check(war_actor.vehicle_id==vehicle.vehicle_id and war_actor.reload_weapon.is_empty() and war_actor.paused_reloads.is_empty(),"boarding a vehicle hard-resets personal reload progress")
	game.reset_operation()
	check(war_actor.reload_weapon.is_empty() and war_actor.paused_reloads.is_empty(),"War round reset keeps all per-life reload state cleared")
	game.show_menu();game.queue_free();await process_frame;await process_frame;await create_timer(.25).timeout
	var report: Dictionary={"checks":checks,"failures":failures,"policy":"Paused time per gun, current life only. No background completion; death, new life, vehicle entry and round reset clear every reload."}
	NavalStorage.write_json("res://tests/reload-resume-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
