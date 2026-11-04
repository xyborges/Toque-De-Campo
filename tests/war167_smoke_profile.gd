extends SceneTree
var game: WarGame
var label:="before"
var results: Array[Dictionary]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	run.call_deferred()
func run() -> void:
	Engine.max_fps=0;root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN
	await process_frame;await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	game.combat_effects=WarEffects.new();game.world_root.add_child(game.combat_effects)
	var manager:=game.vehicle_system as WarVehicles;manager.set_process(false);manager.set_physics_process(false)
	var actor:=game.local_player as WarPlayer;actor.apply_identity(1,"soldier");game.members[1].team=1;game.members[2].team=0
	var vehicle:=manager.vehicles.v_bmp2 as WarVehicle
	vehicle.position=Vector3.ZERO;vehicle.rotation=Vector3.ZERO;vehicle.heading=0;vehicle.show();vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id
	manager.last_controlled="";manager._process(.1);manager.vehicle_view.zoom_level=2
	var stages: Array[String]=["idle_normal","fire_normal","idle_thermal","fire_thermal"]
	for stage in stages:
		var thermal_mode:=stage.contains("thermal");var firing:=stage.begins_with("fire")
		if manager.thermal!=thermal_mode: manager.toggle_thermal()
		var samples: Array[float]=[];var process_samples: Array[float]=[];var physics_samples: Array[float]=[]
		var until:=Time.get_ticks_usec()+6000000;var started:=Time.get_ticks_usec();var previous:=started;var shot_at:=0;var sequence:=0;var max_puffs:=0
		while Time.get_ticks_usec()<until:
			await process_frame
			var now:=Time.get_ticks_usec();var dt:=float(now-previous)*.000001;previous=now
			manager._process(dt)
			if firing and now>shot_at:
				sequence+=1;shot_at=now+240000
				# Use the same replicated accepted-shot presentation as the game.
				manager._present_shot(1,vehicle.muzzle.global_position,-vehicle.muzzle.global_basis.z,"autocannon",stage+str(sequence))
			if now-started>1000000:
				samples.append(dt*1000);process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			var active:=0
			for data: Dictionary in game.combat_effects.slots:
				if not data.is_empty(): active+=1
			max_puffs=maxi(max_puffs,active)
		samples.sort();var total:=0.
		for value in samples: total+=value
		var worst:=0.;var n:=maxi(1,int(ceilf(samples.size()*.01)))
		for index in n: worst+=samples[samples.size()-1-index]
		var result: Dictionary={"stage":stage,"frames":samples.size(),"mean_ms":total/samples.size(),"fps":1000/(total/samples.size()),"one_percent_low":1000/(worst/n),"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples.back(),"max_active_puffs":max_puffs,"resolution":root.size,"gpu":RenderingServer.get_video_adapter_name()}
		results.append(result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await process_frame;await create_timer(.4).timeout
	NavalStorage.write_json("res://tests/war167-smoke-"+label+".json",{"stages":results,"label":label,"native":true});quit(0)
