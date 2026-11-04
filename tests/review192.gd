extends SceneTree
var game: WarGame
var manager: WarVehicles
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func block(point: Vector3,extent: Vector3) -> StaticBody3D:
	var node:=StaticBody3D.new();node.position=point;node.collision_layer=1
	var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=extent;c.shape=shape;node.add_child(c);game.world_root.add_child(node);return node
func member(id: int,team: int,local:=false) -> WarPlayer:
	var actor:=game._spawn_player(id,local,false,Vector3(id*8,0,-10)) as WarPlayer
	actor.set_physics_process(false)
	game.members[id]={"team":team,"role":"soldier","deployed":false,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"respawn_pending":false,"shield":0.,"gadget":WarRules.launcher_for_team(team),"pending":{},"last_gadget":-100.}
	game._deploy(id,team,"soldier",WarRules.TEAM_RIFLES[team],WarRules.launcher_for_team(team),"base")
	game.members[id].shield=0.
	return actor
func run() -> void:
	game=load("res://tests/review192_game.gd").new();game.offline_operation=true;game.set_meta("test_mode",true);game.set_meta("war_test",true);game.set_meta("war_visual_preview",true);root.add_child(game)
	game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.join_ready=true;game.set_physics_process(false)
	manager=game.vehicle_system;manager.set_physics_process(false);manager.set_process(false);game.war_fx.set_physics_process(false)
	var actor:=member(1,0,true);var enemy:=member(2,1)
	game.ui_focus.close_all();game.war_ui.deployment.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var apc:=manager.vehicles.v_guarani as WarVehicle
	for vehicle: WarVehicle in manager.vehicles.values(): vehicle.collision_layer=0;vehicle.position=Vector3(500,0,500)
	apc.position=Vector3(20,21.06,-15);apc.heading=0;apc.rotation=Vector3.ZERO;apc.collision_layer=17
	var slab:=block(Vector3(20,20.5,-15),Vector3(35,1,35))
	apc.allocate_seat(1);actor.vehicle_id=apc.vehicle_id;game.members[1].vehicle=apc.vehicle_id;manager.sync_occupants(apc)
	actor.body_collision.disabled=true
	await physics_frame;await physics_frame
	var exit:=manager.safe_exit(apc,actor)
	check(bool(exit.get("ok",false)) and float(Vector3(exit.get("position",Vector3.ZERO)).y)>21.,"raised collision slab, rather than buried terrain, supports the APC exit")
	var wall:=block(apc.position+Vector3(-3,2,0),Vector3(1,5,18));await physics_frame;await physics_frame
	exit=manager.safe_exit(apc,actor)
	check(bool(exit.get("ok",false)) and Vector3(exit.position).x>apc.position.x,"blocked left exits fall back to the clear right side")
	wall.queue_free();await physics_frame;await physics_frame
	check(manager.release(1) and actor.vehicle_id.is_empty() and actor.hp==100,"normal exit clears occupation without changing life or health")
	apc.allocate_seat(1);actor.vehicle_id=apc.vehicle_id;game.members[1].vehicle=apc.vehicle_id;manager.sync_occupants(apc)
	var cage:=block(apc.position+Vector3.UP*3,Vector3(30,9,30));await physics_frame;await physics_frame
	check(not manager.release(1) and apc.driver==1,"fully blocked perimeter keeps the reservation and never teleports through a wall")
	cage.queue_free();await physics_frame;await physics_frame
	manager.release(1);actor.position=Vector3(-20,0,0)
	var tank:=manager.vehicles.v_abrams as WarVehicle;tank.position=Vector3(0,.03,0);tank.rotation=Vector3.ZERO;tank.heading=0;tank.collision_layer=17
	var barrier:=block(Vector3(0,2,-5),Vector3(12,4,1));await physics_frame;await physics_frame
	tank.speed=8
	for i in 120: tank.simulate(1./60.,{"throttle":1.,"aim":Vector3(0,2,-500)});await physics_frame
	check(absf(tank.speed)<.2,"wall contact removes stored forward speed")
	var old_z:=tank.position.z
	for i in 12: tank.simulate(1./60.,{"throttle":-1.,"aim":Vector3(0,2,-500)});await physics_frame
	check(tank.speed<-.2 and tank.position.z>old_z,"reverse responds immediately after a blocked forward command")
	barrier.queue_free();await physics_frame
	apc.allocate_seat(1);actor.vehicle_id=apc.vehicle_id;game.members[1].vehicle=apc.vehicle_id;manager.last_controlled=apc.vehicle_id;manager.last_control_role="operator"
	manager.orbit_yaw=0;manager.orbit_pitch=0;manager.vehicle_view.reset(false)
	manager.vehicle_view.update(manager,apc,true,1./60.)
	var height:=manager.camera.position.y
	manager.orbit_pitch=.5;apc.aim(1.,apc.position+Vector3(0,100,-200),true)
	manager.vehicle_view.update(manager,apc,true,1./60.)
	check(absf(manager.camera.position.y-height)<.001,"raising the physical barrel cannot lift the seated optic camera")
	manager.orbit_yaw=-.7;manager.vehicle_view.update(manager,apc,true,1./60.)
	var intent:=manager.camera.unproject_position(manager.vehicle_view.intent_point)
	check(intent.distance_to(root.get_visible_rect().size*.5)>20,"immediate intent cue can move away from the actual gun sight")
	var before_height:=manager.camera.position.y
	for i in 30:
		manager._present_shot(1,apc.muzzle.global_position,Vector3.FORWARD,"hmg","test-mg-"+str(i));manager.vehicle_view.update(manager,apc,true,1./60.)
	check(absf(manager.camera.position.y-before_height)<.001 and manager.hull_shock==0,"machine-gun burst adds no vertical camera translation or cumulative shake")
	manager.release(1,true);actor.position=Vector3(-20,0,0);enemy.position=Vector3(20,0,20);game.members[2].shield=0
	var point: Vector3=enemy.hit_regions.chest.global_position
	manager.explode(1,point,52,4.3,"autocannon","review-direct30",{"collider":enemy.hit_regions.chest,"position":point,"normal":Vector3.UP},150.)
	check(enemy.hp==0,"30 mm direct infantry contact is lethal using real blast exposure and damage")
	check(game.elimination_events.size()==1 and not game.elimination_events[0][1],"enemy kill sends one private positive confirmation")
	var armor_hp:=apc.hp
	manager.damage_from_hit(1,apc,52,"autocannon",Vector3.FORWARD)
	check(is_equal_approx(armor_hp-apc.hp,52.),"30 mm armor damage remains independent of the increased infantry damage")
	game.objective_states.B.owner=0
	game._deploy(1,0,"medic","fal","stinger","B")
	var life:=actor.life_id;actor.hp=0;actor.deployed=false;game._on_player_died(actor,2)
	var ready:=float(game.members[1].ready_at)
	game.war_clock=ready-.01;game._process_queued_deployments()
	check(actor.hp==0 and actor.life_id==life,"death preserves the eight-second gate")
	game.war_clock=ready+.01;game._process_queued_deployments();game._physics_process(0.)
	check(actor.hp==0 and game.war_ui.deployment.visible,"eight seconds opens the deployment map without automatic respawn")
	check(game.war_ui.role()=="medic" and str(game.war_ui.spawn_select.get_item_metadata(game.war_ui.spawn_select.selected))=="B","next-life class and objective are restored for review")
	game.objective_states.B.owner=1;game.war_ui.refresh_spawns();game.war_ui._process(.11)
	check(game.war_ui.invalid_spawn and game.war_ui.deploy_button.disabled,"lost selected objective requires an explicit new spawn choice")
	var map:=game.war_ui.deployment_map;map.size=Vector2(600,500);map.region=map.map_rect()
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=map.project(WarRules.BASES[0]);map._gui_input(click)
	check(not game.war_ui.invalid_spawn and map.selected_spawn=="base","clicking a valid base on the shared map selects a legal spawn")
	game.war_ui._deploy()
	check(actor.hp==100 and actor.life_id==life+1 and actor.war_class=="medic","explicit confirmation creates one new life with the reviewed loadout")
	actor.position=Vector3(WarCoast.PORTS[1].x,4.1,WarCoast.PORTS[1].z)
	var at:=actor.position;game.war_clock+=150
	game.war_safe_reset(1);game._physics_process(.01)
	check(actor.position.distance_to(at)<.01 and not game.war_ui.deployment.visible,"standing alive at the port does not open deployment or teleport to base")
	var fresh: Dictionary=WarRules.fresh_objectives().B
	var more:=WarRules.capture(fresh.duplicate(true),[3,1],1.)
	var one:=WarRules.capture(fresh.duplicate(true),[1,0],1.)
	var tied:=WarRules.capture(more.duplicate(true),[2,2],1.)
	check(float(more.progress)>float(one.progress) and float(more.progress)<.2,"capture superiority accelerates moderately rather than instantly")
	check(tied.contested and is_equal_approx(float(tied.progress),float(more.progress)),"equal forces contest and freeze the authoritative capture progress")
	actor.position=WarTerrain.point(WarRules.OBJECTIVES.B.position.x,WarRules.OBJECTIVES.B.position.z);game.objective_states.B=more;game.war_ui._refresh_capture(actor)
	check(game.war_ui.capture_panel.visible and "CAPTURANDO" in game.war_ui.capture_label.text,"capture HUD uses the actual shared objective state")
	WarWeather.seed=6
	check(WarWeather.intensity(205)>.5 and float(GameDayNight.sample(205).daylight)>.9,"seeded showers can occur in daylight without client random rolls")
	check(WarRules.OBJECTIVES.B.position.distance_to(WarRules.OBJECTIVES.C.position)>320,"B and C are separated along distinct village/trench positions")

	actor.position=Vector3.ZERO;actor.weapon_id="fal";actor._refresh_weapon();actor.fire_cooldown=0
	var saved_enemy: Dictionary=game.members[2].duplicate(true)
	game.members.erase(2)
	var ammo_before:=int(actor.ammo.fal);var shots_before:=actor.shot_sequence
	actor.fire();game.war_ui._process(.11)
	check(int(actor.ammo.fal)==ammo_before and actor.shot_sequence==shots_before and game.war_ui.waiting_panel.visible,"solo waiting blocks prediction before ammunition/recoil and displays the actual reason")
	game._server_accept_shot(1,999,actor.life_id,actor.camera.global_position,Vector3.FORWARD,"fal",0)
	check(int(game.shot_sequences.get(1,0))==999 and int(actor.ammo.fal)==ammo_before,"rejected waiting-state shots acknowledge inventory without spawning ghost projectiles")
	game.members[2]=saved_enemy;enemy.hp=100;enemy.deployed=true
	game.war_ui._process(.11)
	check(game._battle_active() and not game.war_ui.waiting_panel.visible,"returning opposing player releases the waiting gate without restarting the match")
	var report:={"checks":checks,"failures":failures,"native":DisplayServer.get_name()!="headless"}
	NavalStorage.write_json("res://work/review192-results.json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
