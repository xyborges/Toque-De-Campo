extends SceneTree

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures.append(message)

func run() -> void:
	var locomotion:=WarLocomotion.new()
	check(WarLocomotion.longitudinal_target(0.,4.,.1,5.)>.3,"acceleration produces positive presentation weight")
	check(absf(WarLocomotion.longitudinal_target(4.,4.,.1,5.))<.0001,"steady speed remains neutral")
	check(WarLocomotion.longitudinal_target(4.,0.,.1,5.)<-.3,"braking produces negative presentation weight")
	check(WarLocomotion.PRESENTATION_FPP_TRAVEL<=.03,"FPP travel stays bounded to three centimetres")

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

	locomotion.moving=1.
	locomotion.sprint=0.
	locomotion.phase=0.
	locomotion.presentation_longitudinal=.75

	locomotion.tactical_motion_pilot=false
	locomotion.pose_weapon(actor)
	var world_off:=actor.weapon_root.transform
	var view_off:=actor.view_root.transform

	actor.weapon_root.transform=Transform3D.IDENTITY
	actor.view_root.transform=Transform3D.IDENTITY
	locomotion.tactical_motion_pilot=true
	locomotion.pose_weapon(actor)
	var world_on:=actor.weapon_root.transform
	var view_on:=actor.view_root.transform
	var view_difference:=view_on.origin-view_off.origin
	var expected_z:=.75*WarLocomotion.PRESENTATION_FPP_TRAVEL

	check(world_on.is_equal_approx(world_off),"pilot leaves authoritative world weapon unchanged")
	check(absf(view_difference.x)<.000001 and absf(view_difference.y)<.000001,"pilot adds no lateral or vertical FPP drift")
	check(absf(view_difference.z-expected_z)<.000001,"pilot adds only bounded longitudinal FPP travel")
	check(actor.camera==null,"isolated presentation path does not require or mutate a camera")

	actor.free()
	print("REALISMO_R1A "+JSON.stringify({"checks":checks,"failures":failures,"travel_m":WarLocomotion.PRESENTATION_FPP_TRAVEL}))
	quit(0 if failures.is_empty() else 1)