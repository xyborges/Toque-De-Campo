extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles
	actor.set_posture(2)
	for i in 60: actor.stance.advance(actor,1./60.);actor._animate_walk()
	actor.set_posture(0)
	for i in 60: actor.stance.advance(actor,1./60.);actor._animate_walk()
	actor.set_gadget(true,"stinger");actor._update_weapon_pose()
	var drone:=WarDrone.new();drone.drone_id="launcher-test";drone.team=1;game.world_root.add_child(drone)
	drone.position=actor.camera_pivot.global_position+Vector3(0,0,-100);manager.drones[drone.drone_id]=drone
	manager._update_gadgets(.1);manager._update_gadgets(1.5)
	var before: int=game.war_fx.counter;var charges:int=game.members[1].charges
	manager.use_gadget(1)
	print("LAUNCHER_RESULT ",{"fired":game.war_fx.counter>before,"charges_before":charges,"charges_after":game.members[1].charges,"weapon":actor.weapon_id,"equipped":actor.gadget_equipped,"lock":manager.locks,"muzzle":str(actor.launcher_muzzle.global_position),"eye":str(actor.camera_pivot.global_position)})
	game.show_menu();game.queue_free();await process_frame;quit()
