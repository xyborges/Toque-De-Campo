extends SceneTree
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var game: WarGame
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: errors.append(label);print("FAIL ",label)
func run() -> void:
	game=FIXTURE.new();root.add_child(game);await process_frame
	var actor:=game.local_player as WarPlayer
	var optics: RefCounted=actor.weapon_optics
	var all_weapons:=GameWeapons.INFANTRY_IDS
	for mode in ["offline","desert","war"]:
		for team in [0,1]:
			var base:=GameLoadouts.defaults(mode,all_weapons,"soldier",team)
			check(not base.has("optic"),"legacy defaults have no forced scope")
			var input:=base.duplicate();input.optic="scope4x"
			check(GameLoadouts.validate(input,mode,all_weapons,"soldier",team).ok,"supported rifle accepts optional scope")
			input.optic="forged";check(not GameLoadouts.validate(input,mode,all_weapons,"soldier",team).ok,"unknown optic rejected")
	var sniper:={"primary":"sniper","optic":"scope4x"}
	check(GameLoadouts.validate(sniper,"desert",all_weapons).ok,"4x can attach to sniper")
	check(GameLoadouts.validate(sniper,"desert",all_weapons,"soldier",0,true).slots.has("optic"),"repair preserves compatible sniper optic")
	for weapon in ["fal","ak"]:
		actor.weapon_id=weapon;actor.set_meta("weapon_optics",{});actor._refresh_weapon()
		var muzzle:=actor.get_muzzle_position()
		actor.set_meta("weapon_optics",{weapon:"scope4x"});actor.refresh_weapon_optics();actor._update_view()
		check(actor.weapon_root.find_children("Scope4x","",true,false).size()==1,"one world attachment "+weapon)
		check(actor.view_root.find_children("Scope4x","",true,false).size()==1,"one FPP attachment "+weapon)
		check(actor.get_muzzle_position().distance_to(muzzle)<.00001,"attachment does not move muzzle "+weapon)
		actor.clear_aim();actor.cycle_weapon_aim()
		check(actor.iron_sights and not actor.uses_telescopic_sight(),"single click raises physical optic without full-screen scope "+weapon)
		check(actor.view_root.visible,"real rifle remains visible while aiming "+weapon)
		actor.cycle_weapon_aim();check(not actor.aiming and not actor.iron_sights,"second click returns to prior perspective "+weapon)
		for i in 3: actor.refresh_weapon_optics();actor._update_view()
		check(actor.weapon_root.find_children("Scope4x","",true,false).size()==1,"repeated refresh reuses attachment "+weapon)
		check(not is_instance_valid(optics.view),"no rendering viewport for headless or lowered optics")
		actor.set_meta("weapon_optics",{});actor.refresh_weapon_optics();actor._update_view()
		check(actor.weapon_root.find_child("Scope4x",true,false)==null,"optional attachment removes cleanly "+weapon)
	var manager:=game.vehicle_system as WarVehicles
	var bikes: Array=[]
	for v: WarVehicle in manager.vehicles.values():
		if bool(v.spec.get("transport",false)): bikes.append(v)
	check(bikes.size()==6,"six motorcycles total")
	for team in [0,1]: check(bikes.filter(func(v):return v.team==team).size()==3,"three bikes per team")
	var bike: WarVehicle=bikes[0]
	# A real flat support near the real spawn gives safe_exit/respawn their
	# normal shape queries instead of replacing those authority functions.
	var floor_body:=StaticBody3D.new();var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(100,.2,100);floor_shape.shape=box;floor_body.add_child(floor_shape)
	floor_body.position=Vector3(bike.position.x,bike.position.y-.1,bike.position.z);game.world_root.add_child(floor_body)
	await physics_frame
	actor.hp=100.;actor.deployed=true;actor.apply_identity(bike.team,"soldier")
	game.members[1].team=bike.team;game.members[1].role="soldier";game.members[1].deployed=true
	actor.position=bike.position+Vector3(2.,.15,0)
	manager.command_for(1,"enter",{"id":bike.vehicle_id});await physics_frame
	check(bike.driver==1 and actor.vehicle_id==bike.vehicle_id,"authority reserves motorcycle seat")
	manager.sync_occupants(bike);actor._physics_process(.016)
	check(actor.body_root.visible and not actor.weapon_root.visible,"seated rider visible, rifle hidden")
	check(not actor.hit_regions.chest.get_child(0).disabled,"rider remains vulnerable")
	var before:=bike.shot_sequence
	manager.command_for(1,"weapon",{"slot":2});manager._fire_vehicle(bike)
	check(bike.selected=="primary" and bike.shot_sequence==before,"transport cannot select or fire a mounted weapon")
	bike.position.x+=6.;bike.abandoned_left=.01
	check(not bike.abandoned_return_due(185.),"occupied bike never returns to base")
	check(manager.release(1),"rider can exit safely")
	check(actor.vehicle_id.is_empty() and bike.driver==0,"exit clears reservation")
	await physics_frame
	check(not actor.body_collision.disabled,"exit restores character collider")
	bike.position.x+=6.;bike.reset_abandonment()
	check(not bike.abandoned_return_due(179.),"abandoned timer does not expire before 180 seconds")
	check(bike.abandoned_return_due(1.),"abandoned timer reaches 180 seconds")
	var hp:=bike.hp;manager.damage_from_hit(2,bike,20.,"ak",Vector3.FORWARD)
	check(bike.hp==hp-20.,"unarmored bike accepts infantry damage")
	manager.damage_from_hit(2,bike,1000.,"ak",Vector3.FORWARD)
	check(bike.destroyed and bike.respawn_left==15. and bike.snapshot().respawn==15,"destroyed bike gets replicated 15 second timer")
	# Do not block the spawn during this test.
	actor.position+=Vector3(20,0,20)
	manager._step_vehicle_respawns(14.9);check(bike.destroyed,"respawn not before 15 seconds")
	manager._step_vehicle_respawns(.1);await physics_frame
	check(not bike.destroyed and bike.hp==float(bike.spec.hp),"motorcycle respawns with full health")
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors}
	NavalStorage.write_json("res://work/optics-transport-validation.json",report);print("OPTICS_TRANSPORT ",JSON.stringify(report))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
