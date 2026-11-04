extends SceneTree

# Actual War world, original grass only. The old palette is an explicit
# reference, not a parallel gameplay implementation. No FPS claim is made.
const POINTS:={"field":Vector2(-150,-650),"burnt":Vector2(-80,-155),"road":Vector2(-400,25.*sin(-400.*.009))}
const TIMES:={"day":0.,"night":490.}
var game: WarGame
var cycle: WarDayNight
var camera: Camera3D
var captures: Array[Dictionary]=[]
var errors: Array[String]=[]
var output_dir:=""
var lights_before:=0

func _initialize() -> void: run.call_deferred()

func check(value: bool,label: String) -> void:
	if not value: errors.append(label);push_error(label)

func light_count() -> int:
	return game.world_root.find_children("*","Light3D",true,false).size()

func palette(seconds: float,legacy: bool) -> void:
	game.war_clock=seconds;cycle.apply_time(seconds,true)
	if legacy:
		var daylight:=cycle.daylight
		cycle.moon.light_energy=.22*(1-daylight);cycle.moon.light_color=Color("6c8eb5")
		cycle.environment.ambient_light_energy=lerpf(.30,.34,daylight)
		cycle.environment.ambient_light_color=Color("7a8b9e").lerp(Color("a9b3b8"),daylight)
		var sky:=cycle.environment.sky.sky_material as ProceduralSkyMaterial
		sky.sky_top_color=Color("09131f").lerp(Color("5f6d75"),daylight)
		sky.sky_horizon_color=Color("253343").lerp(Color("9ba5a3"),daylight)
		sky.ground_horizon_color=sky.sky_horizon_color
		sky.ground_bottom_color=Color("111c29").lerp(Color("46483f"),daylight)
		cycle.fog_color=Color("243747").lerp(Color("8e999b"),daylight)
		cycle.environment.fog_light_color=cycle.fog_color
	var weather:=game.world_root.find_child("WarWeather",true,false) as WarWeather
	if is_instance_valid(weather) and is_instance_valid(weather.ocean):
		var sea:=weather.ocean.material_override as ShaderMaterial
		if sea: sea.set_shader_parameter("daylight",cycle.daylight)

func ground_metrics(screenshot: Image) -> Dictionary:
	# Fixed lower-central ROI reduces sky/HUD contamination. Scene pixels can
	# still include props; these are display values, not a lux measurement.
	var values: Array[float]=[];var total:=0.
	for x in range(int(screenshot.get_width()*.15),int(screenshot.get_width()*.85),8):
		for y in range(int(screenshot.get_height()*.55),int(screenshot.get_height()*.90),8):
			var colour:=screenshot.get_pixel(x,y)
			var value:=colour.r*.2126+colour.g*.7152+colour.b*.0722
			values.append(value);total+=value
	values.sort()
	return {"mean":total/maxi(1,values.size()),"median":values[values.size()/2],"p10":values[int(values.size()*.1)],"p90":values[int(values.size()*.9)],"samples":values.size()}

func capture(zone: String,mode: String,legacy: bool) -> void:
	palette(float(TIMES[mode]),legacy)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var screenshot:=root.get_texture().get_image()
	var variant:="before" if legacy else "after"
	var path:=output_dir.path_join("%s-%s-%s.png"%[variant,zone,mode])
	check(screenshot.save_png(path)==OK,"save "+path)
	check(light_count()==lights_before,"no lights added by time/palette change")
	captures.append({"zone":zone,"mode":mode,"variant":variant,"file":path,"roi":ground_metrics(screenshot),"ambient_energy":cycle.environment.ambient_light_energy,"moon_energy":cycle.moon.light_energy,"daylight":cycle.daylight,"light_count":light_count(),"moon_shadows":cycle.moon.shadow_enabled,"sun_shadows":cycle.sun.shadow_enabled})

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Night capture needs a graphical renderer");quit(1);return
	seed(193);Engine.max_fps=60
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	output_dir=ProjectSettings.globalize_path("res://work/night-visibility-"+Time.get_datetime_string_from_system().replace(":","-"))
	check(DirAccess.make_dir_recursive_absolute(output_dir)==OK,"capture directory")
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: check(false,"world ready");await finish();return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(2.).timeout
	game.ui_focus.close_all();game.hud_layer.hide();game.menu_layer.hide();game.loading_screen.hide()
	# Freeze gameplay/weather/power-grid animation so A/B use the same scene.
	game.set_process(false);game.set_physics_process(false)
	for node: Node in game.world_root.find_children("*","Node",true,false): node.set_process(false);node.set_physics_process(false)
	if is_instance_valid(game.bot_director): game.bot_director.stop()
	cycle=game.world_root.find_child("WarDayNight",true,false) as WarDayNight
	check(is_instance_valid(cycle),"real War day/night exists")
	if not is_instance_valid(cycle): await finish();return
	check(GameDayNight.PERIOD==840.,"14-minute cycle preserved")
	check(game.world_root.get_node_or_null("VegetationVisuals")==null,"new grass not enabled in normal War")
	lights_before=light_count()
	camera=Camera3D.new();camera.far=3000.;camera.fov=70.;root.add_child(camera)
	for zone: String in POINTS:
		var at: Vector2=POINTS[zone]
		camera.global_position=WarTerrain.point(at.x,at.y+12.)+Vector3.UP*1.8
		camera.look_at(WarTerrain.point(at.x,at.y)+Vector3.UP*.2);camera.make_current()
		for mode: String in TIMES:
			await capture(zone,mode,true);await capture(zone,mode,false)
			var before: Dictionary=captures[-2].roi;var after: Dictionary=captures[-1].roi
			if mode=="night": check(float(after.median)>float(before.median),"night ground becomes more readable: "+zone)
			else: check(absf(float(after.mean)-float(before.mean))<.01,"day rendering preserved: "+zone)
	check(captures.size()==12,"all before/after captures")
	await finish()

func finish() -> void:
	var report:={"ok":errors.is_empty(),"errors":errors,"captures":captures,"cycle_seconds":GameDayNight.PERIOD,"scope":"Frozen real War world, original vegetation, day/night before/after images. Lower-central display luminance is descriptive; not an FPS, network or human visibility certification."}
	NavalStorage.write_json(output_dir.path_join("report.json"),report)
	print("NIGHT_VISIBILITY ",JSON.stringify({"ok":report.ok,"errors":errors,"captures":captures.size(),"report":output_dir.path_join("report.json")}))
	if is_instance_valid(game): game.queue_free()
	if is_instance_valid(camera): camera.queue_free()
	await process_frame;quit(0 if report.ok else 1)
