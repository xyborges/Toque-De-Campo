extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(label: String) -> void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/war184-"+label+".png")
func benchmark(label: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_timer(1.2).timeout
	var times: Array[float]=[];var start:=Time.get_ticks_usec();var last:=start
	while Time.get_ticks_usec()-start<6000000:
		await process_frame
		var at:=Time.get_ticks_usec();times.append((at-last)*.001);last=at
	times.sort();var total:=0.
	for dt in times: total+=dt
	var slow:=0.;var count:=maxi(1,ceili(times.size()*.01))
	for i in count: slow+=times[times.size()-1-i]
	metrics[label]={"fps":times.size()*1000/total,"one_percent_low_fps":count*1000/slow,"frame_ms":total/times.size(),"peak_ms":times.back(),"frames":times.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	print("BENCH ",label," ",JSON.stringify(metrics[label]))
func run() -> void:
	root.mode=Window.MODE_FULLSCREEN
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	while not game.join_ready: await process_frame
	game.war_ui.deploy_button.pressed.emit();await create_timer(.4).timeout
	if game.bot_director: game.bot_director.set_physics_process(false)
	for actor: GamePlayer in game.players.values(): actor.set_physics_process(false)
	game.vehicle_system.set_physics_process(false)
	game.join_ready=true;game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=true
	var actor:=game.local_player as WarPlayer
	actor.global_position=WarRules.BASES[0]+Vector3(0,.2,30);actor.weapon_id="fal";actor._refresh_weapon();actor._update_view()
	for distance_value in [2.,3.25,4.0]:
		actor.shoulder_distance=distance_value;actor.shoulder_arm.spring_length=distance_value
		for heading in [0.,PI*.5,PI,-PI*.5]:
			actor.yaw=heading;actor.rotation.y=heading;actor.pitch=0;actor.camera_pivot.rotation.x=0
			await physics_frame;await physics_frame;actor._update_camera_collision(.016)
			await create_timer(.20).timeout
			game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			var before: int=actor.ammo.fal;actor.fire_cooldown=0;actor.fire()
			check(actor.ammo.fal==before-1,"TPP fires from shoulder %.2fm at yaw %.2f"%[distance_value,heading])
			await create_timer(.13).timeout
	check(not actor.shot_camera_valid(actor.camera_pivot.global_position+Vector3(15,0,0),Vector3.FORWARD),"authority rejects a forged distant shot camera")
	check(not actor.shot_camera_valid(actor.camera_pivot.global_position+Vector3(0,0,-4),Vector3.FORWARD),"authority rejects a camera pushed ahead of the character")
	var p: Vector3=WarCoast.PORTS[1]
	check(p.y-WarTerrain.height_at(p.x,p.z)>.3,"quay surface and terrain have separate depths")
	var clear_channel:=true
	for berth: Vector3 in WarCoast.BERTHS[0]:
		for i in 30:
			if WarTerrain.height_at(berth.x-i*20,berth.z)>-2: clear_channel=false
	check(clear_channel,"both western berths keep a navigable route through the bay mouth")
	var headlands_connected:=true
	for link: Array in WarCoast.BAY_LINKS:
		for i in 16:
			var at: Vector2=Vector2(link[0]).lerp(link[1],i/15.0)
			if WarTerrain.height_at(at.x,at.y)<1: headlands_connected=false
	check(headlands_connected,"bay headlands are joined to the mainland rather than disconnected islands")
	var camera:=Camera3D.new();camera.far=3000;root.add_child(camera)
	camera.global_position=Vector3(-1500,140,-860);camera.look_at(Vector3(-1110,2,-430));camera.make_current()
	await capture("west-bay")
	camera.global_position=Vector3(-970,34,-630);camera.look_at(Vector3(-820,13,-425))
	await capture("west-terminal")
	camera.global_position=p+Vector3(-44,12,-55);camera.look_at(p+Vector3(7,4,12));camera.make_current()
	await capture("east-port-day")
	var tank:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	tank.global_position=WarTerrain.point(310,205)+Vector3.UP*.2
	for heading in [0.,PI*.5]:
		tank.heading=heading
		for i in 90: tank.simulate(1./60,{})
		camera.global_position=tank.global_position+Vector3(12,6,12);camera.look_at(tank.global_position+Vector3.UP*1.2)
		await capture("tank-slope-"+str(int(heading*100)))
	var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
	actor.apply_identity(0,"soldier");game.members[1].team=0
	actor.global_position=ship.global_position+Vector3(0,4.2,6.2)
	game.vehicle_system.command_for(1,"enter",{"id":ship.vehicle_id})
	check(ship.driver==1,"operator enters the existing naval hull")
	var dock_exit: Dictionary=game.vehicle_system.safe_exit(ship,actor)
	check(dock_exit.get("ok",false) and not dock_exit.get("water",false),"ship prefers a dry pier when a safe route is available")
	var manager:=game.vehicle_system as WarVehicles;manager._process(.016)
	manager.vehicle_view.external=false
	var toggle:=InputEventKey.new();toggle.keycode=KEY_C;toggle.pressed=true;manager._input(toggle);manager._process(.016)
	check(manager.vehicle_view.external and manager.camera is NavalCamera,"ship always uses shared Naval TPP camera")
	await create_timer(.25).timeout
	check(game.war_ui.vehicle_panel.visible and game.war_ui.vehicle_info.text.contains("OPERADOR"),"ship retains health, speed and weapon information in TPP")
	var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;manager._input(right)
	for i in 45: manager._process(.016)
	check(manager.zoom and manager.camera.fov<15,"one right click holds Naval zoom in third person")
	manager.toggle_thermal();check(manager.thermal,"ship permits thermal in third person")
	await capture("ship-thermal")
	manager.toggle_thermal();manager.zoom=false
	for i in 60: manager._process(.016)
	await capture("ship-normal")
	ship.global_position=Vector3(-1200,0,-650);ship.heading=0;ship.rotation=Vector3.ZERO
	manager.sync_occupants(ship);await physics_frame;await physics_frame
	check(manager.release(1),"operator can leave at sea")
	check(actor.vehicle_id.is_empty() and ship.driver==0 and actor.in_water(),"exit clears operator and enters swimming at the surface")
	actor._swim_physics(.016)
	var sequence:=actor.shot_sequence;actor.fire_cooldown=0;actor.fire()
	check(actor.shot_sequence==sequence and actor.swimming,"swimmer cannot fire")
	actor.global_position=p+Vector3(-15,.5,0);actor.swimming=false;actor._update_view()
	manager.set_process(false);camera.make_current();camera.global_position=p+Vector3(-28,8,-70);camera.look_at(p+Vector3(-8,2,-10))
	game.war_clock=GameDayNight.PERIOD*(.5-GameDayNight.START_HOUR/24.) # noon
	await create_timer(.35).timeout
	var grid:=game.power_grid
	var lit:=0
	for pole: WarPowerPole in grid.poles.values():
		if is_instance_valid(pole.lamp) and pole.lamp.visible: lit+=1
	check(lit==0,"street lights remain off during the day")
	game.war_clock=GameDayNight.PERIOD*(1-GameDayNight.START_HOUR/24.)
	await create_timer(.6).timeout
	lit=0
	for pole: WarPowerPole in grid.poles.values():
		if is_instance_valid(pole.lamp) and pole.lamp.visible: lit+=1
	check(lit>0 and lit<=WarPowerGrid.MAX_LIGHTS,"night lights illuminate nearby roads within the global light budget")
	await capture("east-port-night")
	Engine.max_fps=0
	grid.set_process(false)
	for pole: WarPowerPole in grid.poles.values(): pole.set_lit(false)
	await benchmark("night_lights_disabled")
	grid.set_process(true)
	await benchmark("night_lights_enabled")
	Engine.max_fps=60
	var pole:=grid.poles.port_1_1 as WarPowerPole
	var wire_end_before:=pole.attachment()
	game._apply_hit(1,{"collider":pole},55,"chest","fal",Vector3.RIGHT)
	check(not pole.broken and is_equal_approx(pole.hp,65),"pole damage is applied through normal projectile impact")
	game._apply_hit(1,{"collider":pole},80,"chest","fal",Vector3.RIGHT)
	await create_timer(1.8).timeout
	check(pole.broken and not pole.lamp.visible and not grid.poles.port_1_3.energized,"broken pole switches off itself and downstream circuit")
	check(is_instance_valid(pole) and pole.attachment().distance_to(wire_end_before)>4,"broken upper section remains in the world and pulls its attached wires")
	check(pole.upper_collision.get_parent()==pole and pole.upper_collision.position.distance_to(Vector3(0,5.9,0))>1,"falling pole updates its physical collision")
	var saved:=grid.snapshot();var observer:=WarPowerGrid.new();observer.game=game;game.world_root.add_child(observer)
	for state: Array in saved: observer.receive(str(state[0]),float(state[1]),float(state[2]))
	check(observer.poles.port_1_1.broken and not observer.poles.port_1_3.energized,"late state restores broken pole and electrical circuit")
	observer.queue_free()
	await capture("east-port-broken-pole")
	NavalStorage.write_json("res://tests/war184-results.json",{"checks":checks,"failures":failures,"metrics":metrics,"resolution":root.size,"method":"Actual rendered frames, same fixed night camera, 6 seconds per light-budget case; not a 12-player benchmark"})
	game.show_menu();game.queue_free();camera.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
