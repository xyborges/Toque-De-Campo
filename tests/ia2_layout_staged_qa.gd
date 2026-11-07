extends SceneTree

# Reproduce static layout in the original blocking call and incremental
# pre-ENet coroutine. Require byte-for-byte canonical JSON equivalence.
var last_frame_us:=0
var max_frame_ms:=0.0
var frame_intervals: Array[float]=[]
var budget_ms:=8.0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--budget-ms="):budget_ms=clampf(float(arg.trim_prefix("--budget-ms=")),1.0,33.0)
	Engine.max_fps=60
	process_frame.connect(_on_frame)
	run.call_deferred()

func _on_frame() -> void:
	var now:=Time.get_ticks_usec()
	if last_frame_us>0:
		var elapsed:float=(now-last_frame_us)*.001
		max_frame_ms=maxf(max_frame_ms,elapsed)
		frame_intervals.append(elapsed)
	last_frame_us=now

func run() -> void:
	var plan_file=load("res://modes/war/scripts/favela_layout.gd")
	var patterns: Array[bool]=[false,true,true,false,false,true,true,false,false,true]
	var first_digest: String=""
	var results: Array[Dictionary]=[]
	var failed:=false
	for i in patterns.size():
		await process_frame
		WarFavelaMap.housing_lots.clear()
		last_frame_us=Time.get_ticks_usec()
		max_frame_ms=0.0
		frame_intervals.clear()
		var t:=Time.get_ticks_usec()
		var metrics: Dictionary={}
		var lots: Array[Dictionary]=[]
		if patterns[i]:
			metrics=await WarFavelaMap.ia2_prepare_layout_staged(self,budget_ms)
			lots=WarFavelaMap.housing_lots
		else:
			lots=WarFavelaMap.housing_plan()
		# Capture the frame that spans the final invocation return as well.
		await process_frame
		var duration_ms:float=(Time.get_ticks_usec()-t)*.001
		var digest:=JSON.stringify(lots).sha256_text()
		if first_digest.is_empty():first_digest=digest
		if digest!=first_digest or lots.size()!=4313:
			push_error("STAGED_LAYOUT_MISMATCH "+str(i))
			failed=true
		var record: Dictionary={"run":i+1,"mode":"staged" if patterns[i] else "original",
			"duration_ms":duration_ms,"max_frame_interval_ms":max_frame_ms,
			"lots":lots.size(),"digest":digest,
			"stage_max_slice_ms":metrics.get("max_slice_ms",0.0),
			"stage_yield_checks":metrics.get("yield_checks",0),
			"frame_samples":frame_intervals.size()}
		results.append(record)
		print("IA2_STAGED_LAYOUT_RUN ",JSON.stringify(record))
	print("IA2_STAGED_LAYOUT_RESULT ",JSON.stringify({
		"passed":not failed,"runs":results.size(),"digest":first_digest,
		"data":results}))
	quit(1 if failed else 0)
