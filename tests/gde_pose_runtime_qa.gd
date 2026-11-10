extends SceneTree
## Test the EXACT production GameInfantryPose opt-in and fallback paths.
var checks:=0
var failures: Array[String]=[]
var max_error:=0.0

func _initialize() -> void:_run.call_deferred()

func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<12:failures.append(label)

func diff(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_POSE_RUNTIME_QA ",JSON.stringify({"checks":checks,"failures":["GDE class unavailable"]}))
		quit(2);return
	var initial_mode: bool=GameInfantryPose.native_pose_enabled
	var actor:=GamePlayer.new()
	actor.is_local=false
	actor.body_root=Node3D.new()
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261110
	for i in 420:
		actor.pitch=rng.randf_range(-1.25,1.2)
		actor.lean=rng.randf_range(-1.,1.)
		actor.stance.prone_weight=rng.randf_range(0.,1.)
		actor.body_root.transform=Transform3D(Basis.from_euler(Vector3(rng.randf_range(-.4,.4),rng.randf_range(-2.5,2.5),rng.randf_range(-.2,.2))),Vector3(rng.randf_range(-6.,6.),0.,rng.randf_range(-6.,6.)))
		var offset:=Vector3(rng.randf_range(-.2,.2),rng.randf_range(-.14,.14),rng.randf_range(-.8,0))
		GameInfantryPose.native_pose_enabled=false
		var fallback_upper: Transform3D=GameInfantryPose.upper_transform(actor)
		var fallback_weapon: Transform3D=GameInfantryPose.weapon_pose(actor,offset)
		GameInfantryPose.native_pose_enabled=true
		var native_upper: Transform3D=GameInfantryPose.upper_transform(actor)
		var native_weapon: Transform3D=GameInfantryPose.weapon_pose(actor,offset)
		var eu:=diff(fallback_upper,native_upper)
		var ew:=diff(fallback_weapon,native_weapon)
		max_error=maxf(max_error,maxf(eu,ew))
		verify(eu<.0002,"fallback vs native torso mismatch "+str(i))
		verify(ew<.0004,"fallback vs native weapon mismatch "+str(i))
	verify(GameInfantryPose.native_pose_checked,"native extension initialized once")
	verify(GameInfantryPose.native_pose_instance!=null,"native extension instance retained")
	GameInfantryPose.native_pose_enabled=initial_mode
	actor.body_root.free()
	actor.free()
	print("GDE_POSE_RUNTIME_QA ",JSON.stringify({"checks":checks,"failures":failures,"samples":420,"max_error":max_error,"flag_at_launch":initial_mode,"restored":GameInfantryPose.native_pose_enabled==initial_mode}))
	quit(0 if failures.is_empty() else 1)
