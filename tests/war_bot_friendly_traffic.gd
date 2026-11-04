extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var manager:=game.vehicle_system as WarVehicles;var actor:=game.local_player as WarPlayer
	var ally:=game.make_actor(90,false,0,"soldier",Vector3.ZERO) as WarPlayer
	var enemy:=game.players[2] as WarPlayer
	var director:=WarBotDirector.new();director.game=game
	var origin:=WarTerrain.point(-100,100)+Vector3.UP*.15
	var floor:=StaticBody3D.new();floor.position=origin-Vector3.UP*.6
	var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,1,200);floor_shape.shape=box;floor.add_child(floor_shape);game.world_root.add_child(floor)
	for vehicle: WarVehicle in manager.vehicles.values():vehicle.global_position=origin+Vector3(500,0,500)
	for kind in ["guarani","bmp2","abrams","t90"]:
		var vehicle:=manager.vehicles["v_"+kind] as WarVehicle
		vehicle.global_position=origin;vehicle.heading=0.;vehicle.rotation=Vector3.ZERO;vehicle.speed=8.;vehicle.team=0;vehicle.destroyed=false;vehicle.allocate_seat(1)
		actor.war_team=0;actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id
		ally.hp=100.;ally.deployed=true;ally.war_team=0;ally.vehicle_id="";ally.global_position=origin+Vector3(0,0,-15);ally.velocity=Vector3.ZERO
		enemy.global_position=origin+Vector3(80,0,-80)
		await physics_frame;await physics_frame
		var record: Dictionary={};var closest:=INF
		for frame in 110:
			game.war_clock+=1./60.;var plan:=director._traffic_plan(vehicle,record)
			vehicle.simulate(1./60.,{"throttle":.3 if not bool(plan.get("brake",false)) else 0.,"steer":0.,"brake":bool(plan.get("brake",false)),"aim":vehicle.aim_target})
			closest=minf(closest,vehicle.global_position.distance_to(ally.global_position))
			await physics_frame
		print("TRAFFIC_STOP ",kind," speed ",vehicle.speed," closest ",closest," allyhp ",ally.hp)
		check(absf(vehicle.speed)<.2,kind+" brakes to a full stop before friendly infantry")
		check(closest>float(vehicle.spec.size.z)*.5+1.0 and ally.hp==100.,kind+" preserves pedestrian clearance and health")
		check(record.traffic.get("reason","") in ["friendly_infantry","friendly_no_clear_bypass"],kind+" detects infantry rather than relying on collision")
		# Predict a teammate crossing toward the lane, not only their present point.
		vehicle.global_position=origin;vehicle.speed=8.;ally.global_position=origin+Vector3(3.8,0,-12);ally.velocity=Vector3(-5,0,0);game.war_clock+=.5;record={};director.spatial_at=0.
		var crossing:=director._traffic_plan(vehicle,record);check(bool(crossing.get("brake",false)),kind+" anticipates a crossing friendly soldier")
		# Hostile collision damage is unchanged: the safety planner does not stop
		# just because an enemy is standing ahead on a clear road.
		ally.global_position=origin+Vector3(80,0,70);ally.velocity=Vector3.ZERO;enemy.global_position=origin+Vector3(0,0,-12);enemy.war_team=1;game.war_clock+=.5;record={};director.spatial_at=0.
		check(director._traffic_plan(vehicle,record).is_empty(),kind+" does not turn enemy infantry into friendly traffic")
		vehicle.global_position=origin+Vector3(500,0,500)
	# A complete moving hull must not squeeze its centre between two old ray
	# traces. The planner checks width, and only attempts a clear wide bypass.
	var follower:=manager.vehicles.v_guarani as WarVehicle;var lead:=manager.vehicles.v_abrams as WarVehicle
	follower.global_position=origin;follower.heading=0.;follower.rotation=Vector3.ZERO;follower.speed=0.
	lead.global_position=origin+Vector3(0,0,-35);lead.rotation=Vector3.ZERO;lead.speed=0.
	ally.global_position=origin+Vector3(80,0,80);enemy.global_position=origin+Vector3(80,0,-80)
	await physics_frame;await physics_frame;game.war_clock+=.5;director.spatial_at=0.
	var passing:=director._traffic_plan(follower,{})
	check(passing.has("point") and absf(Vector3(passing.point).x-origin.x)>(float(follower.spec.size.x)+float(lead.spec.size.x))*.5,"stopped vehicle is passed only through a wide corridor")
	# Exercise the actual driver steering, not only its proposed waypoints.
	actor.vehicle_id=follower.vehicle_id;game.members[1].vehicle=follower.vehicle_id;follower.allocate_seat(1)
	var drive_record: Dictionary={"objective":"A","vehicle_goal":"A","vehicle_path":[origin+Vector3(0,0,-100)],"vehicle_index":0,"boarding_until":0.,"vehicle_check_at":game.war_clock,"last_position":origin,"vehicle_stuck":0.,"target":0,"line_clear":false}
	var closest_hulls:=INF;var lateral_pass:=0.
	for tick in 900:
		game.war_clock+=1./60.;director._drive(actor,drive_record,1./60.);follower.simulate(1./60.,manager.controls.get(1,{}))
		closest_hulls=minf(closest_hulls,Vector2(follower.position.x-lead.position.x,follower.position.z-lead.position.z).length());lateral_pass=maxf(lateral_pass,absf(follower.position.x-origin.x))
		await physics_frame
		if follower.global_position.z<lead.global_position.z-10.:break
	print("ACTUAL_BYPASS ",{"side":lateral_pass,"gap":closest_hulls,"position":follower.global_position,"lead":lead.global_position,"control":manager.controls.get(1,{}),"record":drive_record})
	check(lateral_pass>4. and closest_hulls>4. and follower.global_position.z<lead.global_position.z,"actual Guarani driver steers around stopped heavy vehicle without rear impact")
	follower.global_position=origin;follower.heading=0.;follower.rotation=Vector3.ZERO;follower.speed=0.
	var wall:=StaticBody3D.new();wall.position=origin+Vector3(0,1,-6)
	var collision:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(30,4,2);collision.shape=wall_box;wall.add_child(collision);game.world_root.add_child(wall)
	await physics_frame;await physics_frame;game.war_clock+=.5
	check(bool(director._traffic_plan(follower,{}).get("brake",false)),"blocked flanks stop the vehicle instead of pushing into a column")
	# Cache empty and occupied decisions alike; no scan of every actor or hull
	# is repeated at 60 Hz. Actor neighbourhood comes from one shared 5 Hz grid.
	var cache: Dictionary={};game.war_clock+=.5;director._traffic_plan(follower,cache);var next_check: float=cache.traffic_check_at
	for frame in 4:game.war_clock+=.01;director._traffic_plan(follower,cache)
	check(is_equal_approx(float(cache.traffic_check_at),next_check),"traffic decisions remain cached between 120 ms updates")
	wall.free();lead.global_position=origin+Vector3(500,0,500)
	enemy.hp=100.;enemy.deployed=true;enemy.global_position=origin+Vector3(0,0,-6.);enemy.vehicle_id=""
	enemy.body_collision.disabled=false;enemy._set_hitboxes_enabled(true)
	follower.global_position=origin;follower.heading=0.;follower.rotation=Vector3.ZERO;follower.speed=8.;follower.team=0
	await physics_frame;await physics_frame
	for tick in 60:
		game.war_clock+=1./60.;follower.simulate(1./60.,{"throttle":.3,"steer":0.,"aim":follower.aim_target});await physics_frame
		if enemy.hp<100.:break
	print("HOSTILE_CONTACT ",{"hp":enemy.hp,"position":follower.global_position,"enemy":enemy.global_position,"collisions":follower.get_slide_collision_count(),"operator":manager.is_operator(1),"active":game._battle_active(),"driver":follower.driver,"seat":follower.seat_of(1),"recent":manager.runover_recent})
	check(enemy.hp<100.,"hostile infantry still receives speed-dependent physical runover damage")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authoritative planner and actual movement of Guarani, BMP-2, Abrams and T-90 braking before allied infantry; predictive crossing, real Guarani overtaking of a stationary Abrams with 7.24 m minimum centre separation, blocked-column stop and cached spatial query cadence. Actual hostile Guarani runover still killed a deployed enemy with physical contact. Offline fixture; same server-owned director is used for online bots. Runover damage code unchanged."}
	var file:=FileAccess.open("res://work/war-bot-friendly-traffic.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WAR_BOT_FRIENDLY_TRAFFIC ",JSON.stringify(report));director.free();game.show_menu();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
