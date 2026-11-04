extends SceneTree
## P1i release gate: prove that the authoritative CollisionRig carries region
## metadata through WarGame damage, limb grouping, death disabling and ragdoll
## presentation without requiring hit Areas to remain children of visual meshes.
const Fixture=preload("res://tests/war_optics_fixture.gd")

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

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

func reset_alive(game: WarGame,target: WarPlayer) -> void:
	target.hp=100.
	target.limbs=CombatRules.fresh_limbs()
	target.detached_region=""
	target.last_hit_region=""
	target.last_impact_weapon=""
	target.last_impact_direction=Vector3.ZERO
	target.deployed=true
	target.body_root.show()
	target.weapon_root.show()
	if game.members.has(target.peer_id):
		game.members[target.peer_id].shield=-1.
		game.members[target.peer_id].deployed=true
	target._set_hitboxes_enabled(true)
	await physics_frame
	target._p1g_collision_tick()
	await physics_frame

func hit_region(game: WarGame,shooter: WarPlayer,target: WarPlayer,id: String,amount: float,weapon: String="fal") -> Dictionary:
	var area:=target.hit_regions[id] as Area3D
	var group:=CombatRules.region_group(str(area.get_meta("hit_region",id)))
	var before_hp:=target.hp
	var before_limb:=float(target.limbs.get(group,100.))
	game._apply_hit(shooter.peer_id,{"collider":area,"position":area.global_position},amount,"chest",weapon,Vector3.RIGHT)
	return {
		"id":id,
		"meta":str(area.get_meta("hit_region","")),
		"group":group,
		"hp_loss":before_hp-target.hp,
		"limb_loss":before_limb-float(target.limbs.get(group,100.)),
		"last":target.last_hit_region
	}

func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if is_instance_valid(game.vehicle_system): game.vehicle_system.set_physics_process(false)
	var shooter:=game.players[1] as WarPlayer
	var target:=game.players[2] as WarPlayer
	shooter.set_process(false);shooter.set_physics_process(false)
	target.set_process(false);target.set_physics_process(false)
	target.weapon_id="g3"
	target.owned=["g3","ak","fal","glock","sniper"]
	target.loadout=target.owned.duplicate()
	target.set_meta("weapon_optics",{})
	target.set_meta("weapon_attachments",{"g3":{}})
	target._refresh_weapon()
	target.stance.reset(target)
	target.locomotion.reset(target)
	target.set_posture(0,false,true)
	target.stance.advance(target,1.)
	target.next_pose_usec=0
	target._animate_walk()
	target._set_hitboxes_enabled(true)
	await physics_frame
	target.p1g_set_collision_pilot(true)
	await physics_frame
	var rig:=target.p1g_collision_rig as WarCollisionRigProxy

	check(is_instance_valid(rig) and rig.using_authority,"CollisionRig is authoritative before damage")
	check(target.hit_regions==rig.regions and rig.regions.size()==16,"damage pipeline sees 16 proxy regions")
	var excluded: Array[RID]=game._collision_excludes(target.peer_id,false)
	var excluded_proxy:=0
	for area: Area3D in rig.regions.values():
		if excluded.has(area.get_rid()): excluded_proxy+=1
	check(excluded_proxy==16,"self-shot exclusion follows authoritative proxy dictionary")

	await reset_alive(game,target)
	var arm: Dictionary=hit_region(game,shooter,target,"armL",20.)
	check(arm.meta=="armL" and arm.last=="armL","upper-arm proxy metadata reaches take_damage")
	check(float(arm.hp_loss)>0. and float(arm.limb_loss)>0.,"upper-arm proxy damages health and arm limb")
	check(target.limbs.armR==100. and target.limbs.legL==100.,"arm hit does not alter unrelated limbs")
	check(rig.using_authority and target.hit_regions==rig.regions,"nonfatal arm hit keeps proxy authority")

	await reset_alive(game,target)
	var hand: Dictionary=hit_region(game,shooter,target,"handL",20.)
	check(hand.meta=="handL" and hand.last=="handL" and hand.group=="armL","hand proxy maps to left-arm limb group")
	check(float(hand.hp_loss)>0. and float(hand.limb_loss)>0.,"hand proxy produces bounded health and limb damage")

	await reset_alive(game,target)
	var leg: Dictionary=hit_region(game,shooter,target,"legR",20.)
	check(leg.meta=="legR" and leg.last=="legR" and leg.group=="legR","right-leg proxy preserves exact region")
	check(float(leg.hp_loss)>0. and float(leg.limb_loss)>0.,"leg proxy damages matching limb")
	check(target.limbs.legL==100.,"right-leg hit leaves left leg intact")

	await reset_alive(game,target)
	var pelvis: Dictionary=hit_region(game,shooter,target,"abdomenPelvis",20.)
	check(pelvis.meta=="abdomen" and pelvis.last=="abdomen" and pelvis.group=="torso","pelvis proxy preserves legacy abdomen metadata contract")
	check(float(pelvis.hp_loss)>0. and float(pelvis.limb_loss)>0.,"pelvis proxy damages torso group")

	# Fatal headshot: the collider is still the proxy, but the living player
	# must disable the authoritative hitboxes and the ragdoll must build from
	# the visual articulated body, which is intentionally separate.
	await reset_alive(game,target)
	var head_area:=target.hit_regions["head"] as Area3D
	var head_before:=target.hp
	game._apply_hit(shooter.peer_id,{"collider":head_area,"position":head_area.global_position},50.,"chest","sniper",Vector3.RIGHT)
	await physics_frame
	check(head_before>0. and target.hp<=0.,"proxy headshot reaches fatal damage path")
	check(target.last_hit_region=="head" and target.last_impact_weapon=="sniper","fatal proxy hit records region and weapon")
	check(target.last_impact_direction.x>.9,"fatal proxy hit preserves impact direction")
	check(all_disabled(rig.regions),"death disables authoritative proxy hitboxes")
	check(target.deaths>=1,"death accounting runs from proxy collision")
	check(not target.body_root.visible,"living body presentation hides after proxy death")

	var torso:=DeathRagdoll.create(game.world_root,target,target.global_position)
	var corpse:=torso.get_parent()
	check(is_instance_valid(corpse) and corpse.has_node("Head") and corpse.has_node("ArmL") and corpse.has_node("ShinL"),"ragdoll builds complete articulated corpse after proxy death")
	check(corpse.get_node("Head") is RigidBody3D and corpse.get_node("Torso") is RigidBody3D,"ragdoll physical head and torso exist")
	await physics_frame
	var rag_head:=corpse.get_node("Head") as RigidBody3D
	var rag_torso:=corpse.get_node("Torso") as RigidBody3D
	check(rag_head.linear_velocity.x>0. and rag_torso.linear_velocity.x>0.,"fatal head impact pushes struck ragdoll part and trunk")
	check(rig.regions["head"]!=head_area or target.hit_regions["head"]==head_area,"ragdoll creation does not mutate proxy region identity")

	var result: Dictionary={
		"pass":failures.is_empty(),
		"checks":checks,
		"failures":failures,
		"arm":arm,
		"hand":hand,
		"leg":leg,
		"pelvis":pelvis,
		"death_region":target.last_hit_region,
		"ragdoll_head_speed":rag_head.linear_velocity.length(),
		"ragdoll_torso_speed":rag_torso.linear_velocity.length()
	}
	print("P1I_DAMAGE_RAGDOLL ",JSON.stringify(result))
	corpse.queue_free()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
