extends SceneTree
# Multi-vehicle movement benchmark for bot-operated War vehicles.
var game: WarGame
var director: WarBotDirector
var manager: WarVehicles
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func fail(label: String) -> void:
	failures.append(label)
	push_error("BOT_VEHICLE_INTENSITY_FAIL "+label)

func _driver(peer: int,vehicle: WarVehicle,objective: String,slot: int) -> Dictionary:
	var actor:=game._spawn_player(peer,false,false,vehicle.global_position) as WarPlayer
	actor.apply_identity(vehicle.team,"soldier")
	actor.deployed=true;actor.hp=100.;actor.set_physics_process(false)
	game.members[peer]={"team":vehicle.team,"role":"soldier","deployed":true,"bot":true,"vehicle":vehicle.vehicle_id,"vehicle_seat":0,"vehicle_role":"operator","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	actor.vehicle_id=vehicle.vehicle_id
	vehicle.allocate_seat(peer)
	actor.body_collision.set_deferred("disabled",true)
	var record: Dictionary={"team":vehicle.team,"slot":slot,"objective":objective,"target":0,"target_vehicle":"","line_clear":false,"vehicle_goal":"","vehicle_path":[],"vehicle_index":0,"vehicle_stuck":0.,"vehicle_check_at":0.,"boarding_until":0.,"last_position":vehicle.global_position,"terrain_detour":Vector3.INF}
	director.bots[peer]=record
	return {"actor":actor,"vehicle":vehicle,"record":record,"start":vehicle.global_position,"distance":0.,"stops":0,"samples":0,"speed_sum":0.}

func _run() -> void:
	game=WarGame.new()
	game.operation_id=WarOperation.AFGHAN
	game.offline_operation=true
	game.set_meta("war_test",true);game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+40000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready:
		fail("game not ready");quit(1);return
	director=game.bot_director as WarBotDirector
	director.stop()
	manager=game.vehicle_system as WarVehicles
	var specs=[
		["v_bike_0_0","D",8],
		["v_guarani","D",0],
		["v_abrams","D",1],
		["v_bike_1_0","B",8],
		["v_bmp2","B",0],
		["v_t90","B",1]
	]
	var probes: Array=[]
	var peer:=17100
	for spec in specs:
		var vehicle:=manager.vehicles.get(spec[0]) as WarVehicle
		if not is_instance_valid(vehicle):
			fail("missing "+str(spec[0]));continue
		probes.append(_driver(peer,vehicle,str(spec[1]),int(spec[2])))
		peer+=1
	await physics_frame
	for frame in 900:
		for probe in probes:
			var vehicle: WarVehicle=probe.vehicle
			if vehicle.driver<=0: continue
			var before:=vehicle.global_position
			director._drive(probe.actor,probe.record,1./60.)
			probe.distance=float(probe.distance)+before.distance_to(vehicle.global_position)
		await physics_frame
		if frame>=120:
			for probe in probes:
				var vehicle: WarVehicle=probe.vehicle
				probe.samples=int(probe.samples)+1
				probe.speed_sum=float(probe.speed_sum)+absf(vehicle.speed)
				if absf(vehicle.speed)<.5: probe.stops=int(probe.stops)+1
	var report: Array=[]
	for probe in probes:
		var vehicle: WarVehicle=probe.vehicle
		var objective: Vector3=WarRules.OBJECTIVES[str(probe.record.objective)].position
		var avg:=float(probe.speed_sum)/maxi(1,int(probe.samples))
		var stopped_ratio:=float(probe.stops)/maxi(1,int(probe.samples))
		var displacement:=Vector3(probe.start).distance_to(vehicle.global_position)
		var speed_ratio:=avg/maxf(1.,float(vehicle.spec.speed))
		report.append({"id":vehicle.vehicle_id,"kind":vehicle.kind,"team":vehicle.team,"avg_speed":avg,"speed_ratio":speed_ratio,"stopped_ratio":stopped_ratio,"displacement":displacement,"distance_to_objective":vehicle.global_position.distance_to(objective),"max_speed":float(vehicle.spec.speed)})
		if speed_ratio<.35: fail(vehicle.vehicle_id+" average speed fell below 35% of vehicle capability")
		if stopped_ratio>.15: fail(vehicle.vehicle_id+" spent more than 15% of travel sample stopped")
	# Armed bots must keep advancing while engaging a target that is not
	# already on top of the capture point. The old controller stopped at 180 m.
	var guarani_probe: Dictionary={}
	for probe in probes:
		if str((probe.vehicle as WarVehicle).vehicle_id)=="v_guarani":
			guarani_probe=probe
		elif is_instance_valid(probe.vehicle):
			(probe.vehicle as WarVehicle).global_position+=Vector3(600,0,600)
	if not guarani_probe.is_empty():
		var guarani:=guarani_probe.vehicle as WarVehicle
		guarani.global_position=WarTerrain.point(-380,720)+Vector3.UP*.35
		guarani.speed=0.
		guarani_probe.record.vehicle_path=[];guarani_probe.record.vehicle_goal=""
		var enemy:=game._spawn_player(17990,false,false,guarani.global_position+Vector3(0,0,-100)) as WarPlayer
		enemy.apply_identity(1,"soldier");enemy.deployed=true;enemy.hp=100.;enemy.set_physics_process(false)
		game.members[17990]={"team":1,"role":"soldier","deployed":true,"bot":true,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
		guarani_probe.record.target=17990;guarani_probe.record.line_clear=true
		director._drive(guarani_probe.actor,guarani_probe.record,1./60.)
		var combat_control: Dictionary=manager.controls.get(guarani_probe.actor.peer_id,{})
		if float(combat_control.get("throttle",0.))<=.1: fail("armed vehicle froze during a distant infantry engagement")
		report.append({"combat_throttle":float(combat_control.get("throttle",0.)),"combat_target_distance":guarani.global_position.distance_to(enemy.global_position)})
	print("BOT_VEHICLE_INTENSITY ",JSON.stringify(report))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
