extends SceneTree
## Verify all N candidate repulsions against existing per-ally GDScript rule.
var checks:=0
var failures: Array[String]=[]
var largest_difference:=0.0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok and failures.size()<18:failures.append(message)

func _reference(positions: PackedVector3Array,i: int) -> Vector3:
	var separation:=Vector3.ZERO
	for j in positions.size():
		if i==j:continue
		var offset:=positions[i]-positions[j]
		offset.y=0
		var distance:=offset.length()
		if distance>.01 and distance<1.1:
			separation+=offset/distance*(1.1-distance)
	return separation

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_NATIVE_SEPARATION_QA ",JSON.stringify({"error":"native class not loaded"}))
		quit(2);return
	var native: Object=ClassDB.instantiate("WarNativePoseMath")
	if not native.has_method("separation_batch"):
		print("GDE_NATIVE_SEPARATION_QA ",JSON.stringify({"error":"missing separation_batch"}))
		quit(2);return
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261110
	for n in [0,1,2,12,28,57]:
		for sample in 100:
			var positions:=PackedVector3Array()
			for i in n:
				# 75% clustered near each other, 25% across map.
				var cluster: bool=i%4!=0
				var x:=rng.randf_range(-1.6,1.6) if cluster else rng.randf_range(-700,700)
				var z:=rng.randf_range(-1.6,1.6) if cluster else rng.randf_range(-700,700)
				positions.append(Vector3(x,rng.randf_range(-30,60),z))
			if n>4 and sample==0:
				positions.set(1,positions[2])
			if n>4 and sample==1:
				positions.set(1,positions[2]+Vector3(.01,3.,0.))
			var actual: PackedVector3Array=native.separation_batch(positions)
			_check(actual.size()==n,"batch size %d %d"%[n,sample])
			if actual.size()!=n:continue
			for i in n:
				var expected:=_reference(positions,i)
				var e:=expected.distance_to(actual[i])
				largest_difference=maxf(largest_difference,e)
				_check(e<.0001,"separation %d/%d/%d divergence %.8f"%[n,sample,i,e])
				_check(is_zero_approx(actual[i].y),"unexpected y force")
	print("GDE_NATIVE_SEPARATION_QA ",JSON.stringify({"checks":checks,
		"failures":failures,"max_error":largest_difference,
		"candidate_counts":[0,1,2,12,28,57],"samples_per_count":100}))
	quit(0 if failures.is_empty() else 1)
