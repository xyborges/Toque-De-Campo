extends SceneTree

# Regression for an infantry presentation that was hidden on entering a hull
# and only rebuilt after manually switching weapons.  The test intentionally
# keeps the AK equipped throughout the complete board/exit flow.
var errors: Array[String]=[]
var checks:=0

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: errors.append(label);print("FAIL ",label)

func wait_for(test: Callable,seconds:=30.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	return false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game:=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	check(await wait_for(func():return game.join_ready,75.),"offline world is ready")
	if not errors.is_empty(): quit(1);return
	game.request_deploy(1,"soldier","ak","rpg","base")
	check(await wait_for(func():return is_instance_valid(game.local_player) and game.local_player.deployed and game.local_player.weapon_id=="ak",30.),"AK infantry deployment")
	if not errors.is_empty(): game.queue_free();quit(1);return
	var actor:=game.local_player as WarPlayer
	game.third_person=false;actor._update_view()
	var vehicle:=game.vehicle_system.vehicles.get("v_bmp2") as WarVehicle
	vehicle.global_position=actor.global_position+actor.global_basis*Vector3(0,0,-2.5);vehicle.velocity=Vector3.ZERO;vehicle.speed=0.
	await physics_frame
	game.vehicle_system.command_for(actor.peer_id,"enter",{"id":vehicle.vehicle_id})
	check(await wait_for(func():return actor.vehicle_id==vehicle.vehicle_id,8.),"AK player boards armored vehicle")
	check(not actor.weapon_root.visible,"boarding hides world weapon")
	check(game.vehicle_system.release(actor.peer_id,true),"forced safe exit accepted")
	check(await wait_for(func():return actor.vehicle_id.is_empty(),8.),"AK player exits armored vehicle")
	await process_frame;await process_frame
	check(actor.weapon_id=="ak","exit keeps AK equipped")
	check(is_instance_valid(actor.weapon_root.get_node_or_null("Imported_ak")),"exit rebuilds AK world rig")
	check(is_instance_valid(actor.view_root) and str(actor.view_root.get_meta("weapon",""))=="ak","exit rebuilds AK first-person rig")
	check(is_instance_valid(actor.muzzle_marker) and actor.body_root.visible,"exit restores infantry presentation")
	var report:={"checks":checks,"ok":errors.is_empty(),"errors":errors,"scope":"offline production WarGame; unchanged AK through armored vehicle board and forced safe exit"}
	NavalStorage.write_json("res://work/war-vehicle-exit-presentation.json",report);print("WAR_VEHICLE_EXIT_PRESENTATION ",JSON.stringify(report))
	game.show_menu();game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
