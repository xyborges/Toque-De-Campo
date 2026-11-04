extends SceneTree
var game: WarGame
var actors: Array[WarPlayer]=[]
var samples: Array[float]=[]
var process_times: Array[float]=[]
var phase:=0.
var measuring:=false
var last_frame:=0
var viewport: SubViewport
func _initialize() -> void: run.call_deferred()
func _process(delta: float) -> bool:
	var now:=Time.get_ticks_usec()
	if measuring and last_frame>0:
		samples.append((now-last_frame)*.001);process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
	last_frame=now;phase+=delta
	for actor in actors:
		if not is_instance_valid(actor): continue
		actor.pitch=sin(phase*.4+actor.peer_id)*.18;actor.lean=sin(phase*.6+actor.peer_id)*.75
		actor.locomotion.moving=.7;actor.locomotion.phase=phase*3.;actor.locomotion.speed=2.
		if actor.reload_left>0:
			actor.reload_left=maxf(0,actor.reload_left-delta)
			if actor.reload_left<=0: actor.complete_reload()
		elif int(phase/8)>int(actor.get_meta("bench_reload_cycle",0)):
			actor.set_meta("bench_reload_cycle",int(phase/8));actor.ammo[actor.weapon_id]=0;actor.reserves[actor.weapon_id]=100;actor.begin_reload(actor.weapon_id,float(GameWeapons.ITEMS[actor.weapon_id].reload))
		actor._update_weapon_pose();actor._animate_walk()
	return false
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.own_world_3d=true;root.add_child(viewport)
	var display:=TextureRect.new();display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
	game=load("res://tests/war_optics_fixture.gd").new();viewport.add_child(game);game.vehicle_system.set_process(false)
	game.local_player.position=Vector3(-200,0,0);game.players[2].position=Vector3(-200,0,10)
	for i in 12:
		var actor: WarPlayer=game.make_actor(100+i,false,i%2,"soldier",Vector3((i%6)*1.8-4.5,0,-(i/6)*3.))
		actor.owned=GameWeapons.INFANTRY_IDS.duplicate();actor.loadout=actor.owned.duplicate();actor.weapon_id="fal" if i%2==0 else "glock";actor._refresh_weapon();actor._update_view();actor.ammo[actor.weapon_id]=0;actor.begin_reload(actor.weapon_id,float(GameWeapons.ITEMS[actor.weapon_id].reload))
		actors.append(actor)
	for i in 9:
		var id: String=WarPrefabFactory.ITEMS.keys()[i]
		WarMapContent.instantiate(game.world_root,WarPrefabFactory.PATH+id+".tscn",Vector3((i%3)*9.-9.,0,-10.-(i/3)*10),true)
	var camera:=Camera3D.new();game.world_root.add_child(camera);camera.position=Vector3(9,5,12);camera.look_at(Vector3(0,1,-5));camera.current=true
	await create_timer(4.).timeout;measuring=true;last_frame=Time.get_ticks_usec();await create_timer(8.).timeout;measuring=false
	samples.sort();var sum:=0.
	for value in samples: sum+=value
	var tail:=0.;var count:=maxi(1,int(samples.size()*.01))
	for i in count: tail+=samples[samples.size()-1-i]
	var result: Dictionary={"scope":"isolated 12 animated soldier models, both firearm reloads, lean poses and nine library props; not a full 12-player network match","resolution":str(viewport.size),"gpu":RenderingServer.get_video_adapter_name(),"frames":samples.size(),"average_fps":1000./(sum/samples.size()),"one_percent_low_fps":1000./(tail/count),"p95_frame_ms":samples[mini(samples.size()-1,int(samples.size()*.95))],"peak_frame_ms":samples[-1],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	viewport.get_texture().get_image().save_png("res://work/pose189-benchmark-after.png")
	NavalStorage.write_json("res://tests/pose189-benchmark-after-results.json",result);print(JSON.stringify(result));actors.clear();viewport.queue_free();display.queue_free();await create_timer(.4).timeout;quit()

