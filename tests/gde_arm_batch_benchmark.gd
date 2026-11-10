extends SceneTree
## Complete two-bone arm IK (not cheap torso) for 28 bots, 2 arms each.
## Both paths include data dispatch, return values and result consumption.
const BOTS:=28
const FRAMES:=360
const ROUNDS:=7
var data_sets: Array=[]
var failures: Array[String]=[]

func _initialize() -> void:_run.call_deferred()

func arm_inputs(side: String,i: int) -> Dictionary:
	var left:=side=="L"
	var shoulder:=Vector3(-.32 if left else .32,1.1+sin(float(i)*.12)*.2,0)
	var grip:=shoulder+Vector3((-.18 if left else .2),-.25+sin(float(i)*.2)*.12,-.48)
	return {"shoulder":shoulder,"grip":grip,
		"hand_basis":Basis.from_euler(Vector3(.12+float(i)*.002,0.,-.08)),
		"upper_basis":Basis.from_euler(Vector3(.08,0.,sin(float(i)*.1)*.07)),
		"side":side,"proportion":1.+sin(float(i)*.13)*.2,
		"cuff":Vector3(-.035,-.029,.075) if left else Vector3(.023,-.025,.085)}

func trial(native: bool) -> Dictionary:
	var checksum:=0.0
	var begin:=Time.get_ticks_usec()
	for frame in FRAMES:
		for data: Array[Dictionary] in data_sets:
			if native:
				var output: Array=WarHumanRig._native_arm_batch(data)
				for transforms: Array in output:
					if transforms.size()==4:
						var elbow: Transform3D=transforms[2]
						checksum+=elbow.origin.x+elbow.basis.y.y
			else:
				for item: Dictionary in data:
					var transforms: Array=WarHumanRig._solve_arm_gd(item)
					if transforms.size()==4:
						var elbow: Transform3D=transforms[2]
						checksum+=elbow.origin.x+elbow.basis.y.y
	return {"ms":float(Time.get_ticks_usec()-begin)/1000.,"checksum":checksum}

func median(items: Array[float]) -> float:
	var arr:=items.duplicate()
	arr.sort()
	return arr[int(arr.size()/2)]

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_ARM_BENCH ",JSON.stringify({"error":"Native class not available"}));quit(2);return
	for i in BOTS:
		var duo: Array[Dictionary]=[arm_inputs("R",i),arm_inputs("L",i)]
		data_sets.append(duo)
	GameInfantryPose.native_pose_enabled=true
	var modes: Dictionary={"gd":[],"native":[]}
	for _warmup in 2:
		trial(false);trial(true)
	for r in ROUNDS:
		var order:=PackedStringArray(["gd","native"]) if r%2==0 else PackedStringArray(["native","gd"])
		for mode in order:
			modes[mode].append(trial(mode=="native"))
	var med: Dictionary={}
	var checksums: Dictionary={}
	for mode: String in modes:
		var values: Array[float]=[]
		for result: Dictionary in modes[mode]:values.append(float(result.ms))
		med[mode]=median(values)
		checksums[mode]=modes[mode][0].checksum
	var equal:=absf(float(checksums.gd)-float(checksums.native))<.1
	if not equal:failures.append("Checksum differs; cannot infer timing parity")
	print("GDE_ARM_BENCH ",JSON.stringify({"bots":BOTS,"arms_per_bot":2,"frames":FRAMES,
		"rounds":ROUNDS,"arm_solves_per_trial":BOTS*2*FRAMES,
		"median_ms":med,"speedup_native":float(med.gd)/maxf(.001,float(med.native)),
		"checksums":checksums,"checksums_equal":equal,"failures":failures,
		"scope":"pure two-bone IK including packed input generation and return consumption; no scene nodes, hitbox, Jolt or render"}))
	GameInfantryPose.native_pose_enabled=false
	quit(0 if failures.is_empty() else 1)
