extends SceneTree
var failures: Array[String]=[]
var captures: Array[String]=[]
var measurements: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("e4d6a7");world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1,0);camera.far=2500;camera.make_current()
	var effects:=GameCombatVisuals.new();world.add_child(effects)
	var visual:=effects.acquire("sniper")
	for fov in [70.,7.]:
		camera.fov=fov
		for distance in [100.,600.,1000.]:
			var initial:=Vector3.FORWARD*607.6
			var flight: float=distance/607.6
			var end:=GameBulletPhysics.advance(Vector3(0,1,0),initial,12,.008,flight)
			var previous:=GameBulletPhysics.advance(Vector3(0,1,0),initial,12,.008,maxf(0,flight-1./60))
			camera.look_at(end.position)
			effects.draw(visual,previous.position,end.position,camera)
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			var image:=root.get_texture().get_image();var point:=camera.unproject_position(end.position)*Vector2(image.get_size())/root.get_visible_rect().size
			var colored:=0
			for x in range(int(point.x)-5,int(point.x)+6):
				for y in range(int(point.y)-5,int(point.y)+6):
					var color:=image.get_pixel(x,y)
					if color.b>color.g*1.25 and color.r>.35: colored+=1
			measurements.append({"fov":fov,"distance":distance,"visible_pixels":colored,"tip_error":visual.node.global_position.distance_to(end.position)})
			if colored<1 or visual.node.global_position.distance_to(end.position)>.001: failures.append("tracer not visible/aligned at"+str(distance)+"m fov"+str(fov))
			if distance==600:
				var path:="res://work/tracer171-day-"+str(int(fov))+".png";image.save_png(path);captures.append(path)
	var result:={"failures":failures,"measurements":measurements,"captures":captures,"method":"Native rendered pixels against a bright daytime background. Tip and trail use shared ballistic positions; no separate tracer simulation."}
	NavalStorage.write_json("res://tests/tracer171-results.json",result);print(JSON.stringify(result));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
