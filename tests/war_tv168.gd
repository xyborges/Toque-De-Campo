extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func capture(name_text: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/war168-"+name_text+".png")
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles
	manager.set_process(false);game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for vehicle: WarVehicle in manager.vehicles.values(): vehicle.collision_layer=0
	for kind in WarRules.VEHICLES:
		var vehicle:=manager.vehicles["v_"+str(kind)] as WarVehicle
		vehicle.position=Vector3(0,12,0);vehicle.rotation=Vector3.ZERO;vehicle.heading=0;vehicle.show();vehicle.collision_layer=1|16
		vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;actor.apply_identity(vehicle.team,"soldier");game.members[1].team=vehicle.team;game.members[1].vehicle=vehicle.vehicle_id
		game.members[2].team=1-vehicle.team;game.players[2].apply_identity(1-vehicle.team,"soldier")
		manager._process(.1);vehicle.aim(.1,Vector3(0,15,-300),true)
		check(var_to_bytes(vehicle.snapshot()).size()<1200,"vehicle state stays below MTU: "+str(kind))
		manager.command_for(1,"weapon",{"slot":2})
		check(vehicle.selected=="secondary","slot2 selects the secondary on "+str(kind))
		var position:=vehicle.secondary_muzzle.global_position;var count: int=game.war_fx.counter
		vehicle.reload_left=4;vehicle.reloading=true
		manager._fire_vehicle(vehicle)
		check(game.war_fx.counter==count+1,"secondary fires while main gun is reloading: "+str(kind))
		var shot: Dictionary=game.war_fx.rounds[game.war_fx.active_slots[-1]]
		check(Vector3(shot.position).distance_to(position)<.001,"secondary projectile starts at its real marker: "+str(kind))
		check(vehicle.secondary_ammo==int(WarRules.SECONDARY[kind].capacity)-1,"exactly one secondary round is consumed: "+str(kind))
		manager._fire_vehicle(vehicle);check(game.war_fx.counter==count+1,"held trigger respects its independent cooldown: "+str(kind))
		if kind in ["guarani","bmp2"]:
			check(manager.tv.viewing() and manager.tv.has_link(vehicle.vehicle_id),"APC operator gets a camera on the real missile: "+str(kind))
			check(manager.thermal_allowed(),"TV camera supports the operator thermal sensor: "+str(kind))
			var id:=str(shot.shot_id);var current: Vector3=shot.velocity.normalized()
			manager.orbit_yaw=-.6;manager.orbit_pitch=.25
			manager.accept_control(1,100+checks,manager._local_control())
			game.war_fx._step(shot,1./120.)
			check(current.angle_to(Vector3(shot.velocity).normalized())<=float(WarRules.TV_MISSILE.turn_rate)/120+.001,"server bounds steering rate: "+str(kind))
			for tick in 24:
				game.war_clock+=1./120.;game.war_fx._step(shot,1./120.)
			manager._process(.1)
			check(manager.camera.global_position.distance_to(shot.position)<.11,"camera follows the physical projectile: "+str(kind))
			check(vehicle.driver==1 and actor.vehicle_id==vehicle.vehicle_id,"TV camera does not relinquish the operator seat: "+str(kind))
			var input:=manager._local_control()
			check(float(input.throttle)==0 and float(input.steer)==0 and not input.fire and input.aim==vehicle.aim_target,"TV controls brake the hull and preserve turret target: "+str(kind))
			await capture(str(kind)+"-tv")
			manager.tv.request_release();manager._process(.1)
			check(not manager.tv.viewing() and not manager.tv.has_link(vehicle.vehicle_id) and bool(shot.active),"C exits camera but missile continues without link: "+str(kind))
			vehicle.secondary_fire_wait=0;vehicle.secondary_reload_left=0;vehicle.secondary_ammo=1;manager._fire_vehicle(vehicle)
			check(game.war_fx.counter==count+1,"cannot create a second missile while first remains in flight: "+str(kind))
			manager.explosion_event(id,shot.position,4.5)
			check(not manager.tv.has_flight(vehicle.vehicle_id) and not shot.active,"authoritative impact removes camera and guidance: "+str(kind))
		else:
			check(vehicle.reload_left==4 and vehicle.reloading,"coax does not reset main cannon reload: "+str(kind))
			check(vehicle.secondary_reload_left==0,"coax retains its magazine after one round: "+str(kind))
			check(float(vehicle.spec.gravity)==17 and float(vehicle.spec.blast)>9,"tank shell has increased drop and blast: "+str(kind))
		await capture(str(kind)+"-optic")
		vehicle.clear_seats();vehicle.hide();vehicle.collision_layer=0;actor.vehicle_id="";game.members[1].vehicle="";manager.tv.clear()
	var vehicle:=manager.vehicles.v_guarani as WarVehicle
	actor.apply_identity(0,"soldier");game.members[1].team=0;game.members[2].team=1;game.players[2].apply_identity(1,"soldier")
	vehicle.show();vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id;vehicle.secondary_ammo=1;vehicle.secondary_fire_wait=0;vehicle.secondary_reload_left=0;vehicle.selected="secondary"
	manager._process(.1);manager._fire_vehicle(vehicle)
	check(manager.tv.viewing(),"new TV flight starts after prior impact")
	actor.hp=0;manager.tv.tick(.1);manager._process(.1)
	check(not manager.tv.viewing() and not manager.tv.has_link(vehicle.vehicle_id),"death releases guidance immediately")
	manager.reset_occupancy();check(manager.tv.flights.is_empty() and manager.tv.view_id.is_empty(),"round reset clears all TV records")
	manager._respawn_vehicle(vehicle)
	check(vehicle.secondary_ammo==1 and vehicle.secondary_reserve==5 and vehicle.secondary_reload_left==0,"respawn restores finite APC secondary state")
	check(WarDayNight.PERIOD==840.,"day/night remains a full fourteen-minute cycle")
	var output:={"checks":checks,"failures":failures}
	FileAccess.open("res://tests/war-tv168-results.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"));print(JSON.stringify(output));game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

