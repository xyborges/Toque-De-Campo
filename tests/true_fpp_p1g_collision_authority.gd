extends SceneTree
## P1g QA: activate the independent collision rig under an explicit pilot,
## prove that it becomes the only shootable region tree, stays updated when
## visual articulation is LOD-stale, falls back safely for unsupported actions
## and can restore the legacy regions without losing enabled/disabled state.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)

func shape_of(area: Area3D) -> CollisionShape3D:
	if not is_instance_valid(area): return null
	for child in area.get_children():
		if child is CollisionShape3D: return child as CollisionShape3D
	return null

func all_disabled(regions: Dictionary) -> bool:
	for area: Area3D in regions.values():
		var shape:=shape_of(area)
		if area.collision_layer!=0: return false
		if is_instance_valid(shape) and not shape.disabled: return false
	return true

func all_enabled(regions: Dictionary) -> bool:
	for area: Area3D in regions.values():
		var shape:=shape_of(area)
		if area.collision_layer!=2: return false
		if not is_instance_valid(shape) or shape.disabled: return false
	return true

func configure_neutral(actor: WarPlayer,weapon: String) -> void:
	actor.deployed=true
	actor.hp=100.
	actor.vehicle_id=""
	actor.utility_mode=""
	actor.gadget_equipped=false
	actor.weapon_id=weapon
	actor.owned=["g3","ak","fal","glock","sniper"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor.set_meta("weapon_attachments",{weapon:{}})
	actor._refresh_weapon()
	actor.velocity=Vector3.ZERO
	actor.locomotion.reset(actor)
	actor.stance.reset(actor)
	actor.set_posture(0,false,true)
	actor.stance.advance(actor,1.)
	actor.pitch=0.
	actor.lean=0.
	actor.recoil=0.
	actor.attack_anim=0.
	actor.reload_left=0.
	actor.reload_total=0.
	actor.reload_weapon=""
	actor.fire_cooldown=0.
	actor.aiming=false
	actor.iron_sights=false
	actor.next_pose_usec=0
	actor._animate_walk()

func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false)
	actor.set_physics_process(false)
	check(not actor.p1g_authority_collision_pilot,"P1g is disabled by default")
	configure_neutral(actor,"g3")
	actor._set_hitboxes_enabled(true)
	await process_frame
	var legacy: Dictionary=actor.hit_regions.duplicate()
	check(legacy.size()==16,"legacy rig exposes 16 regions")
	check(all_enabled(legacy),"legacy regions start as the shootable authority")

	actor.p1g_set_collision_pilot(true)
	var rig:=actor.p1g_collision_rig as WarCollisionRigProxy
	check(is_instance_valid(rig),"pilot builds independent CollisionRig")
	check(rig.regions.size()==16,"proxy contains 16 physical regions")
	check(rig.using_authority,"proxy becomes authoritative under QA pilot")
	check(actor.hit_regions==rig.regions,"gameplay hit_regions dictionary points to proxy")
	check(all_disabled(legacy),"legacy visual hitboxes are disabled before proxy authority")
	check(all_enabled(rig.regions),"proxy hitboxes inherit enabled collision state")
	await physics_frame

	var frame: Dictionary=Solver.solve(actor.p1g_collision_bindings,Solver.state(actor))
	var parity: Dictionary=Snapshot.compare(frame,rig.snapshot())
	check(bool(frame.get("supported",false)),"neutral G3 state is solver-supported")
	check(parity.missing.is_empty() and parity.max_origin_m<.00001 and parity.max_basis_delta<.00001 and parity.muzzle_origin_m<.00001,"proxy matches pure solver frame")

	var chest:=rig.regions["chest"] as Area3D
	var ray:=PhysicsRayQueryParameters3D.create(chest.global_position+Vector3(0,0,2),chest.global_position-Vector3(0,0,2),2,[actor.get_rid()])
	ray.collide_with_areas=true
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(),"physics ray hits authoritative proxy")
	check(not hit.is_empty() and hit.collider in rig.regions.values(),"ray collider belongs to proxy, not visual hierarchy")
	check(not hit.is_empty() and (hit.collider as Area3D).has_meta("hit_region"),"proxy preserves hit-region metadata")

	# Prove physics pose advances even if presentation LOD would skip _animate_walk.
	var proxy_before: Dictionary=rig.snapshot()
	var legacy_before: Dictionary=rig.legacy_snapshot(actor)
	actor.next_pose_usec=Time.get_ticks_usec()+1000000
	actor.pitch=.42
	actor.lean=.48
	actor._p1g_collision_tick()
	var proxy_after: Dictionary=rig.snapshot()
	var legacy_after: Dictionary=rig.legacy_snapshot(actor)
	var proxy_motion: Dictionary=Snapshot.compare(proxy_before,proxy_after)
	var visual_motion: Dictionary=Snapshot.compare(legacy_before,legacy_after)
	check(proxy_motion.max_origin_m>.02 and proxy_motion.muzzle_origin_m>.02,"proxy reacts to aim independently of visual pose tick")
	check(visual_motion.max_origin_m<.000001 and visual_motion.muzzle_origin_m<.000001,"legacy visual hitboxes remain stale in the forced LOD scenario")
	check(rig.using_authority and actor.hit_regions==rig.regions,"LOD skip does not relinquish proxy authority")

	# Unsupported action mirrors legacy geometry but does not swap back mid-life.
	actor.gadget_equipped=true
	var fallbacks_before:=actor.p1g_legacy_fallback_frames
	actor._p1g_collision_tick()
	var fallback_parity: Dictionary=Snapshot.compare(rig.legacy_snapshot(actor),rig.snapshot())
	check(actor.p1g_legacy_fallback_frames>fallbacks_before,"unsupported gadget state records legacy fallback")
	check(fallback_parity.max_origin_m<.000001 and fallback_parity.max_basis_delta<.000001 and fallback_parity.muzzle_origin_m<.000001,"fallback mirrors legacy transforms into proxy")
	check(rig.using_authority and actor.hit_regions==rig.regions,"fallback keeps one authoritative collision hierarchy")
	actor.gadget_equipped=false

	# Weapon change must rebind from preserved legacy regions while proxy remains live.
	configure_neutral(actor,"ak")
	var old_solver_frames:=actor.p1g_solver_frames
	actor._p1g_collision_tick()
	check(actor.p1g_collision_binding_key.begins_with("ak|"),"weapon change recalibrates binding from legacy authored regions")
	check(actor.p1g_solver_frames>old_solver_frames,"AK returns to independent solver after rebind")
	var ak_frame: Dictionary=Solver.solve(actor.p1g_collision_bindings,Solver.state(actor))
	var ak_parity: Dictionary=Snapshot.compare(ak_frame,rig.snapshot())
	check(bool(ak_frame.get("supported",false)) and ak_parity.max_origin_m<.00001 and ak_parity.muzzle_origin_m<.00001,"AK proxy matches recalibrated solver")

	# Preserve disabled state through a full restoration, then prove legacy can re-enable.
	actor._set_hitboxes_enabled(false)
	await process_frame
	check(all_disabled(rig.regions),"ordinary hitbox disable acts on proxy while it is authority")
	actor.p1g_set_collision_pilot(false)
	check(not rig.using_authority,"pilot can restore legacy hierarchy")
	check(actor.hit_regions==legacy,"gameplay dictionary returns to original legacy regions")
	check(all_disabled(legacy),"disabled collision state survives proxy-to-legacy restoration")
	check(all_disabled(rig.regions),"proxy remains inert after restoration")
	actor._set_hitboxes_enabled(true)
	await physics_frame
	check(all_enabled(legacy),"legacy regions re-enable normally after pilot shutdown")
	check(all_disabled(rig.regions),"re-enabling legacy does not create double proxy collision")

	var result: Dictionary={
		"pass":failures.is_empty(),
		"checks":checks,
		"failures":failures,
		"solver_frames":actor.p1g_solver_frames,
		"legacy_fallback_frames":actor.p1g_legacy_fallback_frames,
		"proxy_motion_m":proxy_motion.max_origin_m,
		"visual_stale_m":visual_motion.max_origin_m
	}
	print("P1G_COLLISION_AUTHORITY ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
