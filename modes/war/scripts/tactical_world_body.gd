extends RefCounted
class_name WarTacticalWorldBody

# R2C-0: experimental, single-frame world-pose adapter.
# NOTE: Torso and Pelvis own collision regions. They MUST move together
# with the rendered mesh and only from the authoritative offline physics
# pose. Remote players, bots and real network rooms are deliberately excluded
# until P1k's independent physical PoseFrame passes the performance gate.
const INTENT = preload("res://modes/war/scripts/tactical_body_pose.gd")

static func eligible(actor: GamePlayer,motion) -> bool:
	if not actor is WarPlayer: return false
	if not motion.tactical_motion_pilot or not motion.tactical_body_pilot or not motion.tactical_world_pilot: return false
	var soldier := actor as WarPlayer
	if not soldier.is_local or bool(soldier.get_meta("war_bot",false)) or not is_instance_valid(soldier.game): return false
	if not soldier.game.offline_operation or not soldier.game.third_person: return false
	if soldier.hp<=0. or not soldier.deployed or not soldier.vehicle_id.is_empty() or soldier.in_water(): return false
	if soldier.crouched or soldier.prone or soldier.stance.crouch_weight>.001 or soldier.stance.prone_weight>.001: return false
	if soldier.aiming or soldier.iron_sights or soldier.weapon_optics.presented(): return false
	if soldier.reload_left>0. or soldier.fire_cooldown>0. or soldier.gadget_equipped: return false
	if GameWeapons.canonical(soldier.weapon_id)!="g3": return false
	if not soldier.utility_mode.is_empty() or soldier.grenade_selected or not soldier.grenade_held_id.is_empty(): return false
	if soldier.grenade_throw_left>0. or soldier._grenade_active(): return false
	if is_instance_valid(soldier.melee_rig) and soldier.melee_rig.running: return false
	if not is_instance_valid(soldier.body_root) or soldier.avatar_parts.is_empty(): return false
	return is_instance_valid(soldier.body_root.get_node_or_null("Pelvis")) and is_instance_valid(soldier.avatar_parts.get("torso"))

static func apply(actor: GamePlayer,motion) -> bool:
	if not eligible(actor,motion): return false
	var forward: float=motion.presentation_longitudinal
	var lateral: float=motion.presentation_lateral
	var impact: float=motion.presentation_landing
	var offset: Vector3=INTENT.hip_offset(forward,lateral,impact)
	var hip_turn: Vector3=INTENT.hip_angles(forward,lateral)
	var torso_turn: Vector3=INTENT.torso_angles(forward,lateral,impact)
	if offset.is_zero_approx() and hip_turn.is_zero_approx() and torso_turn.is_zero_approx(): return false
	# This is called ONLY after GameInfantryPose.apply() re-seeds the authored
	# physical pose, then WarStance.pose(). No cumulative deltas across frames.
	# The Area3D hit regions stay descendants of both modified pivots.
	var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
	var torso:=actor.avatar_parts.torso as Node3D
	motion.world_pelvis_rest=pelvis.transform
	motion.world_pelvis_dirty=true
	pelvis.position+=offset
	pelvis.basis=pelvis.basis*Basis.from_euler(hip_turn)
	torso.basis=torso.basis*Basis.from_euler(torso_turn)
	return true
