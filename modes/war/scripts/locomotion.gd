extends RefCounted
class_name WarLocomotion

const TACTICAL_BODY_POSE = preload("res://modes/war/scripts/tactical_body_pose.gd")
const TACTICAL_WORLD_BODY = preload("res://modes/war/scripts/tactical_world_body.gd")
const TACTICAL_POSE_FRAME = preload("res://modes/war/scripts/tactical_pose_frame.gd")

# Presentation follows distance actually covered, including replicated actors.
# It never integrates stale network velocity or changes the camera transform.
var previous := Vector3.ZERO
var initialized := false
var life := 0
var phase := 0.0
var distance_since_step := 0.0
var speed := 0.0
var moving := 0.0
var sprint := 0.0
var grounded := false
var ground_clock := 0.0
var ground_point := Vector3.ZERO
var step_sequence := 0
var local_direction := Vector3.ZERO

# R1 tactical-motion pilot. These states are presentation-only: they are
# derived from real actor motion and never feed CharacterBody velocity,
# hitboxes, weapon_root, the camera or replicated state.
var presentation_longitudinal := 0.0
var presentation_lateral := 0.0
var presentation_lateral_speed := 0.0
var presentation_yaw := 0.0
var presentation_landing := 0.0
var presentation_fall_speed := 0.0
var presentation_was_grounded := false
var tactical_motion_pilot := OS.get_environment("TDC_TACTICAL_MOTION_PILOT")=="1" or "--tactical-motion-pilot" in OS.get_cmdline_user_args()
var tactical_body_pilot := OS.get_environment("TDC_TACTICAL_BODY_PILOT")=="1" or "--tactical-body-pilot" in OS.get_cmdline_user_args()
# Separate R2C gate: may move physical world pivots ONLY in local offline TPP.
var tactical_world_pilot := OS.get_environment("TDC_TACTICAL_WORLD_PILOT")=="1" or "--tactical-world-pilot" in OS.get_cmdline_user_args()
# Restore the exact original physical pivot before the next base pose.
# GameInfantryPose.apply resets pelvis Z only; without this X/Y would drift.
var world_pelvis_rest := Transform3D.IDENTITY
var world_pelvis_dirty := false
# Lazily allocated only for an eligible, non-neutral local offline R2C pose.
var world_pose_frame: TACTICAL_POSE_FRAME
const PRESENTATION_ACCEL_SCALE := 2.2
const PRESENTATION_RESPONSE_IN := 24.0
const PRESENTATION_RESPONSE_OUT := 3.2
const PRESENTATION_FPP_TRAVEL := 0.028
const PRESENTATION_LATERAL_ACCEL_SCALE := 2.4
const PRESENTATION_LATERAL_RESPONSE_IN := 20.0
const PRESENTATION_LATERAL_RESPONSE_OUT := 3.2
const PRESENTATION_LATERAL_FPP_TRAVEL := 0.022
const PRESENTATION_TURN_RATE_SCALE := 2.2
const PRESENTATION_TURN_WEIGHT_LIMIT := 0.4
const PRESENTATION_LANDING_THRESHOLD := 2.5
const PRESENTATION_LANDING_FULL_SPEED := 6.0
const PRESENTATION_LANDING_FPP_TRAVEL := 0.035
const PRESENTATION_LANDING_RECOVERY := 4.5

func reset(actor: GamePlayer) -> void:
	previous=actor.global_position;initialized=true;life=actor.life_id
	phase=0;distance_since_step=0;speed=0;moving=0;sprint=0;grounded=false;ground_clock=0
	local_direction=Vector3.ZERO;presentation_longitudinal=0.;presentation_lateral=0.;presentation_landing=0.
	presentation_lateral_speed=0.;presentation_yaw=actor.rotation.y;presentation_fall_speed=0.
	presentation_was_grounded=actor.is_on_floor()

static func longitudinal_target(previous_speed: float,current_speed: float,delta: float,reference_speed: float) -> float:
	var safe_delta:=maxf(delta,.001)
	var acceleration:=(current_speed-previous_speed)/safe_delta
	# Ignore tiny correction noise. The scale follows the actor's own movement
	# speed instead of assuming one fixed walk speed for every class/mode.
	if absf(acceleration)<.35:return 0.
	return clampf(acceleration/maxf(reference_speed*PRESENTATION_ACCEL_SCALE,4.),-1.,1.)

func _advance_presentation(previous_speed: float,current_speed: float,delta: float,reference_speed: float) -> void:
	var target:=longitudinal_target(previous_speed,current_speed,delta,reference_speed)
	var response:=PRESENTATION_RESPONSE_IN if absf(target)>absf(presentation_longitudinal) else PRESENTATION_RESPONSE_OUT
	presentation_longitudinal=move_toward(presentation_longitudinal,target,delta*response)

static func lateral_target(previous_lateral_speed: float,current_lateral_speed: float,yaw_delta: float,delta: float,reference_speed: float,forward_speed: float) -> float:
	var safe_delta:=maxf(delta,.001)
	var lateral_acceleration:=(current_lateral_speed-previous_lateral_speed)/safe_delta
	var strafe:=0.
	if absf(lateral_acceleration)>=.35:
		# The held weapon visually lags the acceleration instead of leading it.
		strafe=-lateral_acceleration/maxf(reference_speed*PRESENTATION_LATERAL_ACCEL_SCALE,4.)
	var yaw_rate:=yaw_delta/safe_delta
	var forward_factor:=clampf(absf(forward_speed)/maxf(reference_speed,.1),0.,1.4)
	var turn:=0.
	if absf(yaw_rate)>=.03 and forward_factor>.05:
		# Positive Godot yaw turns left, so the FPP copy moves right: a small
		# inertial lag opposite the curve.
		turn=clampf(yaw_rate/PRESENTATION_TURN_RATE_SCALE*forward_factor,-PRESENTATION_TURN_WEIGHT_LIMIT,PRESENTATION_TURN_WEIGHT_LIMIT)
	return clampf(strafe+turn,-1.,1.)

func _advance_lateral(previous_lateral_speed_value: float,current_lateral_speed: float,yaw_delta: float,delta: float,reference_speed: float,forward_speed: float) -> void:
	var target:=lateral_target(previous_lateral_speed_value,current_lateral_speed,yaw_delta,delta,reference_speed,forward_speed)
	var response:=PRESENTATION_LATERAL_RESPONSE_IN if absf(target)>absf(presentation_lateral) else PRESENTATION_LATERAL_RESPONSE_OUT
	presentation_lateral=move_toward(presentation_lateral,target,delta*response)

static func landing_target(fall_speed: float) -> float:
	if fall_speed<=PRESENTATION_LANDING_THRESHOLD:return 0.
	return smoothstep(PRESENTATION_LANDING_THRESHOLD,PRESENTATION_LANDING_FULL_SPEED,fall_speed)

func _advance_landing(actor: GamePlayer,delta: float) -> void:
	var current_grounded:=actor.is_on_floor()
	if not tactical_motion_pilot or not actor.is_local:
		presentation_landing=0.;presentation_fall_speed=0.;presentation_was_grounded=current_grounded
		return
	presentation_landing=move_toward(presentation_landing,0.,delta*PRESENTATION_LANDING_RECOVERY)
	if not current_grounded:
		presentation_fall_speed=maxf(presentation_fall_speed,maxf(0.,-actor.velocity.y))
	elif not presentation_was_grounded:
		presentation_landing=maxf(presentation_landing,landing_target(presentation_fall_speed))
		presentation_fall_speed=0.
	else:
		presentation_fall_speed=0.
	presentation_was_grounded=current_grounded

func advance(actor: GamePlayer,delta: float) -> void:
	if actor.in_water(): reset(actor);return
	if not initialized or life!=actor.life_id:
		reset(actor);return
	var displacement:=actor.global_position-previous
	previous=actor.global_position
	var distance:=Vector2(displacement.x,displacement.z).length()
	if actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty() or distance>maxf(1.0,actor.move_speed*delta*4):
		reset(actor);return
	# A teleport, respawn or correction is not a foot contact. Normal remote
	# interpolation covers real distance and therefore gives the same cadence.
	var actual_speed:=distance/maxf(delta,.001)
	var previous_speed_value:=speed
	_advance_landing(actor,delta)
	if tactical_motion_pilot and actor.is_local:
		_advance_presentation(previous_speed_value,actual_speed,delta,actor.move_speed)
		var local_motion:=actor.global_basis.inverse()*displacement
		var safe_delta:=maxf(delta,.001)
		var current_lateral_speed:=local_motion.x/safe_delta
		var forward_speed:=absf(local_motion.z)/safe_delta
		var yaw_delta:=wrapf(actor.rotation.y-presentation_yaw,-PI,PI)
		_advance_lateral(presentation_lateral_speed,current_lateral_speed,yaw_delta,delta,actor.move_speed,forward_speed)
		presentation_lateral_speed=current_lateral_speed
		presentation_yaw=actor.rotation.y
	else:
		if presentation_longitudinal!=0.:presentation_longitudinal=0.
		if presentation_lateral!=0.:presentation_lateral=0.
		presentation_lateral_speed=0.;presentation_yaw=actor.rotation.y
	speed=actual_speed
	# Stationary replicated actors can retain a nonzero last velocity. Only
	# actual displacement starts a gait, and there is no reason to raycast an
	# unchanged contact every 100 ms. Resume with an immediate ground query.
	if actual_speed<=.18:
		moving=move_toward(moving,0,delta*9);sprint=move_toward(sprint,0,delta*7)
		distance_since_step=0;ground_clock=0
		if moving==0 and sprint==0: return
	ground_clock-=delta
	if actor.is_local or actor.get_meta("war_bot",false):
		grounded=actor.is_on_floor() and absf(actor.velocity.y)<1.0
		ground_point=actor.global_position
	elif ground_clock<=0:
		ground_clock=.10
		var ray:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.20,actor.global_position-Vector3.UP*.30,1,[actor.get_rid()])
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
		grounded=not hit.is_empty() and Vector3(hit.normal).y>.5 and absf(displacement.y/maxf(delta,.001))<2.5
		ground_point=hit.position if grounded else actor.global_position
	var active:=grounded and actual_speed>.18
	var precision:=actor.aiming or actor.iron_sights or actor.crouched or actor.prone or actor.reload_left>0 or actor._grenade_active() or actor.gadget_equipped or actor.fire_cooldown>0
	var running:=active and actual_speed>actor.move_speed*1.13 and not precision
	moving=move_toward(moving,1.0 if active else 0.0,delta*9)
	sprint=move_toward(sprint,1.0 if running else 0.0,delta*7)
	if distance>.002:
		local_direction=actor.global_basis.inverse()*displacement.normalized()
	if not active:
		distance_since_step=0
		return
	var cycle_distance:=lerpf(3.6,4.0,sprint)*(0.70 if actor.crouched else 1.0)
	phase=fposmod(phase+distance/cycle_distance*TAU,TAU)
	distance_since_step+=distance
	if distance_since_step>=cycle_distance*.5:
		distance_since_step=fmod(distance_since_step,cycle_distance*.5)
		step_sequence+=1
		if not actor.prone:
			var side: float=-1.0 if step_sequence%2==0 else 1.0
			var point:=ground_point+actor.global_basis*Vector3(side*.14,.035,0)
			actor.emit_step_sound(step_sequence,point,running)

func pose_body(actor: GamePlayer) -> void:
	if actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty(): return
	# The base rig already writes the neutral pose. Rewriting all joints while
	# idle dirties each attached hitbox in the physics broadphase repeatedly.
	if moving==0 and sprint==0: return
	var amount:=moving*(.28 if actor.crouched else lerpf(.36,.67,sprint))
	var forward:=clampf(-local_direction.z,-1,1)
	var lateral:=clampf(local_direction.x,-1,1)
	var stride:=sin(phase)*amount
	actor.avatar_parts.leg_l.rotation=Vector3(-stride*forward,0,-stride*lateral*.55)
	actor.avatar_parts.leg_r.rotation=Vector3(stride*forward,0,stride*lateral*.55)
	actor.avatar_parts.leg_l.rotation.z-=atan2(actor.lean*.04,.78)
	actor.avatar_parts.leg_r.rotation.z-=atan2(actor.lean*.04,.78)
	for entry in [["leg_l","legL"],["leg_r","legR"]]:
		if float(actor.limbs[entry[1]])<=0: actor.avatar_parts[entry[0]].rotation*=.2
	if not grounded:
		# A compact jump/fall pose replaces the previous walking in mid-air.
		actor.avatar_parts.leg_l.rotation=Vector3(-.18,0,0)
		actor.avatar_parts.leg_r.rotation=Vector3(.12,0,0)

func pose_torso(actor: GamePlayer) -> void:
	if actor._grenade_active() or (is_instance_valid(actor.melee_rig) and actor.melee_rig.running): return
	actor.avatar_parts.torso.rotation.x=-.085*sprint*maxf(0,-local_direction.z)
	actor.avatar_parts.torso.rotation.z=-local_direction.x*.035*moving

func clear_tactical_world_body(actor: GamePlayer) -> void:
	if not world_pelvis_dirty: return
	if is_instance_valid(actor.body_root):
		var pelvis:=actor.body_root.get_node_or_null("Pelvis") as Node3D
		if is_instance_valid(pelvis): pelvis.transform=world_pelvis_rest
	world_pelvis_dirty=false
	if is_instance_valid(world_pose_frame): world_pose_frame.invalidate()

func pose_tactical_world_body(actor: GamePlayer) -> bool:
	return TACTICAL_WORLD_BODY.apply(actor,self) if tactical_world_pilot else false

func _allows_tactical_body_fpp(actor: GamePlayer) -> bool:
	if not tactical_motion_pilot or not tactical_body_pilot or not actor.is_local or not actor is WarPlayer: return false
	var soldier := actor as WarPlayer
	if not is_instance_valid(soldier.game) or soldier.game.third_person: return false
	if soldier.crouched or soldier.prone or not soldier.utility_mode.is_empty(): return false
	if soldier.grenade_selected or not soldier.grenade_held_id.is_empty() or soldier.grenade_throw_left>0.: return false
	return GameWeapons.canonical(soldier.weapon_id)=="g3"

func pose_weapon(actor: GamePlayer) -> void:
	if actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty(): return
	var landing_only:=tactical_motion_pilot and actor.is_local and presentation_landing>0.
	if moving==0 and sprint==0 and not landing_only: return
	# Aiming, firing, reloads and grenade poses own their complete transform.
	# The muzzle and both world-space grips move with the actual weapon root.
	if actor.aiming or actor.iron_sights or actor.reload_left>0 or actor.fire_cooldown>0 or actor._grenade_active() or actor.gadget_equipped: return
	if is_instance_valid(actor.melee_rig) and actor.melee_rig.running: return
	var pulse:=sin(phase)
	var lift:=absf(cos(phase))
	var weight:=moving*(.38+.62*sprint)
	var offset:=Vector3(pulse*.012*weight,-.09*sprint-lift*.012*weight,.035*sprint)
	var rotation_offset:=Vector3(.06*sprint,0,.12*sprint+pulse*.012*weight)
	actor.weapon_root.position+=Basis(Vector3.RIGHT,actor.pitch)*offset
	actor.weapon_root.rotation+=rotation_offset
	if is_instance_valid(actor.view_root):
		actor.view_root.position+=offset
		actor.view_root.rotation+=rotation_offset
		# Only the local FPP copy receives R1A/R1B/R1C inertia. Aiming/reload/fire
		# paths returned above preserve exact sight alignment and ballistic origin.
		if tactical_motion_pilot and actor.is_local:
			actor.view_root.position.z+=presentation_longitudinal*PRESENTATION_FPP_TRAVEL
			actor.view_root.position.x+=presentation_lateral*PRESENTATION_LATERAL_FPP_TRAVEL
			actor.view_root.position.y-=presentation_landing*PRESENTATION_LANDING_FPP_TRAVEL
			# R2B is a presentation-only G3 shoulder reaction. The prospective
			# hip/torso targets are NOT applied to body pivots or hit regions.
			# Keep the full War-specific action/stance/perspective contract narrow.
			if _allows_tactical_body_fpp(actor):
				actor.view_root.rotation+=TACTICAL_BODY_POSE.fpp_weapon_angles(presentation_longitudinal,presentation_lateral,presentation_landing)

