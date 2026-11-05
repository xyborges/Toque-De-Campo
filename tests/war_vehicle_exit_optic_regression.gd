extends SceneTree

var game: WarGame
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func slab(at: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.collision_layer=1
	var collision:=CollisionShape3D.new()
	var volume:=BoxShape3D.new()
	volume.size=size
	collision.shape=volume
	body.add_child(collision)
	body.position=at
	game.world_root.add_child(body)
	return body

func run() -> void:
	game=load("res://tests/review192_game.gd").new()
	game.offline_operation=true
	game.set_meta("test_mode",true)
	game.set_meta("war_test",true)
	game.set_meta("war_visual_preview",true)
	root.add_child(game)
	game.mode="pvp"
	game.map_kind="desert"
	game._enter_match_world()
	game.join_ready=true
	game.set_physics_process(false)
	var system:=game.vehicle_system as WarVehicles
	system.set_physics_process(false)
	system.set_process(false)
	game.war_fx.set_physics_process(false)
	var actor:=game._spawn_player(1,true,false,Vector3(14,21.1,-15)) as WarPlayer
	actor.set_physics_process(false)
	actor.set_process(false)
	game.members[1]={"team":0,"role":"soldier","deployed":false,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"respawn_pending":false,"shield":0.,"gadget":WarRules.launcher_for_team(0),"pending":{},"last_gadget":-100.}
	var rifle: String=WarRules.TEAM_RIFLES[0]
	var slots:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",0)
	slots.primary=rifle
	slots.sidearm="glock"
	slots.optic="scope4x"
	check(game._deploy(1,0,"soldier",rifle,WarRules.launcher_for_team(0),"base",slots),"deployed real soldier with scoped rifle and pistol")
	game.ui_focus.close_all()
	game.war_ui.deployment.hide()
	actor.weapon_id="glock"
	actor._refresh_weapon()
	check(actor.weapon_optics.selected_weapon=="glock" and actor.weapon_optics.selected_optic.is_empty(),"pistol begins without rifle optical attachment")
	var state: Dictionary=game.members[1].duplicate(true)
	var ride: WarVehicle=system.vehicles.v_guarani
	state.vehicle=ride.vehicle_id
	state.vehicle_seat=0
	state.vehicle_role="operator"
	game.war_identity(1,state)
	check(actor.weapon_id=="glock","boarding identity keeps equipped pistol")
	check(actor.weapon_optics.selected_weapon=="glock" and actor.weapon_optics.selected_optic.is_empty(),"boarding identity does not mount rifle optic on pistol")
	check(actor.weapon_root.find_children("Scope4x","",true,false).is_empty(),"no world optic attached to pistol on boarding")
	check(not is_instance_valid(actor.view_root) or actor.view_root.find_children("Scope4x","",true,false).is_empty(),"no first-person rifle optic left on pistol")
	var changed: Dictionary=state.duplicate(true)
	changed.loadout=state.loadout.duplicate(true)
	changed.loadout.optic="prism4x"
	game.war_identity(1,changed)
	check(actor.weapon_id=="glock" and actor.weapon_optics.selected_weapon=="glock","changed loadout restores actual pistol after temporary rifle")
	check(actor.weapon_root.find_children("Scope4x","",true,false).is_empty(),"changed loadout never mounts scope on pistol")
	state=changed.duplicate(true)
	state.vehicle=""
	state.vehicle_seat=-1
	state.vehicle_role=""
	game.war_identity(1,state)
	actor.restore_infantry_presentation_after_vehicle_exit()
	check(actor.weapon_id=="glock" and actor.weapon_optics.selected_optic.is_empty(),"exiting still has unscoped pistol")
	check(actor.weapon_root.find_children("Scope4x","",true,false).is_empty(),"no floating optic after exiting vehicle")
	actor.weapon_id=rifle
	actor._refresh_weapon()
	check(actor.weapon_optics.selected_optic=="prism4x","rifle retains its dedicated optic after dismount")
	check(actor.weapon_root.find_children("Scope4x","",true,false).size()==1,"rifle optic mounts exactly once")
	actor.weapon_id="glock"
	actor._refresh_weapon()
	check(actor.weapon_root.find_children("Scope4x","",true,false).is_empty(),"changing back to pistol does not carry optics")
	var floor_body:=slab(Vector3(20,20.5,-15),Vector3(65,1,65))
	for candidate: WarVehicle in system.vehicles.values():
		candidate.collision_layer=0
		candidate.global_position=Vector3(250,1,250)
	for kind in ["guarani","bmp2","abrams","t90"]:
		var vehicle: WarVehicle=null
		for candidate: WarVehicle in system.vehicles.values():
			if candidate.kind==kind:vehicle=candidate;break
		if vehicle==null:
			check(false,kind+" spawned")
			continue
		vehicle.global_position=Vector3(20,21.06,-15)
		vehicle.rotation=Vector3.ZERO
		vehicle.heading=0.
		vehicle.collision_layer=1|16
		await physics_frame
		await physics_frame
		var capsule:=CapsuleShape3D.new()
		capsule.radius=.36
		capsule.height=1.8
		var forbidden:=vehicle.global_position+Vector3(0,-1.8,0)
		check(not system._exit_endpoint_outside_hull(vehicle,actor,forbidden,capsule,game.world_root.get_world_3d().direct_space_state),kind+" rejects position under hull even when collider is above")
		var result:=system.safe_exit(vehicle,actor)
		check(bool(result.get("ok",false)),kind+" has a valid side exit on clear raised slab")
		if bool(result.get("ok",false)):
			var at: Vector3=result.position
			var relative:=Basis(Vector3.UP,vehicle.rotation.y).inverse()*(at-vehicle.global_position)
			var half: Vector3=Vector3(vehicle.spec.size)*.5
			check(absf(relative.x)>=half.x+.45 or absf(relative.z)>=half.z+.45,kind+" exit clears the hull footprint")
			check(at.y>21.,kind+" exit remains on top of raised platform")
		vehicle.collision_layer=0
		vehicle.global_position=Vector3(250,1,250)
	floor_body.queue_free()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"War identity scoped rifle/pistol, boarding and exit; all four armoured vehicle capsule and clear raised-platform exit positions."}
	print("WAR_VEHICLE_EXIT_OPTIC ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
