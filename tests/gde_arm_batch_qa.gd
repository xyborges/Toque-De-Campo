extends SceneTree
## Numerical parity of complete arm/elbow/forearm/hand IK, both sides and batch.
var checks:=0
var failures: Array[String]=[]
var max_error:=0.0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok and failures.size()<18:failures.append(message)

func transform_error(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),
		maxf(a.basis.x.distance_to(b.basis.x),
		maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_ARM_BATCH_QA ",JSON.stringify({"checks":0,"failures":["Native library not loaded"]}))
		quit(2);return
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261110
	var sample_count:=480
	var native: Object=ClassDB.instantiate("WarNativePoseMath")
	check(native!=null,"Native instance")
	for sample in sample_count:
		var inputs: Array[Dictionary]=[]
		for left in [false,true]:
			var side: String="L" if left else "R"
			var scale:=rng.randf_range(.65,1.5)
			var arm_base:=Vector3((-.35 if left else .35)+rng.randf_range(-.07,.07),
				rng.randf_range(.06,1.4),rng.randf_range(-.65,.22))
			var grip:=arm_base+Vector3(
				rng.randf_range(-.3,.3),rng.randf_range(-.66,.15),rng.randf_range(-.85,.10))
			var basis:=Basis.from_euler(Vector3(rng.randf_range(-1.1,1.1),
				rng.randf_range(-.8,.8),rng.randf_range(-.5,.5)))
			var upper_basis:=Basis.from_euler(Vector3(rng.randf_range(-.8,.8),
				rng.randf_range(-.3,.3),rng.randf_range(-.2,.2)))
			var cuff:=Vector3(-.035,-.029,.075) if left else Vector3(.023,-.025,.085)
			inputs.append({"shoulder":arm_base,"grip":grip,"hand_basis":basis,
				"upper_basis":upper_basis,"side":side,"cuff":cuff,"proportion":scale})
		var shoulders:=PackedVector3Array()
		var grips:=PackedVector3Array()
		var hand_bases: Array[Basis]=[]
		var upper_bases: Array[Basis]=[]
		var side_flags:=PackedInt32Array()
		var proportions:=PackedFloat32Array()
		var cuffs:=PackedVector3Array()
		for data in inputs:
			shoulders.append(data.shoulder)
			grips.append(data.grip)
			hand_bases.append(data.hand_basis)
			upper_bases.append(data.upper_basis)
			side_flags.append(1 if data.side=="L" else 0)
			proportions.append(data.proportion)
			cuffs.append(data.cuff)
		var batch: Array=native.arm_batch(shoulders,grips,hand_bases,upper_bases,
			side_flags,proportions,cuffs)
		check(batch.size()==2,"batch size sample "+str(sample))
		if batch.size()!=2:continue
		for j in 2:
			var expected: Array=WarHumanRig._solve_arm_gd(inputs[j])
			var actual: Array=batch[j]
			check(expected.size()==4 and actual.size()==4,"4 transforms sample "+str(sample))
			if expected.size()!=4 or actual.size()!=4:continue
			for k in 4:
				var err:=transform_error(expected[k],actual[k])
				max_error=maxf(max_error,err)
				check(err<.00025,"IK divergence sample %d arm %d part %d: %.9f"%
					[sample,j,k,err])
	# An unreachable target is explicitly rejected instead of producing NaNs.
	var invalid: Array=native.arm_batch(
		PackedVector3Array([Vector3.ZERO]),PackedVector3Array([Vector3.ZERO]),
		[Basis.IDENTITY],[Basis.IDENTITY],PackedInt32Array([0]),
		PackedFloat32Array([1.]),PackedVector3Array([Vector3.ZERO]))
	check(invalid.size()==1 and (invalid[0] as Array).is_empty(),
		"zero-length arm rejected safely")
	print("GDE_ARM_BATCH_QA ",JSON.stringify({"checks":checks,"failures":failures,
		"random_pairs":sample_count,"max_transform_error":max_error}))
	quit(0 if failures.is_empty() else 1)
