extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=NavalWorld.new();root.add_child(world);world.build(true,43)
	var camera:=NavalCamera.new();world.add_child(camera);camera.position=Vector3(0,12,40);camera.look_at(Vector3(0,0,-80));camera.current=true
	var ship:=NavalShip.new();world.add_child(ship);ship.build("light",2,"test","Navio");ship.position=Vector3(0,0,-160)
	var numbers:=GameDamageNumbers.new();world.add_child(numbers)
	for time in [0.,240.]:
		world.update_time(time)
		if not is_equal_approx(world.clock,time): failures.append("wave clock changed")
		if not is_equal_approx(float(world.water.material_override.get_shader_parameter("ocean_time")),time): failures.append("water clock mismatch")
		await create_timer(.25).timeout
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/naval-154-"+("day" if time==0 else "night")+".png")
	world.update_time(0)
	for fov in [70.,14.]:
		camera.fov=fov
		numbers.show_damage("zoom:"+str(fov),ship.global_position+Vector3.UP*6,55,false,true)
		await create_timer(.12).timeout
		var label: Label3D=numbers.active.back().label
		var top: Vector3=label.global_position+camera.global_basis.y*label.font_size*label.pixel_size*label.scale.y
		var pixels: float=camera.unproject_position(top).distance_to(camera.unproject_position(label.global_position))
		if absf(pixels-18)>.2: failures.append("naval damage number size "+str(pixels))
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/naval-154-damage-"+str(int(fov))+".png")
	world.queue_free();await process_frame
	var result: Dictionary={"failures":failures,"cycle":480,"damage_pixels":18};NavalStorage.write_json("res://tests/naval-visual-154-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
