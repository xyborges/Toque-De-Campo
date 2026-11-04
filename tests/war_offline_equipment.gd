extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func wait_for(condition: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())
func key(code: int,pressed:=true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func click(button: int,pressed:=true) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;Input.parse_input_event(event)
func capture(label_text: String) -> void:
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/war-offline-equipment-"+label_text+".png")
func run() -> void:
	Engine.max_fps=60
	game=WarGame.new();game.offline_operation=true
	game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	check(await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),25),"local equipment operation starts without transport")
	game.request_deploy(0,"soldier","fal","rpg","base")
	check(await wait_for(func():return game.players.size()==12,15),"local equipment operation includes both conquest squads")
	game.bot_director.stop() # Deterministic vehicle/equipment fixture; bots cannot interrupt it.
	var human:=game.local_player as WarPlayer
	var vehicles:=game.vehicle_system as WarVehicles
	var apc:=vehicles.vehicles.v_guarani as WarVehicle
	human.position=WarTerrain.point(apc.position.x-3.6,apc.position.z)+Vector3.UP*.15
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await process_frame
	check(game.gameplay_input_allowed(),"native focused window enables normal gameplay input")
	key(KEY_F);await physics_frame;key(KEY_F,false);await process_frame
	check(human.vehicle_id==apc.vehicle_id and apc.driver==1,"F enters the nearby friendly APC through local command validation")
	check(human.body_collision.disabled and not human.body_root.visible,"vehicle entry hides infantry and disables its body collision")
	check(await wait_for(func():return vehicles.camera.current and game.player_in_vehicle,1),"local authoritative vehicle activates its chase camera")
	var before:=apc.global_position
	Input.action_press("move_forward");await create_timer(1.4).timeout;Input.action_release("move_forward")
	check(apc.global_position.distance_to(before)>1.5 and apc.speed>0,"normal movement input drives the local authoritative APC")
	var flash_before: int=game.war_fx.flash_cursor;var ammo_before:=apc.ammo
	click(MOUSE_BUTTON_LEFT);await create_timer(.36).timeout;click(MOUSE_BUTTON_LEFT,false)
	check(apc.ammo<ammo_before and apc.shot_sequence>0,"APC trigger fires real projectiles and consumes its magazine")
	check(game.war_fx.flash_cursor!=flash_before,"local APC shot presents a muzzle flash")
	check(game.combat_audio.pools.has("1:hmg"),"local APC shot creates its spatial weapon audio voice")
	var fov_before:=vehicles.camera.fov
	click(MOUSE_BUTTON_RIGHT);click(MOUSE_BUTTON_RIGHT,false);await create_timer(.5).timeout
	check(vehicles.zoom and vehicles.camera.fov<fov_before-15,"right click toggles persistent local vehicle zoom")
	await capture("apc-zoom")
	key(KEY_X);key(KEY_X,false);await process_frame
	check(vehicles.thermal,"local vehicle thermal view can be toggled")
	key(KEY_F);key(KEY_F,false);await physics_frame;await process_frame
	check(human.vehicle_id.is_empty() and apc.driver==0,"F releases the exclusive vehicle operator")
	check(not human.body_collision.disabled and human.body_root.visible,"vehicle exit restores infantry collision and visibility")
	check(await wait_for(func():return human.camera.current and not game.player_in_vehicle and not vehicles.thermal,1),"vehicle exit restores infantry camera and clears thermal")
	check(human.position.y>=WarTerrain.height_at(human.position.x,human.position.z)-.05,"vehicle exit places infantry above valid terrain")
	# Open terrain fixture keeps the drone clear of the base canopy and removes
	# friendly actors from the grenade blast test, without altering simulation.
	human.position=WarTerrain.point(-450,280)+Vector3.UP*.15;human.velocity=Vector3.ZERO
	key(KEY_B);key(KEY_B,false);await physics_frame;await process_frame
	check(human.vehicle_id.begins_with("drone_") and vehicles.drones.size()==1,"B launches a local bomb drone through the existing eligibility rules")
	var drone:=vehicles.find_target(human.vehicle_id) as WarDrone
	if is_instance_valid(drone):
		var drone_start:=drone.global_position;var battery_before:=drone.battery
		Input.action_press("move_forward");Input.action_press("jump")
		var flight_deadline:=Time.get_ticks_msec()+2200
		while Time.get_ticks_msec()<flight_deadline and is_instance_valid(drone):
			await physics_frame
		Input.action_release("move_forward");Input.action_release("jump")
		if not is_instance_valid(drone):
			print("DRONE_EARLY_REMOVAL "+JSON.stringify({"controls":vehicles.controls.get(1,{}),"fire_held":vehicles.fire_held,"human_hp":human.hp,"actor_vehicle":human.vehicle_id,"war_clock":game.war_clock,"projectiles":game.war_fx.active_slots.size()}))
			check(false,"local drone survives its controlled flight before detonation")
			game.show_menu();game.queue_free();await process_frame;await process_frame
			quit(1);return
		check(drone.global_position.distance_to(drone_start)>12 and drone.battery<battery_before,"local drone follows movement and lift input while consuming battery")
		check(vehicles.camera.current,"drone switches to its own control camera")
		check(not drone.rotors.is_empty() and absf(drone.rotors[0].rotation.y)>.01,"local authoritative drone animates its rotors")
		await capture("drone")
		var points_before:=int(game.match_stats.rows[1].points)
		click(MOUSE_BUTTON_LEFT);await physics_frame;click(MOUSE_BUTTON_LEFT,false)
		check(await wait_for(func():return vehicles.drones.is_empty() and human.vehicle_id.is_empty(),3),"drone trigger detonates and releases the local operator")
		await process_frame
		check(human.camera.current and not game.player_in_vehicle,"drone detonation restores the infantry camera")
		check(int(game.match_stats.rows[1].points)==points_before,"detonating one's own drone awards no enemy-drone points")
	else:
		check(false,"drone actor exists after local launch")
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	key(KEY_G);key(KEY_G,false);await process_frame
	check(human.grenade_selected and human.grenade_held_id.is_empty(),"G equips an unarmed grenade in the local player's hand")
	click(MOUSE_BUTTON_LEFT);await physics_frame
	var grenade_id:=human.grenade_held_id;var primed_at:=Time.get_ticks_msec()
	check(not grenade_id.is_empty() and human.grenade_fuse_left>4.5,"left click primes the shared five-second local grenade")
	var rifle_ammo:=int(human.ammo.fal);human.fire()
	check(int(human.ammo.fal)==rifle_ammo,"held grenade prevents infantry firearm shots")
	await create_timer(.7).timeout;click(MOUSE_BUTTON_LEFT,false);await physics_frame
	check(human.grenade_held_id.is_empty() and game.grenades_system.rounds.has(grenade_id),"releasing left click launches the actual locally authoritative grenade")
	check(await wait_for(func():return game.grenades_system.events.has(grenade_id),6),"local grenade detonates through the shared fuse and explosion system")
	var fuse_ms:=Time.get_ticks_msec()-primed_at
	check(fuse_ms>=4800 and fuse_ms<=5500,"grenade fuse lasts five seconds from priming, including time held")
	# Diagnostic undeployment permits choosing a second class without killing
	# the actor directly; normal _deploy resets all class inventory and visuals.
	human.hp=0;human.deployed=false;game.members[1].deployed=false;game.members[1].ready_at=0.
	game.request_deploy(0,"antitank","fal","stinger","rally")
	await physics_frame;await process_frame
	check(human.hp==100 and human.war_class=="antitank","offline deployment can change to the existing antitank class")
	key(KEY_7);key(KEY_7,false);await process_frame
	check(not human.gadget_equipped,"team 1 cannot equip the opposite team RPG through key 7")
	key(KEY_8);key(KEY_8,false);await process_frame
	check(human.gadget_equipped and human.gadget=="stinger","key 8 switches to the Stinger in local mode")
	key(KEY_1);key(KEY_1,false);await process_frame
	check(not human.gadget_equipped and human.launcher_model==null and human.weapon_id=="glock","key 1 removes the launcher and equips the pistol")
	key(KEY_8);key(KEY_8,false);await process_frame;key(KEY_2);key(KEY_2,false);await process_frame
	check(not human.gadget_equipped and human.launcher_model==null and human.weapon_id=="fal","key 2 restores the rifle without a stuck launcher")
	await capture("antitank-rifle")
	game.show_menu();game.queue_free();await process_frame;await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var report: Dictionary={"checks":checks,"failures":failures,"fixture":"Real native input and offline authoritative systems. AI is stopped during equipment checks; class change uses diagnostic undeployment."}
	NavalStorage.write_json("res://tests/war-offline-equipment-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
