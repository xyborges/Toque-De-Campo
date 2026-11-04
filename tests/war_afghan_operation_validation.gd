extends SceneTree

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func wait_for(condition: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await process_frame
	return bool(condition.call())

func run() -> void:
	var game:=WarGame.new()
	game.operation_id=WarOperation.AFGHAN
	game.offline_operation=true
	game.set_meta("war_test",true)
	root.add_child(game)
	check(await wait_for(func():return is_instance_valid(game) and game.join_ready,35.),"Afghan offline operation reaches deployment")
	if is_instance_valid(game):
		check(game.operation_id==WarOperation.AFGHAN,"WarGame keeps Afghan operation")
		check(WarRules.CURRENT_OPERATION==WarOperation.AFGHAN,"WarRules configured for Afghan")
		check(WarTerrain.operation_id==WarOperation.AFGHAN and is_equal_approx(WarTerrain.HALF,1000.),"WarTerrain uses Afghan 2 km bounds")
		check(game._network_port()==3015,"Afghan online operation uses dedicated UDP 3015")
		check(WarRules.team_name(0)=="EUA" and WarRules.team_name(1)=="Mujahidins","Afghan team identities")
		check(WarRules.OBJECTIVES.size()==5 and WarRules.OBJECTIVES.has("A") and WarRules.OBJECTIVES.has("E"),"Afghan conquest objectives A-E")
		check(is_instance_valid(game.world_root) and bool(game.world_root.get_meta("afghan_war",false)),"War world reuses Afghan map builder")
		check(is_instance_valid(game.world_root) and int(game.world_root.get_meta("war_map_size",0))==2000,"Afghan War world reports 2 km map")
		for base: Vector3 in WarRules.BASES:
			check(absf(base.y-BRAfghanMap.height_at(base.x,base.z))<.05,"Base is grounded on Afghan terrain")
		for id in WarRules.OBJECTIVES:
			var p: Vector3=WarRules.OBJECTIVES[id].position
			check(absf(p.y-BRAfghanMap.height_at(p.x,p.z))<.05,"Objective "+id+" grounded on Afghan terrain")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"operation":"afghan","port":3015}
	print("WAR_AFGHAN_OPERATION_VALIDATION ",JSON.stringify(report))
	if is_instance_valid(game):game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
