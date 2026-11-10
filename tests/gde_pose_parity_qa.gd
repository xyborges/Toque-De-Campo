extends SceneTree
## Windows GDExtension pilot: actual GameInfantryPose parity, not FPS.
var checks:=0
var failures: Array[String]=[]
var max_upper_error:=0.0
var max_weapon_error:=0.0

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> void:
	checks+=1
	if not ok and failures.size()<12:failures.append(message)

func error_between(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_POSE_PARITY ",JSON.stringify({"checks":0,"failures":["native class unavailable; compile matching OS library before executing"]}))
		quit(2);return
	var native: Object=ClassDB.instantiate("WarNativePoseMath")
	require(native!=null,"native class instantiation")
	if native==null:quit(2);return
	var actor:=GamePlayer.new()
	actor.is_local=false
	actor.body_root=Node3D.new()
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261110
	var pitches:=PackedFloat32Array()
	var leans:=PackedFloat32Array()
	for i in 900:
		actor.pitch=rng.randf_range(-1.65,1.65)
		actor.lean=rng.randf_range(-1,1)
		actor.stance.prone_weight=rng.randf_range(0,1)
		actor.body_root.transform=Transform3D(Basis.from_euler(Vector3(rng.randf_range(-.6,.6),rng.randf_range(-3,3),rng.randf_range(-.4,.4))),Vector3(rng.randf_range(-5,5),rng.randf_range(-3,3),rng.randf_range(-5,5)))
		var offset:=Vector3(rng.randf_range(-.4,.4),rng.randf_range(-.4,.4),rng.randf_range(-.7,0))
		var upper: Transform3D=GameInfantryPose.upper_transform(actor)
		var upper_cpp: Transform3D=native.upper_transform(actor.pitch,actor.lean)
		var eu:=error_between(upper,upper_cpp)
		max_upper_error=maxf(max_upper_error,eu)
		require(eu<.0002,"upper pose mismatch sample "+str(i)+" error="+str(eu))
		var weapon: Transform3D=GameInfantryPose.weapon_pose(actor,offset)
		var clamped:=actor.clamp_aim_pitch(actor.pitch)
		var weapon_cpp: Transform3D=native.weapon_transform(clamped,actor.lean,actor.stance.prone_weight,actor.body_root.transform,offset)
		var ew:=error_between(weapon,weapon_cpp)
		max_weapon_error=maxf(max_weapon_error,ew)
		require(ew<.0004,"weapon pose mismatch sample "+str(i)+" error="+str(ew))
		if i<28:
			pitches.append(actor.pitch)
			leans.append(actor.lean)
	var result: Array=native.upper_batch(pitches,leans)
	require(result.size()==28,"batch returns one result per bot")
	for i in result.size():
		actor.pitch=float(pitches[i]);actor.lean=float(leans[i])
		var expected: Transform3D=GameInfantryPose.upper_transform(actor)
		require(error_between(result[i],expected)<.0002,"batch parity bot "+str(i))
	actor.body_root.free()
	actor.free()
	print("GDE_POSE_PARITY ",JSON.stringify({"checks":checks,"failures":failures,"random_states":900,"batch_bots":28,"max_upper_error":max_upper_error,"max_weapon_error":max_weapon_error}))
	quit(0 if failures.is_empty() else 1)
