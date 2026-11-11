extends RefCounted
class_name GameInfantryPose

const LEAN_DISTANCE:=.23
const LEAN_ROLL:=.18
const WAIST:=Vector3(0,.87,0)

# C++ visual-pose backend preferred when the native extension is complete;
# explicit legacy flags or missing native methods retain GDScript fallback.
# Authoritative collision physics still owns the same pose state / hitboxes.
static var native_pose_enabled:=GameNativeRuntime.enabled("pose")
static var native_pose_checked:=false
static var native_pose_instance: Object

static func _native_math() -> Object:
	if not native_pose_enabled:return null
	if not native_pose_checked:
		native_pose_checked=true
		if ClassDB.class_exists("WarNativePoseMath"):
			native_pose_instance=ClassDB.instantiate("WarNativePoseMath")
	return native_pose_instance

static func allowed(actor: GamePlayer) -> bool:
	if actor.hp<=0 or actor.is_npc: return false
	if actor is WarPlayer:
		return actor.deployed and actor.vehicle_id.is_empty() and not actor.in_water()
	return not actor.game.player_in_vehicle

static func limit_lean(actor: GamePlayer,value: float) -> float:
	if not is_finite(value) or not allowed(actor): return 0.
	value=clampf(value,-1,1)
	if absf(value)<.001: return 0.
	var anchor:=actor.global_position+Vector3.UP*actor.camera_pivot.position.y
	var desired:=anchor+actor.global_basis*Vector3(value*LEAN_DISTANCE,0,0)
	# Sweep the head/shoulder volume, never move the eye through a wall.
	var safe:=CameraObstruction.resolve(actor.get_world_3d(),anchor,desired,[actor.get_rid()],.21)
	return value*float(safe.fraction)

static func advance(actor: GamePlayer,delta: float) -> void:
	var requested:=actor.network_lean
	if actor.is_local:
		requested=Input.get_axis("lean_left","lean_right") if allowed(actor) and actor.game.gameplay_input_allowed() else 0.
	if not allowed(actor): requested=0.
	var target:=limit_lean(actor,requested)
	actor.lean=lerpf(actor.lean,target,1.-exp(-delta*14.))
	# Retract immediately when a moving player reaches an obstruction.
	# The whole interval from centre to the swept target is already safe.
	# Only a release/reversal can leave the interpolated eye outside it.
	if signf(actor.lean)!=signf(target) or absf(actor.lean)>absf(target)+.0001:
		actor.lean=limit_lean(actor,actor.lean)
	if absf(actor.lean)<.0001: actor.lean=0.
	actor.camera_pivot.position.x=actor.lean*LEAN_DISTANCE
	actor.camera_pivot.rotation.z=-actor.lean*LEAN_ROLL

static func upper_transform(actor: GamePlayer) -> Transform3D:
	if native_pose_enabled:
		var native: Object=_native_math()
		if native!=null:
			var result: Transform3D=native.upper_transform(actor.pitch,actor.lean)
			return result
	var bend:=clampf(actor.pitch*.42,-.49,.49)
	var basis:=Basis(Vector3.BACK,-actor.lean*LEAN_ROLL)*Basis(Vector3.RIGHT,bend)
	return Transform3D(basis,WAIST+Vector3(actor.lean*.04,0,0)-basis*WAIST)

static func apply(actor: GamePlayer) -> void:
	if actor.avatar_parts.is_empty() or not allowed(actor): return
	var upper:=upper_transform(actor)
	var torso: Node3D=actor.avatar_parts.torso
	var head: Node3D=actor.avatar_parts.head
	if not actor.has_meta("upper_body_rest"):
		actor.set_meta("upper_body_rest",{"torso":torso.position,"head":head.position,"left":actor.avatar_parts.arm_l.position,"right":actor.avatar_parts.arm_r.position,"pelvis":actor.body_root.get_node("Pelvis").position,"leg_l":actor.avatar_parts.leg_l.position,"leg_r":actor.avatar_parts.leg_r.position})
	var rest: Dictionary=actor.get_meta("upper_body_rest")
	var hip_shift:=actor.lean*.04
	var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
	pelvis.position=Vector3(rest.pelvis)+Vector3(hip_shift,0,0)
	pelvis.rotation.z=-actor.lean*.035
	for leg_key in ["leg_l","leg_r"]:
		var leg: Node3D=actor.avatar_parts[leg_key]
		leg.position=Vector3(rest[leg_key])+Vector3(hip_shift,0,0)
		# Counter-angle the planted legs instead of leaving the pelvis behind.
		# Gait owns X; stance owns this small lateral weight transfer.
		leg.rotation.z=-atan2(hip_shift,.78)
	# Keep authored melee/gait rotations while distributing the vertical aim
	# between waist and neck. Uniforms and hit regions are children of these.
	var animation:=Basis.from_euler(torso.rotation)
	torso.position=upper*Vector3(rest.torso)
	torso.basis=upper.basis*animation*Basis.from_scale(Vector3.ONE*clampf(float(actor.body_proportions.get("torso",1.)),.65,1.5))
	var neck:=Vector3(0,float(rest.head.y)-.21,0)
	var head_basis:=Basis(Vector3.RIGHT,clampf(actor.pitch*.92,-1.12,1.12))*Basis(Vector3.BACK,-actor.lean*LEAN_ROLL)
	head.position=upper*neck+head_basis*(Vector3(rest.head)-neck)
	head.basis=head_basis*Basis.from_scale(Vector3.ONE*clampf(float(actor.body_proportions.get("head",1.)),.65,1.5))
	for entry in [["arm_l","left"],["arm_r","right"]]:
		var point: Vector3=rest[entry[1]]
		if actor.get_meta("articulated_arms",false):
			# The shoulder joint belongs outside the plate carrier, including
			# saved torso widths. Elbows then solve outside its silhouette.
			point.x=signf(point.x)*(.325*clampf(float(actor.body_proportions.get("torso",1.)),.65,1.5)+.025)
		actor.avatar_parts[entry[0]].position=upper*point

static func weapon_pose(actor: GamePlayer,offset: Vector3) -> Transform3D:
	var pitch:=actor.clamp_aim_pitch(actor.pitch+(actor.recoil if actor.is_local else 0.))
	if native_pose_enabled:
		var native: Object=_native_math()
		if native!=null:
			var result: Transform3D=native.weapon_transform(pitch,actor.lean,actor.stance.prone_weight,actor.body_root.transform,offset)
			return result
	# Roll is around the sight axis after pitch, just like the camera. Doing
	# these in reverse steers a raised/lowered barrel sideways while leaning.
	var aim:=Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,-actor.lean*LEAN_ROLL)
	var upper:=upper_transform(actor)
	var shoulder:=upper*Vector3(0,1.42,0)
	# The prone rig moves its shoulders beside the head at ground level.
	# Reusing the standing shoulder sent the real weapon over a metre above
	# the eyes; IK then stretched both arms vertically to reach that weapon.
	# Blend by the same posture weight so lowering/raising stays continuous.
	var prone_weight:=clampf(actor.stance.prone_weight,0.,1.)
	shoulder=shoulder.lerp(Vector3(actor.lean*.04,.13,-.64),prone_weight)
	# When depressing the muzzle, extend the hands in front of the carrier
	# rather than folding wrists into it. This moves the real held weapon.
	var clearance: float=(.10+.07*absf(actor.lean))*smoothstep(.4,1.3,-pitch)
	shoulder+=upper.basis*Vector3(0,0,-clearance)
	# Rotate a short forward grip around the shoulder. Rotating the former
	# camera-to-chest offset sent the grip behind the torso when looking down.
	return actor.body_root.transform*Transform3D(aim,shoulder+aim*offset)

static func reset(actor: GamePlayer) -> void:
	actor.lean=0.;actor.network_lean=0.
	if is_instance_valid(actor.camera_pivot): actor.camera_pivot.position.x=0;actor.camera_pivot.rotation.z=0
	if actor.has_meta("upper_body_rest"):
		var rest: Dictionary=actor.get_meta("upper_body_rest")
		actor.avatar_parts.torso.position=rest.torso
		actor.avatar_parts.torso.rotation=Vector3.ZERO
		actor.avatar_parts.head.position=rest.head
		actor.avatar_parts.head.rotation=Vector3.ZERO
		actor.avatar_parts.arm_l.position=rest.left;actor.avatar_parts.arm_r.position=rest.right
		actor.body_root.get_node("Pelvis").position=rest.pelvis
		actor.body_root.get_node("Pelvis").rotation=Vector3.ZERO
		for key in ["leg_l","leg_r"]:
			actor.avatar_parts[key].position=rest[key];actor.avatar_parts[key].rotation.z=0.
