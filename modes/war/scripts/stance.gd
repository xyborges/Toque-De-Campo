extends RefCounted
class_name WarStance
# Real joints/region hitboxes move together. No vertical squash of the body.
var crouch_weight:=0.0
var prone_weight:=0.0
var leg_parts: Dictionary={}
var neutral_leg_reach:=0.0
var reference_foot_y:=0.0
static var shin_mesh: ArrayMesh

func leg_scale(actor: GamePlayer) -> float:
	# Read the already sanitized rig scale, including replicated appearances.
	return actor.avatar_parts.leg_l.scale.y

func visual_ground_offset(actor: GamePlayer) -> float:
	# Keep the existing foot plane when customization changes leg length.
	# This only moves the presented rig; never the CharacterBody or terrain.
	return neutral_leg_reach*(leg_scale(actor)-1.)

func _walking_ground_offset(actor: GamePlayer) -> float:
	var lowest:=INF
	for data: Dictionary in leg_parts.values():
		var pose: Transform3D=data.joint.transform*data.knee.transform*data.shoe.transform
		var basis:=actor.body_root.basis*pose.basis
		var centre: Vector3=actor.body_root.basis*(pose*Vector3(data.foot_centre))
		var half: Vector3=data.foot_half
		# Exact lower Y of the same eight transformed AABB corners. Compute
		# the support extent directly instead of transforming every corner.
		lowest=minf(lowest,centre.y-absf(basis.x.y)*half.x-absf(basis.y.y)*half.y-absf(basis.z.y)*half.z)
	return reference_foot_y-lowest if is_finite(lowest) else visual_ground_offset(actor)

static func lower_leg_mesh() -> ArrayMesh:
	if shin_mesh: return shin_mesh
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var calf:=WarBodyMesh.loft("stance193-shin",[[-.40,.073,.08,0],[-.30,.08,.09,0],[-.1,.09,.10,0],[0,.095,.10,0]],14,.9)
	surface.append_from(calf,0,Transform3D.IDENTITY)
	# A closed rounded joint bridges the thigh/calf at a deep knee bend.
	# It shares the shin's draw/material instead of adding a separate mesh node.
	var joint:=SphereMesh.new();joint.radius=.105;joint.height=.21;joint.radial_segments=14;joint.rings=6
	surface.append_from(joint,0,Transform3D.IDENTITY);surface.index();shin_mesh=surface.commit()
	return shin_mesh

func apply_collision(actor: GamePlayer,value: int,clearance:=true) -> bool:
	if not is_instance_valid(actor.body_collision): return false
	var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=[1.75,1.45,1.85][value]
	# Every posture shares a zero foot plane. A prone centre at radius+2 cm
	# let gravity settle the actor origin below the standing foot plane, so
	# standing was then rejected as an overlap with the floor itself.
	var pose:=Transform3D(Basis(Vector3.RIGHT,PI*.5) if value==2 else Basis.IDENTITY,Vector3(0,[.875,.725,.32][value],-.18 if value==2 else 0.))
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1|16;query.exclude=[actor.get_rid()];query.margin=.001;query.transform=actor.global_transform*pose
	# Test slightly above the floor skin; headroom becomes more conservative.
	query.transform.origin+=Vector3.UP*.003
	# Do not stand through a ceiling or lie through a wall.
	if clearance and not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	actor.body_collision.shape=shape;actor.body_collision.transform=pose
	actor.prone=value==2;actor.crouched=value==1;actor.body_root.scale=Vector3.ONE
	return true

func advance(actor: GamePlayer,delta: float) -> void:
	var rate:=1.-exp(-delta*10.)
	crouch_weight=lerpf(crouch_weight,1. if actor.crouched else 0.,rate)
	prone_weight=lerpf(prone_weight,1. if actor.prone else 0.,rate)
	if absf(crouch_weight-float(actor.crouched))<.001: crouch_weight=float(actor.crouched)
	if absf(prone_weight-float(actor.prone))<.001: prone_weight=float(actor.prone)
	var height:=1.68+visual_ground_offset(actor)*(1.-prone_weight)-.55*leg_scale(actor)*crouch_weight-1.20*prone_weight
	if not actor.swimming and actor.camera_pivot.position.y!=height: actor.camera_pivot.position.y=height
	var forward:=-.90*prone_weight
	if not actor.swimming and actor.camera_pivot.position.z!=forward: actor.camera_pivot.position.z=forward

func build_legs(actor: GamePlayer) -> void:
	if not leg_parts.is_empty(): return
	for side in ["L","R"]:
		var leg: Node3D=actor.avatar_parts["leg_"+side.to_lower()]
		var pants:=leg.get_node("Leg"+side+"Mesh") as MeshInstance3D
		var knee:=Node3D.new();knee.name="Knee"+side;knee.position=Vector3(0,-.42,0);leg.add_child(knee)
		pants.mesh=WarBodyMesh.loft("stance193-thigh",[[-.42,.09,.10,0],[-.32,.105,.115,0],[-.12,.135,.14,0],[0,.13,.14,0]],14,.9);pants.position=Vector3.ZERO
		var lower:=MeshInstance3D.new();lower.name="Shin"+side;lower.mesh=lower_leg_mesh();lower.material_override=pants.material_override;knee.add_child(lower)
		var shoe:=leg.get_node("Shoe"+side) as Node3D
		shoe.reparent(knee,true)
		if actor.hit_regions.has("leg"+side):
			var area: Area3D=actor.hit_regions["leg"+side]
			area.position=Vector3(0,-.20,0)
			(area.get_child(0) as CollisionShape3D).shape=BoxShape3D.new();area.get_child(0).shape.size=Vector3(.25,.42,.28)
		var area:=Area3D.new();area.name="ShinHit"+side;area.collision_layer=2;area.collision_mask=0;area.monitoring=false;area.set_meta("hit_region","shin"+side)
		var volume:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.22,.38,.25);volume.shape=box;area.position=Vector3(0,-.20,0);area.add_child(volume);knee.add_child(area);actor.hit_regions["shin"+side]=area
		# Cache the sole bounds once. Walking needs eight point transforms per
		# boot, not another ground ray, collision body or grass interaction.
		var bounds: AABB=shoe.mesh.get_aabb()
		for child in shoe.get_children():
			if child is MeshInstance3D and child.mesh: bounds=bounds.merge(child.transform*child.mesh.get_aabb())
		var corners:=PackedVector3Array()
		var lowest:=INF
		for i in 8:
			var point:=bounds.get_endpoint(i);corners.append(point)
			lowest=minf(lowest,(knee.transform*shoe.transform*point).y)
		neutral_leg_reach=maxf(neutral_leg_reach,-lowest)
		reference_foot_y=leg.position.y-neutral_leg_reach
		leg_parts[side]={"joint":leg,"knee":knee,"lower":lower,"shoe":shoe,"foot_corners":corners,"foot_centre":bounds.get_center(),"foot_half":bounds.size*.5,"sole_y":bounds.position.y}

func pose(actor: GamePlayer,refresh_grips:=true) -> void:
	if actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty() or actor.swimming: return
	build_legs(actor)
	var c:=crouch_weight;var p:=prone_weight
	var previous_height:=actor.body_root.position.y
	actor.body_root.position.y=visual_ground_offset(actor)*(1.-p)-.54*leg_scale(actor)*c+.22*p
	if c==0 and p==0:
		for data: Dictionary in leg_parts.values(): data.knee.rotation.x=0;data.shoe.rotation=Vector3.ZERO
		# Swinging around a fixed hip shortened both legs vertically, leaving
		# a visible gap while running. Plant the lowest sole during grounded
		# gait; the independent camera stays smooth and jumps keep their pose.
		if actor.locomotion.grounded and actor.locomotion.moving>0:
			actor.body_root.position.y=_walking_ground_offset(actor)
		# The base animation solved grips using the previous body height.
		# Finish them against the corrected torso in the same presentation tick.
		if refresh_grips and not is_equal_approx(previous_height,actor.body_root.position.y): _refresh_grip_pose(actor)
		return
	# Prone turns the complete torso forward while the neck counter-rotates
	# to keep the eye and weapon oriented toward the actual aim.
	var torso: Node3D=actor.avatar_parts.torso
	torso.rotation.x=lerp_angle(torso.rotation.x,-PI*.5,p)
	torso.position=torso.position.lerp(Vector3(0,.06,-.42),p)
	var head: Node3D=actor.avatar_parts.head
	head.position=head.position.lerp(Vector3(0,.22,-1.02),p)
	var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
	pelvis.position=pelvis.position.lerp(Vector3(0,.04,.05),p);pelvis.rotation.x=-PI*.5*p
	for side in ["L","R"]:
		var data: Dictionary=leg_parts[side];var leg: Node3D=data.joint;var knee: Node3D=data.knee
		var sign_value: float=-1 if side=="L" else 1
		var crawl:=sin(actor.locomotion.phase+(0 if side=="L" else PI))*.20*actor.locomotion.moving
		leg.position=leg.position.lerp(Vector3(sign_value*.16,0,.10),p)
		# Solve a forward knee bend toward the planted boot. The old negative
		# thigh / positive knee signs bent both knees behind the character.
		var foot_z: float=-.055+sin(actor.locomotion.phase+(0 if side=="L" else PI))*.10*actor.locomotion.moving
		var dy: float=reference_foot_y-float(data.sole_y)*leg.scale.y-actor.body_root.position.y-leg.position.y
		var dz: float=foot_z-leg.position.z
		var a:=.42*leg.scale.y;var b:=.36*leg.scale.y
		var reach:=clampf(Vector2(dy,dz).length(),absf(a-b)+.001,a+b-.001)
		var thigh:=atan2(-dz,-dy)+acos(clampf((a*a+reach*reach-b*b)/(2*a*reach),-1,1))
		var bend:=-acos(clampf((reach*reach-a*a-b*b)/(2*a*b),-1,1))
		leg.rotation.x=lerpf(lerpf(leg.rotation.x,thigh,c),-PI*.5+(.04+crawl)*p,p)
		leg.rotation.z+=sign_value*.07*p
		var knee_y: float=actor.body_root.position.y+leg.position.y-a*cos(leg.rotation.x)
		var ankle_y:=.22*leg.scale.y+.02+maxf(0,crawl)*.04
		var prone_bend:=-acos(clampf((knee_y-ankle_y)/b,-1,1))-leg.rotation.x
		knee.rotation.x=bend*c+prone_bend*p
		# Squatting boots stay planted. Prone boots follow the shin, with toes
		# resting down and the boot shaft pointing back toward the calf.
		data.shoe.rotation.x=-(leg.rotation.x+knee.rotation.x)*c
		var pad:=knee.get_node_or_null("KneePad") as Node3D
		if pad:
			pad.rotation.x=-knee.rotation.x*.5
			pad.position=Basis(Vector3.RIGHT,pad.rotation.x)*Vector3(0,0,-.11)
	# Keep arm solve outside the vest in both low postures.
	if p>.001:
		var width:=.325*clampf(float(actor.body_proportions.get("torso",1.)),.65,1.5)+.025
		actor.avatar_parts.arm_l.position=actor.avatar_parts.arm_l.position.lerp(Vector3(-width,.13,-.64),p)
		actor.avatar_parts.arm_r.position=actor.avatar_parts.arm_r.position.lerp(Vector3(width,.13,-.64),p)
	if refresh_grips: _refresh_grip_pose(actor)

func _refresh_grip_pose(actor: GamePlayer) -> void:
	if actor._grenade_active():
		var progress:=1-actor.grenade_throw_left/.75
		var grip:=Vector3(.32,-.26,-.48)
		if actor.grenade_throw_left>0: grip+=Vector3(-.10,.12,-.35)*sin(progress*PI)
		actor._pose_arm(actor.avatar_parts.arm_r,actor.camera_pivot.global_position+actor.global_basis*Basis(Vector3.RIGHT,actor.pitch)*grip,"armR")
		actor._pose_arm(actor.avatar_parts.arm_l,actor.camera_pivot.global_position+actor.global_basis*Vector3(-.26,-.40,-.18),"armL")
	else:
		actor._update_weapon_pose()
		var right:=actor.melee_rig.grip_right.global_position if is_instance_valid(actor.melee_rig) else actor.weapon_root.global_position
		var support:=FALModel.SUPPORT if actor.weapon_id=="fal" else Vector3(0,-.015,-.16 if actor.weapon_id!="glock" else .035)
		var left:=actor.melee_rig.grip_left.global_position if is_instance_valid(actor.melee_rig) else actor.weapon_root.to_global(support)
		if actor.weapon_id=="sniper": right=actor._sniper_hand_target(false);left=actor._sniper_hand_target(true)
		elif actor.weapon_id=="ak":right=actor._ak_hand_target(false);left=actor._ak_hand_target(true)
		elif actor.weapon_id=="g3":right=actor.weapon_hand_target(false);left=actor.weapon_hand_target(true)
		actor._pose_arm(actor.avatar_parts.arm_r,right,"armR")
		actor._pose_arm(actor.avatar_parts.arm_l,left,"armL")

func reset(actor: GamePlayer) -> void:
	actor.prone=false;actor.crouched=false;crouch_weight=0;prone_weight=0
	actor.body_root.position.y=visual_ground_offset(actor);actor.body_root.scale=Vector3.ONE
	actor.camera_pivot.position.z=0
	for data: Dictionary in leg_parts.values(): data.knee.rotation=Vector3.ZERO;data.shoe.rotation=Vector3.ZERO
	apply_collision(actor,0,false)
	actor.next_pose_usec=0


