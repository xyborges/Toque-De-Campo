extends SceneTree

const METRICS=preload("res://scripts/frame_pacing.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures.append(message)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var metrics:=METRICS.new()
	metrics.kind="foot"
	var now:=1000000
	metrics.sample(now,0,2.,1.)
	for frame in 600:
		now+=50000 if frame%90==89 else 16667
		metrics.sample(now,frame+1,2.,1.)
	var result:=metrics.report(now)
	check(result.frames==600 and result.frame.samples==600,"one sample per interval; initialization is excluded")
	check(absf(float(result.frame.p50_ms)-16.667)<.001 and result.frame.max_ms==50.,"normal frame budget and short stalls remain distinguishable")
	check(result.outliers.size()==6 and result.frames_over_25ms==6,"periodic 50 ms stalls survive the bounded report")
	check(absf(float(result.outliers[1].since_previous_ms)-1533.363)<.1,"reports preserve the interval between periodic stalls")
	metrics.correction(.2);metrics.correction(.1)
	metrics.snapshot(now);metrics.snapshot(now+50000);metrics.snapshot(now+250000)
	result=metrics.report(now+300000)
	check(result.position_corrections==2 and is_equal_approx(float(result.maximum_correction_m),.2),"server corrections are counted without recording positions")
	check(result.vehicle_snapshots==3 and result.maximum_vehicle_snapshot_gap_ms==200. and result.vehicle_snapshot_age_ms==50.,"vehicle update gaps are measured separately from rendering")
	metrics.reset(now)
	for frame in 2501:metrics.sample(now+frame*10000,frame/2,1.,.5)
	result=metrics.report(now+25000000)
	check(result.frames==2500 and result.frame.samples==1200 and metrics.durations.size()==1200,"long sessions retain fixed memory per timing series")
	check(result.no_physics_step_frames==1250,"render frames without a physics step are visible independently of wall stalls")
	check(result.position_corrections==0 and result.vehicle_snapshots==0 and result.outliers.is_empty(),"new windows clear previous events")
	var started:=Time.get_ticks_usec()
	for frame in 20000:metrics.sample(now+frame*10000,frame/2,1.,.5)
	print("SAMPLE_MEAN_USEC ",(Time.get_ticks_usec()-started)/20000.)
	for i in range(result.size(), 34):
		result["context_%d" % i] = i
	result.render = {"draw_calls": 1234}
	result.rtt_ms = 54
	GameDiagnostics.record("frame_pacing_test",result)
	var session:=GameDiagnostics.session()
	session.flush()
	var rows:=FileAccess.get_file_as_string(session.path).strip_edges().split("\n")
	var saved: Dictionary=JSON.parse_string(rows[-1])
	check(saved.event=="frame_pacing_test" and saved.details.frame.samples==1200 and saved.details.has("vehicle_snapshot_age_ms"),"actual diagnostics writer retains the timing payload")
	check(saved.details.get("render", {}).get("draw_calls") == 1234 and saved.details.get("rtt_ms") == 54, "render and network context survive after the first 32 fields")
	quit(0 if failures.is_empty() else 1)
