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
	game.war_round_ended(0,60.)
	check(game.match_ended and game.war_ui.round_panel.visible and is_equal_approx(game.round_restart_left,60.),"round end opens the result menu for one minute")
	check(not game.gameplay_input_allowed() and not game._battle_active(),"round break prevents live combat")
	game.tickets=[10,20];game.objective_states.A.owner=1;actor.kills=4;actor.deaths=3
	game.match_stats.register(actor.peer_id,"test",0);game.match_stats.rows[actor.peer_id].points=500
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	vehicle.allocate_seat(actor.peer_id);game.members[actor.peer_id].vehicle=vehicle.vehicle_id;actor.vehicle_id=vehicle.vehicle_id
	vehicle.ammo=0;vehicle.hp=20
	game._physics_process(59.5)
	check(game.match_ended and game.round_restart_left>.4 and game.round_restart_left<.6,"offline intermission counts while the world is paused")
	game._physics_process(.6);await physics_frame;await physics_frame
	check(not game.match_ended and is_equal_approx(game.match_left,WarRules.DURATION) and game.tickets==[300,300],"new round resets timer and tickets")
	check(int(game.objective_states.A.owner)==-1 and int(game.objective_states.E.owner)==-1,"objectives start neutral")
	check(vehicle.driver==0 and vehicle.hp==vehicle.spec.hp and vehicle.ammo==vehicle.capacity(),"vehicle occupancy, health and ammunition reset")
	check(actor.deployed and actor.hp==100 and actor.vehicle_id.is_empty() and actor.position.distance_to(WarRules.BASES[0])<35,"human restarts automatically at selected team's base")
	check(actor.kills==0 and actor.deaths==0 and int(game.match_stats.rows[actor.peer_id].points)==0,"round statistics reset")
	check(not game.war_ui.round_panel.visible,"round menu closes after restart")
	game.show_menu();game.queue_free();await process_frame
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/round195-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
