extends SceneTree

# A deterministic playback test, not a network or GPU benchmark.
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)

func monotone_segment() -> void:
	var motion:=GameSnapshotMotion.new()
	# A real collision can sharply reduce distance within one packet period
	# while the prior sample still carries the pre-impact velocity.
	motion.push(Vector3.ZERO,Vector3(25,0,0),Vector3.ZERO,0.)
	motion.push(Vector3(.01,0,0),Vector3.ZERO,Vector3.ZERO,.05)
	var previous:=-INF
	for i in 101:
		var point:=motion.sample(GameSnapshotMotion.DELAY+float(i)*.0005).origin
		check(point.x>=-.00001 and point.x<=.01001,"collision interpolation remains inside its authoritative segment")
		check(point.x>=previous-.00001,"collision interpolation never overshoots then reverses")
		previous=point.x

func clock_and_delivery() -> void:
	var motion:=GameSnapshotMotion.new()
	var pending: Array[Dictionary]=[]
	var next_snapshot:=0.;var next_sequence:=0
	var previous_clock:=-INF;var previous_x:=-INF;var largest_step:=0.;var backward_steps:=0;var frozen_frames:=0
	# Variable packet arrival (including reordering and a short loss burst),
	# constant authoritative velocity, and two rendered frame durations.
	var wall:=0.
	for frame in 1800:
		var dt:=1./(60. if frame%11 else 40.)
		wall+=dt
		while next_snapshot<=wall:
			var sequence:=next_sequence;next_sequence+=1
			var latency: float=[.035,.060,.040,.095,.045,.055][sequence%6]
			if sequence%19!=10 and not (next_snapshot>8. and next_snapshot<8.16):
				pending.append({"time":next_snapshot,"arrival":next_snapshot+latency,"position":Vector3(next_snapshot*12,0,0)})
			next_snapshot+=.05
		pending.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.arrival)<float(b.arrival))
		while not pending.is_empty() and float(pending.front().arrival)<=wall:
			var packet: Dictionary=pending.pop_front()
			motion.push(packet.position,Vector3(12,0,0),Vector3.ZERO,packet.time)
		if motion.samples.is_empty(): continue
		var clock:=motion.advance(dt);var position:=motion.sample(clock).origin
		check(clock>=previous_clock,"render clock remains monotonic under jitter")
		check(clock<=float(motion.samples.back().time)+GameSnapshotMotion.DELAY+GameSnapshotMotion.MAX_AHEAD+.00001,"render clock stays within bounded authoritative horizon")
		if is_finite(previous_x):
			var step:=position.x-previous_x
			if step<-.00001: backward_steps+=1
			if absf(step)<.00001 and frame>30: frozen_frames+=1
			largest_step=maxf(largest_step,step)
		previous_clock=clock;previous_x=position.x
	check(backward_steps==0,"straight moving ship has no backwards corrections")
	check(largest_step<.40,"normal packets do not cause multi-metre steps")
	check(frozen_frames<12,"short loss burst does not produce repeated stopping")
	measurements={"frames":1800,"backward_steps":backward_steps,"frozen_frames":frozen_frames,"largest_step_m":largest_step}
	# Long interruption: clock cannot run unbounded and resumed state catches
	# up once; this is not evidence that a multi-second outage can be hidden.
	for i in 600: motion.advance(1./60.)
	check(motion.render_clock<=float(motion.samples.back().time)+.24001,"ten second outage does not accumulate a ten second render lead")
	motion.push(Vector3(600,0,0),Vector3(12,0,0),Vector3.ZERO,50.)
	motion.advance(1./60.)
	check(motion.render_clock>=50. and motion.render_clock<50.1,"resumed stream catches up without prolonged stale playback")
	motion.clear();check(not motion.clock_ready and motion.samples.is_empty(),"respawn clears playback clock and buffer")
	motion.push(Vector3(-50,0,0),Vector3.ZERO,Vector3.ZERO,60.)
	check(motion.sample(motion.advance(1./60.)).origin.distance_to(Vector3(-50,0,0))<.0001,"new life never interpolates across the previous position")

func run() -> void:
	monotone_segment();clock_and_delivery()
	NavalStorage.write_json("res://work/ship-motion-regression.json",{"ok":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements})
	print("SHIP_MOTION_REGRESSION ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements}))
	quit(0 if failures.is_empty() else 1)
