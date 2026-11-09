extends SceneTree

const WarTacticalBodyPose = preload("res://modes/war/scripts/tactical_body_pose.gd")

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func close(actual: float,expected: float,tolerance:=.000001) -> bool:
	return absf(actual-expected)<=tolerance

func run() -> void:
	var neutral_hip:=WarTacticalBodyPose.hip_offset(0.,0.,0.)
	var neutral_angles:=WarTacticalBodyPose.hip_angles(0.,0.)
	var neutral_torso:=WarTacticalBodyPose.torso_angles(0.,0.,0.)
	var neutral_weapon:=WarTacticalBodyPose.fpp_weapon_angles(0.,0.,0.)
	check(neutral_hip.is_zero_approx(),"neutral hip translation is identity")
	check(neutral_angles.is_zero_approx(),"neutral hip rotation is identity")
	check(neutral_torso.is_zero_approx(),"neutral torso rotation is identity")
	check(neutral_weapon.is_zero_approx(),"neutral FPP weapon rotation is identity")

	var pos_hip:=WarTacticalBodyPose.hip_offset(.8,.7,0.)
	var neg_hip:=WarTacticalBodyPose.hip_offset(-.8,-.7,0.)
	var pos_hip_angles:=WarTacticalBodyPose.hip_angles(.8,.7)
	var neg_hip_angles:=WarTacticalBodyPose.hip_angles(-.8,-.7)
	var pos_torso:=WarTacticalBodyPose.torso_angles(.8,.7,0.)
	var neg_torso:=WarTacticalBodyPose.torso_angles(-.8,-.7,0.)
	var pos_weapon:=WarTacticalBodyPose.fpp_weapon_angles(.8,.7,0.)
	var neg_weapon:=WarTacticalBodyPose.fpp_weapon_angles(-.8,-.7,0.)
	check(pos_hip.is_equal_approx(-neg_hip),"hip translation is symmetric under movement reversal")
	check(pos_hip_angles.is_equal_approx(-neg_hip_angles),"hip rotation is symmetric under movement reversal")
	check(pos_torso.is_equal_approx(-neg_torso),"torso rotation is symmetric under movement reversal")
	check(pos_weapon.is_equal_approx(-neg_weapon),"weapon rotation is symmetric under movement reversal")
	check(pos_hip.x>0. and pos_hip.z<0.,"hip goes sideways and countertravels during acceleration")
	check(pos_hip_angles.x<0. and pos_hip_angles.z>0.,"hips resist forward pitch and lean into lateral acceleration")
	check(pos_torso.x>0. and pos_torso.z<0.,"torso pitch and lateral roll counter the hip reaction")
	check(pos_weapon.x>0. and pos_weapon.z<0.,"FPP shoulder reaction follows the small torso movement")
	check(absf(pos_weapon.x)<absf(pos_torso.x),"FPP weapon never amplifies torso pitch")
	check(absf(pos_weapon.z)<absf(pos_torso.z),"FPP weapon never amplifies torso roll")

	var impact_hip:=WarTacticalBodyPose.hip_offset(0.,0.,.6)
	var impact_torso:=WarTacticalBodyPose.torso_angles(0.,0.,.6)
	var impact_weapon:=WarTacticalBodyPose.fpp_weapon_angles(0.,0.,.6)
	check(close(impact_hip.x,0.) and close(impact_hip.z,0.),"landing alone introduces no lateral/forward hip motion")
	check(impact_hip.y<0.,"landing makes virtual hip compress down")
	check(impact_torso.x>0. and close(impact_torso.y,0.) and close(impact_torso.z,0.),"landing adds forward torso compression without yaw or roll")
	check(impact_weapon.x>0. and close(impact_weapon.y,0.) and close(impact_weapon.z,0.),"landing adds a small FPP shoulder pitch only")
	check(close(impact_weapon.x,.6*WarTacticalBodyPose.FPP_WEAPON_LANDING_PITCH),"landing weapon pitch derives exclusively from filtered R1C state")

	var max_hip:=WarTacticalBodyPose.hip_offset(999.,999.,999.)
	var max_torso:=WarTacticalBodyPose.torso_angles(999.,999.,999.)
	var max_weapon:=WarTacticalBodyPose.fpp_weapon_angles(999.,999.,999.)
	check(max_hip.x<=.014001 and max_hip.y>=-.012001 and absf(max_hip.z)<=.006001,"hip offsets clamp to centimetre-scale contract")
	check(max_torso.x<=.054001 and absf(max_torso.z)<=.028001,"torso never exceeds the designed angular limits")
	check(max_weapon.x<=.028001 and absf(max_weapon.z)<=.020001,"FPP weapon pitch/roll never exceed restrained angular limits")
	check(max_weapon.length()<.036,"combined FPP weapon rotation is below roughly two degrees")
	check(WarTacticalBodyPose.hip_offset(-999.,-999.,-999.).y<=0.,"negative landing never pops the pelvis upward")
	check(WarTacticalBodyPose.fpp_weapon_angles(-999.,-999.,-999.).x>=-.010001,"negative landing is discarded, not inverted")

	var nan_weight:=NAN
	var inf_weight:=INF
	check(WarTacticalBodyPose.hip_offset(nan_weight,inf_weight,nan_weight).is_zero_approx(),"invalid inputs cannot poison hip transform")
	check(WarTacticalBodyPose.hip_angles(nan_weight,inf_weight).is_zero_approx(),"invalid inputs cannot poison hip orientation")
	check(WarTacticalBodyPose.torso_angles(nan_weight,inf_weight,nan_weight).is_zero_approx(),"invalid inputs cannot poison torso orientation")
	check(WarTacticalBodyPose.fpp_weapon_angles(nan_weight,inf_weight,nan_weight).is_zero_approx(),"invalid inputs cannot poison FPP presentation")

	var sample_h:=WarTacticalBodyPose.hip_offset(.45,-.62,.5)
	var sample_t:=WarTacticalBodyPose.torso_angles(.45,-.62,.5)
	var sample_w:=WarTacticalBodyPose.fpp_weapon_angles(.45,-.62,.5)
	var recomputed_w:=WarTacticalBodyPose.fpp_weapon_angles(.45,-.62,.5)
	check(sample_w.is_equal_approx(recomputed_w),"same R1 inputs produce exactly the same R2 output")
	check(sample_h.is_finite() and sample_t.is_finite() and sample_w.is_finite(),"combined pose outputs stay finite")
	check(close(sample_w.y,.62*WarTacticalBodyPose.FPP_WEAPON_LATERAL_YAW),"sideways weapon yaw sign stays consistent")
	check(close(sample_t.z,.62*WarTacticalBodyPose.TORSO_LATERAL_ROLL),"torso lateral counter-roll sign stays consistent")

	var report:={
		"checks":checks,
		"failures":failures,
		"max_hip_m":str(max_hip),
		"max_torso_rad":str(max_torso),
		"max_fpp_weapon_rad":str(max_weapon),
		"sample_hip_m":str(sample_h),
		"sample_torso_rad":str(sample_t),
		"sample_fpp_weapon_rad":str(sample_w),
		"physical_hip_applied":false,
		"physical_torso_applied":false
	}
	print("REALISMO_R2A_POSE "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
