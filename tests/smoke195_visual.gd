extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game);await process_frame
	var manager:=game.vehicle_system as WarVehicles;manager.set_process(false)
	game.combat_effects=WarEffects.new();game.world_root.add_child(game.combat_effects)
	var actor:=game.local_player as WarPlayer;var vehicle:=manager.vehicles.v_guarani as WarVehicle
	vehicle.position=Vector3(0,20,0);vehicle.rotation=Vector3.ZERO;vehicle.aim(.1,Vector3(0,22,-500),true);vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id;vehicle.selected="secondary"
	manager._process(.1);manager._fire_vehicle(vehicle);manager._process(.1)
	if not manager.tv.viewing(): failures.append("TV view not active")
	var shot: Dictionary=game.war_fx.find_round(manager.tv.view_id)
	var point: Vector3=shot.get("position",Vector3.ZERO)
	manager.register_smoke("visual",point,game.war_clock+12.)
	game.war_clock+=2.;manager._process(.1);manager._update_smoke_overlay(1.)
	if not is_instance_valid(manager.smoke_overlay) or manager.smoke_overlay.color.a<.8: failures.append("TV is not obscured inside smoke")
	manager.toggle_thermal();manager._update_smoke_overlay(1.)
	if not manager.thermal or manager.smoke_overlay.color.a<.8: failures.append("thermal TV is not obscured")
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/smoke195-tv.png")
	manager.camera.global_position=point+Vector3(100,0,0);manager._update_smoke_overlay(1.)
	if manager.smoke_overlay.color.a>.1: failures.append("smoke obscures camera outside cloud")
	print(JSON.stringify({"failures":failures}));game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
