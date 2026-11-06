extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game:=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready:
		push_error("IA2_MAP_STAGE: join_ready timeout")
		quit(2);return
	var map:=game.world_root.get_node_or_null("FavelaWar") as WarFavelaMap
	if not is_instance_valid(map):
		push_error("IA2_MAP_STAGE: no FavelaWar node")
		quit(2);return
	var stages: Dictionary=map.build_metrics.get("ia2_stage_times_ms",{})
	var total:=0.0
	for value in stages.values():total+=float(value)
	print("IA2_MAP_STAGES ",JSON.stringify({"stages_ms":stages,
		"total_stage_ms":total,"map_build_ms":map.build_metrics.build_ms,
		"world_build_ms":game.world_build_ms,
		"tiles":map.build_metrics.terrain_tiles,
		"collision_shapes":map.build_metrics.collision_shapes,
		"visuals":map.build_metrics.visuals}))
	quit(0 if stages.size()>=10 else 3)
