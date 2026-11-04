extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var actor:=game.local_player as WarPlayer
	game.supply_points.A=actor.global_position;game.objective_states.A.owner=1
	actor.reserves.fal=0;game.vehicle_system.resupply_point(actor.peer_id)
	check(actor.reserves.fal==0,"enemy objective cannot resupply")
	game.objective_states.A.owner=0;game.vehicle_system.resupply_point(actor.peer_id)
	check(actor.reserves.fal>0,"friendly captured point refills infantry")
	actor.reserves.fal=0;game.vehicle_system.resupply_point(actor.peer_id)
	check(actor.reserves.fal==0,"point supply respects cooldown")
	var tank:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	tank.global_position=actor.global_position;tank.allocate_seat(actor.peer_id);actor.vehicle_id=tank.vehicle_id;game.members[actor.peer_id].vehicle=tank.vehicle_id
	tank.reserve=0;game.vehicle_system.resupply_point(actor.peer_id)
	check(tank.reserve>0,"friendly captured point refills an operated tank")
	game.vehicle_system.deploy_smoke(actor.peer_id)
	check(game.vehicle_system.smoke_screens.size()==1,"tank deploys smoke")
	game.vehicle_system.deploy_smoke(actor.peer_id)
	check(game.vehicle_system.smoke_screens.size()==1,"smoke cooldown prevents duplicates")
	game.vehicle_system.reset_occupancy()
	check(game.vehicle_system.smoke_screens.is_empty(),"match reset clears smoke state")
	game.show_menu();game.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
