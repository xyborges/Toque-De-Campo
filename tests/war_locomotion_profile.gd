extends SceneTree
var game: WarGame
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+30000
	while (not game.join_ready or not is_instance_valid(game.local_player)) and Time.get_ticks_msec()<until: await process_frame
	game.request_deploy(0,"soldier","fal","rpg","base")
	while game.players.size()<12 and Time.get_ticks_msec()<until: await process_frame
	game.bot_director.stop();game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	var actors: Array[WarPlayer]=[]
	for actor: WarPlayer in game.players.values():
		actor.set_physics_process(false);actor.remove_meta("war_bot");actor.is_local=false;actor.velocity=Vector3.ZERO
		actor.position=WarTerrain.point((actors.size()%6)*4-10,-210+(actors.size()/6)*10)+Vector3.UP*.15
		actor.locomotion.reset(actor);actors.append(actor)
	await physics_frame
	var result: Dictionary={}
	for method in ["advance","pose_body","pose_weapon"]:
		var total:=0;var max_us:=0
		for frame in 100:
			var clock:=Time.get_ticks_usec()
			for actor in actors:
				if method=="advance": actor.locomotion.advance(actor,1./60)
				else: actor.locomotion.call(method,actor)
			var elapsed:=Time.get_ticks_usec()-clock
			total+=elapsed;max_us=maxi(max_us,elapsed)
			await physics_frame
		result[method]={"us_per_frame_12actors":float(total)/100,"max_us":max_us}
	NavalStorage.write_json("res://work/war-locomotion-profile.json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await process_frame;await process_frame;quit()
