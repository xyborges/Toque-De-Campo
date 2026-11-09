extends SceneTree

const BODY_POSE = preload("res://modes/war/scripts/tactical_body_pose.gd")
const ACTORS := 28
const TICKS := 720
const PAIRS := 5

func _initialize() -> void:
	run.call_deferred()

# Synthetic cost boundary, NOT a gameplay-FPS benchmark. It deliberately
# simulates 28 actors but evaluates the R2 function only for the ONE local FPP
# actor, matching the opt-in production contract. No physics, draw or ENet.
func sweep(pilot: bool) -> Dictionary:
	var sink := 0.
	var start_us := Time.get_ticks_usec()
	for frame in TICKS:
		var forward := sin(float(frame)*.055)
		var side := cos(float(frame)*.067)
		var landing := maxf(0.,sin(float(frame)*.038))
		for actor_id in ACTORS:
			sink += float(actor_id)*.0000002
			if pilot and actor_id==0:
				var angles := BODY_POSE.fpp_weapon_angles(forward,side,landing)
				sink += angles.x+angles.y+angles.z
	return {"elapsed_ms":float(Time.get_ticks_usec()-start_us)/1000.,"checksum":sink}

func median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[int(sorted.size()/2)]

func run() -> void:
	var aa_deltas: Array[float]=[]
	var ab_deltas: Array[float]=[]
	var controls: Array[float]=[]
	var pilots: Array[float]=[]
	var baseline_counts := {"actors":ACTORS,"ticks":TICKS,"actor_frames":ACTORS*TICKS,"local_fpp_solves":TICKS}
	for warmup in 3:
		sweep(false)
		sweep(true)
	for i in PAIRS:
		var aa_0 := sweep(false)
		var aa_1 := sweep(false)
		aa_deltas.append(float(aa_1.elapsed_ms)-float(aa_0.elapsed_ms))
		var a := sweep(false)
		var b := sweep(true)
		controls.append(float(a.elapsed_ms))
		pilots.append(float(b.elapsed_ms))
		ab_deltas.append(float(b.elapsed_ms)-float(a.elapsed_ms))
	var aa_median := median(aa_deltas)
	var ab_median := median(ab_deltas)
	var per_local_tick_us := ab_median*1000./float(TICKS)
	var report := {
		"fixture":"R2B pure pose, 28 actors but ONE local player; no physics, renderer, AI or network",
		"counts":baseline_counts,
		"aa_deltas_ms":aa_deltas,
		"ab_deltas_ms":ab_deltas,
		"aa_median_delta_ms":aa_median,
		"ab_median_delta_ms":ab_median,
		"estimated_overhead_us_per_local_tick":per_local_tick_us,
		"a_elapsed_ms":controls,
		"b_elapsed_ms":pilots,
		"note":"Exploratory only. No FPS or p95/p99 claim; normal mode/remote bots do not evaluate R2B."
	}
	print("REALISMO_R2B_MICROBENCH "+JSON.stringify(report))
	quit(0)
