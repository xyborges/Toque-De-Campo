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

# Fixed order shared by the packed runtime buffers. The public dictionary API
# preserves authored region IDs, including missing optional regions.
const MOUNT_INDEX: Dictionary={"head":0,"torso":1,"pelvis":2,"upperL":3,"upperR":4,"lowerL":5,"lowerR":6,"handL":7,"handR":8,"thighL":9,"thighR":10,"shinL":11,"shinR":12,"footL":13,"footR":14}
const SIDES: Array[String]=["L","R"]

# Runtime inputs and calibration use typed fields. Public dictionary adapters
# remain available for QA. Each actor owns its buffers; no state is quantized
# or reused across ticks, and the solve still runs at the physics cadence.
class PoseInput:
	extends RefCounted
	var weapon: String=""
	var pitch: float=0.
	var lean: float=0.
	var scoped: bool=false
	var iron: bool=false
	var aiming: bool=false
	var optic_enabled: bool=false
	var optic_weight: float=0.
	var optic_id: String=""
	var fire_cooldown: float=0.
	var grounded: bool=false
	var phase: float=0.
	var direction: Vector3=Vector3.ZERO
	var velocity_ground_speed: float=0.
	var crouched: bool=false
	var prone: bool=false
	var legs_intact: bool=true
	var crouch_weight: float=0.
	var prone_weight: float=0.
	var moving: float=0.
	var sprint: float=0.
	var reaction: float=0.
	var reload_left: float=0.
	var reload_total: float=0.
	var reload_weapon: String=""
	var attack: float=0.
	var recoil: float=0.
	var special: bool=false

	static func from_dictionary(values: Dictionary) -> PoseInput:
		var out:=PoseInput.new()
		out.weapon=str(values.get("weapon",""))
		out.pitch=float(values.get("pitch",0.))
		out.lean=float(values.get("lean",0.))
		out.scoped=bool(values.get("scoped",false))
		out.iron=bool(values.get("iron",false))
		out.aiming=bool(values.get("aiming",false))
		out.optic_enabled=bool(values.get("optic_enabled",false))
		out.optic_weight=float(values.get("optic_weight",0.))
		out.optic_id=str(values.get("optic_id",""))
		out.fire_cooldown=float(values.get("fire_cooldown",0.))
		out.grounded=bool(values.get("grounded",false))
		out.phase=float(values.get("phase",0.))
		out.direction=Vector3(values.get("direction",Vector3.ZERO))
		out.velocity_ground_speed=float(values.get("velocity_ground_speed",0.))
		out.crouched=bool(values.get("crouched",false))
		out.prone=bool(values.get("prone",false))
		out.legs_intact=bool(values.get("legs_intact",true))
		out.crouch_weight=float(values.get("crouch_weight",0.))
		out.prone_weight=float(values.get("prone_weight",0.))
		out.moving=float(values.get("moving",0.))
		out.sprint=float(values.get("sprint",0.))
		out.reaction=float(values.get("reaction",0.))
		out.reload_left=float(values.get("reload_left",0.))
		out.reload_total=float(values.get("reload_total",0.))
		out.reload_weapon=str(values.get("reload_weapon",""))
		out.attack=float(values.get("attack",0.))
		out.recoil=float(values.get("recoil",0.))
		out.special=bool(values.get("special",false))
		return out

class LegCalibration:
	extends RefCounted
	var base_position: Vector3
	var thigh: Transform3D
	var knee: Transform3D
	var shoe: Transform3D
	var sole_y: float
	var foot_centre: Vector3
	var foot_half: Vector3
	var leg_scale: Vector3

	static func from_dictionary(value: Dictionary) -> LegCalibration:
		var out:=LegCalibration.new()
		out.base_position=value.base_position
		out.thigh=value.thigh
		out.knee=value.knee
		out.shoe=value.shoe
		out.sole_y=value.sole_y
		out.foot_centre=value.foot_centre
		out.foot_half=value.foot_half
		out.leg_scale=value.leg_scale
		return out

class Calibration:
	extends RefCounted
	var offsets: Dictionary
	var rest: Dictionary
	var legs: Array[LegCalibration]=[]
	var neutral_grip: Dictionary
	var weapon_id: String
	var hand_basis_local: Basis
	var muzzle_model_local: Transform3D
	var right_model_local: Vector3
	var model_rest_basis: Basis
	var model_rest_position: Vector3
	var optic_id: String
	var optic_aimed_offset: Vector3
	var ground_y: float
	var leg_scale: float
	var reference_foot_y: float
	var torso_proportion: float
	var head_proportion: float
	var arm_proportion: float
	var leg_proportion: float
	var bound_regions: int
	var mounts: Array[Transform3D]=[]
	var region_ids: Array[String]=[]
	var region_mounts: Array[int]=[]
	var region_offsets: Array[Transform3D]=[]
	var region_poses: Array[Transform3D]=[]
	var frame: Dictionary={"supported":true,"regions":{},"has_muzzle":true,"muzzle":Transform3D.IDENTITY}
	var presentation: Dictionary={"legL":{},"legR":{}}
	var arm_results: Array[Dictionary]=[{},{}]

	static func from_dictionary(values: Dictionary) -> Calibration:
		var out:=Calibration.new()
		out.offsets=values.offsets
		out.rest=values.rest
		for side in SIDES: out.legs.append(LegCalibration.from_dictionary(values.legs[side]))
		out.mounts.resize(15)
		for id: String in REGION_MOUNTS:
			if values.offsets.has(id):
				out.region_ids.append(id)
				out.region_mounts.append(MOUNT_INDEX[REGION_MOUNTS[id]])
				out.region_offsets.append(values.offsets[id])
		out.region_poses.resize(out.region_ids.size())
		out.neutral_grip=values.neutral_grip
		out.weapon_id=values.weapon_id
		out.hand_basis_local=values.hand_basis_local
		out.muzzle_model_local=values.muzzle_model_local
		out.right_model_local=values.right_model_local
		out.model_rest_basis=values.model_rest_basis
		out.model_rest_position=values.model_rest_position
		out.optic_id=values.optic_id
		out.optic_aimed_offset=values.optic_aimed_offset
		out.ground_y=values.ground_y
		out.leg_scale=values.leg_scale
		out.reference_foot_y=values.reference_foot_y
		out.torso_proportion=values.torso_proportion
		out.head_proportion=values.head_proportion
		out.arm_proportion=values.arm_proportion
		out.leg_proportion=values.leg_proportion
		out.bound_regions=values.bound_regions
		return out

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
		# Stance animates these pivots. Binding after equipping in a low
		# posture must retain the neutral bases or solve() adds the bend twice.
		var knee_rest:=Transform3D(Basis.from_scale(knee.scale),knee.position)
		var shoe_rest:=Transform3D(Basis.from_scale(foot.scale),foot.position)
		legs[side]={"base_position":Vector3(rest["leg_"+side.to_lower()]),"thigh":thigh.transform,"knee":knee_rest,"shoe":shoe_rest,"sole_y":float(actor.stance.leg_parts[side].sole_y),"foot_centre":Vector3(actor.stance.leg_parts[side].foot_centre),"foot_half":Vector3(actor.stance.leg_parts[side].foot_half),"leg_scale":leg.scale}
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
	var model_rest_basis:=Basis(model.get_meta("rest_basis",model.basis)) if is_instance_valid(model) else Basis.IDENTITY
	var model_rest_position:=Vector3(model.get_meta("rest_position",model.position)) if is_instance_valid(model) else Vector3.ZERO
	var muzzle_model_local:=model.global_transform.affine_inverse()*actor.muzzle_marker.global_transform if is_instance_valid(model) and is_instance_valid(actor.muzzle_marker) else Transform3D.IDENTITY
	var right_model_local:=model.global_transform.affine_inverse()*actor.weapon_hand_target(false) if is_instance_valid(model) else Vector3.ZERO
	var optic_id:=str(actor.weapon_optics.selected_optic)
	var optic_aimed_offset:=actor.weapon_optics.aimed_offset(weapon_id) if actor.weapon_optics.enabled(actor) else Vector3.ZERO
	var support_target:=actor.weapon_hand_target(true)
	if weapon_id in ["fal","glock","g3"] and is_instance_valid(model):
		support_target=(model.get_node("SupportGrip") as Marker3D).global_position
	var hand_basis_local:=actor.weapon_root.global_basis.inverse()*hand_basis_world
	return {"offsets":offsets,"rest":rest.duplicate(true),"legs":legs,
		"weapon_id":weapon_id,
		"neutral_grip":{"grip_left":weapon_space*support_target,
			"grip_right":weapon_space*actor.weapon_hand_target(false),"hand_basis_local":hand_basis_local,
			"muzzle_local":weapon_space*actor.muzzle_marker.global_transform,"grabbing":false,
			"model":model.transform if is_instance_valid(model) else Transform3D.IDENTITY,
			"timeline":GameReloadPose.state(weapon_id,0.,0.)},
		"hand_basis_local":hand_basis_local,
		"muzzle_model_local":muzzle_model_local,
		"right_model_local":right_model_local,
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
	return _supported(PoseInput.from_dictionary(state))

static func _supported(state: PoseInput) -> bool:
	var c: float=state.crouch_weight
	var p: float=state.prone_weight
	# Match WarStance's continuous weights, including crouch/prone overlap.
	var valid_posture: bool=c>=0. and c<=1. and p>=0. and p<=1.
	var moving: float=state.moving
	var sprint: float=state.sprint
	# The run blend decays slower than movement. While still in the air,
	# either weight keeps the legacy compact jump pose active.
	var walking: bool=moving>=0. and moving<=1. and sprint>=0. and sprint<=1. and ((moving==0. and sprint==0.) or state.grounded)
	# During standing idle, nonzero stale velocity drives the legacy clock
	# gait. Do not silently approximate it with a stationary limb transform.
	var no_stale_gait: bool=moving>.00001 or state.velocity_ground_speed<.001
	var direction: Vector3=state.direction
	var valid_motion: bool=walking and no_stale_gait and state.legs_intact and is_finite(state.phase) and direction.is_finite()
	var iron: bool=state.iron
	var scoped: bool=state.scoped
	var optic_enabled: bool=state.optic_enabled
	var optic_weight: float=state.optic_weight
	var optic_id: String=state.optic_id
	var valid_optic_weight: bool=is_finite(optic_weight) and optic_weight>=0. and optic_weight<=1.
	var optical_state_valid: bool=(not optic_enabled and not scoped and optic_id.is_empty()) or (optic_enabled and valid_optic_weight and not optic_id.is_empty() and (not scoped or optic_weight>.0))
	# Hip/soft-aim/iron without an optic and the full optical raise/lower
	# timeline are both supported. Binding identity is checked in solve().
	var ads_safe: bool=optical_state_valid and (not iron or not optic_enabled or valid_optic_weight)
	var reload_left: float=state.reload_left
	var reload_total: float=state.reload_total
	var reload_safe: bool=reload_left<=.00001 or (reload_total>.00001 and GameWeapons.canonical(state.reload_weapon)==state.weapon)
	return state.weapon in SUPPORTED_WEAPONS and ads_safe and valid_posture and valid_motion and reload_safe and state.fire_cooldown<=0. and state.reaction==0. and state.attack==0. and state.recoil==0. and not state.special

static func state(actor: WarPlayer) -> Dictionary:
	# Refresh validates attachments and updates selected_optic with the mounted
	# optic. The physics tick can use that result without validating it again.
	var optic_id: String=actor.weapon_optics.selected_optic
	var stale_velocity: bool=not actor.is_local and actor.locomotion.initialized and actor.locomotion.speed<=.18
	var ground_speed:=0. if stale_velocity else Vector2(actor.velocity.x,actor.velocity.z).length()
	return {"weapon":actor.weapon_id,"pitch":actor.pitch,"lean":actor.lean,"scoped":actor.weapon_optics.presented(),"iron":actor.iron_sights,"aiming":actor.aiming,"optic_enabled":not optic_id.is_empty(),"optic_weight":actor.weapon_optics.aim_weight,"optic_id":optic_id,"fire_cooldown":actor.fire_cooldown,
		"grounded":actor.locomotion.grounded,"phase":actor.locomotion.phase,
		"direction":actor.locomotion.local_direction,"velocity_ground_speed":ground_speed,
		"crouched":actor.crouched,"prone":actor.prone,
		"legs_intact":float(actor.limbs.legL)>0. and float(actor.limbs.legR)>0.,
		"crouch_weight":actor.stance.crouch_weight,"prone_weight":actor.stance.prone_weight,
		"moving":actor.locomotion.moving,"sprint":actor.locomotion.sprint,"reaction":actor.reaction,
		"reload_left":actor.reload_left,"reload_total":actor.reload_total,"reload_weapon":actor.reload_weapon,"attack":actor.attack_anim,"recoil":actor.recoil,
		"special":actor.is_npc or actor.gadget_equipped or not actor.utility_mode.is_empty() or actor._grenade_active() or actor.in_water() or not actor.deployed or actor.hp<=0 or not actor.vehicle_id.is_empty() or ((float(actor.limbs.armL)<=0. or float(actor.limbs.armR)<=0.) and CombatRules.limb_disability_enabled(actor.game))}

static func capture(actor: WarPlayer,out: PoseInput) -> void:
	# Refresh validates attachments and updates selected_optic with the mounted
	# optic. The physics tick can use that result without validating it again.
	var optic_id: String=actor.weapon_optics.selected_optic
	var stale_velocity: bool=not actor.is_local and actor.locomotion.initialized and actor.locomotion.speed<=.18
	var ground_speed:=0. if stale_velocity else Vector2(actor.velocity.x,actor.velocity.z).length()
	out.weapon=actor.weapon_id
	out.pitch=actor.pitch
	out.lean=actor.lean
	out.scoped=actor.weapon_optics.presented()
	out.iron=actor.iron_sights
	out.aiming=actor.aiming
	out.optic_enabled=not optic_id.is_empty()
	out.optic_weight=actor.weapon_optics.aim_weight
	out.optic_id=optic_id
	out.fire_cooldown=actor.fire_cooldown
	out.grounded=actor.locomotion.grounded
	out.phase=actor.locomotion.phase
	out.direction=actor.locomotion.local_direction
	out.velocity_ground_speed=ground_speed
	out.crouched=actor.crouched
	out.prone=actor.prone
	out.legs_intact=float(actor.limbs.legL)>0. and float(actor.limbs.legR)>0.
	out.crouch_weight=actor.stance.crouch_weight
	out.prone_weight=actor.stance.prone_weight
	out.moving=actor.locomotion.moving
	out.sprint=actor.locomotion.sprint
	out.reaction=actor.reaction
	out.reload_left=actor.reload_left
	out.reload_total=actor.reload_total
	out.reload_weapon=actor.reload_weapon
	out.attack=actor.attack_anim
	out.recoil=actor.recoil
	out.special=actor.is_npc or actor.gadget_equipped or not actor.utility_mode.is_empty() or actor._grenade_active() or actor.in_water() or not actor.deployed or actor.hp<=0 or not actor.vehicle_id.is_empty() or ((float(actor.limbs.armL)<=0. or float(actor.limbs.armR)<=0.) and CombatRules.limb_disability_enabled(actor.game))

static func _gait_angles(input: PoseInput,side: String,lean: float) -> Vector3:
	var moving: float=clampf(input.moving,0.,1.)
	var sprint: float=clampf(input.sprint,0.,1.)
	var phase: float=input.phase
	var direction: Vector3=input.direction
	var amount: float=moving*(.28 if input.crouched else lerpf(.36,.67,sprint))
	var stride: float=sin(phase)*amount
	var forward: float=clampf(-direction.z,-1.,1.)
	var lateral: float=clampf(direction.x,-1.,1.)
	var sign_value: float=-1. if side=="L" else 1.
	return Vector3(sign_value*stride*forward,0.,sign_value*stride*lateral*.55-atan2(lean*.04,.78))

static func _walking_height(bindings: Calibration,gait_left: Vector3,gait_right: Vector3,lean: float) -> float:
	# The authored boot AABB is calibrated once. Keep the exact planted-sole
	# support calculation of WarStance without reading mesh nodes each tick.
	var lowest:=INF
	for side_index in 2:
		var side: String=SIDES[side_index]
		var data: LegCalibration=bindings.legs[side_index]
		var angles:=gait_left if side=="L" else gait_right
		var position: Vector3=data.base_position+Vector3(lean*.04,0.,0.)
		var leg_pose:=Transform3D(Basis.from_euler(angles)*Basis.from_scale(data.leg_scale),position)
		var pose: Transform3D=leg_pose*data.knee*data.shoe
		var basis: Basis=pose.basis
		var centre: Vector3=pose*data.foot_centre
		var half: Vector3=data.foot_half
		lowest=minf(lowest,centre.y-absf(basis.x.y)*half.x-absf(basis.y.y)*half.y-absf(basis.z.y)*half.z)
	return bindings.reference_foot_y-lowest if is_finite(lowest) else bindings.ground_y

static func _upper(pitch: float,lean: float) -> Transform3D:
	var b:=Basis(Vector3.BACK,-lean*.18)*Basis(Vector3.RIGHT,clampf(pitch*.42,-.49,.49))
	return Transform3D(b,WAIST+Vector3(lean*.04,0,0)-b*WAIST)

static func _arm(shoulder: Vector3,grip: Vector3,hand_basis: Basis,upper_pose: Transform3D,side: String,proportion: float,pistol: bool=false,grabbing: bool=false,output: Dictionary={}) -> Dictionary:
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
	var inverse:=arm.inverse() # The quaternion constructs an orthonormal basis.
	var elbow_local:=inverse*elbow
	var wrist_local:=inverse*wrist
	var lower_basis:=Basis(Quaternion(Vector3.DOWN,(wrist_local-elbow_local).normalized()))*Basis.from_scale(Vector3(proportion,b/LOWER,proportion))
	var lower:=Transform3D(lower_basis,(elbow_local+wrist_local)*.5)
	var upper:=Transform3D(Basis.from_scale(Vector3(proportion,a/UPPER,proportion)),Vector3(0,-a*.5,0))
	var hand:=Transform3D(inverse.basis*hand_basis*Basis.from_scale(Vector3.ONE*proportion),inverse*grip)
	output.arm=arm
	output.upper=upper
	output.lower=lower
	output.hand=hand
	return output

static func _reload_geometry(bindings: Calibration,input: PoseInput) -> Dictionary:
	var weapon_id: String=bindings.weapon_id
	var left: float=input.reload_left
	var total: float=input.reload_total
	if left<=.00001 or total<=.00001:
		return bindings.neutral_grip
	var pose: Dictionary=GameReloadPose.state(weapon_id,left,total)
	var rest_basis: Basis=bindings.model_rest_basis
	var rest_position: Vector3=bindings.model_rest_position
	var pose_basis:=Basis.from_euler(Vector3(pose.angles))
	var model_local:=Transform3D(pose_basis if weapon_id in ["fal","glock","g3"] else pose_basis*rest_basis,rest_position+Vector3(pose.offset))
	var grip_left:=model_local*Vector3(pose.hand)
	var grip_right:=model_local*bindings.right_model_local
	var hand_basis_local:=model_local.basis
	if weapon_id=="sniper":
		grip_left=model_local*(rest_basis.inverse()*(Vector3(pose.hand)-rest_position))
		grip_right=model_local*(rest_basis.inverse()*(Vector3(pose.right_hand)-rest_position))
		# Sniper hands remain aligned to the weapon root.
		hand_basis_local=bindings.hand_basis_local
	elif weapon_id=="ak":
		grip_right=model_local*Vector3(pose.right_hand)
		hand_basis_local=model_local.basis*rest_basis.inverse()
	return {"grip_left":grip_left,"grip_right":grip_right,"hand_basis_local":hand_basis_local,
		"grabbing":bool(pose.hand_grabbing),"muzzle_local":model_local*bindings.muzzle_model_local,
		"model":model_local,"timeline":pose}

static func solve(bindings: Dictionary,input: Dictionary,include_presentation:=false) -> Dictionary:
	var captured:=PoseInput.from_dictionary(input)
	# Keep the diagnostic API's safe rejection before reading calibration.
	if not _supported(captured) or captured.weapon!=str(bindings.get("weapon_id","")):
		return {"supported":false,"reason":"Requires matching calibrated firearm and supported posture/motion; recoil and utility remain gated"}
	return solve_cached(Calibration.from_dictionary(bindings),captured,include_presentation)

static func solve_cached(bindings: Calibration,input: PoseInput,include_presentation:=false,packed:=false) -> Dictionary:
	# Borrowed buffers: consumers must finish before this actor's next solve.
	# solve() above creates a fresh calibration for independent QA snapshots.
	if not _supported(input) or input.weapon!=bindings.weapon_id:
		return {"supported":false,"reason":"Requires matching calibrated firearm and supported posture/motion; recoil and utility remain gated"}
	if input.optic_enabled and input.optic_id!=bindings.optic_id:
		return {"supported":false,"reason":"Optic does not match calibrated binding"}
	var pitch: float=clampf(input.pitch,-1.5,1.5)
	var lean: float=clampf(input.lean,-1.,1.)
	var rest: Dictionary=bindings.rest
	var upper:=_upper(pitch,lean)
	var crouch: float=clampf(input.crouch_weight,0.,1.)
	var prone: float=clampf(input.prone_weight,0.,1.)
	var body_height: float=bindings.ground_y*(1.-prone)-.54*bindings.leg_scale*crouch+.22*prone
	var moving: float=input.moving
	var sprint: float=input.sprint
	var phase: float=input.phase
	var direction: Vector3=input.direction
	var gait_left:=_gait_angles(input,"L",lean)
	var gait_right:=_gait_angles(input,"R",lean)
	if crouch<.00001 and prone<.00001 and moving>.00001 and input.grounded:
		body_height=_walking_height(bindings,gait_left,gait_right,lean)
	var body:=Transform3D(Basis.IDENTITY,Vector3(0,body_height,0))
	# WarPlayer clamps muzzle aim more tightly while prone; the torso still
	# uses the raw pose pitch when matching the current procedural rig.
	var weapon_pitch: float=clampf(pitch,-.38 if input.prone else -1.30,1.25)
	var basis_pitch:=Basis(Vector3.RIGHT,weapon_pitch)
	var aim:=basis_pitch*Basis(Vector3.BACK,-lean*.18)
	var shoulder: Vector3=(upper*Vector3(0,1.42,0)).lerp(Vector3(lean*.04,.13,-.64),prone)
	var clearance: float=(.10+.07*absf(lean))*smoothstep(.4,1.3,-weapon_pitch)
	shoulder+=upper.basis*Vector3(0,0,-clearance)
	var weapon_id: String=bindings.weapon_id
	var weapon_offset:=Vector3(.15,-.045,-.38) if weapon_id in ["fal","g3"] else (Vector3(.20,-.035,-.48) if weapon_id=="glock" else Vector3(.23,-.06,-.53))
	var weapon:=Transform3D(aim,body.origin+shoulder+aim*weapon_offset)
	var optical_presenting: bool=input.optic_enabled and (input.iron or input.optic_weight>.00001)
	if not optical_presenting:
		weapon.origin.y-=.05*crouch+1.20*prone
		weapon.origin.z-=.30*prone
		if prone>0.:
			var head_clearance: float=.19*clampf(bindings.head_proportion,.65,1.5)+.06
			weapon.origin.x=lerpf(weapon.origin.x,maxf(weapon.origin.x,head_clearance),prone)
	var optic_enabled: bool=input.optic_enabled
	var optic_weight: float=clampf(input.optic_weight,0.,1.)
	if optic_enabled and (input.iron or optic_weight>.0):
		var camera_position:=Vector3(lean*.23,1.68+bindings.ground_y*(1.-prone)-.55*bindings.leg_scale*crouch-1.20*prone,-.90*prone)
		var aimed:=Transform3D(aim,camera_position+aim*bindings.optic_aimed_offset)
		weapon=weapon.interpolate_with(aimed,smoothstep(0.,1.,optic_weight))
	if (moving>.00001 or sprint>.00001) and not input.aiming and not input.iron and input.reload_left<=.00001:
		var pulse: float=sin(phase)
		var lift: float=absf(cos(phase))
		var weight: float=moving*(.38+.62*sprint)
		var offset:=Vector3(pulse*.012*weight,-.09*sprint-lift*.012*weight,.035*sprint)
		var rotation_offset:=Vector3(.06*sprint,0.,.12*sprint+pulse*.012*weight)
		weapon.origin+=Basis(Vector3.RIGHT,pitch)*offset
		weapon.basis=Basis.from_euler(weapon.basis.get_euler()+rotation_offset)
	var reload_geometry: Dictionary=_reload_geometry(bindings,input)
	var muzzle: Transform3D=weapon*Transform3D(reload_geometry.muzzle_local)
	var torso_scale:=clampf(bindings.torso_proportion,.65,1.5)
	var head_scale:=clampf(bindings.head_proportion,.65,1.5)
	var head_basis:=Basis(Vector3.RIGHT,clampf(pitch*.92,-1.12,1.12))*Basis(Vector3.BACK,-lean*.18)
	var neck:=Vector3(0,float(Vector3(rest.head).y)-.21,0)
	var mounts: Array[Transform3D]=bindings.mounts
	var presentation: Dictionary=bindings.presentation
	var torso_animation:=Basis.from_euler(Vector3(-.085*sprint*maxf(0.,-direction.z),0.,-direction.x*.035*moving))
	var torso_euler: Vector3=(upper.basis*torso_animation).get_euler()
	torso_euler.x=lerp_angle(torso_euler.x,-PI*.5,prone)
	var torso_basis:=Basis.from_euler(torso_euler)*Basis.from_scale(Vector3.ONE*torso_scale)
	var torso_origin: Vector3=(upper*Vector3(rest.torso)).lerp(Vector3(0,.06,-.42),prone)
	var torso:=Transform3D(torso_basis,torso_origin)
	var head:=Transform3D(head_basis*Basis.from_scale(Vector3.ONE*head_scale),(upper*neck+head_basis*(Vector3(rest.head)-neck)).lerp(Vector3(0,.22,-1.02),prone))
	var pelvis_origin: Vector3=(Vector3(rest.pelvis)+Vector3(lean*.04,0,0)).lerp(Vector3(0,.04,.05),prone)
	var pelvis:=Transform3D(Basis.from_euler(Vector3(-PI*.5*prone,0.,-lean*.035)),pelvis_origin)
	mounts[1]=Transform3D(torso.basis,body.origin+torso.origin)
	mounts[0]=Transform3D(head.basis,body.origin+head.origin)
	mounts[2]=Transform3D(pelvis.basis,body.origin+pelvis.origin)
	if include_presentation:
		presentation.body=body
		presentation.torso=torso
		presentation.head=head
		presentation.pelvis=pelvis
		presentation.weapon=weapon
		presentation.model=reload_geometry.model
		presentation.timeline=reload_geometry.timeline
		presentation.grabbing=reload_geometry.grabbing
		presentation.low_posture=crouch>0. or prone>0.
	var legs: Array[LegCalibration]=bindings.legs
	for side_index in 2:
		var side: String=SIDES[side_index]
		var leg: LegCalibration=legs[side_index]
		var sign_value: float=-1. if side=="L" else 1.
		var position: Vector3=(leg.base_position+Vector3(lean*.04,0,0)).lerp(Vector3(sign_value*.16,0,.10),prone)
		var gait_angles:=gait_left if side=="L" else gait_right
		var leg_roll: float=gait_angles.z+sign_value*.07*prone
		var thigh_angle:=gait_angles.x
		var knee_angle:=0.
		if crouch>0. or prone>0.:
			var crawl: float=sin(phase+(0. if side=="L" else PI))*.20*moving
			var foot_z: float=-.055+sin(phase+(0. if side=="L" else PI))*.10*moving
			var dy: float=bindings.reference_foot_y-leg.sole_y*bindings.leg_scale-body_height-position.y
			var dz: float=foot_z-position.z
			var a: float=.42*bindings.leg_scale
			var b: float=.36*bindings.leg_scale
			var reach: float=clampf(Vector2(dy,dz).length(),absf(a-b)+.001,a+b-.001)
			var thigh: float=atan2(-dz,-dy)+acos(clampf((a*a+reach*reach-b*b)/(2*a*reach),-1,1))
			var bend: float=-acos(clampf((reach*reach-a*a-b*b)/(2*a*b),-1,1))
			thigh_angle=lerpf(lerpf(gait_angles.x,thigh,crouch),-PI*.5+(.04+crawl)*prone,prone)
			var knee_y: float=body_height+position.y-a*cos(thigh_angle)
			var ankle_y: float=.22*bindings.leg_scale+.02+maxf(0.,crawl)*.04
			var prone_bend: float=-acos(clampf((knee_y-ankle_y)/b,-1.,1.))-thigh_angle
			knee_angle=bend*crouch+prone_bend*prone
		var shoe_angle: float=-(thigh_angle+knee_angle)*crouch
		var leg_pose:=Transform3D(Basis.from_euler(Vector3(thigh_angle,0.,leg_roll))*Basis.from_scale(leg.leg_scale),position)
		var knee_rest: Transform3D=leg.knee
		var shoe_rest: Transform3D=leg.shoe
		var knee_pose:=Transform3D(Basis(Vector3.RIGHT,knee_angle)*knee_rest.basis,knee_rest.origin)
		var shoe_pose:=Transform3D(Basis(Vector3.RIGHT,shoe_angle)*shoe_rest.basis,shoe_rest.origin)
		var thigh_world:=Transform3D(leg_pose.basis,body.origin+leg_pose.origin)
		var knee_world:=thigh_world*knee_pose
		mounts[9+side_index]=thigh_world*leg.thigh
		mounts[11+side_index]=knee_world
		mounts[13+side_index]=knee_world*shoe_pose
		if include_presentation:
			var leg_frame: Dictionary=presentation["leg"+side]
			leg_frame.joint=leg_pose
			leg_frame.knee=knee_pose
			leg_frame.shoe=shoe_pose
			leg_frame.knee_angle=knee_angle
	for side_index in 2:
		var side: String=SIDES[side_index]
		var point:=Vector3(rest.left if side=="L" else rest.right)
		point.x=signf(point.x)*(.325*torso_scale+.025)
		var arm_position: Vector3=upper*point
		if prone>.001: arm_position=arm_position.lerp(Vector3(point.x,.13,-.64),prone)
		var target: Vector3=weapon*Vector3(reload_geometry.grip_left if side=="L" else reload_geometry.grip_right)
		var relative_grip:=target-body.origin
		var relative_hand_basis:=weapon.basis*Basis(reload_geometry.hand_basis_local)
		var result: Dictionary=_arm(arm_position,relative_grip,relative_hand_basis,upper,side,clampf(bindings.arm_proportion,.65,1.5),bindings.weapon_id=="glock",side=="L" and bool(reload_geometry.grabbing),bindings.arm_results[side_index])
		if result.is_empty():return {"supported":false,"reason":"Invalid arm target"}
		var arm_local: Transform3D=result.arm
		var arm_world:=Transform3D(arm_local.basis,body.origin+arm_local.origin)
		mounts[3+side_index]=arm_world*Transform3D(result.upper)
		mounts[5+side_index]=arm_world*Transform3D(result.lower)
		mounts[7+side_index]=arm_world*Transform3D(result.hand)
		if include_presentation:
			result["grip_error"]=(Transform3D(result.arm)*Vector3(Transform3D(result.hand).origin)).distance_to(relative_grip)
			presentation["arm"+side]=result
	var poses: Array[Transform3D]=bindings.region_poses
	for index in poses.size():
		poses[index]=mounts[bindings.region_mounts[index]]*bindings.region_offsets[index]
	var frame: Dictionary=bindings.frame
	frame.muzzle=muzzle
	if packed:
		frame.erase("regions")
		frame["poses"]=poses
	else:
		frame.erase("poses")
		var regions: Dictionary=frame.get("regions",{})
		for index in poses.size(): regions[bindings.region_ids[index]]=poses[index]
		frame["regions"]=regions
	if include_presentation: frame["presentation"]=presentation
	else: frame.erase("presentation")
	return frame
