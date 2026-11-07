extends SceneTree

# Client preparation must produce a complete world before gameplay starts.
# This uses headless geometry only and never opens ENet.
var staged:=true
var run_id:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--staged="):staged=arg.trim_prefix("--staged=")=="1"
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	Engine.max_fps=60
	run.call_deferred()

func run() -> void:
	WarFavelaMap.housing_lots.clear()
	var started_us:=Time.get_ticks_usec()
	var prep: Dictionary={}
	if staged:prep=await WarFavelaMap.ia2_prepare_layout_staged(self,16.0)
	var prepared_at_us:=Time.get_ticks_usec()
	var digest: String=JSON.stringify(WarFavelaMap.housing_lots).sha256_text() if staged else ""
	var problems: Array[String]=[]
	if staged and int(prep.lots)!=4313:problems.append("wrong staged lot count")
	var game: WarGame=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var timeout:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<timeout:
		await process_frame
	if not game.join_ready:problems.append("world not ready")
	var ready_at_us:=Time.get_ticks_usec()
	if not staged:digest=JSON.stringify(WarFavelaMap.housing_lots).sha256_text()
	if WarFavelaMap.housing_lots.size()!=4313:problems.append("wrong final lot count")
	if digest!="cf02c42b719d067724e2913677870aaadadcd89ba463c577a33cf905e520ea55":problems.append("wrong final lot hash")
	var map: WarFavelaMap=game.world_root.get_node_or_null("FavelaWar") as WarFavelaMap
	if not is_instance_valid(map):
		problems.append("no favela map")
	else:
		if int(map.build_metrics.terrain_tiles)!=225:problems.append("wrong terrain tiles")
		if int(map.build_metrics.collision_shapes)!=11624:problems.append("wrong collision geometry")
		if JSON.stringify(WarFavelaMap.housing_lots).sha256_text()!=digest:problems.append("cache changed during world build")
	print("IA2_STAGED_WORLD_QA ",JSON.stringify({
		"run":run_id,"staged":staged,"preparation":prep,"hash":digest,
		"preparation_elapsed_ms":(prepared_at_us-started_us)*.001,
		"total_to_join_ready_ms":(ready_at_us-started_us)*.001,
		"world_build_ms":game.world_build_ms,
		"geometry":map.build_metrics if is_instance_valid(map) else {},
		"problems":problems}))
	quit(0 if problems.is_empty() else 2)
