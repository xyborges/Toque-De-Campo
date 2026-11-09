extends SceneTree
## Small isolated writer check for the opt-in V27 trace.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	var actor:=WarPlayer.new()
	actor.name="V27TraceWriterActor"
	actor.is_local=false
	actor.is_npc=true
	actor.set_physics_process(false)
	root.add_child(actor)
	await physics_frame
	var recorder:=preload("res://modes/war/scripts/roof_motion_trace.gd")
	for tick in 30:
		actor.global_position+=Vector3(.01,0,0)
		recorder.record(actor,1.0/60.0)
	var found:=false
	var files:=DirAccess.get_files_at("user://")
	for file in files:
		if file.begins_with("favela-v27-roof-") and file.ends_with(".jsonl"):
			var f:=FileAccess.open("user://"+file,FileAccess.READ)
			if f:
				var line:=f.get_line()
				var data=JSON.parse_string(line)
				found=data is Dictionary and data.has("pos") and data.has("camera") and data.has("contacts")
				break
	print("V27_TRACE_WRITER_QA ",JSON.stringify({"pass":found,"records_requested":30}))
	actor.queue_free()
	quit(0 if found else 1)
