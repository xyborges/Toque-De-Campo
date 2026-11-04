extends SceneTree
var output_root:="res://work"
var report_name:="res://tests/war-coast172-results.json"
var checks:=0
var failures: Array[String]=[]
var samples: Dictionary={}
var game: WarGame
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--coast-report-root="): output_root=arg.trim_prefix("--coast-report-root=");report_name=output_root.path_join("war-coast172-results.json")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(id: String,camera: Camera3D,point: Vector3,look: Vector3) -> void:
	camera.global_position=point;camera.look_at(look);camera.make_current()
	await create_timer(.35).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_root.path_join("coast172-"+id+".png"))
func run() -> void:
	check(WarTerrain.HALF==1750,"playable square is3500m by3500m")
	for side in [-1.,1.]:
		for offset in [-1400.,0.,1400.]: check(WarCoast.wet(side*1730,offset) and WarCoast.wet(offset,side*1730),"all borders lie in the surrounding sea")
	for team in 2:
		for point: Vector3 in WarCoast.BERTHS[team]: check(WarTerrain.height_at(point.x,point.z)<-1,"every berth is deep enough for its hull")
	check(WarWeather.intensity(0)==0 and WarWeather.intensity(600)>.95 and WarWeather.intensity(700)==0,"occasional shower has smooth entry and exit")
	var calm:=absf(WarCoast.wave(Vector3(500,0,700),100));var rain:=WarWeather.intensity(600)
	check(rain>.9 and calm>=0,"weather is deterministic from the shared match clock")
	var motion:=GameSnapshotMotion.new()
	for index in 12: motion.push(Vector3(index*2.5,0,0),Vector3(25,0,0),Vector3.ZERO,index*.1)
	var previous:=motion.sample(.72).origin;var minimum:=100.;var maximum:=0.
	for frame in range(1,19):
		var point:=motion.sample(.72+frame/60.).origin;var distance:=point.x-previous.x;minimum=minf(minimum,distance);maximum=maxf(maximum,distance);previous=point
	check(minimum>.39 and maximum<.44,"snapshot buffer moves continuously at25m/s between100ms packets")
	samples.motion_min=minimum;samples.motion_max=maximum
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+40000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	check(game.join_ready,"full offline War map initializes")
	if not game.join_ready: finish();return
	game.war_ui.deploy_button.pressed.emit()
	await create_timer(.7).timeout
	game.set_physics_process(false)
	if game.bot_director: game.bot_director.set_physics_process(false)
	game.vehicle_system.set_physics_process(false);game.vehicle_system.set_process(false)
	for actor: WarPlayer in game.players.values(): actor.set_physics_process(false)
	check(game.world_root.get_meta("war_map_size",0)==3500 and game.world_root.get_meta("war_ports",0)==2 and game.world_root.get_meta("war_bays",0)==1,"full map contains exactly two ports and one bay")
	check(game.world_root.get_meta("war_outer_villages",0)==4 and game.world_root.get_meta("war_tree_count",0)>2000,"villages and expanded batched vegetation populate the land")
	var ships:=0
	for v: WarVehicle in game.vehicle_system.vehicles.values():
		if not v is WarShip: continue
		ships+=1;check(v.seat_capacity()==7 and v.hull.turrets.size()==4,"ship has one operator, six troop seats, and four original naval weapons")
		v.set_meta("size_bytes",var_to_bytes(v.snapshot()).size())
		check(var_to_bytes(v.snapshot()).size()<1350,"single-ship snapshot fits the UDP payload budget")
		check(v.naval_kind in ["heavy","assault"],"only frigate and assault ships are deployed")
	check(ships==4,"two requested ships per team port")
	var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
	var cabin:=ship.get_node("BridgeCollision") as CollisionShape3D
	check(not AABB(-(cabin.shape as BoxShape3D).size*.5,(cabin.shape as BoxShape3D).size).has_point(cabin.to_local(ship.optic.global_position)),"ship optic sits outside the cabin collision volume")
	await physics_frame
	var cabin_query:=PhysicsRayQueryParameters3D.create(cabin.global_position+Vector3.UP*6,cabin.global_position,1|16)
	var cabin_hit:=ship.get_world_3d().direct_space_state.intersect_ray(cabin_query)
	check(cabin_hit.get("collider")==ship,"upper cabin receives actual projectile contacts on the ship body")
	var actor:=game.local_player as WarPlayer;actor.apply_identity(0,"soldier");game.members[1].team=0;game.members[1].shield=0.
	actor.global_position=ship.global_position+Vector3(0,4.2,6.2)
	game.vehicle_system.command_for(1,"enter",{"id":ship.vehicle_id})
	check(ship.driver==1 and ship.seat_of(1)==0 and actor.vehicle_id==ship.vehicle_id,"pier boarding uses authoritative operator allocation")
	ship.choose_weapon(3);check(ship.naval_weapon=="missile","keys1–4 select the actual naval weapons")
	var seat:=ship.to_global(ship.seat_position(1))+Vector3.UP
	ship.allocate_seat(2)
	ship.muzzle.look_at(seat)
	check(ship.protected_lane(),"server protects occupied troop seats from turret firing")
	ship.vacate_seat(2,false)
	var exit: Dictionary=game.vehicle_system.safe_exit(ship,actor)
	check(bool(exit.get("ok",false)),"ship finds a dry collision-free exit on its pier")
	check(WarRules.OBJECTIVES.D.active and WarRules.OBJECTIVES.E.active,"both ports are active capture objectives")
	game.objective_states.D.owner=1;ship.clear_seats();game.vehicle_system._step_port_control()
	check(ship.team==1,"capturing the port transfers only unoccupied ships")
	ship.allocate_seat(1);game.objective_states.D.owner=0;game.vehicle_system._step_port_control()
	check(ship.team==1 and ship.driver==1,"capture does not hijack an occupied ship")
	ship.clear_seats();game.vehicle_system._step_port_control()
	game.members[1].vehicle="";actor.vehicle_id="";actor.global_position=WarRules.BASES[0]+Vector3.UP*.2;actor._update_view()
	check(game.world_root.get_meta("war_city_quarters",0)==10 and game.world_root.get_meta("war_road_links",0)==6,"ten urban quarters and six interregional road links exist")
	var camera:=Camera3D.new();camera.far=5000;root.add_child(camera)
	camera.position=ship.global_position+Vector3(0,8,20);camera.look_at(ship.global_position);camera.make_current()
	game.remote_surface_impact("spark172",ship.global_position+Vector3.UP*2,"vehicle",Vector3.UP)
	check(game.metal_sparks.cursor==8,"metal impact emits bounded physical-position sparks")
	await capture("seats",camera,ship.global_position+Vector3(-14,8,-14),ship.global_position+Vector3.UP)
	game.war_clock=100
	await capture("bay",camera,Vector3(-1160,110,-650),Vector3(-890,8,-430))
	await capture("port",camera,Vector3(1480,95,700),Vector3(1200,5,470))
	await capture("village",camera,WarTerrain.point(-570,560)+Vector3(0,25,-50),WarTerrain.point(-610,610)+Vector3.UP*4)
	game.weather_seed=0;WarWeather.seed=0;game.war_clock=600;await create_timer(.5).timeout
	await capture("rain",camera,Vector3(-1020,14,-520),Vector3(-870,5,-430))
	game.war_clock=100
	await capture("town",camera,WarTerrain.point(-625,-440)+Vector3(22,16,-42),WarTerrain.point(-625,-430)+Vector3.UP*5)
	await capture("wheat",camera,WarTerrain.point(-590,370)+Vector3(0,2,-40),WarTerrain.point(-590,420)+Vector3.UP)
	await capture("pines",camera,WarTerrain.point(-650,850)+Vector3(8,2,-32),WarTerrain.point(-650,880)+Vector3.UP*4)
	# Actual infantry controller in deep water: one second of swimming.
	actor.global_position=Vector3(-1150,-.85,-485);actor.vehicle_id="";actor.hp=100;actor.deployed=true
	actor.body_collision.disabled=false;actor._set_hitboxes_enabled(true);game.third_person=true
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	Input.action_press("move_forward")
	var swim_origin:=actor.global_position
	for frame in 60:
		game.war_clock+=1./60;actor._swim_physics(1./60)
	Input.action_release("move_forward")
	check(actor.swimming and actor.in_water() and absf(actor.body_root.rotation.x)>1,"swimming uses a horizontal animated body")
	check(actor.global_position.distance_to(swim_origin)>1.5,"swim controller moves the character through water")
	check(not actor.weapon_root.visible and not actor._uses_first_person_presentation(),"swimming hides both weapon presentations")
	check(not game.grenade_allowed(actor),"authority rejects cooking or throwing grenades in water")
	var equipped:=actor.weapon_id;actor.equip_quick_slot(1);check(actor.weapon_id==equipped,"water prevents weapon selection")
	var bullets: int=game.war_fx.active_slots.size();game._server_accept_shot(1,500,actor.life_id,actor.camera.global_position,Vector3.FORWARD,"fal")
	check(game.war_fx.active_slots.size()==bullets,"authority rejects firearm packets from a swimmer")
	await capture("swimming",camera,actor.global_position+Vector3(5,2,4),actor.global_position+Vector3.UP)
	game.third_person=false;actor._update_view();actor._swim_physics(1./60)
	check(actor.avatar_parts.arm_l.visible and actor.avatar_parts.arm_r.visible and not actor.avatar_parts.head.visible,"FPP swimming reuses the world arms without showing the weapon or head")
	actor.camera.make_current();await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output_root.path_join("coast172-swimming-fpp.png"))
	actor.global_position=WarRules.BASES[0]+Vector3.UP*.2;actor.war_class="antitank";actor.set_gadget(true,WarRules.launcher_for_team(0))
	actor.global_position=Vector3(-1150,-.85,-485);actor.swimming=false;actor._swim_physics(1./60)
	check(actor.gadget_equipped and not actor.weapon_root.visible,"swimming suppresses a launcher without losing its equipped state")
	actor.global_position=WarRules.BASES[0]+Vector3.UP*.2;actor._physics_process(1./60)
	check(not actor.swimming and actor.gadget_equipped and is_instance_valid(actor.launcher_model) and actor.launcher_model.visible,"launcher presentation is restored after reaching dry ground")
	var core_node:=game.war_fx.get_children()[0] as MultiMeshInstance3D
	check(core_node.custom_aabb.has_point(Vector3(1740,0,1740)),"projectile render bounds cover the expanded map corners")
	var tank:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	tank.global_position=Vector3(-1020,2.65,-479.2);tank.destroyed=false;tank.hp=float(tank.spec.hp);tank.velocity=Vector3.ZERO
	await physics_frame
	tank.simulate(1./60,{})
	check(not tank.destroyed,"land vehicle on a dry pier over deep water is not flooded")
	var crew: Array[int]=[1,WarBotDirector.FIRST_ID]
	for id in crew:
		var occupant:=game.players[id] as WarPlayer
		occupant.hp=100;occupant.deployed=true;occupant.vehicle_id=tank.vehicle_id
		game.members[id].vehicle=tank.vehicle_id;game.members[id].shield=0.;tank.allocate_seat(id)
	tank.global_position=Vector3(-1150,-.85,-485);tank.velocity=Vector3.ZERO
	await physics_frame
	tank.simulate(1./60,{})
	check(tank.destroyed and tank.hp==0 and tank.respawn_left>0,"terrestrial vehicle entering sea is destroyed and enters its respawn timer")
	check(game.players[crew[0]].hp==0 and game.players[crew[1]].hp==0 and tank.seats.is_empty(),"flooding kills the operator and passenger and clears every seat")
	samples.trees=game.world_root.get_meta("war_tree_count",0);samples.grass=game.world_root.get_meta("war_grass_count",0);samples.nodes=get_node_count()
	finish()
func finish() -> void:
	var result:={"checks":checks,"failures":failures,"samples":samples,"native":true}
	FileAccess.open(report_name,FileAccess.WRITE).store_string(JSON.stringify(result));print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)


