extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var medic:=game.local_player as WarPlayer;medic.apply_identity(0,"medic");game.members[1].role="medic";medic.hp=50
	var ally: WarPlayer=game.make_actor(3,false,0,"soldier",Vector3(0,0,-.8));ally.hp=50
	await physics_frame;await physics_frame
	game.vehicle_system.use_gadget(1)
	check(medic.utility_mode=="medic","medic equips the medical item")
	game.vehicle_system.command_for(1,"med_hold",{"pressed":true});game.vehicle_system._update_gadgets(.1)
	check(ally.hp>50 and medic.hp==50,"held item heals ally in front within one metre")
	game.vehicle_system.command_for(1,"med_hold",{"pressed":false})
	var before: float=ally.hp;game.war_clock+=.6;game.vehicle_system._update_gadgets(.1)
	check(ally.hp==before,"releasing stops healing")
	ally.global_position=Vector3(0,0,-2);await physics_frame
	game.vehicle_system.command_for(1,"med_hold",{"pressed":true});game.vehicle_system._update_gadgets(.1)
	check(medic.hp>50,"medic heals self when no ally is within one metre")
	game.vehicle_system.command_for(1,"med_hold",{"pressed":false})
	medic.apply_identity(0,"marksman");game.members[1].role="marksman";medic.set_utility("")
	game.vehicle_system.use_gadget(1);medic.utility_zoom=1
	check(medic.utility_mode=="binoculars" and is_equal_approx(medic.aim_fov(),20.),"marksman binoculars zoom")
	var ammo_before:int=medic.ammo.get(medic.weapon_id,0);medic.fire()
	check(int(medic.ammo.get(medic.weapon_id,0))==ammo_before,"binoculars cannot fire")
	game.show_menu();game.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
