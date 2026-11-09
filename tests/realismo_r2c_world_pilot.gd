extends SceneTree

const FIXTURE = preload("res://tests/war_optics_fixture.gd")
const BODY = preload("res://modes/war/scripts/tactical_body_pose.gd")
const WORLD = preload("res://modes/war/scripts/tactical_world_body.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,description: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+description)
	if not ok: failures.append(description)

func configure(actor: WarPlayer) -> void:
	actor.hp=100.
	actor.deployed=true
	actor.vehicle_id=""
	actor.is_local=true
	actor.game.offline_operation=true
	actor.game.third_person=true
	actor.aiming=false
	actor.iron_sights=false
	actor.reload_left=0.
	actor.fire_cooldown=0.
	actor.utility_mode=""
	actor.grenade_selected=false
	actor.grenade_held_id=""
	actor.grenade_throw_left=0.
	actor.gadget_equipped=false
	actor.crouched=false
	actor.prone=false
	actor.stance.crouch_weight=0.
	actor.stance.prone_weight=0.
	actor.locomotion.tactical_motion_pilot=true
	actor.locomotion.tactical_body_pilot=true
	actor.locomotion.tactical_world_pilot=true
	actor.locomotion.moving=1.
	actor.locomotion.sprint=.25
	actor.locomotion.phase=0.
	actor.locomotion.grounded=true
	actor.locomotion.presentation_longitudinal=.66
	actor.locomotion.presentation_lateral=-.55
	actor.locomotion.presentation_landing=.40
	actor.weapon_id="g3"
	actor.lean=0.
	actor.reaction=0.
	actor.velocity=Vector3.ZERO
	if actor.has_meta("war_bot"): actor.remove_meta("war_bot")

func snapshot(actor: WarPlayer,enabled: bool) -> Dictionary:
	actor.locomotion.tactical_world_pilot=enabled
	actor._animate_walk()
	var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
	var torso:=actor.avatar_parts.torso as Node3D
	return {
		"pelvis":pelvis.transform,"torso":torso.transform,
		"camera":actor.camera.global_transform,
		"muzzle":actor.muzzle_marker.global_transform,
		"weapon":actor.weapon_root.global_transform,
		"body_collision":actor.body_collision.transform,
		"chest":(actor.hit_regions["chest"] as Area3D).global_transform,
		"pelvis_region":(actor.hit_regions["abdomenPelvis"] as Area3D).global_transform,
		"chest_mount":torso.global_transform.affine_inverse()*(actor.hit_regions["chest"] as Area3D).global_transform,
		"pelvis_mount":pelvis.global_transform.affine_inverse()*(actor.hit_regions["abdomenPelvis"] as Area3D).global_transform
	}

func unchanged(off: Dictionary,on: Dictionary,label: String) -> void:
	check((off.pelvis as Transform3D).is_equal_approx(on.pelvis),label+" pelvis unchanged")
	check((off.torso as Transform3D).is_equal_approx(on.torso),label+" torso unchanged")
	check((off.chest as Transform3D).is_equal_approx(on.chest),label+" chest region unchanged")
	check((off.pelvis_region as Transform3D).is_equal_approx(on.pelvis_region),label+" pelvis region unchanged")

func verify_blocked(actor: WarPlayer,label: String) -> void:
	check(not WORLD.eligible(actor,actor.locomotion),label+" rejected by gate")
	actor.locomotion.tactical_world_pilot=false
	var off:=snapshot(actor,false)
	var on:=snapshot(actor,true)
	unchanged(off,on,label)

func run() -> void:
	var game:=FIXTURE.new() as WarGame
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	check(is_instance_valid(actor),"fixture builds a local WarPlayer")
	if not is_instance_valid(actor): quit(1);return
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.owned=["g3","glock","ak"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor.weapon_id="g3"
	actor._refresh_weapon()
	configure(actor)
	actor._update_view()
	check(WORLD.eligible(actor,actor.locomotion),"R2C allowed on offline local standing TPP")

	var off:=snapshot(actor,false)
	var on:=snapshot(actor,true)
	var hip_delta: Vector3=(on.pelvis as Transform3D).origin-(off.pelvis as Transform3D).origin
	var expected_hip:=BODY.hip_offset(.66,-.55,.40)
	check(hip_delta.is_equal_approx(expected_hip),"physical pelvis receives R2A hip translation")
	check(not (on.pelvis as Transform3D).is_equal_approx(off.pelvis),"physical pelvis rotation differs")
	check(not (on.torso as Transform3D).is_equal_approx(off.torso),"physical torso rotation differs")
	check(not (on.chest as Transform3D).is_equal_approx(off.chest),"chest region tracks torso visual")
	check(not (on.pelvis_region as Transform3D).is_equal_approx(off.pelvis_region),"pelvis region tracks hip visual")
	check((off.chest_mount as Transform3D).is_equal_approx(on.chest_mount),"chest hit region stays attached to the exact mesh")
	check((off.pelvis_mount as Transform3D).is_equal_approx(on.pelvis_mount),"pelvis hit region stays attached to the exact mesh")
	check((off.camera as Transform3D).is_equal_approx(on.camera),"camera not modified by R2C")
	check((off.weapon as Transform3D).is_equal_approx(on.weapon),"world weapon not moved by R2C")
	check((off.muzzle as Transform3D).is_equal_approx(on.muzzle),"true muzzle invariant")
	check((off.body_collision as Transform3D).is_equal_approx(on.body_collision),"CharacterBody collision capsule invariant")
	var on_again:=snapshot(actor,true)
	check((on_again.torso as Transform3D).is_equal_approx(on.torso),"no accumulated torso drift")
	check((on_again.pelvis as Transform3D).is_equal_approx(on.pelvis),"no accumulated pelvis drift")
	var restored:=snapshot(actor,false)
	unchanged(off,restored,"switching R2C off restores the exact physical base")

	configure(actor);actor.game.third_person=false
	verify_blocked(actor,"FPP")
	configure(actor);actor.game.offline_operation=false
	verify_blocked(actor,"online client")
	configure(actor);actor.is_local=false
	verify_blocked(actor,"remote actor")
	configure(actor);actor.set_meta("war_bot",true)
	verify_blocked(actor,"bot")
	configure(actor);actor.crouched=true
	verify_blocked(actor,"crouched")
	configure(actor);actor.prone=true
	verify_blocked(actor,"prone")
	configure(actor);actor.aiming=true
	verify_blocked(actor,"aiming")
	configure(actor);actor.iron_sights=true
	verify_blocked(actor,"ADS")
	configure(actor);actor.reload_left=.5
	verify_blocked(actor,"reload")
	configure(actor);actor.fire_cooldown=.1
	verify_blocked(actor,"shot cooldown")
	configure(actor);actor.utility_mode="binoculars"
	verify_blocked(actor,"binoculars")
	configure(actor);actor.grenade_selected=true
	verify_blocked(actor,"grenade")
	configure(actor);actor.vehicle_id="test_vehicle"
	verify_blocked(actor,"seated")
	configure(actor);actor.hp=0.
	verify_blocked(actor,"dead")
	configure(actor);actor.deployed=false
	verify_blocked(actor,"undeployed")
	configure(actor);actor.locomotion.tactical_motion_pilot=false
	verify_blocked(actor,"R1 flag off")
	configure(actor);actor.locomotion.tactical_body_pilot=false
	verify_blocked(actor,"R2B master flag off")
	configure(actor);actor.locomotion.presentation_longitudinal=0.;actor.locomotion.presentation_lateral=0.;actor.locomotion.presentation_landing=0.
	check(not WORLD.apply(actor,actor.locomotion),"neutral weights make no physical writes")

	print("REALISMO_R2C_WORLD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pilot_enabled_in_production":false,"multiplayer_gate":"blocked","applied_local_offline_only":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
