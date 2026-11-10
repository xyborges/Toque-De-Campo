extends SceneTree
## Isolated CPU microbenchmark: GDScript pure math vs GDE singleton vs 28-bot batch.
## Does not exercise skeletons, hitboxes, Jolt, rendering, RPC or a full scene.
const BOT_COUNT:=28
const FRAMES:=1200
const ROUNDS:=7
var native: Object
var pitches:=PackedFloat32Array()
var leans:=PackedFloat32Array()

func _initialize() -> void:_run.call_deferred()

func gd_upper(pitch: float,lean: float) -> Transform3D:
	var bend:=clampf(pitch*.42,-.49,.49)
	var basis:=Basis(Vector3.BACK,-lean*.18)*Basis(Vector3.RIGHT,bend)
	var waist:=Vector3(0,.87,0)
	return Transform3D(basis,waist+Vector3(lean*.04,0,0)-basis*waist)

func sweep(mode: String) -> Dictionary:
	var sum:=0.0
	var begin:=Time.get_ticks_usec()
	if mode=="gd":
		for _frame in FRAMES:
			for i in BOT_COUNT:
				var t:=gd_upper(pitches[i],leans[i])
				sum+=t.origin.x+t.basis.y.x
	elif mode=="native":
		for _frame in FRAMES:
			for i in BOT_COUNT:
				var t: Transform3D=native.upper_transform(pitches[i],leans[i])
				sum+=t.origin.x+t.basis.y.x
	elif mode=="batch":
		for _frame in FRAMES:
			var out: Array=native.upper_batch(pitches,leans)
			for t: Transform3D in out:
				sum+=t.origin.x+t.basis.y.x
	return {"ms":float(Time.get_ticks_usec()-begin)/1000.,"checksum":sum}

func median(data: Array[float]) -> float:
	var a:=data.duplicate()
	a.sort()
	return a[int(a.size()/2)]

func _run() -> void:
	print("GDE_MICRO_ENTER")
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_POSE_MICROBENCH ",JSON.stringify({"error":"native extension unavailable"}))
		quit(2);return
	native=ClassDB.instantiate("WarNativePoseMath")
	for i in BOT_COUNT:
		pitches.append(sin(float(i)*.17)*1.25)
		leans.append(cos(float(i)*.23)*.9)
	var raw: Dictionary={"gd":[],"native":[],"batch":[]}
	for _warmup in 2:
		print("GDE_MICRO_WARMUP "+str(_warmup))
		sweep("gd");sweep("native");sweep("batch")
	for round_id in ROUNDS:
		print("GDE_MICRO_ROUND "+str(round_id))
		var order: PackedStringArray=PackedStringArray(["gd","native","batch"]) if round_id%2==0 else PackedStringArray(["batch","native","gd"])
		for mode in order:
			raw[mode].append(sweep(mode))
	var med: Dictionary={}
	var checksum: Dictionary={}
	for mode: String in raw:
		var ms: Array[float]=[]
		for trial: Dictionary in raw[mode]:ms.append(float(trial.ms))
		med[mode]=median(ms)
		checksum[mode]=raw[mode][0].checksum
	var same:=absf(float(checksum.gd)-float(checksum.native))<.001 and absf(float(checksum.gd)-float(checksum.batch))<.001
	var report: Dictionary={"bots":BOT_COUNT,"frames":FRAMES,"rounds":ROUNDS,"total_transforms_per_trial":FRAMES*BOT_COUNT,"median_ms":med,"speedup_scalar_vs_gd":float(med.gd)/maxf(.000001,float(med.native)),"speedup_batch_vs_gd":float(med.gd)/maxf(.000001,float(med.batch)),"checksums_equal":same,"checksums":checksum,"scope":"pure upper-transform math plus script/native call and output consumption; no graphics, physics, hitbox, RPC or full bots","samples":raw}
	print("GDE_POSE_MICROBENCH ",JSON.stringify(report))
	quit(0 if same else 1)
