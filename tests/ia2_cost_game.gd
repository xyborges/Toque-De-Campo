extends WarGame

# An isolated QA game. Production actors and AI are never modified.
# All overrides invoke the original gameplay implementation unchanged;
# --ia2-brain-off only suppresses _think after benchmark warmup.
class TimedWarPlayer extends WarPlayer:
	func _physics_process(delta: float) -> void:
		var t := IA2CostMetrics.begin()
		super._physics_process(delta)
		IA2CostMetrics.end(&"actor.physics_inclusive",t)

	func _animate_walk() -> void:
		var t := IA2CostMetrics.begin()
		super._animate_walk()
		IA2CostMetrics.end(&"actor.pose_visual_and_hitbox_inclusive",t)

	func _update_weapon_pose() -> void:
		var t := IA2CostMetrics.begin()
		super._update_weapon_pose()
		IA2CostMetrics.end(&"actor.weapon_pose",t)

	func _finish_body_pose() -> void:
		var t := IA2CostMetrics.begin()
		super._finish_body_pose()
		IA2CostMetrics.end(&"actor.body_pose",t)

	func _pose_arm(arm: Node3D,hand_position: Vector3,group: String) -> void:
		var t := IA2CostMetrics.begin()
		super._pose_arm(arm,hand_position,group)
		IA2CostMetrics.end(&"actor.arm_ik",t)

	func _set_hitboxes_enabled(value: bool) -> void:
		var t := IA2CostMetrics.begin()
		super._set_hitboxes_enabled(value)
		IA2CostMetrics.end(&"actor.hitbox_toggle",t)

class TimedBotDirector extends WarBotDirector:
	var brain_off := false

	func _physics_process(delta: float) -> void:
		var t := IA2CostMetrics.begin()
		super._physics_process(delta)
		IA2CostMetrics.end(&"brain_and_movement.director_inclusive",t)

	func _think(id: int) -> void:
		var t := IA2CostMetrics.begin()
		if not brain_off: super._think(id)
		IA2CostMetrics.end(&"brain.decision",t)

	func _move(actor: WarPlayer,record: Dictionary,delta: float) -> void:
		var t := IA2CostMetrics.begin()
		super._move(actor,record,delta)
		IA2CostMetrics.end(&"brain_and_movement.bot_move_inclusive",t)

	func _visible_enemy(actor: WarPlayer) -> WarPlayer:
		var t := IA2CostMetrics.begin()
		var found := super._visible_enemy(actor)
		IA2CostMetrics.end(&"queries.enemy_scan_inclusive",t)
		return found

	func _has_clear_shot(actor: WarPlayer,target: WarPlayer) -> bool:
		var t := IA2CostMetrics.begin()
		var clear := super._has_clear_shot(actor,target)
		IA2CostMetrics.end(&"queries.clear_shot_ray",t)
		return clear

	func _avoid(actor: WarPlayer,direction: Vector3) -> Vector3:
		var t := IA2CostMetrics.begin()
		var result := super._avoid(actor,direction)
		IA2CostMetrics.end(&"queries.avoid_1_to_9_rays",t)
		return result

	func _traffic_clear(vehicle: WarVehicle,start: Vector3,end: Vector3) -> bool:
		var t := IA2CostMetrics.begin()
		var result := super._traffic_clear(vehicle,start,end)
		IA2CostMetrics.end(&"queries.traffic_shape_and_cast",t)
		return result

func _new_player() -> GamePlayer:
	return TimedWarPlayer.new()

func _start_offline() -> void:
	await super._start_offline()
	if not is_inside_tree() or not join_ready or not is_instance_valid(bot_director):return
	var old: WarBotDirector=bot_director
	old.stop()
	old.queue_free()
	var replacement:=TimedBotDirector.new()
	bot_director=replacement
	replacement.setup(self)
	world_root.add_child(replacement)
