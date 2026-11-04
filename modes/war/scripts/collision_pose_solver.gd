extends RefCounted
class_name WarCollisionPoseSolver
## P1b independent, pure-math G3 standing idle collision solver.
## The one-time geometry binding reads static authored hit offsets only.
## solve() reads no Node3D, MeshInstance3D, camera, PhysicsServer or runtime
## scene state. Unsupported weapon/posture/motion is explicitly rejected.
const UPPER:=.37
const LOWER:=.35
const WAIST:=Vector3(0,.87,0)
const G3_MUZZLE:=Vector3(0,.070,-.828)
const G3_GRIP:=Vector3(0,-.046,.035)
const G3_SUPPORT:=Vector3(-.02,-.012,-.36)
const REGION_MOUNTS: Dictionary={
	"head":"head","chest":"torso","abdomen":"torso",
	"abdomenPelvis":"pelvis",
	"armL":"upperL","armR":"upperR",
	"forearmL":"lowerL","forearmR":"lowerR",
	"handL":"handL","handR":"handR",
	"legL":"thighL","legR":"thighR",
	"shinL":"shinL","shinR":"shinR",
	"footL":"footL","footR":"footR"
}

static func bind(actor: WarPlayer) -> Dictionary:
	# Only calibration: local region offsets, authored segment transforms,
	# rest positions and body translation. Never read live visual pose in solve.
	var mounts: Dictionary={
		"head":actor.avatar_parts.head,
		"torso":actor.avatar_parts.torso,
		"pelvis":actor.body_root.get_node("Pelvis"),
		"upperL":actor.avatar_parts.arm_l.get_node("ArmLMesh"),
		"upperR":actor.avatar_parts.arm_r.get_node("ArmRMesh"),
		"lowerL":actor.avatar_parts.arm_l.get_node("ForearmLMesh"),
		"lowerR":actor.avatar_parts.arm_r.get_node("ForearmRMesh"),
		"handL":actor.avatar_parts.arm_l.get_node("HandL"),
		"handR":actor.avatar_parts.arm_r.get_node("HandR"),
		"thighL":actor.avatar_parts.leg_l.get_node("LegLMesh"),
		"thighR":actor.avatar_parts.leg_r.get_node("LegRMesh"),
		"shinL":actor.avatar_parts.leg_l.get_node("KneeL"),
		"shinR":actor.avatar_parts.leg_r.get_node("KneeR"),
		"footL":actor.avatar_parts.leg_l.get_node("KneeL/ShoeL"),
		"footR":actor.avatar_parts.leg_r.get_node("KneeR/ShoeR")
	}
	var offsets: Dictionary={}
	for region_id: String in REGION_MOUNTS:
		var area: Area3D=actor.hit_regions.get(region_id)
		if not is_instance_valid(area):continue
		var mount: Node3D=mounts[REGION_MOUNTS[region_id]]
		# Preserve arbitrary authored offsets, including parent changes
		# in WarHumanRig.build and WarStance.build_legs.
		offsets[region_id]=mount.global_transform.affine_inverse()*area.global_transform
	var rest: Dictionary=actor.get_meta("upper_body_rest",{})
	var legs: Dictionary={}
	for side: String in ["L","R"]:
		var leg: Node3D=actor.avatar_parts["leg_"+side.to_lower()]
		var knee: Node3D=leg.get_node("Knee"+side)
		var foot: Node3D=knee.get_node("Shoe"+side)
		var thigh: Node3D=leg.get_node("Leg"+side+"Mesh")
		legs[side]={"base_position":Vector3(rest["leg_"+side.to_lower()]),"thigh":thigh.transform,"knee":knee.transform,"shoe":foot.transform}
	return {"offsets":offsets,"rest":rest.duplicate(true),"legs":legs,
		"ground_y":actor.stance.visual_ground_offset(actor),
		"torso_proportion":float(actor.body_proportions.get("torso",1.)),
		"head_proportion":float(actor.body_proportions.get("head",1.)),
		"arm_proportion":float(actor.body_proportions.get("arms",1.)),
		"leg_proportion":float(actor.body_proportions.get("legs",1.)),
		"model_rest":Transform3D.IDENTITY,
		"bound_regions":offsets.size()}

static func supported(state: Dictionary) -> bool:
	return str(state.get("weapon",""))=="g3" and not bool(state.get("scoped",false)) and not bool(state.get("iron",false)) and float(state.get("crouch_weight",0.))<.00001 and float(state.get("prone_weight",0.))<.00001 and float(state.get("moving",0.))<.00001 and float(state.get("sprint",0.))<.00001 and float(state.get("reaction",0.))==0. and float(state.get("reload_left",0.))==0. and float(state.get("attack",0.))==0. and float(state.get("recoil",0.))==0. and not bool(state.get("special",false))

static func state(actor: WarPlayer) -> Dictionary:
	return {"weapon":actor.weapon_id,"pitch":actor.pitch,"lean":actor.lean,"scoped":actor.weapon_optics.presented(),"iron":actor.iron_sights,
		"crouch_weight":actor.stance.crouch_weight,"prone_weight":actor.stance.prone_weight,
		"moving":actor.locomotion.moving,"sprint":actor.locomotion.sprint,"reaction":actor.reaction,
		"reload_left":actor.reload_left,"attack":actor.attack_anim,"recoil":actor.recoil,
		"special":actor.gadget_equipped or not actor.utility_mode.is_empty() or actor._grenade_active() or actor.in_water() or not actor.deployed or actor.hp<=0 or not actor.vehicle_id.is_empty()}

static func _upper(pitch: float,lean: float) -> Transform3D:
	var b:=Basis(Vector3.BACK,-lean*.18)*Basis(Vector3.RIGHT,clampf(pitch*.42,-.49,.49))
	return Transform3D(b,WAIST+Vector3(lean*.04,0,0)-b*WAIST)

static func _arm(shoulder: Vector3,grip: Vector3,hand_basis: Basis,upper_pose: Transform3D,side: String,proportion: float) -> Dictionary:
	var cuff:=Vector3(-.035,-.029,.075) if side=="L" else Vector3(.023,-.025,.085)
	var wrist:=grip+hand_basis*cuff
	var direction:=wrist-shoulder
	var distance:=direction.length()
	if distance<.01:return {}
	var a:=UPPER*proportion
	var b:=LOWER*proportion
	var stretch:=maxf(1.,distance/(a+b-.003))
	a*=stretch;b*=stretch
	var along:=direction/distance
	var pole:=upper_pose.basis*Vector3(-.75 if side=="L" else .75,-.70,-.25)
	var perpendicular: Vector3=(pole-along*pole.dot(along)).normalized()
	var projection:=clampf((a*a-b*b+distance*distance)/(2*distance),0,a)
	var elbow:=shoulder+along*projection+perpendicular*sqrt(maxf(0,a*a-projection*projection))
	var arm:=Transform3D(Basis(Quaternion(Vector3.DOWN,(elbow-shoulder).normalized())),shoulder)
	var inverse:=arm.affine_inverse()
	var elbow_local:=inverse*elbow
	var wrist_local:=inverse*wrist
	var lower_basis:=Basis(Quaternion(Vector3.DOWN,(wrist_local-elbow_local).normalized()))*Basis.from_scale(Vector3(proportion,b/LOWER,proportion))
	var lower:=Transform3D(lower_basis,(elbow_local+wrist_local)*.5)
	var upper:=Transform3D(Basis.from_scale(Vector3(proportion,a/UPPER,proportion)),Vector3(0,-a*.5,0))
	var hand:=Transform3D(inverse.basis*hand_basis*Basis.from_scale(Vector3.ONE*proportion),inverse*grip)
	return {"arm":arm,"upper":upper,"lower":lower,"hand":hand}

static func solve(bindings: Dictionary,input: Dictionary) -> Dictionary:
	if not supported(input):return {"supported":false,"reason":"Requires standing idle G3 without optics, reload or utility"}
	var pitch: float=clampf(float(input.pitch),-1.5,1.5)
	var lean: float=clampf(float(input.lean),-1.,1.)
	var rest: Dictionary=bindings.rest
	var upper:=_upper(pitch,lean)
	var body:=Transform3D(Basis.IDENTITY,Vector3(0,float(bindings.ground_y),0))
	var basis_pitch:=Basis(Vector3.RIGHT,pitch)
	var aim:=basis_pitch*Basis(Vector3.BACK,-lean*.18)
	var shoulder: Vector3=upper*Vector3(0,1.42,0)
	var clearance: float=(.10+.07*absf(lean))*smoothstep(.4,1.3,-pitch)
	shoulder+=upper.basis*Vector3(0,0,-clearance)
	var weapon:=body*Transform3D(aim,shoulder+aim*Vector3(.15,-.045,-.38))
	var muzzle: Transform3D=weapon*Transform3D(Basis.IDENTITY,G3_MUZZLE)
	var torso_scale:=clampf(float(bindings.torso_proportion),.65,1.5)
	var head_scale:=clampf(float(bindings.head_proportion),.65,1.5)
	var head_basis:=Basis(Vector3.RIGHT,clampf(pitch*.92,-1.12,1.12))*Basis(Vector3.BACK,-lean*.18)
	var neck:=Vector3(0,float(Vector3(rest.head).y)-.21,0)
	var mounts: Dictionary={}
	mounts["torso"]=body*Transform3D(upper.basis*Basis.from_scale(Vector3.ONE*torso_scale),upper*Vector3(rest.torso))
	mounts["head"]=body*Transform3D(head_basis*Basis.from_scale(Vector3.ONE*head_scale),upper*neck+head_basis*(Vector3(rest.head)-neck))
	mounts["pelvis"]=body*Transform3D(Basis(Vector3.FORWARD,-lean*.035),Vector3(rest.pelvis)+Vector3(lean*.04,0,0))
	var legs: Dictionary=bindings.legs
	for side: String in ["L","R"]:
		var leg: Dictionary=legs[side]
		var position:=Vector3(leg.base_position)+Vector3(lean*.04,0,0)
		var leg_basis:=Basis(Vector3.BACK,-atan2(lean*.04,.78))
		var leg_pose:=body*Transform3D(leg_basis,position)
		mounts["thigh"+side]=leg_pose*Transform3D(leg.thigh)
		mounts["shin"+side]=leg_pose*Transform3D(leg.knee)
		mounts["foot"+side]=leg_pose*Transform3D(leg.knee)*Transform3D(leg.shoe)
	for side: String in ["L","R"]:
		var point:=Vector3(rest.left if side=="L" else rest.right)
		point.x=signf(point.x)*(.325*torso_scale+.025)
		var arm_position:=upper*point
		var target: Vector3=weapon*(G3_SUPPORT if side=="L" else G3_GRIP)
		var relative_grip:=body.affine_inverse()*target
		var relative_hand_basis:=body.basis.inverse()*weapon.basis
		var result: Dictionary=_arm(arm_position,relative_grip,relative_hand_basis,upper,side,clampf(float(bindings.arm_proportion),.65,1.5))
		if result.is_empty():return {"supported":false,"reason":"Invalid arm target"}
		mounts["upper"+side]=body*result.arm*result.upper
		mounts["lower"+side]=body*result.arm*result.lower
		mounts["hand"+side]=body*result.arm*result.hand
	var regions: Dictionary={}
	var offsets: Dictionary=bindings.offsets
	for id: String in REGION_MOUNTS:
		if offsets.has(id): regions[id]=Transform3D(mounts[REGION_MOUNTS[id]])*Transform3D(offsets[id])
	return {"supported":true,"regions":regions,"has_muzzle":true,"muzzle":muzzle}
