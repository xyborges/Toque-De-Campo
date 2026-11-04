extends SceneTree
var game: WarGame
var manager: WarVehicles
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func member(id: int,team: int) -> WarPlayer:
	var actor:=game._spawn_player(id,false,false,WarTerrain.point(-800+id%10*3,-400)) as WarPlayer
	actor.set_physics_process(false);actor.apply_identity(team,"soldier");actor.deployed=true;actor.hp=100
	game.members[id]={"team":team,"role":"soldier","deployed":true,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	game._register_match_stat(actor)
	return actor
func board(id: int,vehicle: WarVehicle) -> void:
	var actor:=game.players[id] as WarPlayer
	actor.apply_identity(vehicle.team,"soldier");game.members[id].team=vehicle.team
	actor.position=WarTerrain.point(vehicle.position.x-3.9,vehicle.position.z)+Vector3.UP*.2
	manager.command_for(id,"enter",{"id":vehicle.vehicle_id})
func prepare(vehicle: WarVehicle) -> void:
	manager.reset_occupancy();manager._respawn_vehicle(vehicle)
	vehicle.position=WarTerrain.point(-450,280);vehicle.heading=0.;vehicle.rotation=Vector3.ZERO
	for actor: WarPlayer in game.players.values():
		actor.hp=100;actor.deployed=true;actor.position=WarTerrain.point(-800+actor.peer_id%10*3,-400)
		game.members[actor.peer_id].shield=0.
func run() -> void:
	game=WarGame.new();game.set_meta("war_host",true);game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.set_physics_process(false);manager=game.vehicle_system as WarVehicles;manager.set_physics_process(false);manager.set_process(false)
	game.war_fx.set_physics_process(false)
	for id in range(701,709): member(id,0)
	member(799,1)
	await physics_frame;await physics_frame
	check(WarRules.PROTOCOL>=2,"seat protocol cannot silently connect an old client")
	for kind in ["guarani","bmp2","abrams","t90"]:
		var vehicle:=manager.vehicles["v_"+kind] as WarVehicle
		prepare(vehicle);await physics_frame;await physics_frame
		var capacity:=6 if kind in ["guarani","bmp2"] else 2
		check(vehicle.seat_capacity()==capacity,"explicit seat capacity matches team transport policy: "+kind)
		for slot in capacity: board(701+slot,vehicle)
		check(vehicle.seats.size()==capacity and vehicle.driver==701 and vehicle.seat_of(701)==0,"first entrant operates and later entrants receive distinct passenger seats: "+kind)
		var unique: Dictionary={};var positions: Dictionary={}
		for id: int in vehicle.occupant_ids(): unique[id]=true;positions[vehicle.seat_position(vehicle.seat_of(id))]=true
		check(unique.size()==capacity and positions.size()==capacity,"no duplicate occupant or coincident seat: "+kind)
		var packet_size:=var_to_bytes(vehicle.snapshot()).size()
		print("OCCUPIED_SNAPSHOT_BYTES ",kind," ",packet_size)
		check(packet_size<1200,"full occupancy snapshot remains below the conservative UDP payload budget: "+kind)
		board(708,vehicle)
		check(game.players[708].vehicle_id.is_empty() and vehicle.seats.size()==capacity,"full vehicle rejects an extra passenger atomically: "+kind)
		var enemy:=game.players[799] as WarPlayer;enemy.apply_identity(1-vehicle.team,"soldier");game.members[799].team=1-vehicle.team
		enemy.position=WarTerrain.point(vehicle.position.x+3.9,vehicle.position.z)+Vector3.UP*.2
		manager.command_for(799,"enter",{"id":vehicle.vehicle_id})
		check(enemy.vehicle_id.is_empty() and vehicle.seats.size()==capacity,"enemy cannot enter a vehicle with available or occupied seats: "+kind)
		var passenger:=702;var input: Dictionary={"throttle":1.,"steer":1.,"aim":vehicle.position+Vector3(50,80,-30),"fire":true,"occupancy":vehicle.control_epoch,"vehicle":vehicle.vehicle_id,"life":game.players[passenger].life_id}
		manager.accept_control(passenger,99,input)
		check(not manager.controls.has(passenger),"passenger control injection cannot drive, aim or fire: "+kind)
		vehicle.ammo=0;vehicle.reloading=false;vehicle.selected="primary"
		manager.command_for(passenger,"reload",{});manager.command_for(passenger,"weapon",{})
		check(not vehicle.reloading and vehicle.selected=="primary","passenger cannot reload or switch mounted weapons: "+kind)
		check(not game._eligible(passenger) and not game.grenade_allowed(game.players[passenger]),"infantry, grenades and class gadget eligibility is revoked while seated: "+kind)
		var rounds: int=game.war_fx.counter;var charges:=int(game.members[passenger].charges)
		manager.use_gadget(passenger);manager.resupply(passenger);manager.launch_drone(passenger)
		game._server_accept_shot(passenger,1,game.players[passenger].life_id,game.players[passenger].camera_pivot.global_position,Vector3.FORWARD,"fal",0)
		check(game.war_fx.counter==rounds and int(game.members[passenger].charges)==charges and manager.drones.is_empty(),"server rejects passenger personal shots and support/drone actions: "+kind)
		vehicle.position+=Vector3(7,0,-11);vehicle.rotation.y=1.1;manager.sync_occupants(vehicle)
		var attached:=true
		for id: int in vehicle.occupant_ids(): attached=attached and game.players[id].global_position.distance_to(vehicle.to_global(vehicle.seat_position(vehicle.seat_of(id))))<.001
		check(attached,"all occupants follow their own local hull attachment while moving and rotating: "+kind)
		var mirror:=WarVehicle.new();mirror.kind=kind;mirror.vehicle_id="mirror";game.world_root.add_child(mirror);mirror.receive(vehicle.snapshot())
		check(mirror.seats==vehicle.seats and mirror.driver==vehicle.driver and mirror.control_epoch==vehicle.control_epoch,"snapshot reconstructs passenger identities for a late observer: "+kind)
		var stale:=vehicle.snapshot();var old_epoch:=vehicle.control_epoch
		manager.controls[701]={"fire":true,"throttle":1.};manager.controls[702]={"fire":true};manager.sequences[701]=150;manager.sequences[702]=200
		check(manager.release(701,true),"operator can leave without discarding passengers: "+kind)
		check(vehicle.driver==702 and vehicle.seat_of(702)==0 and str(game.members[702].vehicle_role)=="operator","oldest passenger is promoted by the authority: "+kind)
		check(not manager.controls.has(701) and not manager.controls.has(702) and not manager.sequences.has(701) and not manager.sequences.has(702),"promotion clears previous and new operator trigger and sequence state: "+kind)
		mirror.receive_seats(vehicle.seats,vehicle.seats_revision,vehicle.control_epoch);mirror.receive(stale)
		check(mirror.driver==702 and mirror.seats==vehicle.seats,"late unreliable movement cannot undo reliable occupancy: "+kind)
		manager.accept_control(702,1,{"throttle":1.,"aim":vehicle.position+Vector3.FORWARD*100,"fire":true,"occupancy":old_epoch,"vehicle":vehicle.vehicle_id,"life":game.players[702].life_id})
		check(not manager.controls.has(702) and vehicle.control_epoch>old_epoch,"old occupancy epoch cannot transfer a held trigger after promotion: "+kind)
		manager.accept_control(702,2,{"throttle":.2,"aim":vehicle.position+Vector3.FORWARD*100,"fire":false,"occupancy":vehicle.control_epoch,"vehicle":vehicle.vehicle_id,"life":game.players[702].life_id})
		check(manager.controls.has(702),"promoted operator can submit a fresh validated control packet: "+kind)
		mirror.queue_free()
	var apc:=manager.vehicles.v_guarani as WarVehicle
	prepare(apc);await physics_frame;await physics_frame
	# Arrival order, not numeric peer IDs, determines the successor.
	board(701,apc);board(704,apc);board(702,apc)
	manager.release(701,true)
	check(apc.driver==704,"promotion respects boarding order rather than peer ID order")
	var operator:=game.players[704] as WarPlayer
	var blocker:=StaticBody3D.new();blocker.collision_layer=1
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,8,30);shape.shape=box;blocker.add_child(shape);game.world_root.add_child(blocker);blocker.position=apc.position+Vector3.UP*2
	await physics_frame;await physics_frame
	var seats_before:=apc.seats.duplicate()
	check(not manager.release(704) and apc.seats==seats_before and operator.vehicle_id==apc.vehicle_id,"blocked exit retains the occupant and reservation instead of teleporting through geometry")
	blocker.queue_free();await physics_frame;await physics_frame
	check(manager.release(704) and operator.vehicle_id.is_empty(),"exit succeeds once a collision-free swept route exists")
	check(operator.position.y>=WarTerrain.height_at(operator.position.x,operator.position.z)+.05,"safe exit rests above terrain rather than inside it")
	prepare(apc);await physics_frame;await physics_frame
	for id in range(701,707): board(id,apc)
	game.players[799].apply_identity(1,"soldier");game.members[799].team=1
	var kills_before:=int(game.match_stats.rows[799].kills)
	manager.damage_from_hit(799,apc,100000,"tank",Vector3.FORWARD)
	var all_dead:=true;var all_released:=true
	for id in range(701,707):
		all_dead=all_dead and game.players[id].hp==0
		all_released=all_released and game.players[id].vehicle_id.is_empty() and str(game.members[id].vehicle).is_empty()
	check(all_dead and all_released,"vehicle destruction kills and releases every actual occupant")
	check(apc.destroyed and apc.seats.is_empty() and apc.driver==0,"destroyed vehicle never promotes a passenger during the death cascade")
	check(int(game.match_stats.rows[799].kills)==kills_before+6,"all six occupant deaths use real authoritative combat statistics")
	manager._step_vehicle_respawns(60)
	check(apc.seats.is_empty() and apc.driver==0 and not apc.destroyed,"one-minute return cannot restore stale occupant reservations")
	prepare(apc);await physics_frame;await physics_frame
	board(701,apc);board(702,apc);manager.controls[701]={"fire":true};manager.sequences[701]=99
	manager.reset_occupancy()
	check(apc.seats.is_empty() and apc.driver==0 and manager.controls.is_empty() and manager.sequences.is_empty(),"round reset clears all reservations and stale control state without promotion")
	check(game.players[701].vehicle_id.is_empty() and game.players[702].vehicle_id.is_empty(),"round reset clears occupant identity on every actor")
	# A late unreliable packet from a previous hull/round must not overwrite
	# reliable occupancy or operate a different vehicle with the same epoch.
	prepare(apc);await physics_frame;await physics_frame
	board(701,apc)
	var stale_round:=apc.snapshot();stale_round.position=apc.position+Vector3(50,0,20);stale_round.hp=12.;stale_round.destroyed=true
	manager._respawn_vehicle(apc)
	var round_mirror:=WarVehicle.new();round_mirror.kind="guarani";round_mirror.vehicle_id="round-mirror";game.world_root.add_child(round_mirror)
	round_mirror.receive(apc.snapshot());round_mirror.receive(stale_round)
	check(not round_mirror.destroyed and round_mirror.hp==float(apc.spec.hp) and round_mirror.destination.is_equal_approx(apc.spawn_position),"late pre-respawn movement snapshot cannot restore old damage, destruction or position")
	round_mirror.queue_free()
	var tank:=manager.vehicles.v_abrams as WarVehicle
	prepare(apc);await physics_frame;await physics_frame
	board(701,apc)
	var previous_control: Dictionary={"throttle":1.,"aim":apc.position+Vector3.FORWARD*100,"fire":true,"occupancy":apc.control_epoch,"vehicle":apc.vehicle_id,"life":game.players[701].life_id}
	manager.release(701,true)
	manager._respawn_vehicle(tank);tank.position=WarTerrain.point(-470,280);tank.heading=0.;tank.rotation=Vector3.ZERO
	await physics_frame;await physics_frame
	# Match the per-hull counters to exercise the collision even after earlier
	# deterministic scenarios have used these existing vehicle instances.
	tank.control_epoch=int(previous_control.occupancy)-1
	board(701,tank)
	check(tank.driver==701 and tank.control_epoch==int(previous_control.occupancy),"cross-vehicle control fixture has matching per-hull epochs")
	manager.accept_control(701,999,previous_control)
	check(not manager.controls.has(701),"delayed controls from a different hull cannot drive or fire the newly entered vehicle")
	manager.accept_trigger(701,1000,true,int(previous_control.occupancy),str(previous_control.vehicle),int(previous_control.life))
	check(not manager.controls.has(701),"delayed trigger from the previous hull cannot fire the newly entered vehicle")
	var current_life:=int(game.players[701].life_id)
	var wrong_life:=previous_control.duplicate();wrong_life.vehicle=tank.vehicle_id;wrong_life.life=current_life-1
	manager.accept_control(701,1001,wrong_life)
	manager.accept_trigger(701,1002,true,tank.control_epoch,tank.vehicle_id,current_life-1)
	check(not manager.controls.has(701),"old-life movement and trigger are both rejected after respawn or reconnect")
	manager.accept_control(701,1003,{"throttle":1.,"aim":tank.position+Vector3.FORWARD*100,"fire":true,"occupancy":tank.control_epoch})
	manager.accept_trigger(701,1004,true,tank.control_epoch,"",-1)
	check(not manager.controls.has(701),"legacy payload without vehicle and life binding cannot operate a vehicle")
	manager.accept_trigger(701,1005,true,tank.control_epoch,tank.vehicle_id,current_life)
	check(bool(manager.controls.get(701,{}).get("fire",false)),"current operator trigger is accepted when hull, life and epoch all match")
	manager.controls.erase(701)
	manager.reset_occupancy()
	var waiting:=game.players[708] as WarPlayer
	waiting.hp=100;waiting.deployed=false;game.members[708].deployed=false
	waiting._set_hitboxes_enabled(false);waiting.body_collision.set_deferred("disabled",true);waiting.body_root.hide()
	await physics_frame
	manager.command_for(708,"exit",{})
	await physics_frame
	check(waiting.body_collision.disabled and not waiting.body_root.visible,"an undeployed peer cannot materialize its spectator body by requesting exit without a seat")
	game.show_menu();game.queue_free();await process_frame;await process_frame
	await create_timer(.25).timeout # Let the audio/retirement threads finish the fatal-hit fixture.
	var report: Dictionary={"checks":checks,"failures":failures,"fixture":"Real War authority, physics safe-exit queries and live seat snapshots; occupancy setup is deterministic and no network login is needed."}
	NavalStorage.write_json("res://tests/war-vehicle-passengers-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
