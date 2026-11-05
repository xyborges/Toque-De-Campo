extends RefCounted
class_name WarCollisionPoseSolver
## P1b independent collision pose solver for common firearm models.
## bind() samples rest-geometry once per equipped weapon. solve() uses only
## state and rest transforms: no Node3D, camera, MeshInstance or physics query.
## Unsupported action/posture/movement is rejected rather than approximated.
const UPPER:=.37
const LOWER:=.35
const WAIST:=Vector3(0,.87,0)
const SUPPORTED_WEAPONS:=["g3","ak","fal","glock","sniper"]
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

static func bind(actor: WarPlayer,region_source: Dictionary={}) -> Dictionary:
	# Only calibration: local region offsets, authored segment transforms,
	# rest positions and body translation. Never read live visual pose in solve.
	# P1g may bind while actor.hit_regions points at the independent proxy;
	# use the preserved legacy region dictionary to keep authored offsets stable.
	var physical_regions: Dictionary=actor.hit_regions if region_source.is_empty() else region_source
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
		var area: Area3D=physical_regions.get(region_id)
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
		legs[side]={"base_position":Vector3(rest["leg_"+side.to_lower()]),"thigh":thigh.transform,"knee":knee.transform,"shoe":foot.transform,"sole_y":float(actor.stance.leg_parts[side].sole_y),"foot_centre":Vector3(actor.stance.leg_parts[side].foot_centre),"foot_half":Vector3(actor.stance.leg_parts[side].foot_half),"leg_scale":leg.scale}
	var weapon_id: String=GameWeapons.canonical(actor.weapon_id)
	var model:=actor.weapon_root.get_node_or_null("Imported_"+weapon_id) as Node3D
	var hand_basis_world: Basis=actor.weapon_root.global_basis
	if weapon_id in ["fal","glock","g3"] and is_instance_valid(model):
		hand_basis_world=model.global_basis
	elif weapon_id=="ak" and is_instance_valid(model):
		hand_basis_world=GameAKReload.hand_basis(model)
	# Treat arm, muzzle and model reference as static offsets for THIS weapon.
	# No scene data from the avatar will be consulted by solve().
	var weapon_space: Transform3D=actor.weapon_root.global_transform.affine_inverse()
	var model_rest:=model.transform if is_instance_valid(model) else Transform3D.IDENTITY
	var model_rest_basis:=Basis(model.get_meta("rest_basis",model.basis)) if is_instance_valid(model) else Basis.IDENTITY
	var model_rest_position:=Vector3(model.get_meta("rest_position",model.position)) if is_instance_valid(model) else Vector3.ZERO
	var muzzle_model_local:=model.global_transform.affine_inverse()*actor.muzzle_marker.global_transform if is_instance_valid(model) and is_instance_valid(actor.muzzle_marker) else Transform3D.IDENTITY
	var right_model_local:=model.global_transform.affine_inverse()*actor.weapon_hand_target(false) if is_instance_valid(model) else Vector3.ZERO
	var optic_id:=str(actor.weapon_optics.selected_optic)
	var optic_aimed_offset:=actor.weapon_optics.aimed_offset(weapon_id) if actor.weapon_optics.enabled(actor) else Vector3.ZERO
	return {"offsets":offsets,"rest":rest.duplicate(true),"legs":legs,
		"weapon_id":weapon_id,
		"grip_left":weapon_space*((actor.avatar_parts.arm_l.get_node("HandL") as Node3D).global_position if weapon_id=="g3" else actor.weapon_hand_target(true)),
		"grip_right":weapon_space*actor.weapon_hand_target(false),
		"hand_basis_local":actor.weapon_root.global_basis.inverse()*hand_basis_world,
		"muzzle_local":weapon_space*actor.muzzle_marker.global_transform,
		"muzzle_model_local":muzzle_model_local,
		"right_model_local":right_model_local,
		"model_rest":model_rest,
		"model_rest_basis":model_rest_basis,
		"model_rest_position":model_rest_position,
		"optic_id":optic_id,
		"optic_aimed_offset":optic_aimed_offset,
		"ground_y":actor.stance.visual_ground_offset(actor),
		"leg_scale":actor.stance.leg_scale(actor),
		"reference_foot_y":actor.stance.reference_foot_y,
		"torso_proportion":float(actor.body_proportions.get("torso",1.)),
		"head_proportion":float(actor.body_proportions.get("head",1.)),
		"arm_proportion":float(actor.body_proportions.get("arms",1.)),
		"leg_proportion":float(actor.body_proportions.get("legs",1.)),
		"bound_regions":offsets.size()}

static func supported(state: Dictionary) -> bool:
	var c: float=float(state.get("crouch_weight",0.))
	var p: float=float(state.get("prone_weight",0.))
	# Mid-transition pose currently depends on the visual frame before stance
	# interpolation; reject it until a previous-pose state is modeled explicitly.
	var steady_posture: bool=c>=0. and c<=1. and (absf(p)<.00001 or (absf(p-1.)<.00001 and c<.00001))
	var moving: float=float(state.get("moving",0.))
	var sprint: float=float(state.get("sprint",0.))
	var walking: bool=moving>=0. and moving<=1. and sprint>=0. and sprint<=1. and (moving<.00001 or bool(state.get("grounded",false)))
	# During standing idle, nonzero stale velocity drives the legacy clock
	# gait. Do not silently approximate it with a stationary limb transform.
	var no_stale_gait: bool=moving>.00001 or float(state.get("velocity_ground_speed",0.))<.001
	var direction: Vector3=state.get("direction",Vector3.ZERO)
	var valid_motion: bool=walking and no_stale_gait and bool(state.get("legs_intact",true)) and is_finite(float(state.get("phase",0.))) and direction.is_finite()
	var iron: bool=bool(state.get("iron",false))
	var scoped: bool=bool(state.get("scoped",false))
	var optic_enabled: bool=bool(state.get("optic_enabled",false))
	var optic_weight: float=float(state.get("optic_weight",0.))
	var optic_id: String=str(state.get("optic_id",""))
	var valid_optic_weight: bool=is_finite(optic_weight) and optic_weight>=0. and optic_weight<=1.
	var optical_state_valid: bool=(not optic_enabled and not scoped and optic_id.is_empty()) or (optic_enabled and valid_optic_weight and not optic_id.is_empty() and (not scoped or optic_weight>.0))
	# Hip/soft-aim/iron without an optic and the full optical raise/lower
	# timeline are both supported. Binding identity is checked in solve().
	var ads_safe: bool=optical_state_valid and (not iron or not optic_enabled or valid_optic_weight)
	var reload_left: float=float(state.get("reload_left",0.))
	var reload_total: float=float(state.get("reload_total",0.))
	var reload_weapon: String=GameWeapons.canonical(str(state.get("reload_weapon","")))
	var reload_active: bool=reload_left>.00001
	var reload_safe: bool=not reload_active or (reload_total>.00001 and reload_weapon==GameWeapons.canonical(str(state.get("weapon",""))))
	return str(state.get("weapon","")) in SUPPORTED_WEAPONS and ads_safe and steady_posture and valid_motion and reload_safe and float(state.get("fire_cooldown",0.))<=0. and float(state.get("reaction",0.))==0. and float(state.get("attack",0.))==0. and float(state.get("recoil",0.))==0. and not bool(state.get("special",false))

static func state(actor: WarPlayer) -> Dictionary:
	return {"weapon":actor.weapon_id,"pitch":actor.pitch,"lean":actor.lean,"scoped":actor.weapon_optics.presented(),"iron":actor.iron_sights,"aiming":actor.aiming,"optic_enabled":actor.weapon_optics.enabled(actor),"optic_weight":actor.weapon_optics.aim_weight,"optic_id":str(actor.weapon_optics.selected_optic),"fire_cooldown":actor.fire_cooldown,
		"grounded":actor.locomotion.grounded,"phase":actor.locomotion.phase,
		"direction":actor.locomotion.local_direction,"velocity_ground_speed":Vector2(actor.velocity.x,actor.velocity.z).length(),
		"crouched":actor.crouched,"prone":actor.prone,
		"legs_intact":float(actor.limbs.legL)>0. and float(actor.limbs.legR)>0.,
		"crouch_weight":actor.stance.crouch_weight,"prone_weight":actor.stance.prone_weight,
		"moving":actor.locomotion.moving,"sprint":actor.locomotion.sprint,"reaction":actor.reaction,
		"reload_left":actor.reload_left,"reload_total":actor.reload_total,"reload_weapon":actor.reload_weapon,"attack":actor.attack_anim,"recoil":actor.recoil,
		"special":actor.gadget_equipped or not actor.utility_mode.is_empty() or actor._grenade_active() or actor.in_water() or not actor.deployed or actor.hp<=0 or not actor.vehicle_id.is_empty()}

static func _gait_angles(input: Dictionary,side: String,lean: float) -> Vector3:
	var moving: float=clampf(float(input.get("moving",0.)),0.,1.)
	var sprint: float=clampf(float(input.get("sprint",0.)),0.,1.)
	var phase: float=float(input.get("phase",0.))
	var direction: Vector3=input.get("direction",Vector3.ZERO)
	var amount: float=moving*(.28 if bool(input.get("crouched",false)) else lerpf(.36,.67,sprint))
	var stride: float=sin(phase)*amount
	var forward: float=clampf(-direction.z,-1.,1.)
	var lateral: float=clampf(direction.x,-1.,1.)
	var sign_value: float=-1. if side=="L" else 1.
	return Vector3(sign_value*stride*forward,0.,sign_value*stride*lateral*.55-atan2(lean*.04,.78))

static func _walking_height(bindings: Dictionary,input: Dictionary,lean: float) -> float:
	# The authored boot AABB is calibrated once. Keep the exact planted-sole
	# support calculation of WarStance without reading mesh nodes each tick.
	var lowest:=INF
	for side: String in ["L","R"]:
		var data: Dictionary=bindings.legs[side]
		var angles:=_gait_angles(input,side,lean)
		var position: Vector3=Vector3(data.base_position)+Vector3(lean*.04,0.,0.)
		var leg_pose:=Transform3D(Basis.from_euler(angles)*Basis.from_scale(Vector3(data.leg_scale)),position)
		var pose: Transform3D=leg_pose*Transform3D(data.knee)*Transform3D(data.shoe)
		var basis: Basis=pose.basis
		var centre: Vector3=pose*Vector3(data.foot_centre)
		var half: Vector3=data.foot_half
		lowest=minf(lowest,centre.y-absf(basis.x.y)*half.x-absf(basis.y.y)*half.y-absf(basis.z.y)*half.z)
	return float(bindings.reference_foot_y)-lowest if is_finite(lowest) else float(bindings.ground_y)

static func _upper(pitch: float,lean: float) -> Transform3D:
	var b:=Basis(Vector3.BACK,-lean*.18)*Basis(Vector3.RIGHT,clampf(pitch*.42,-.49,.49))
	return Transform3D(b,WAIST+Vector3(lean*.04,0,0)-b*WAIST)

static func _arm(shoulder: Vector3,grip: Vector3,hand_basis: Basis,upper_pose: Transform3D,side: String,proportion: float,pistol: bool=false,grabbing: bool=false) -> Dictionary:
	var cuff:=Vector3(-.035,-.029,.075) if side=="L" and not pistol and not grabbing else Vector3(.023,-.025,.085)
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

static func _reload_geometry(bindings: Dictionary,input: Dictionary) -> Dictionary:
	var weapon_id: String=str(bindings.weapon_id)
	var left: float=float(input.get("reload_left",0.))
	var total: float=float(input.get("reload_total",0.))
	var reload_weapon: String=GameWeapons.canonical(str(input.get("reload_weapon","")))
	var active: bool=left>.00001 and total>.00001 and reload_weapon==weapon_id
	var pose: Dictionary=GameReloadPose.state(weapon_id,left if active else 0.,total)
	var model_local: Transform3D=Transform3D(bindings.model_rest)
	var grip_left: Vector3=bindings.grip_left
	var grip_right: Vector3=bindings.grip_right
	var hand_basis_local: Basis=bindings.hand_basis_local
	var grabbing:=false
	var muzzle_local: Transform3D=Transform3D(bindings.muzzle_local)
	if active:
		var rest_basis: Basis=bindings.model_rest_basis
		var rest_position: Vector3=bindings.model_rest_position
		var pose_basis:=Basis.from_euler(Vector3(pose.angles))
		model_local=Transform3D(pose_basis if weapon_id in ["fal","glock","g3"] else pose_basis*rest_basis,rest_position+Vector3(pose.offset))
		if weapon_id=="sniper":
			grip_left=model_local*(rest_basis.inverse()*(Vector3(pose.hand)-rest_position))
			grip_right=model_local*(rest_basis.inverse()*(Vector3(pose.right_hand)-rest_position))
			# Sniper hands intentionally stay aligned to the weapon root while
			# the imported one-piece rifle rocks below them.
			hand_basis_local=Basis(bindings.hand_basis_local)
		elif weapon_id=="ak":
			grip_left=model_local*Vector3(pose.hand)
			grip_right=model_local*Vector3(pose.right_hand)
			hand_basis_local=model_local.basis*rest_basis.inverse()
		else:
			grip_left=model_local*Vector3(pose.hand)
			grip_right=model_local*Vector3(bindings.right_model_local)
			hand_basis_local=model_local.basis
		grabbing=bool(pose.get("hand_grabbing",false))
		muzzle_local=model_local*Transform3D(bindings.muzzle_model_local)
	return {"active":active,"pose":pose,"grip_left":grip_left,"grip_right":grip_right,
		"hand_basis_local":hand_basis_local,"grabbing":grabbing,"muzzle_local":muzzle_local}

static func solve(bindings: Dictionary,input: Dictionary) -> Dictionary:
	if not supported(input) or str(input.get("weapon",""))!=str(bindings.get("weapon_id","")):
		return {"supported":false,"reason":"Requires matching calibrated firearm and supported posture/motion; recoil and utility remain gated"}
	if bool(input.get("optic_enabled",false)) and str(input.get("optic_id",""))!=str(bindings.get("optic_id","")):
		return {"supported":false,"reason":"Optic does not match calibrated binding"}
	var pitch: float=clampf(float(input.pitch),-1.5,1.5)
	var lean: float=clampf(float(input.lean),-1.,1.)
	var rest: Dictionary=bindings.rest
	var upper:=_upper(pitch,lean)
	var crouch: float=clampf(float(input.crouch_weight),0.,1.)
	var prone: float=clampf(float(input.prone_weight),0.,1.)
	var body_height: float=float(bindings.ground_y)*(1.-prone)-.54*float(bindings.leg_scale)*crouch+.22*prone
	var moving: float=float(input.get("moving",0.))
	var sprint: float=float(input.get("sprint",0.))
	var phase: float=float(input.get("phase",0.))
	var direction: Vector3=input.get("direction",Vector3.ZERO)
	if crouch<.00001 and prone<.00001 and moving>.00001 and bool(input.get("grounded",false)):
		body_height=_walking_height(bindings,input,lean)
	var body:=Transform3D(Basis.IDENTITY,Vector3(0,body_height,0))
	# WarPlayer clamps muzzle aim more tightly while prone; the torso still
	# uses the raw pose pitch when matching the current procedural rig.
	var weapon_pitch: float=clampf(pitch,-.38 if prone>.99999 else -1.30,1.25)
	var basis_pitch:=Basis(Vector3.RIGHT,weapon_pitch)
	var aim:=basis_pitch*Basis(Vector3.BACK,-lean*.18)
	var shoulder: Vector3=(upper*Vector3(0,1.42,0)).lerp(Vector3(lean*.04,.13,-.64),prone)
	var clearance: float=(.10+.07*absf(lean))*smoothstep(.4,1.3,-weapon_pitch)
	shoulder+=upper.basis*Vector3(0,0,-clearance)
	var weapon_id: String=bindings.weapon_id
	var weapon_offset:=Vector3(.15,-.045,-.38) if weapon_id in ["fal","g3"] else (Vector3(.20,-.035,-.48) if weapon_id=="glock" else Vector3(.23,-.06,-.53))
	var weapon:=body*Transform3D(aim,shoulder+aim*weapon_offset)
	var optical_presenting: bool=bool(input.get("optic_enabled",false)) and (bool(input.get("iron",false)) or float(input.get("optic_weight",0.))>.00001)
	if not optical_presenting:
		weapon.origin.y-=.05*crouch+1.20*prone
		weapon.origin.z-=.30*prone
		if prone>0.:
			var head_clearance: float=.19*clampf(float(bindings.head_proportion),.65,1.5)+.06
			weapon.origin.x=lerpf(weapon.origin.x,maxf(weapon.origin.x,head_clearance),prone)
	var optic_enabled: bool=bool(input.get("optic_enabled",false))
	var optic_weight: float=clampf(float(input.get("optic_weight",0.)),0.,1.)
	if optic_enabled and (bool(input.get("iron",false)) or optic_weight>.0):
		var camera_position:=Vector3(lean*.23,1.68+float(bindings.ground_y)*(1.-prone)-.55*float(bindings.leg_scale)*crouch-1.20*prone,-.90*prone)
		var aimed:=Transform3D(aim,camera_position+aim*Vector3(bindings.optic_aimed_offset))
		weapon=weapon.interpolate_with(aimed,smoothstep(0.,1.,optic_weight))
	if (moving>.00001 or sprint>.00001) and not bool(input.get("aiming",false)) and not bool(input.get("iron",false)) and float(input.get("reload_left",0.))<=.00001:
		var pulse: float=sin(phase)
		var lift: float=absf(cos(phase))
		var weight: float=moving*(.38+.62*sprint)
		var offset:=Vector3(pulse*.012*weight,-.09*sprint-lift*.012*weight,.035*sprint)
		var rotation_offset:=Vector3(.06*sprint,0.,.12*sprint+pulse*.012*weight)
		weapon.origin+=Basis(Vector3.RIGHT,pitch)*offset
		weapon.basis=Basis.from_euler(weapon.basis.get_euler()+rotation_offset)
	var reload_geometry: Dictionary=_reload_geometry(bindings,input)
	var muzzle: Transform3D=weapon*Transform3D(reload_geometry.muzzle_local)
	var torso_scale:=clampf(float(bindings.torso_proportion),.65,1.5)
	var head_scale:=clampf(float(bindings.head_proportion),.65,1.5)
	var head_basis:=Basis(Vector3.RIGHT,clampf(pitch*.92,-1.12,1.12))*Basis(Vector3.BACK,-lean*.18)
	var neck:=Vector3(0,float(Vector3(rest.head).y)-.21,0)
	var mounts: Dictionary={}
	var torso_animation:=Basis.from_euler(Vector3(-.085*sprint*maxf(0.,-direction.z),0.,-direction.x*.035*moving))
	var torso_euler: Vector3=(upper.basis*torso_animation).get_euler()
	torso_euler.x=lerp_angle(torso_euler.x,-PI*.5,prone)
	var torso_basis:=Basis.from_euler(torso_euler)*Basis.from_scale(Vector3.ONE*torso_scale)
	var torso_origin: Vector3=(upper*Vector3(rest.torso)).lerp(Vector3(0,.06,-.42),prone)
	mounts["torso"]=body*Transform3D(torso_basis,torso_origin)
	mounts["head"]=body*Transform3D(head_basis*Basis.from_scale(Vector3.ONE*head_scale),(upper*neck+head_basis*(Vector3(rest.head)-neck)).lerp(Vector3(0,.22,-1.02),prone))
	var pelvis_origin: Vector3=(Vector3(rest.pelvis)+Vector3(lean*.04,0,0)).lerp(Vector3(0,.04,.05),prone)
	var pelvis_basis:=Basis.from_euler(Vector3(-PI*.5*prone,0.,-lean*.035))
	mounts["pelvis"]=body*Transform3D(pelvis_basis,pelvis_origin)
	var legs: Dictionary=bindings.legs
	for side: String in ["L","R"]:
		var leg: Dictionary=legs[side]
		var sign_value: float=-1. if side=="L" else 1.
		var position: Vector3=(Vector3(leg.base_position)+Vector3(lean*.04,0,0)).lerp(Vector3(sign_value*.16,0,.10),prone)
		var gait_angles: Vector3=_gait_angles(input,side,lean)
		var leg_roll: float=gait_angles.z+sign_value*.07*prone
		var crawl: float=sin(phase+(0. if side=="L" else PI))*.20*moving
		var foot_z: float=-.055+sin(phase+(0. if side=="L" else PI))*.10*moving
		var dy: float=float(bindings.reference_foot_y)-float(leg.sole_y)*float(bindings.leg_scale)-body_height-position.y
		var dz: float=foot_z-position.z
		var a: float=.42*float(bindings.leg_scale)
		var b: float=.36*float(bindings.leg_scale)
		var reach: float=clampf(Vector2(dy,dz).length(),absf(a-b)+.001,a+b-.001)
		var thigh: float=atan2(-dz,-dy)+acos(clampf((a*a+reach*reach-b*b)/(2*a*reach),-1,1))
		var bend: float=-acos(clampf((reach*reach-a*a-b*b)/(2*a*b),-1,1))
		var thigh_angle: float=lerpf(lerpf(gait_angles.x,thigh,crouch),-PI*.5+(.04+crawl)*prone,prone)
		var knee_y: float=body_height+position.y-a*cos(thigh_angle)
		var ankle_y: float=.22*float(bindings.leg_scale)+.02+maxf(0.,crawl)*.04
		var prone_bend: float=-acos(clampf((knee_y-ankle_y)/b,-1.,1.))-thigh_angle
		var knee_angle: float=bend*crouch+prone_bend*prone
		var shoe_angle: float=-(thigh_angle+knee_angle)*crouch
		var leg_pose:=body*Transform3D(Basis.from_euler(Vector3(thigh_angle,0.,leg_roll))*Basis.from_scale(Vector3(leg.leg_scale)),position)
		var knee_pose:=Transform3D(Basis(Vector3.RIGHT,knee_angle)*Transform3D(leg.knee).basis,Vector3(Transform3D(leg.knee).origin))
		var shoe_pose:=Transform3D(Basis(Vector3.RIGHT,shoe_angle)*Transform3D(leg.shoe).basis,Vector3(Transform3D(leg.shoe).origin))
		mounts["thigh"+side]=leg_pose*Transform3D(leg.thigh)
		mounts["shin"+side]=leg_pose*knee_pose
		mounts["foot"+side]=leg_pose*knee_pose*shoe_pose
	for side: String in ["L","R"]:
		var point:=Vector3(rest.left if side=="L" else rest.right)
		point.x=signf(point.x)*(.325*torso_scale+.025)
		var arm_position: Vector3=(upper*point).lerp(Vector3(-(.325*torso_scale+.025) if side=="L" else (.325*torso_scale+.025),.13,-.64),prone)
		var target: Vector3=weapon*Vector3(reload_geometry.grip_left if side=="L" else reload_geometry.grip_right)
		var relative_grip:=body.affine_inverse()*target
		var relative_hand_basis:=body.basis.inverse()*weapon.basis*Basis(reload_geometry.hand_basis_local)
		var result: Dictionary=_arm(arm_position,relative_grip,relative_hand_basis,upper,side,clampf(float(bindings.arm_proportion),.65,1.5),str(bindings.weapon_id)=="glock",side=="L" and bool(reload_geometry.grabbing))
		if result.is_empty():return {"supported":false,"reason":"Invalid arm target"}
		mounts["upper"+side]=body*result.arm*result.upper
		mounts["lower"+side]=body*result.arm*result.lower
		mounts["hand"+side]=body*result.arm*result.hand
	var regions: Dictionary={}
	var offsets: Dictionary=bindings.offsets
	for id: String in REGION_MOUNTS:
		if offsets.has(id): regions[id]=Transform3D(mounts[REGION_MOUNTS[id]])*Transform3D(offsets[id])
	return {"supported":true,"regions":regions,"has_muzzle":true,"muzzle":muzzle}
