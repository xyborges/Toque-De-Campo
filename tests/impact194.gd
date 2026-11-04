extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1;print(("PASS " if value else "FAIL ")+label)
	if not value: failures.append(label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(game);game.vehicle_system.set_physics_process(false)
	var driver:=game.players[1] as WarPlayer
	var victim:=game.players[2] as WarPlayer
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	for other: WarVehicle in game.vehicle_system.vehicles.values():
		if other!=vehicle: other.collision_layer=0
	var floor_body:=StaticBody3D.new();floor_body.collision_layer=1
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.5,100);shape.shape=box;shape.position=Vector3(0,-.25,0);floor_body.add_child(shape);game.world_root.add_child(floor_body)
	vehicle.global_position=Vector3(0,.04,0);vehicle.heading=0;vehicle.rotation=Vector3.ZERO;vehicle.speed=9.
	driver.global_position=Vector3(8,0,8);vehicle.allocate_seat(driver.peer_id);driver.vehicle_id=vehicle.vehicle_id;game.members[driver.peer_id].vehicle=vehicle.vehicle_id
	victim.global_position=Vector3(0,.04,-4.0);victim.velocity=Vector3.ZERO;game.members[victim.peer_id].shield=0
	await physics_frame;await physics_frame
	victim.body_collision.disabled=false;victim._set_hitboxes_enabled(true)
	await physics_frame
	for i in 60:
		vehicle.simulate(1./60.,{"throttle":1.,"steer":0.,"aim":vehicle.aim_target})
		await physics_frame
		if victim.hp<=0: break
	check(victim.hp<=0,"moving APC physically collides and kills an exposed enemy")
	check(victim.last_impact_weapon=="runover" and victim.last_impact_direction.z<-.5,"runover carries the impact direction")
	check(driver.kills==1 and victim.deaths==1,"driver receives kill and victim receives death")
	var teammate:=game.call("make_actor",3,false,0,"soldier",Vector3(0,.04,-4)) as WarPlayer
	game.members[3].shield=0;await physics_frame;await physics_frame;teammate.body_collision.disabled=false;teammate._set_hitboxes_enabled(true);await physics_frame
	vehicle.global_position=Vector3(0,.04,-1.1);vehicle.speed=1.5;vehicle.velocity=Vector3.ZERO
	var slow_contact:=false
	for i in 60:
		vehicle.simulate(1./60.,{"throttle":0.,"steer":0.,"aim":vehicle.aim_target})
		for index in vehicle.get_slide_collision_count():
			var collision:=vehicle.get_slide_collision(index)
			for hit in collision.get_collision_count():
				if collision.get_collider(hit)==teammate: slow_contact=true
		await physics_frame
	check(slow_contact and teammate.hp==100,"real slow vehicle contact does not damage a player")
	var points_before:=int(game.match_stats.rows[driver.peer_id].points)
	vehicle.global_position=Vector3(0,.04,0);vehicle.speed=9.;vehicle.velocity=Vector3.ZERO
	for i in 60:
		vehicle.simulate(1./60.,{"throttle":1.,"steer":0.,"aim":vehicle.aim_target});await physics_frame
		if teammate.hp<=0: break
	check(teammate.hp<=0 and driver.kills==1,"friendly runover counts death without crediting an enemy kill")
	check(int(game.match_stats.rows[driver.peer_id].points)==points_before-WarRules.TEAMKILL_PENALTY,"friendly runover deducts the teamkill penalty once")
	var target:=game.call("make_actor",4,false,1,"soldier",Vector3(10,.04,-5)) as WarPlayer
	game.members[4].shield=0;await physics_frame;await physics_frame;target.body_collision.disabled=false;target._set_hitboxes_enabled(true);await physics_frame
	vehicle.clear_seats();vehicle.collision_layer=0
	var tank:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	tank.collision_layer=1|16;tank.global_position=Vector3(10,.04,0);tank.heading=0;tank.rotation=Vector3.ZERO;tank.speed=9.
	tank.allocate_seat(driver.peer_id);driver.vehicle_id=tank.vehicle_id;game.members[driver.peer_id].vehicle=tank.vehicle_id
	for i in 60:
		tank.simulate(1./60.,{"throttle":1.,"steer":0.,"aim":tank.aim_target});await physics_frame
		if target.hp<=0: break
	check(target.hp<=0 and driver.kills==2,"tank collision also attributes a fast runover to its operator")
	var corpse:=DeathRagdoll.create(game.world_root,victim,victim.global_position)
	var root_corpse:=corpse.get_parent()
	var peak:=0.;var separation:=0.
	for i in 150:
		await physics_frame
		for body in root_corpse.get_children():
			if body is RigidBody3D:
				peak=maxf(peak,body.linear_velocity.length())
				separation=maxf(separation,body.global_position.distance_to(corpse.global_position))
	check(peak<11. and separation<2.7,"runover ragdoll remains bounded and connected")
	var body:=RigidBody3D.new();body.mass=25;game.world_root.add_child(body)
	var hand:=RigidBody3D.new();hand.mass=1.;game.world_root.add_child(hand)
	DeathRagdoll.apply_fatal_impact({"Torso":body,"HandL":hand},"handL",Vector3.RIGHT,"fal")
	await physics_frame
	check(hand.linear_velocity.x>0 and body.linear_velocity.x>0,"bullet pushes the struck hand and trunk in the hit direction")
	body.queue_free();hand.queue_free();root_corpse.queue_free();game.show_menu();game.queue_free();await process_frame
	var result: Dictionary={"checks":checks,"failures":failures,"peak":peak,"separation":separation};NavalStorage.write_json("res://tests/impact194-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
