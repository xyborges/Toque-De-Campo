extends SceneTree

const FIXTURE = preload("res://tests/war_optics_fixture.gd")
const BODY_POSE = preload("res://modes/war/scripts/tactical_body_pose.gd")

var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func configure(actor: WarPlayer) -> void:
	actor.hp = 100.
	actor.deployed = true
	actor.is_local = true
	actor.vehicle_id = ""
	actor.aiming = false
	actor.iron_sights = false
	actor.reload_left = 0.
	actor.fire_cooldown = 0.
	actor.utility_mode = ""
	actor.grenade_selected = false
	actor.grenade_held_id = ""
	actor.grenade_throw_left = 0.
	actor.gadget_equipped = false
	actor.crouched = false
	actor.prone = false
	actor.weapon_id = "g3"
	actor.game.third_person = false
	actor.locomotion.tactical_motion_pilot = true
	actor.locomotion.moving = 1.
	actor.locomotion.sprint = 0.
	actor.locomotion.phase = 0.
	actor.locomotion.presentation_longitudinal = .65
	actor.locomotion.presentation_lateral = -.60
	actor.locomotion.presentation_landing = .55

func snapshot(actor: WarPlayer, body_enabled: bool) -> Dictionary:
	actor.locomotion.tactical_body_pilot = body_enabled
	actor._update_weapon_pose()
	return {
		"view": actor.view_root.transform,
		"world": actor.weapon_root.transform,
		"camera": actor.camera.transform,
		"torso": actor.avatar_parts.torso.transform,
		"head": actor.avatar_parts.head.transform,
	}

func compare(actor: WarPlayer, label: String, expect_extra: bool) -> void:
	var off := snapshot(actor, false)
	var on := snapshot(actor, true)
	var expected := BODY_POSE.fpp_weapon_angles(
		actor.locomotion.presentation_longitudinal,
		actor.locomotion.presentation_lateral,
		actor.locomotion.presentation_landing
	)
	var observed := (on.view as Transform3D).basis.get_euler() - (off.view as Transform3D).basis.get_euler()
	var good_angle := observed.is_equal_approx(expected) if expect_extra else observed.is_zero_approx()
	check(good_angle, label + ": extra FPP angles are correctly gated")
	check((off.world as Transform3D).is_equal_approx(on.world), label + ": world weapon remains authoritative")
	check((off.camera as Transform3D).is_equal_approx(on.camera), label + ": camera transform stays identical")
	check((off.view as Transform3D).origin.is_equal_approx((on.view as Transform3D).origin), label + ": no extra camera-relative weapon translation")
	check((off.torso as Transform3D).is_equal_approx(on.torso) and (off.head as Transform3D).is_equal_approx(on.head), label + ": body/head pivots stay identical")
	if expect_extra:
		var again := snapshot(actor, true)
		check((on.view as Transform3D).is_equal_approx(again.view), label + ": no cumulative transform drift")
		var restored := snapshot(actor, false)
		check((off.view as Transform3D).is_equal_approx(restored.view), label + ": disabling flag restores original view pose")
	cases.append({"case":label,"extra":expect_extra,"observed_rad":str(observed),"expected_rad":str(expected)})

func run() -> void:
	var game := FIXTURE.new() as WarGame
	root.add_child(game)
	await process_frame
	var actor := game.local_player as WarPlayer
	check(is_instance_valid(actor), "optics fixture created a WarPlayer")
	if not is_instance_valid(actor):
		quit(1)
		return
	actor.owned = ["g3", "glock", "ak"]
	actor.loadout = actor.owned.duplicate()
	actor.set_meta("weapon_optics", {})
	actor.weapon_id = "g3"
	actor._refresh_weapon()
	actor.set_process(false)
	actor.set_physics_process(false)
	configure(actor)
	actor._update_view()

	compare(actor,"G3 FPP normal standing",true)
	configure(actor)
	actor.game.third_person = true
	compare(actor,"TPP switched",false)
	configure(actor)
	actor.aiming = true
	compare(actor,"aiming",false)
	configure(actor)
	actor.iron_sights = true
	compare(actor,"iron sights ADS",false)
	configure(actor)
	actor.reload_left = .8
	compare(actor,"reloading",false)
	configure(actor)
	actor.fire_cooldown = .12
	compare(actor,"firing recoil priority",false)
	configure(actor)
	actor.crouched = true
	compare(actor,"crouch",false)
	configure(actor)
	actor.prone = true
	compare(actor,"prone",false)
	configure(actor)
	actor.utility_mode = "binoculars"
	compare(actor,"binocular utility",false)
	configure(actor)
	actor.grenade_selected = true
	compare(actor,"grenade selected",false)
	configure(actor)
	actor.grenade_held_id = "grenade"
	compare(actor,"grenade held",false)
	configure(actor)
	actor.grenade_throw_left = .20
	compare(actor,"grenade throwing",false)
	configure(actor)
	actor.gadget_equipped = true
	compare(actor,"gadget",false)
	configure(actor)
	actor.weapon_id = "ak"
	compare(actor,"AK excluded from G3 pilot",false)
	configure(actor)
	actor.is_local = false
	compare(actor,"nonlocal actor",false)
	configure(actor)
	actor.locomotion.tactical_motion_pilot = false
	compare(actor,"R1 master flag disabled",false)
	configure(actor)
	actor.hp = 0.
	compare(actor,"dead player",false)
	configure(actor)
	actor.vehicle_id = "vehicle-test"
	compare(actor,"seated in vehicle",false)

	var report := {"checks":checks,"failures":failures,"cases":cases,"body_hierarchy_written":false,"world_weapon_written_by_r2b":false}
	print("REALISMO_R2B_G3 "+JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
