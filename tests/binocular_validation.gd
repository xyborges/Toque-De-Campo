extends SceneTree

# Functional real-rig checks. This test does not benchmark or certify the
# rendered binocular mask; root runs it before the graphical review.
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var game: WarGame
var actor: WarPlayer
var checks:=0
var failures: Array[String]=[]
var pose_samples: Array[Dictionary]=[]

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)

func equip() -> void:
	actor.hp=100.;actor.deployed=true;actor.vehicle_id=""
	game.members[1].deployed=true;game.members[1].vehicle="";game.members[1].role="marksman"
	actor.apply_identity(0,"marksman")
	game.vehicle_system._set_utility(1,"")
	game.vehicle_system._set_utility(1,"binoculars")
	actor.utility_equip_weight=1.;actor.utility_raise_weight=0.
	actor._utility_pose()

func command_zoom(level: Variant,life: Variant=null) -> void:
	game.vehicle_system.command_for(1,"utility_zoom",{"level":level,"life":actor.life_id if life==null else life})

func contact_check(level: int,pitch: float) -> void:
	actor.pitch=pitch;actor.camera_pivot.rotation.x=pitch
	actor.utility_equip_weight=1.;actor.utility_raise_weight=1. if level>0 else 0.
	actor._animate_walk();actor._utility_pose()
	check(is_instance_valid(actor.utility_model),"reusable binocular model exists")
	if not is_instance_valid(actor.utility_model): return
	var errors: Dictionary={}
	for side in ["L","R"]:
		var hand: Node3D=actor.avatar_parts["arm_"+side.to_lower()].get_node("Hand"+side)
		var marker:=actor.utility_model.get_node("GripLeft" if side=="L" else "GripRight") as Marker3D
		var distance:=hand.global_position.distance_to(marker.global_position)
		errors[side]=distance
		check(distance<.002,"binocular hand contact %s level %d pitch %.2f"%[side,level,pitch])
	check(actor.utility_model.transform.is_finite(),"finite equipment pose")
	check(not actor.weapon_root.visible,"held gun hidden with binoculars")
	if is_instance_valid(actor.view_root): check(not actor.view_root.visible,"first-person gun hidden with binoculars")
	if is_instance_valid(game.scope_overlay): check(not game.scope_overlay.visible,"sniper scope is not reused for binoculars")
	if is_instance_valid(game.aim_dot): check(not game.aim_dot.visible,"gun reticle hidden with binoculars")
	pose_samples.append({"level":level,"pitch":pitch,"hands":errors,"position":actor.utility_model.position})

func command_validation() -> void:
	equip();command_zoom(1)
	check(actor.utility_zoom==1 and int(game.members[1].utility_zoom)==1,"authority accepts zoom and stores member state")
	for bad in ["2",2.0,NAN,INF,-1,3,null,{},true]:
		command_zoom(bad)
		check(actor.utility_zoom==1,"invalid zoom rejected: "+str(bad))
	for bad_life in [actor.life_id-1,actor.life_id+1,"1",1.0,NAN]:
		command_zoom(2,bad_life)
		check(actor.utility_zoom==1,"invalid or stale life rejected: "+str(bad_life))
	game.vehicle_system.command_for(1,"utility_zoom",{"level":2})
	check(actor.utility_zoom==1,"life is mandatory")
	actor.apply_identity(0,"soldier");game.members[1].role="soldier"
	command_zoom(2);check(actor.utility_zoom==1,"wrong class cannot control binocular zoom")
	actor.apply_identity(0,"marksman");game.members[1].role="marksman"
	actor.vehicle_id="v_guarani";game.members[1].vehicle="v_guarani"
	actor.set_utility_zoom(0);command_zoom(2)
	check(actor.utility_zoom==0,"vehicle occupant cannot activate binocular zoom")
	actor.vehicle_id="";game.members[1].vehicle=""
	actor.deployed=false;game.members[1].deployed=false
	command_zoom(2);check(actor.utility_zoom==0,"undeployed player cannot activate binocular zoom")
	actor.deployed=true;game.members[1].deployed=true
	# Exercise the real terrain/water predicate rather than replacing it.
	var old_position:=actor.global_position
	var ocean:=Vector3(WarTerrain.HALF-10.,-1.,WarTerrain.HALF-10.)
	actor.global_position=ocean
	check(actor.in_water(),"water case uses a real submerged coastal coordinate")
	command_zoom(2);check(actor.utility_zoom==0,"submerged player cannot activate binocular zoom")
	actor.global_position=old_position
	actor.hp=0.;command_zoom(2)
	check(actor.utility_zoom==0,"dead player cannot activate binocular zoom")
	actor.hp=100.
	actor.set_utility_zoom(1)
	game.vehicle_system.utility_zoom_state(1,actor.life_id-1,2)
	check(actor.utility_zoom==1,"stale authority zoom event cannot affect a new life")
	game.vehicle_system.utility_zoom_state(1,actor.life_id,2)
	check(actor.utility_zoom==2,"matching authority zoom event applies")
	game.vehicle_system._set_utility(1,"")
	check(actor.utility_zoom==0 and int(game.members[1].utility_zoom)==0,"clearing utility clears member and actor zoom")

func blocked_weapon_actions() -> void:
	equip()
	actor.weapon_id="fal";actor._refresh_weapon();actor._utility_pose()
	actor.ammo.fal=1;actor.reserves.fal=20;actor.fire_cooldown=0.;actor.reload_left=0.;actor.reload_weapon="";actor.paused_reloads.clear()
	var ammo_before: Dictionary=actor.ammo.duplicate(true)
	var reserves_before: Dictionary=actor.reserves.duplicate(true)
	var sequence_before:=actor.shot_sequence
	# Bypass only the local input focus gate: the real utility/fire guard must
	# prevent firing even for authoritative remote actors and bots.
	actor.is_local=false;actor.fire();actor.is_local=true
	check(actor.ammo==ammo_before and actor.shot_sequence==sequence_before,"binoculars cannot fire the stowed gun")
	actor.start_reload()
	check(actor.reload_left==0. and actor.reload_weapon.is_empty(),"binoculars block direct local reload")
	game._server_reload(1,"fal")
	check(actor.reload_left==0. and actor.reload_weapon.is_empty(),"authority blocks reload of the stowed gun")
	check(actor.ammo==ammo_before and actor.reserves==reserves_before,"blocked actions preserve ammunition")
	actor.hp=0.;actor.set_utility_zoom(1);actor.start_reload();actor.fire()
	check(actor.utility_zoom==0 and actor.reload_left==0. and actor.ammo==ammo_before,"death blocks optics and gun actions")
	actor.hp=100.;game.vehicle_system._set_utility(1,"")

func late_identity() -> void:
	equip()
	var data: Dictionary=game.members[1].duplicate(true)
	data.utility="binoculars";data.utility_zoom=2
	game.war_identity(1,data)
	check(actor.utility_mode=="binoculars" and actor.utility_zoom==2,"late identity restores held binoculars and zoom")
	data.erase("utility_zoom");game.war_identity(1,data)
	check(actor.utility_mode=="binoculars" and actor.utility_zoom==0,"older identity without zoom uses zero")
	data.utility_zoom=2;data.vehicle="v_guarani";game.war_identity(1,data)
	check(actor.utility_mode.is_empty() and actor.utility_zoom==0,"late occupied identity cannot open infantry optics")
	data.vehicle="";data.utility="";data.utility_zoom=0;game.war_identity(1,data)

func run() -> void:
	game=FIXTURE.new();root.add_child(game)
	await process_frame;await physics_frame
	actor=game.local_player as WarPlayer
	actor.set_process(false);actor.set_physics_process(false)
	check(game.world_root.get_node_or_null("VegetationVisuals")==null,"isolated equipment fixture allocates no grass controller")
	for third_person in [false,true]:
		game.third_person=third_person;actor._update_view()
		var normal_fov:=actor.camera.fov
		equip()
		var model_id:=actor.utility_model.get_instance_id()
		for level in [0,1,2,0]:
			command_zoom(level)
			check(actor.utility_zoom==level,"zoom cycle accepts level "+str(level))
			check(game.third_person==third_person,"zoom preserves preferred perspective")
			if level>0:
				check(is_equal_approx(actor.camera.fov,20. if level==1 else 10.),"binocular magnification uses camera FOV")
				check(actor.camera.get_parent()==actor.camera_pivot,"optics use head camera")
			else:
				check(is_equal_approx(actor.camera.fov,normal_fov),"lowered binoculars restore normal FOV")
				check(actor.camera.get_parent()==(actor.shoulder_arm if third_person else actor.camera_pivot),"lowered binoculars restore camera parent")
			for pitch in [-.60,0.,.60]: contact_check(level,pitch)
			check(actor.utility_model.get_instance_id()==model_id,"pose and zoom reuse the same held model")
		if DisplayServer.get_name()=="headless": check(not is_instance_valid(actor.binocular_overlay),"headless creates no optical overlay")
		game.vehicle_system._set_utility(1,"")
		check(actor.utility_zoom==0 and actor.utility_model==null and actor.utility_view==null,"unequip clears optical state and presentations")
		check(is_equal_approx(actor.camera.fov,normal_fov) and game.third_person==third_person,"unequip restores perspective and FOV")
		await process_frame
	command_validation();blocked_weapon_actions();late_identity()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"poses":pose_samples,"headless":DisplayServer.get_name()=="headless","scope":"Real War rig/authority commands, equipment grips, lifecycle and camera. Not network transport, rendered optical-mask QA or performance acceptance."}
	NavalStorage.write_json("res://work/binocular-validation.json",report)
	print("BINOCULAR_VALIDATION ",JSON.stringify({"ok":report.ok,"checks":checks,"failures":failures}))
	game.show_menu();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
