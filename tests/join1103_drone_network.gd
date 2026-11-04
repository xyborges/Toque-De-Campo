extends SceneTree
var role:="server"
var game: WarGame
var checks:=0
var failures: Array[String]=[]
const EXPECTED:=["qa_a","qa_c","qa_d"]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func wait_for(test: Callable,seconds:=30.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		if test.call():return true
		await process_frame
	return false
func run() -> void:
	game=load("res://tests/join1103_drone_network_fixture.gd").new()
	game.set_meta("war_test",true);game.set_meta("war_visual_preview",role!="server");game.set_meta("war_host",role=="server")
	game.set("hold_first",role=="bravo");root.add_child(game);game.address_input.text="127.0.0.1";game.nickname_input.text=role
	print("DRONE_QA_BOOT ",role," online=",game.online," status=",game.status_label.text," testing=",game.testing," port=",game._network_port())
	if role=="server":
		for key in ["qa_a","qa_b","qa_c"]:game.call("spawn_drone",key)
		check(await wait_for(func():return game.get("drone_results").size()==2),"two real clients completed and reported their drone sets")
		check(game.get("qa").get("mutated_while_loading",false),"authority removed an old drone and added another during held client admission")
		var ids: Array=game.vehicle_system.drones.keys();ids.sort()
		check(ids==EXPECTED,"authority retains expected three drones after mutation")
		for label in ["alpha","bravo"]:
			var value: Dictionary=game.get("drone_results").get(label,{})
			check(value.get("ids",[])==ids,"client "+label+" drone set matches authority")
			check(int(value.get("largest",99))<=2,"client "+label+" creates at most two drones per confirmed batch")
		check(int(game.get("drone_results").get("bravo",{}).get("calls",0))>=3,"late client receives multiple additive drone baseline batches")
		check(game.loading_baselines.is_empty() and game.players.size()==2,"all admissions finished without leaking loading transfers")
		game._broadcast("qa_done",[]);await create_timer(.5).timeout
	else:
		if role=="bravo":await create_timer(2.).timeout
		await game.join_game("pvp")
		check(await wait_for(func():return game.join_ready),"client admission completed "+role)
		check(await wait_for(func():
			var ids: Array=game.vehicle_system.drones.keys();ids.sort();return ids==EXPECTED
		),"client retains every expected drone including prior batches "+role)
		var ids: Array=game.vehicle_system.drones.keys();ids.sort()
		game.rpc_id(1,"qa_drone_result",role,ids,int(game.vehicle_system.get("largest_batch")),int(game.vehicle_system.get("baseline_calls")))
		check(await wait_for(func():return game.get_meta("done",false)),"healthy client remains connected through mutation "+role)
	var result:={"role":role,"checks":checks,"failures":failures}
	NavalStorage.write_json("res://work/join1103-drone-network-"+role+".json",result);print(JSON.stringify(result))
	game.closing=true;game.online=false;game.multiplayer.multiplayer_peer.close();game.free();await process_frame;quit(0 if failures.is_empty() else 1)

