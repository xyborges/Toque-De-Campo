extends SceneTree
var label := "before"
var selected := "all"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-pass="): label = arg.trim_prefix("--capture-pass=")
		if arg.begins_with("--capture-map="): selected = arg.trim_prefix("--capture-map=")
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens/extended-look/"+label))
	for kind: String in ["office","desert","naval"]:
		if selected!="all" and selected!=kind: continue
		var branch: Node3D
		var scene: Node
		var started := Time.get_ticks_msec()
		if kind=="naval":
			var world := NavalWorld.new()
			root.add_child(world)
			world.build(true,17391)
			world.update_time(0)
			branch = world
			scene = world
		else:
			var game = load("res://scenes/main.tscn").instantiate()
			game.set_meta("test_mode",true)
			root.add_child(game)
			game.start_offline("training" if kind=="office" else "desert")
			game.set_physics_process(false)
			for actor in game.players.values():
				actor.set_physics_process(false)
				actor.hide()
			game.hud_layer.hide()
			game.menu_layer.hide()
			game.music_player.stop()
			branch = game.world_root
			scene = game
		var build_ms := Time.get_ticks_msec()-started
		var camera := Camera3D.new()
		branch.add_child(camera)
		camera.fov = 72
		camera.far = 4500
		camera.current = true
		var views := _views(kind)
		if label=="after": views.append_array(_details(kind))
		var results: Array = []
		for view: Dictionary in views:
			camera.global_position = view.position
			camera.look_at(view.target)
			if kind=="naval": branch.update_time(float(view.get("time",0)))
			await create_timer(0.9).timeout
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screens/extended-look/%s/%s-%s.png" % [label,kind,view.id]))
			var frames := 0
			var sample_start := Time.get_ticks_msec()
			var end := sample_start+800
			while Time.get_ticks_msec()<end:
				await process_frame
				frames += 1
			results.append({"view":view.id,"fps":frames/maxf(.001,(Time.get_ticks_msec()-sample_start)/1000.0),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("ENVIRONMENT_CAPTURE ",kind," ",JSON.stringify({"build_ms":build_ms,"views":results}))
		FileAccess.open("res://tests/screens/extended-look/%s/%s-metrics.json" % [label,kind],FileAccess.WRITE).store_string(JSON.stringify({"build_ms":build_ms,"views":results}))
		scene.queue_free()
		await process_frame
		await process_frame
	quit()
func _views(kind: String) -> Array:
	if kind=="office": return [
		{"id":"warehouse","position":Vector3(9,5.2,5),"target":Vector3(-1,2,-14)},
		{"id":"annex","position":Vector3(0,2,-30),"target":Vector3(0,1.7,-43)},
		{"id":"workstations","position":Vector3(-7,1.7,5),"target":Vector3(4,1.1,-1)}]
	if kind=="desert": return [
		{"id":"outpost","position":Vector3(36,18,42),"target":Vector3(0,2,-7)},
		{"id":"ground","position":Vector3(14,1.75,12),"target":Vector3(0,1.5,-6)},
		{"id":"dunes","position":Vector3(65,13,85),"target":Vector3(-30,3,-45)}]
	return [
		{"id":"lighthouse","position":Vector3(-105,42,-35),"target":Vector3(-260,12,-180)},
		{"id":"archipelago","position":Vector3(-400,130,650),"target":Vector3(-40,10,0)},
		{"id":"harbor","position":Vector3(535,32,-310),"target":Vector3(430,6,-410)}]

func _details(kind: String) -> Array:
	if kind=="office":
		var result: Array = []
		for id in OfficeMap.ROOM_CENTERS:
			var p: Vector3 = OfficeMap.ROOM_CENTERS[id]
			result.append({"id":id,"position":p+Vector3(4.7,1.8,2.0),"target":p+Vector3(-2,1.1,-1)})
		return result
	if kind=="desert": return [
		{"id":"communications","position":Vector3(-2.8,1.8,-3.8),"target":Vector3(-6,1.1,-8)},
		{"id":"logistics","position":Vector3(-33,2.4,-3),"target":Vector3(-19,1.4,-17)},
		{"id":"maintenance","position":Vector3(31,2.7,-8),"target":Vector3(24,1.5,-13)}]
	return [
		{"id":"radar","position":Vector3(385,60,315),"target":Vector3(290,25,230)},
		{"id":"fortification","position":Vector3(-305,60,485),"target":Vector3(-390,22,390)},
		{"id":"night","position":Vector3(-150,35,-75),"target":Vector3(-260,25,-180),"time":450.0},
		{"id":"seabed","position":Vector3(750,-35,750),"target":Vector3(720,-70,700)}]
