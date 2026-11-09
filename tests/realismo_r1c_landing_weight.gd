extends SceneTree

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)

func run() -> void:
	var below:=WarLocomotion.landing_target(2.49)
	var threshold:=WarLocomotion.landing_target(WarLocomotion.PRESENTATION_LANDING_THRESHOLD)
	var step_drop:=WarLocomotion.landing_target(3.0)
	var normal:=WarLocomotion.landing_target(4.4)
	var hard:=WarLocomotion.landing_target(WarLocomotion.PRESENTATION_LANDING_FULL_SPEED)
	var extreme:=WarLocomotion.landing_target(12.0)

	check(is_zero_approx(below),"sub-threshold vertical contact produces no landing weight")
	check(is_zero_approx(threshold),"landing threshold itself remains neutral")
	check(step_drop>0. and step_drop<.10,"small real drop produces only a tiny bounded response")
	check(normal>.50 and normal<.62,"normal 4.4 m/s landing maps to a moderate response")
	check(is_equal_approx(hard,1.),"6 m/s reaches the configured full landing response")
	check(is_equal_approx(extreme,1.),"extreme falls remain clamped to the same visual ceiling")
	check(WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL<=.035,"landing FPP travel is capped to 3.5 centimetres")

	var normal_mm:=normal*WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL*1000.
	check(normal_mm>=18. and normal_mm<=22.,"normal jump landing visual target stays in the 18-22 mm window")

	var recovery:=normal
	var recovery_frames:=0
	while recovery>0. and recovery_frames<60:
		recovery=move_toward(recovery,0.,(1.0/60.0)*WarLocomotion.PRESENTATION_LANDING_RECOVERY)
		recovery_frames+=1
	var recovery_ms:=recovery_frames*1000.0/60.0
	check(recovery_ms>=100. and recovery_ms<=160.,"normal landing recovers in the 100-160 ms window")

	var actor:=GamePlayer.new()
	actor.is_local=true
	actor.hp=100.
	actor.deployed=true
	actor.vehicle_id=""
	actor.weapon_root=Node3D.new()
	actor.weapon_root.name="WorldWeapon"
	actor.add_child(actor.weapon_root)
	actor.view_root=Node3D.new()
	actor.view_root.name="FirstPersonPresentation"
	actor.add_child(actor.view_root)

	var locomotion:=WarLocomotion.new()
	locomotion.tactical_motion_pilot=true
	locomotion.moving=0.
	locomotion.sprint=0.
	locomotion.presentation_longitudinal=.25
	locomotion.presentation_lateral=-.30
	locomotion.presentation_landing=normal

	var world_before:=actor.weapon_root.transform
	var view_before:=actor.view_root.transform
	locomotion.pose_weapon(actor)
	var world_after:=actor.weapon_root.transform
	var view_after:=actor.view_root.transform
	var delta:=view_after.origin-view_before.origin

	check(world_after.is_equal_approx(world_before),"R1C leaves the authoritative world weapon unchanged")
	check(absf(delta.y+normal*WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL)<.000001,"R1C adds only the expected downward FPP travel")
	check(absf(delta.x+.30*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL)<.000001,"R1C composes with R1B lateral inertia")
	check(absf(delta.z-.25*WarLocomotion.PRESENTATION_FPP_TRAVEL)<.000001,"R1C composes with R1A longitudinal inertia")
	check(view_after.basis.is_equal_approx(view_before.basis),"R1C adds no weapon rotation")
	check(actor.camera==null,"R1C presentation path does not require or mutate a camera")

	actor.view_root.transform=Transform3D.IDENTITY
	actor.aiming=true
	locomotion.pose_weapon(actor)
	check(actor.view_root.transform.is_equal_approx(Transform3D.IDENTITY),"ADS remains protected from landing presentation offset")

	actor.free()
	print("REALISMO_R1C "+JSON.stringify({
		"checks":checks,
		"failures":failures,
		"normal_weight":normal,
		"normal_travel_mm":normal_mm,
		"recovery_ms":recovery_ms,
		"travel_limit_mm":WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL*1000.
	}))
	quit(0 if failures.is_empty() else 1)
