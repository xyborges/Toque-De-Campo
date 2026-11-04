extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func run() -> void:
	Engine.max_fps=60
	var world:=Node3D.new();root.add_child(world)
	WarWorld.atmosphere(world)
	var cycle:=world.get_node("WarDayNight") as WarDayNight
	check(is_instance_valid(cycle) and GameDayNight.PERIOD==840,"War reuses the fourteen-minute shared day/night cycle")
	cycle.set_process(false)
	cycle.apply_time(40,true)
	var day_color:=cycle.environment.fog_light_color;var day_energy:=cycle.sun.light_energy
	check(cycle.daylight==1 and day_energy>.6,"noon has War's overcast daylight and directional light")
	cycle.apply_time(280,true)
	check(cycle.daylight==0 and cycle.sun.light_energy==0 and cycle.moon.light_energy>.09,"midnight disables sunlight and enables moon fill")
	check(cycle.environment.ambient_light_energy>=.159 and cycle.environment.fog_light_color!=day_color,"night retains the configured ambient minimum and changes the atmosphere")
	cycle.apply_time(520,true)
	check(cycle.daylight==1 and is_equal_approx(cycle.sun.light_energy,day_energy),"a complete 480-second period returns to the same noon")
	var copy_world:=Node3D.new();root.add_child(copy_world);WarWorld.atmosphere(copy_world)
	var other:=copy_world.get_node("WarDayNight") as WarDayNight;other.set_process(false)
	for time_value in [0.,100.,200.,300.,400.,480.,935.]:
		cycle.apply_time(time_value,true);other.apply_time(time_value,true)
		check(is_equal_approx(cycle.daylight,other.daylight) and cycle.sun.rotation.is_equal_approx(other.sun.rotation) and cycle.environment.fog_light_color.is_equal_approx(other.environment.fog_light_color),"same replicated War clock produces the same illumination: "+str(time_value))
	other.environment.sky=null;copy_world.queue_free()
	var camera:=Camera3D.new();camera.fov=70;camera.far=1600;camera.position=Vector3(0,3,20);world.add_child(camera);camera.make_current()
	var visuals:=WarProjectiles.new();world.add_child(visuals);visuals.set_physics_process(false)
	check(visuals.available.size()==WarProjectiles.LIMIT and visuals.active_slots.is_empty(),"larger heavy tracers retain the existing fixed projectile pool")
	for index in 3:
		var distance_value: float=[50.,300.,900.][index]
		var point:=camera.global_position+Vector3((index-1)*distance_value*.25,0,-distance_value)
		var shot: Dictionary={"weapon":"tank","position":point,"active":true,"history":[point+Vector3(-distance_value*.03,0,6),point],"fade":.075,"velocity":Vector3(0,0,-570)}
		var before:=shot.duplicate(true)
		visuals._draw_round(index,shot,camera)
		check(shot==before,"visibility cannot change a shell's physics state: "+str(distance_value)+" m")
		var expected:=WarProjectiles.projectile_width(camera,point,3.2,.1,4.0)
		check(expected>=.1 and expected<=4.0,"shell width has bounded screen-size compensation: "+str(distance_value)+" m")
		if visuals.cores:
			check(is_equal_approx(visuals.cores.get_instance_transform(index).basis.x.length()*.05,expected),"rendered core uses the compensated width: "+str(distance_value)+" m")
	var point:=camera.global_position+Vector3(0,0,-300)
	var normal:=WarProjectiles.projectile_width(camera,point,3.2,.1,4.0);camera.fov=17
	check(WarProjectiles.projectile_width(camera,point,3.2,.1,4.0)<normal,"zoom reduces world width instead of magnifying a giant tracer")
	camera.fov=70
	if DisplayServer.get_name()!="headless":
		visuals.cores.visible_instance_count=3;visuals.trails.visible_instance_count=3*WarProjectiles.TRAIL_SEGMENTS
		cycle.apply_time(40,true);await process_frame;await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://work/war163-shells-day.png")
		cycle.apply_time(280,true);await process_frame;await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://work/war163-shells-night.png")
	check(is_equal_approx(GameWeaponAudio.profile("fal").db,-10.5) and is_equal_approx(GameWeaponAudio.profile("sniper").db,-7.5),"weapon sounds gain a modest 1.5 dB while retaining the shared limiter")
	cycle.environment.sky=null;WarWorld.cloud_noise=null
	world.queue_free();await process_frame;await process_frame;await create_timer(.3).timeout
	var report: Dictionary={"checks":checks,"failures":failures,"fixture":"Real atmosphere and rendering pools; clock and shell positions controlled for repeatable checks. Does not simulate a human combat session."}
	NavalStorage.write_json("res://tests/war163-environment-projectiles-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
