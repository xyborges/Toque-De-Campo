extends SceneTree

var role:="server"
var game: WarGame
var failures: Array[String]=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()

func wait_for(test: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if test.call(): return true
	return false

func validate(report: Dictionary) -> void:
	if report.get("heights",[])!=[150,620]: failures.append("fracture heights")
	if not bool(report.get("source_intact",false)): failures.append("source power grid changed")
	if str(report.get("signature","")).is_empty(): failures.append("missing real circuit signature")
	if int(report.get("source_poles",0))<3: failures.append("missing source circuit")
	var power: Array=report.get("power",[])
	if power.size()<3 or not bool(power[0]) or bool(power[1]) or bool(power[2]): failures.append("mirrored circuit continuity")
	if not report.get("errors",[]).is_empty(): failures.append_array(report.errors)

func run() -> void:
	game=load("res://tests/war_real_pole_fixture.gd").new()
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		if not await wait_for(func():return is_instance_valid(game.world_root) and game.online and is_instance_valid(game.power_grid),120.): failures.append("server world")
		elif not await wait_for(func():return game.pole_acks.size()==2,150.): failures.append("first and late client acknowledgements")
		else:
			var server_report: Dictionary=game.pole_report();validate(server_report)
			for peer_report: Dictionary in game.pole_acks.values():
				validate(peer_report)
				if peer_report.signature!=server_report.signature: failures.append("different real circuit signatures")
			game._broadcast("qa_phase",["real_pole_complete"]);await create_timer(.8).timeout
	else:
		if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and is_instance_valid(game.power_grid),130.): failures.append("client joined")
		elif not game.init_pole_mirror(): failures.append("client mirror")
		else:
			game.rpc_id(1,"qa_real_poles_ready")
			if not await wait_for(func():return game.phase=="real_pole_complete",150.): failures.append("authority completion")
			else: validate(game.pole_report())
	var report: Dictionary=game.pole_report() if is_instance_valid(game.power_grid) else {}
	var file:=FileAccess.open("res://work/real-pole-"+role+".json",FileAccess.WRITE)
	if file==null: push_error("real pole report unavailable");quit(2);return
	file.store_string(JSON.stringify({"role":role,"failures":failures,"report":report,"graphical":DisplayServer.get_name()!="headless","scope":"real WarPowerGrid circuit/positions copied into a test-only noncolliding mirror; production grid untouched; experimental RPC"}));file.close()
	print("REAL_POLE_RESULT ",role," ",failures)
	quit(0 if failures.is_empty() else 1)
