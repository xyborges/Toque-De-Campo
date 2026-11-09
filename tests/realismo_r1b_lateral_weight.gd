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
	var delta:=1.0/60.0
	var ref:=WarRules.WALK_SPEED

	var right_strafe:=WarLocomotion.lateral_target(0.,ref,0.,delta,ref,0.)
	var left_strafe:=WarLocomotion.lateral_target(0.,-ref,0.,delta,ref,0.)
	var steady_strafe:=WarLocomotion.lateral_target(ref,ref,0.,delta,ref,0.)
	check(right_strafe<-.9,"right strafe acceleration makes the FPP copy lag left")
	check(left_strafe>.9,"left strafe acceleration makes the FPP copy lag right")
	check(absf(steady_strafe)<.0001,"steady strafe adds no persistent lateral offset")

	var yaw_step:=deg_to_rad(90.)*delta
	var curve_left:=WarLocomotion.lateral_target(0.,0.,yaw_step,delta,ref,ref)
	var curve_right:=WarLocomotion.lateral_target(0.,0.,-yaw_step,delta,ref,ref)
	var turn_still:=WarLocomotion.lateral_target(0.,0.,yaw_step,delta,ref,0.)
	check(curve_left>.3 and curve_left<=WarLocomotion.PRESENTATION_TURN_WEIGHT_LIMIT,"left curve lags the FPP copy to the right within the cap")
	check(curve_right<-.3 and absf(curve_right)<=WarLocomotion.PRESENTATION_TURN_WEIGHT_LIMIT,"right curve lags the FPP copy to the left within the cap")
	check(absf(turn_still)<.0001,"turning while stationary does not create lateral weapon inertia")
	check(WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL<=.025,"lateral FPP travel stays bounded to 2.5 centimetres")

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
	locomotion.moving=1.
	locomotion.sprint=0.
	locomotion.phase=0.
	locomotion.presentation_longitudinal=.4
	locomotion.presentation_lateral=.3

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
	var view_delta:=view_on.origin-view_off.origin

	check(world_on.is_equal_approx(world_off),"R1B leaves the authoritative world weapon unchanged")
	check(absf(view_delta.x-.3*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL)<.000001,"R1B adds only the expected lateral FPP travel")
	check(absf(view_delta.z-.4*WarLocomotion.PRESENTATION_FPP_TRAVEL)<.000001,"R1B composes with the existing R1A longitudinal travel")
	check(absf(view_delta.y)<.000001,"R1B adds no vertical drift")
	check(view_on.basis.is_equal_approx(view_off.basis),"R1B adds no weapon rotation in this step")
	check(actor.camera==null,"R1B presentation path does not require or mutate a camera")

	actor.free()
	print("REALISMO_R1B "+JSON.stringify({"checks":checks,"failures":failures,"lateral_travel_m":WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL,"turn_cap":WarLocomotion.PRESENTATION_TURN_WEIGHT_LIMIT}))
	quit(0 if failures.is_empty() else 1)
