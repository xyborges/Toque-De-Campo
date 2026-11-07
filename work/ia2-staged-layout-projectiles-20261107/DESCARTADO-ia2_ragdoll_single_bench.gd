extends SceneTree

# Compare full ragdoll construction with/without redundant part-part
# collision exceptions. Masks and joints must remain identical.
var samples: Array[float]=[]
var violations: Array[String]=[]
var mode: String=""
var run_id:=0

func _initialize() -> void:
	mode=OS.get_environment("TDC_IA2_RAGDOLL_MASK_ONLY")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	Engine.max_fps=0
	_go.call_deferred()

func _summary(values: Array[float]) -> Dictionary:
	var sorted:=values.duplicate()
	sorted.sort()
	var total:=0.0
	for v in sorted:total+=v
	return {"count":sorted.size(),"mean_ms":total/sorted.size(),
		"p95_ms":sorted[ceili(sorted.size()*.95)-1],
		"p99_ms":sorted[ceili(sorted.size()*.99)-1],
		"max_ms":sorted.back()}

func _go() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var actor: WarPlayer=game.players.get(2)
	if not is_instance_valid(actor):violations.append("actor missing")
	var shape_count:=0
	var joint_count:=0
	var exception_count:=0
	for i in 16:
		await physics_frame
		var begin:=Time.get_ticks_usec()
		var torso: RigidBody3D=DeathRagdoll.create(game.world_root,actor,actor.global_position)
		var duration:float=(Time.get_ticks_usec()-begin)*.001
		samples.append(duration)
		var corpse:=torso.get_parent()
		var parts: Array[RigidBody3D]=[]
		var joints: Array[Joint3D]=[]
		for node in corpse.get_children():
			if node is RigidBody3D:parts.append(node)
			elif node is Joint3D:joints.append(node)
		shape_count=parts.size()
		joint_count=joints.size()
		var exceptions:=0
		for part in parts:
			if part.collision_layer!=8 or part.collision_mask!=1:
				violations.append("incorrect layer or mask in corpse "+str(i))
			exceptions+=part.get_collision_exceptions().size()
			if not part.global_position.is_finite():violations.append("invalid initial pose")
		exception_count=exceptions
		if mode=="1" and exceptions>joints.size()*2:violations.append("redundant explicit exceptions remain")
		if mode!="1" and exceptions<=joints.size()*2:violations.append("original explicit exceptions missing")
		await physics_frame
		for part in parts:
			if not part.global_position.is_finite() or not part.linear_velocity.is_finite():
				violations.append("physics unstable")
		corpse.queue_free()
		await process_frame
	if shape_count<10 or joint_count<9:violations.append("missing parts or joints")
	var record={"mode":"mask_only" if mode=="1" else "original",
		"run":run_id,"ragdolls":samples.size(),"bodies":shape_count,
		"joints":joint_count,"exceptions_in_last_corpse":exception_count,
		"create_ms":_summary(samples),"errors":violations}
	print("IA2_RAGDOLL_MASK_BENCH ",JSON.stringify(record))
	game.queue_free()
	await process_frame
	quit(0 if violations.is_empty() else 2)
