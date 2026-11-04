extends SceneTree
const VISUALS=preload("res://modes/battle_royale/ui/loot_visuals.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var results: Array=[]
	for i in 6:
		var optimized:=i%2==1
		var view:=VISUALS.new();view.set_meta("test_visuals",true);root.add_child(view);view.set_process(false)
		if optimized:view.prepare()
		var times: Array=[]
		var start:=Time.get_ticks_usec()
		if not optimized:
			# The old snapshot created every newly visible model synchronously.
			for id in 96:view._acquire("weapon:fal")
			times.append((Time.get_ticks_usec()-start)*.001)
		else:
			var records: Array=[]
			for id in 96:records.append({"id":id,"kind":"weapon","weapon":"fal","position":Vector3.ZERO})
			view.update_visible(records,Vector3.ZERO)
			while not view.pending.is_empty():
				start=Time.get_ticks_usec();view._process(0.);times.append((Time.get_ticks_usec()-start)*.001)
		results.append({"optimized":optimized,"max_creation_slice_ms":times.max(),"slices":times.size(),"created":view.created})
		view.free();await process_frame
	NavalStorage.write_json("res://work/br-loot-creation-benchmark.json",{"scope":"Headless CPU model-construction stress, 96 FALs; excludes GPU, shader compilation and preparation during loading. Not an FPS measurement.","samples":results})
	print("LOOT_CREATION ",JSON.stringify(results));quit()
