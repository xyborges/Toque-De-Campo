extends SceneTree
var world: NavalWorld
var camera: Camera3D
var shots: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	world = NavalWorld.new()
	root.add_child(world)
	world.build(true,19)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.position = Vector3(0,125,180)
	camera.look_at(Vector3.ZERO)
	for i in range(6):
		var ship := NavalShip.new()
		world.add_child(ship)
		ship.build("heavy",i,"qa"+str(i),"Carga")
		ship.position = Vector3((i%3-1)*35,0,(i/3)*45-20)
	for i in range(192):
		var visual := NavalProjectileVisual.new()
		world.add_child(visual)
		visual.build()
		visual.setup("lightMG")
		var angle := i*2.399
		var pos := Vector3(sin(angle)*float(15+i%75),3.0+i%40,cos(angle)*float(15+i%75))
		var shot := {"origin":pos-Vector3(0,0,-600)*0.25,"velocity":Vector3(0,0,-600),"gravity":12.0,"weapon":"lightMG","time":0.0,"visual":visual}
		shots.append(shot)
	for i in range(128): world.effect(Vector3(sin(i*3.1)*65,1.0+i%10,cos(i*2.4)*55),Color("ffb26b"),3.0,15.0)
	var elapsed := 0.0
	var samples: Array[float] = []
	var draw_calls := 0.0
	while elapsed<8.0:
		await process_frame
		var delta := root.get_process_delta_time()
		elapsed += delta
		world.update_time(elapsed)
		for shot in shots: shot.visual.update_shot(shot,0.25+fmod(elapsed,0.02),camera.global_position)
		if elapsed>2.0:
			samples.append(delta)
			draw_calls = maxf(draw_calls,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var total := 0.0
	for sample in samples: total += sample
	var report := {"ships":6,"projectiles":192,"effects_cap":128,"average_fps":samples.size()/maxf(total,0.001),"maximum_draw_calls":draw_calls,"active_effects":world.effects.size()}
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/naval-load.png")
	FileAccess.open("res://tests/naval-load-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit()
