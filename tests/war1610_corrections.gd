extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var samples: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1;print(("PASS " if value else "FAIL ")+message)
	if not value: failures.append(message)
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	game.damage_numbers=GameDamageNumbers.new();game.world_root.add_child(game.damage_numbers)
	var manager:=game.vehicle_system as WarVehicles;manager.set_process(false)
	var actor:=game.local_player as WarPlayer;var target:=game.players[2] as WarPlayer
	var floor:=StaticBody3D.new();floor.collision_layer=1
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(150,1,2200);collider.shape=box;collider.position=Vector3(0,-.5,-900);floor.add_child(collider);game.world_root.add_child(floor)
	var terrain:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(150,2200);terrain.mesh=plane;terrain.position.z=-900;game.world_root.add_child(terrain)
	for vehicle: WarVehicle in manager.vehicles.values(): vehicle.hide();vehicle.collision_layer=0
	var tank:=manager.vehicles.v_abrams as WarVehicle;tank.global_position=Vector3(0,.08,0);tank.rotation=Vector3.ZERO;tank.heading=0;tank.turret_yaw=0;tank.turret.rotation=Vector3.ZERO;tank.allocate_seat(1)
	actor.vehicle_id=tank.vehicle_id;actor.apply_identity(0,"soldier");game.members[1].team=0;game.members[1].vehicle=tank.vehicle_id
	manager.last_controlled=tank.vehicle_id;manager.last_control_role="operator"
	game.members[2].team=1;target.apply_identity(1,"soldier");target.global_position=Vector3(0,.02,-850);target._set_hitboxes_enabled(true)
	await physics_frame;await physics_frame
	check(WarRules.VEHICLES.guarani.gun=="autocannon" and WarRules.VEHICLES.guarani.speed_shot==405 and WarRules.VEHICLES.guarani.blast>0,"Guarani uses30mm ballistics and blast")
	check(WarRules.VEHICLES.abrams.speed_shot==484.5 and WarRules.VEHICLES.t90.speed_shot==476,"both tank shells are15percent slower")
	check(manager.vehicles.v_guarani.capacity()==30 and is_equal_approx(manager.vehicles.v_guarani.muzzle.position.z,-2.2),"Guarani muzzle and magazine match30mm model")
	manager.command_for(1,"weapon",{"slot":2});check(tank.selected=="secondary","2 selects only the secondary")
	manager.command_for(1,"weapon",{"slot":1});check(tank.selected=="primary","1 selects only the main gun")
	manager.command_for(1,"weapon",{"slot":3});check(tank.selected=="primary","unavailable slot3 does not change weapons")
	game.gameplay_input_allowed() # Input tests below also use the real focus gate.
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var key:=InputEventKey.new();key.keycode=KEY_2;key.pressed=true;manager._input(key);check(tank.selected=="secondary","physical key2 reaches vehicle selection")
	key.keycode=KEY_1;manager._input(key);check(tank.selected=="primary","physical key1 reaches vehicle selection")
	# Aim the real muzzle with the analytically required elevation for850m.
	var desired: Vector3=target.hit_regions.chest.global_position
	var origin:=tank.muzzle.global_position;var horizontal:=Vector2(desired.x-origin.x,desired.z-origin.z).length();var vertical:=desired.y-origin.y
	var speed:=float(tank.spec.speed_shot);var gravity:=float(tank.spec.gravity)
	var pitch:=atan((speed*speed-sqrt(pow(speed,4)-gravity*(gravity*horizontal*horizontal+2*vertical*speed*speed)))/(gravity*horizontal))
	tank.gun_pitch=pitch;tank.elevation.rotation.x=pitch;tank.fire_wait=0;tank.ammo=1;tank.reload_left=0;tank.reloading=false
	game.members[2].shield=0;game._register_match_stat(actor);game._register_match_stat(target)
	manager._fire_vehicle(tank)
	var shot: Dictionary=game.war_fx.rounds[game.war_fx.active_slots[-1]]
	check(Vector3(shot.position).distance_to(tank.muzzle.global_position)<.001,"tank shell starts at the actual muzzle")
	for tick in 240:
		if not shot.active: break
		game.war_fx._step(shot,1./120.)
	samples.long_shot={"point":shot.position,"distance":shot.distance,"target_hp":target.hp,"kills":actor.kills,"damage":game.match_stats.rows[1].damage}
	check(target.hp==0 and actor.kills==1 and int(game.match_stats.rows[1].kills)==1,"850m shell kill is attributed to the tank operator")
	check(game.match_stats.rows[1].damage==100 and not game.damage_numbers.active.is_empty(),"850m splash sends actual damage feedback")
	var before:=actor.kills;manager.explode(1,shot.position,600,11,"tank",str(shot.shot_id));check(actor.kills==before,"repeated blast event cannot award another kill")
	# A wall blocks AoE; a body directly hit receives its real contact once.
	target.hp=100;target.deployed=true;game.members[2].deployed=true;target.life_id+=1;target.global_position=Vector3(15,0,-30)
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(8,6,.5);wall_shape.shape=wall_box;wall.position=Vector3(15,2,-28);wall.add_child(wall_shape);game.world_root.add_child(wall)
	await physics_frame;await physics_frame
	manager.explode(1,Vector3(15,.1,-25),600,11,"tank","wall-case")
	check(target.hp==100,"solid wall blocks tank blast")
	wall.queue_free();await physics_frame;await physics_frame
	manager.explode(1,Vector3(15,.1,-25),600,11,"tank","open-case")
	check(target.hp==0 and actor.kills==2,"same exposed target receives splash and kill credit")
	var enemy:=manager.vehicles.v_bmp2 as WarVehicle;enemy.hp=580;enemy.destroyed=false;enemy.global_position=Vector3(0,0,-1200);enemy.show()
	manager.damage_from_hit(1,enemy,100,"tank",Vector3.FORWARD)
	check(manager.last_damage_confirmation.owner==1 and manager.last_damage_confirmation.damage==100,"vehicle HP damage sends feedback to its original shooter")
	tank.selected="secondary";tank.secondary_ammo=1;tank.secondary_reload_left=0;tank.secondary_fire_wait=0
	# APC flight inherits FLIR and permits toggling it without changing seats.
	var apc:=manager.vehicles.v_guarani as WarVehicle;tank.clear_seats();apc.allocate_seat(1);actor.vehicle_id=apc.vehicle_id;game.members[1].vehicle=apc.vehicle_id
	manager.last_controlled=apc.vehicle_id;manager.vehicle_view.external=false
	manager.toggle_thermal();check(manager.thermal,"operator optic activates thermal")
	apc.selected="secondary";manager._fire_vehicle(apc)
	check(manager.tv.viewing() and manager.thermal and manager.thermal_allowed(),"TV camera inherits enabled thermal")
	key.keycode=KEY_T;manager._input(key);check(not manager.thermal,"T can disable FLIR from inside the TV missile")
	manager._input(key);check(manager.thermal,"T can restore FLIR inside the TV missile")
	manager.tv.request_release();manager.vehicle_view.external=true;manager._process(.1)
	check(not manager.thermal,"external hull camera remains nonthermal")
	# Native pixels verify farLOD heat beyond the previous650m cutoff.
	manager.vehicle_view.external=false;manager.toggle_thermal();var thermal:=manager.get_node("Thermal") as WarThermal
	enemy.allocate_seat(2);game.damage_numbers.hide();game.hud_layer.hide()
	manager.camera.make_current();manager.camera.global_position=Vector3(0,4,0);manager.camera.look_at(enemy.global_position+Vector3.UP*1.1);manager.camera.fov=7
	thermal.set_enabled(true);thermal._scan()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.save_png("res://work/thermal1610-1200m.png")
	var pixel:=manager.camera.unproject_position(enemy.global_position+Vector3.UP*1.1)*Vector2(image.get_size())/root.get_visible_rect().size;var brightest:=0.0
	for x in range(int(pixel.x)-18,int(pixel.x)+19):
		for y in range(int(pixel.y)-14,int(pixel.y)+15):
			var color:=image.get_pixel(clampi(x,0,image.get_width()-1),clampi(y,0,image.get_height()-1));brightest=maxf(brightest,color.r)
	samples.camera_fov=manager.camera.fov;samples.enemy_pose=str(enemy.global_position);samples.camera_pose=str(manager.camera.global_position);samples.active_camera=str(root.get_camera_3d());samples.thermal_distance=1200;samples.thermal_peak=brightest
	check(brightest>.72,"vehicle heat remains visible in native pixels at1200m")
	var wall_cover:=StaticBody3D.new();var visual:=MeshInstance3D.new();var cover:=BoxMesh.new();cover.size=Vector3(35,16,1);visual.mesh=cover;visual.material_override=EnvironmentKit.material("concrete:303435");visual.position=Vector3(0,6,-600);game.world_root.add_child(visual)
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	image=root.get_texture().get_image();image.save_png("res://work/thermal1610-occluded.png")
	var covered_peak:=0.0
	for x in range(int(pixel.x)-18,int(pixel.x)+19):
		for y in range(int(pixel.y)-14,int(pixel.y)+15): covered_peak=maxf(covered_peak,image.get_pixel(x,y).r)
	samples.covered_peak=covered_peak;check(covered_peak<brightest-.15,"thermal keeps depth testing behind an opaque wall")
	wall_cover.free()
	var bus_count:=AudioServer.bus_count;GameAudioSettings.ensure();GameAudioSettings.ensure();check(AudioServer.bus_count==bus_count,"audio initialization reuses category buses")
	GameAudioSettings.set_volume("Ambiente",0);check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambiente")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Armas")),"ambient mute preserves combat audio")
	GameAudioSettings.set_volume("Veiculos",.42);GameAudioSettings.flush();GameAudioSettings.loaded_path="";GameAudioSettings.ensure()
	check(absf(GameAudioSettings.get_volume("Veiculos")-.42)<.001,"audio levels persist across reload")
	var result:={"checks":checks,"failures":failures,"samples":samples};FileAccess.open("res://tests/war1610-corrections-results.json",FileAccess.WRITE).store_string(JSON.stringify(result));print(JSON.stringify(result))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
