extends SceneTree
## Full arm IK + actual Node3D writes: GDScript versus native direct.
const BOTS:=28
const FRAMES:=360
const ROUNDS:=7
var pairs: Array=[]
var native: Object
var nodes: Array[Node3D]=[]

func _initialize() -> void:_run.call_deferred()

func arm_data(i: int,left: bool) -> Dictionary:
	var side: String="L" if left else "R"
	var shoulder:=Vector3(-.34 if left else .34,1.+sin(i*.13)*.15,.1)
	var arm:=Node3D.new()
	var upper:=Node3D.new()
	var lower:=Node3D.new()
	var hand:=Node3D.new()
	nodes.append_array([arm,upper,lower,hand])
	return {"arm":arm,"upper":upper,"lower":lower,"hand":hand,
		"shoulder":shoulder,
		"grip":shoulder+Vector3((-.16 if left else .18),-.27+sin(i*.17)*.1,-.46),
		"hand_basis":Basis.from_euler(Vector3(.05+i*.005,.03,-.04)),
		"upper_basis":Basis.from_euler(Vector3(.12,0.,sin(i*.11)*.09)),
		"side":side,"proportion":1.+sin(i*.17)*.12,
		"cuff":Vector3(-.035,-.029,.075) if left else Vector3(.023,-.025,.085)}

func trial(use_native: bool) -> Dictionary:
	var checksum:=0.0
	var at:=Time.get_ticks_usec()
	for frame in FRAMES:
		for pair: Array[Dictionary] in pairs:
			if use_native:
				if int(native.apply_arms_direct(pair))!=2:
					return {"ms":-1.,"checksum":-99999.}
			else:
				for data: Dictionary in pair:
					var solved: Array=WarHumanRig._solve_arm_gd(data)
					var arm: Node3D=data.arm
					var upper: Node3D=data.upper
					var lower: Node3D=data.lower
					var hand: Node3D=data.hand
					arm.basis=(solved[0] as Transform3D).basis
					upper.position=(solved[1] as Transform3D).origin
					upper.scale=(solved[1] as Transform3D).basis.get_scale()
					lower.transform=solved[2]
					hand.transform=solved[3]
			for data: Dictionary in pair:
				var lower: Node3D=data.lower
				checksum+=lower.position.x+lower.basis.y.y
	return {"ms":float(Time.get_ticks_usec()-at)/1000.,"checksum":checksum}

func median(a: Array[float]) -> float:
	var v:=a.duplicate()
	v.sort()
	return v[v.size()/2]

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_ARM_DIRECT_BENCH ",JSON.stringify({"error":"native extension unavailable"}))
		quit(2);return
	native=ClassDB.instantiate("WarNativePoseMath")
	for i in BOTS:
		var duo: Array[Dictionary]=[arm_data(i,false),arm_data(i,true)]
		pairs.append(duo)
	for i in 2:
		trial(false);trial(true)
	var timings: Dictionary={"gd":[],"native":[]}
	var sums: Dictionary={}
	for round_id in ROUNDS:
		var order:=PackedStringArray(["gd","native"]) if round_id%2==0 else PackedStringArray(["native","gd"])
		for mode in order:
			var result:=trial(mode=="native")
			timings[mode].append(result)
			sums[mode]=result.checksum
	var med: Dictionary={}
	for mode: String in timings:
		var nums: Array[float]=[]
		for result: Dictionary in timings[mode]:nums.append(result.ms)
		med[mode]=median(nums)
	var same:=absf(float(sums.gd)-float(sums.native))<.1
	print("GDE_ARM_DIRECT_BENCH ",JSON.stringify({"bots":BOTS,"arms":BOTS*2,
		"frames":FRAMES,"repetitions":ROUNDS,"arm_writes_per_trial":BOTS*2*FRAMES,
		"medians_ms":med,"native_speedup":float(med.gd)/maxf(float(med.native),.001),
		"checksums":sums,"equal":same,
		"scope":"Complete 2-bone IK + scene Node3D writes for four parts per arm, input data pre-prepared; no rendering, game engine physics or other scripts"}))
	for node: Node3D in nodes:node.free()
	quit(0 if same and float(med.native)>0 else 1)
