extends SceneTree
var label:="before"
var map_name:="desert"
var game: Node3D
var clock:=0.0
var fire_clock:=0.0
var sequence:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--map="): map_name=arg.trim_prefix("--map=")
	run.call_deferred()
func run() -> void:
	root.borderless=true;root.size=Vector2i(1920,1080);root.position=Vector2i.ZERO
	game=load("res://tests/combat_render_before_fixture.gd" if label=="before" else "res://tests/combat_render_benchmark_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.start_offline("training" if map_name=="office" else "desert")
	game.local_player.set_physics_process(false)
	game.local_player.global_position=Vector3(0,0,3 if map_name=="office" else 20)
	game.local_player.weapon_id="fal";game.local_player._refresh_weapon();game.local_player._update_view()
	game.ui_focus.close_all();game.third_person=false;game.local_player._update_view()
	await create_timer(2).timeout
	var reports: Array=[]
	for settings in [["quiet",0,true,true],["one",1,true,true],["one_no_flash",1,false,true],["one_no_trace",1,true,false],["six",6,true,true],["six_no_fx",6,false,false]]:
		game.flash_enabled=settings[2];game.traces_enabled=settings[3]
		var samples: Array[float]=[];var processing: Array[float]=[];var physics: Array[float]=[]
		var draws:=0.;var triangles:=0.;var nodes:=0.;var physical:=0;var last:=Time.get_ticks_usec()
		var begin:=Time.get_ticks_msec();fire_clock=0
		while Time.get_ticks_msec()-begin<6000:
			await process_frame
			var now:=Time.get_ticks_usec();var delta: float=(now-last)*.000001;last=now;clock+=delta
			fire_clock+=delta
			if settings[1]>0 and fire_clock>=.11:
				fire_clock-=.11
				for index in settings[1]:
					sequence+=1
					var origin: Vector3=game.local_player.get_muzzle_position()+Vector3((index-settings[1]/2.)*.5,0,0)
					game._spawn_projectile(1,origin,Vector3.FORWARD,"fal",false,true,"1:1:"+str(sequence))
					game._muzzle_flash(origin);game.play_weapon_sound("fal",origin,index+1)
				game.local_player.present_fire()
			if Time.get_ticks_msec()-begin<1000: continue
			samples.append(delta);processing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			draws=maxf(draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));triangles=maxf(triangles,Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));nodes=maxf(nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT));physical=maxi(physical,game.projectiles.size())
		var sorted:=samples.duplicate();sorted.sort();var slow:=maxi(1,ceili(samples.size()*.01));var sum_slow:=0.
		for i in slow: sum_slow+=sorted[sorted.size()-1-i]
		var result: Dictionary={"case":settings[0],"frames":samples.size(),"fps":samples.size()/samples.reduce(func(a,b):return a+b,0.),"one_percent_low":slow/sum_slow,"frame_mean_ms":samples.reduce(func(a,b):return a+b,0.)/samples.size()*1000,"worst_ms":sorted.back()*1000,"process_ms":processing.reduce(func(a,b):return a+b,0.)/processing.size(),"physics_ms":physics.reduce(func(a,b):return a+b,0.)/physics.size(),"draw_calls":draws,"triangles":triangles,"nodes":nodes,"projectiles":physical}
		reports.append(result);print(JSON.stringify(result))
		NavalStorage.write_json("res://tests/combat-render-"+label+"-"+map_name+".json",{"label":label,"map":map_name,"results":reports,"gpu":RenderingServer.get_video_adapter_name(),"size":root.size})
	NavalStorage.write_json("res://tests/combat-render-"+label+"-"+map_name+".json",{"label":label,"map":map_name,"results":reports,"gpu":RenderingServer.get_video_adapter_name(),"size":root.size})
	game.show_menu();game.queue_free();await process_frame;quit()
