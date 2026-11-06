extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var order: Array[bool]=[false,true,true,false,false,true]
	var baseline: Array[Dictionary]=[]
	var times_a: Array[float]=[]
	var times_b: Array[float]=[]
	var reused:=0
	var equal:=true
	var amounts: Array[int]=[]
	for fast in order:
		var planner=load("res://modes/war/scripts/favela_layout.gd").new()
		planner.routes=WarFavelaMap.road_envelopes()
		planner.bases=WarFavelaMap.BASES_2D
		planner.objectives=WarFavelaMap.OBJECTIVES_2D
		planner.ia2_reuse_frontage=fast
		var started:=Time.get_ticks_usec()
		var lots: Array[Dictionary]=planner._plan()
		var duration:float=(Time.get_ticks_usec()-started)*.001
		if fast:
			times_b.append(duration)
			reused+=planner.ia2_frontage_reuses
			equal=equal and lots==baseline
		else:
			times_a.append(duration)
			baseline=lots
		amounts.append(lots.size())
		print("IA2_LAYOUT_STEP ",JSON.stringify({"fast":fast,"ms":duration,"lots":lots.size(),"reuse_calls":planner.ia2_frontage_reuses}))
	var digest: String=JSON.stringify(baseline).sha256_text()
	var sorted_a:=times_a.duplicate()
	var sorted_b:=times_b.duplicate()
	sorted_a.sort();sorted_b.sort()
	var report={"same_lots_and_placement":equal,"lots_per_run":amounts,
		"baseline_times_ms":times_a,"fast_times_ms":times_b,
		"median_baseline_ms":sorted_a[1],"median_fast_ms":sorted_b[1],
		"reused_frontage_calls":reused,
		"baseline_sha256":digest}
	print("IA2_LAYOUT_QA ",JSON.stringify(report))
	quit(0 if equal and baseline.size()>100 else 1)
