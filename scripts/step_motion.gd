extends RefCounted
class_name GameStepMotion
const MAX_STEP:=.42
# Only war bots cache failed step probes. Their normal CharacterBody physics
# still runs on every tick. First successful steps are NEVER delayed.
const BOT_FAILED_STEP_RETRY_TICKS:=7
# Opt-in experiment: step probes drop substantially, but the P99 result
# is inconsistent on Forward+. Do not change gameplay by default.
static var bot_step_cache_enabled: bool=("--experimental-bot-step-cache" in OS.get_cmdline_user_args()) and not ("--no-step-cache" in OS.get_cmdline_user_args())
static var qa_enabled: bool="--step-probe" in OS.get_cmdline_user_args()
static var qa_moves:=0
static var qa_attempts:=0
static var qa_successes:=0
static var qa_reused_failures:=0
static func qa_reset() -> void:
	qa_moves=0;qa_attempts=0;qa_successes=0;qa_reused_failures=0
static func qa_report() -> Dictionary:
	return {"moves":qa_moves,"blocked_step_attempts":qa_attempts,"successful_steps":qa_successes,"avoided_repeated_failed_probes":qa_reused_failures}
# Instrumented pass-through; the original Jolt query and collision output are unchanged.
static func _ia1_step_test(actor: CharacterBody3D,origin_t: Transform3D,motion: Vector3,collision: KinematicCollision3D=null) -> bool:
	if not BotCostProbe.enabled or not bool(actor.get_meta("war_bot",false)):
		return actor.test_move(origin_t,motion,collision)
	var __begun:=Time.get_ticks_usec()
	var hit:=actor.test_move(origin_t,motion,collision)
	BotCostProbe.record("step_test",Time.get_ticks_usec()-__begun)
	return hit

static func move(actor: CharacterBody3D,delta: float) -> void:
	if qa_enabled:qa_moves+=1
	var horizontal:=Vector3(actor.velocity.x,0,actor.velocity.z)*delta
	var wanted:=actor.velocity
	var start:=actor.global_position
	var supported:=actor.is_on_floor() or Engine.get_physics_frames()-int(actor.get_meta("step_contact_frame",-100))<=2
	if BotCostProbe.enabled and bool(actor.get_meta("war_bot",false)):
		var __begun:=Time.get_ticks_usec()
		actor.move_and_slide()
		BotCostProbe.record("move_slide",Time.get_ticks_usec()-__begun)
	else:
		actor.move_and_slide()
	# Slope projection is displacement, not a jump impulse to keep on the
	# next tick. Retaining its positive Y alternated falling/snap on uphills.
	if wanted.y<=.1 and actor.is_on_floor(): actor.velocity.y=minf(actor.velocity.y,0.)
	var blocked:=false
	for i in actor.get_slide_collision_count():
		var contact:=actor.get_slide_collision(i)
		if contact.get_normal().y<cos(actor.floor_max_angle): blocked=true;break
	var travelled:=actor.global_position-start
	horizontal-=Vector3(travelled.x,0,travelled.z)
	if blocked and supported and wanted.y<=.1 and horizontal.length_squared()>.000001:
		var is_bot: bool=bot_step_cache_enabled and bool(actor.get_meta("war_bot",false))
		var step_frame:=Engine.get_physics_frames()
		var heading:=Vector3(wanted.x,0,wanted.z).normalized()
		if is_bot:
			var failed: Dictionary=actor.get_meta("war_failed_step",{})
			if not failed.is_empty() and step_frame<int(failed.get("expires",0)):
				var old_position: Vector3=failed.get("position",Vector3.INF)
				var old_heading: Vector3=failed.get("heading",Vector3.ZERO)
				if start.distance_squared_to(old_position)<.0625 and heading.dot(old_heading)>.94:
					if qa_enabled:qa_reused_failures+=1
					return
		if qa_enabled:qa_attempts+=1
		var raised:=actor.global_transform
		if not _ia1_step_test(actor,raised,Vector3.UP*MAX_STEP):
			raised.origin.y+=MAX_STEP
			if not _ia1_step_test(actor,raised,horizontal):
				var ahead:=raised;ahead.origin+=horizontal
				var contact:=KinematicCollision3D.new()
				if _ia1_step_test(actor,ahead,Vector3.DOWN*(MAX_STEP+.08),contact) and contact.get_normal().y>.05:
					var rise:=MAX_STEP+contact.get_travel().y
					if rise>.015 and rise<=MAX_STEP+.005:
						# The rounded capsule first contacts the tread edge at a
						# sloping normal. Move only the requested horizontal distance
						# and retain contact for the next edge tick; never add speed.
						actor.global_position=ahead.origin+contact.get_travel()+Vector3.UP*.004
						actor.set_meta("step_contact_frame",Engine.get_physics_frames())
						var snap:=actor.floor_snap_length
						actor.velocity=Vector3(0,-.1,0);actor.floor_snap_length=0
						if BotCostProbe.enabled and bool(actor.get_meta("war_bot",false)):
							var __begun:=Time.get_ticks_usec()
							actor.move_and_slide()
							BotCostProbe.record("move_slide",Time.get_ticks_usec()-__begun)
						else:
							actor.move_and_slide()
						actor.velocity=Vector3(wanted.x,minf(0,actor.velocity.y),wanted.z);actor.floor_snap_length=snap
						if is_bot: actor.remove_meta("war_failed_step")
						if qa_enabled:qa_successes+=1
						return
		if is_bot:
			# Do not repeat an identical *failed* sweep for a fixed wall every
			# frame. Position/heading changes invalidate it immediately.
			actor.set_meta("war_failed_step",{"expires":step_frame+BOT_FAILED_STEP_RETRY_TICKS,"position":start,"heading":heading})
