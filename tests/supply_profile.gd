extends SceneTree
var game: Node3D
var role:="server"
var sample:="before"
var checks:=0
var failures: Array[String]=[]
var metrics: Dictionary={}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="): role=argument.trim_prefix("--role=")
		if argument.begins_with("--sample="): sample=argument.trim_prefix("--sample=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable,seconds:=15.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	failures.append("timeout at "+str(game.phase));return false
func phase(value: String) -> void: game.phase=value;game._broadcast("qa_phase",[value])
func report(label: String,data: Dictionary={}) -> void: game.rpc_id(1,"qa_report",role+":"+label,data)
func frames(count: int) -> Array[float]:
	var samples: Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in count:
		await process_frame
		var current:=Time.get_ticks_usec();samples.append((current-previous)/1000.);previous=current
	return samples
func describe(values: Array[float]) -> Dictionary:
	var ordered:=values.duplicate();ordered.sort();var total:=0.
	for number in values: total+=number
	return {"average_fps":1000.*values.size()/maxf(.001,total),"p95_ms":ordered[int(ordered.size()*.95)],"max_ms":ordered.back(),"frames":values.size()}
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/supply_profile_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": game.dedicated_pvp=true;game.host_game("pvp");await server()
	else: game.join_game("pvp");await client()
	var result: Dictionary={"role":role,"sample":sample,"checks":checks,"failures":failures,"metrics":metrics}
	NavalStorage.write_json("res://tests/supply-profile-"+sample+"-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.players.size()==3): return
	check(game.players.size()==3,"three independent ENet clients joined the real desert map")
	var owner: GamePlayer
	for actor: GamePlayer in game.players.values():
		if actor.name=="owner": owner=actor
	if not is_instance_valid(owner): check(false,"owner exists");return
	owner.life_id+=1;owner.position=Vector3(-3.35,.16,-5.3);owner.velocity=Vector3.ZERO
	game.state_clocks.erase(owner.peer_id);game._broadcast("remote_player_respawn",[owner.peer_id,owner.position,owner.life_id])
	for weapon in owner.ammo: owner.ammo[weapon]=0;owner.reserves[weapon]=0
	owner.grenades=0;game.sync_inventory(owner)
	phase("warmup")
	if not await wait_for(func():return game.reports.has("owner:warmup"),20): return
	phase("measure")
	if not await wait_for(func():return game.reports.has("owner:measure"),10): return
	check(owner.ammo.fal==30 and owner.ammo.glock==12 and owner.ammo.sniper==5 and owner.reserves.fal==180 and owner.grenades==2,"crate replenishes actual authoritative stocks without creating extra ammo")
	check(game.domination.supply_wait(owner.peer_id)>15,"supply cooldown remains authoritative")
	metrics={"supply_call_microseconds":game.supply_microseconds,"owner":game.reports["owner:measure"]}
	phase("observers")
	if not await wait_for(func():return game.reports.has("watcher_a:measure") and game.reports.has("watcher_b:measure")): return
	metrics.observers=[game.reports["watcher_a:measure"],game.reports["watcher_b:measure"]]
	phase("finish");await create_timer(.3).timeout
func client() -> void:
	if not await wait_for(func():return is_instance_valid(game.local_player) and game.players.size()==3): return
	game.local_player.set_physics_process(false);game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not await wait_for(func():return game.phase=="warmup"): return
	if role=="owner":
		if not await wait_for(func():return game.local_player.ammo.fal==0 and game.local_player.position.z<0): return
		metrics.baseline=describe(await frames(120));report("warmup")
	if not await wait_for(func():return game.phase=="measure"): return
	game.inventory_calls=0;game.equipment_calls=0;game.hud_calls=0
	if role=="owner":
		var actor:=game.local_player as GamePlayer;var mesh_id:=actor.weapon_root.get_child(0).get_instance_id();var nodes:=get_node_count()
		var started:=Time.get_ticks_msec();game.request_supplies(actor)
		if not await wait_for(func():return actor.ammo.fal==30 and actor.grenades==2,5): return
		metrics.response_ms=Time.get_ticks_msec()-started;metrics.inventory_calls=game.inventory_calls;metrics.equipment_calls=game.equipment_calls;metrics.hud_calls_until_response=game.hud_calls
		check(actor.weapon_root.get_child(0).get_instance_id()==mesh_id,"replenishing does not replace the equipped weapon mesh")
		metrics.after=describe(await frames(120));metrics.nodes_delta=get_node_count()-nodes
		report("measure",metrics)
	else:
		if not await wait_for(func():return game.phase=="observers"): return
		report("measure",{"inventory_calls":game.inventory_calls,"equipment_calls":game.equipment_calls,"hud_calls":game.hud_calls})
	await wait_for(func():return game.phase=="finish")
