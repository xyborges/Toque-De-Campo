extends SceneTree

# Presentation QA only. This deliberately freezes gameplay and moves a test
# camera; screenshots do not validate frame pacing, hitboxes, or PvP fairness.
const VISUALS=preload("res://modes/war/scripts/vegetation_visuals.gd")
const BIOME=preload("res://modes/war/scripts/biome_map.gd")
const ZONES:={"field":Vector2(-150,-650),"burnt":Vector2(-80,-155)}
const DISTANCES:=[3.0,20.0,60.0]
const MODES:={"day":0.0,"night":490.0,"rain":210.0,"thermal":0.0}
var game: WarGame
var manager: Node3D
var camera: Camera3D
var cycle: WarDayNight
var weather: WarWeather
var thermal: WarThermal
var output_dir:=""
var errors: Array[String]=[]
var captures: Array[Dictionary]=[]
var quick:=false

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	errors.append(message)
	push_error(message)

func wait_frames(count: int) -> void:
	for i in count: await process_frame

func wait_stream(seconds:=25.0) -> bool:
	# The manager creates the streamer in _process, then the streamer slices
	# a cell into a fixed number of candidates per frame. Do not photograph
	# an unfinished queue as though the quality preset were fully populated.
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		await process_frame
		if int(manager.level)==0: return true
		var stream: Node3D=manager.streamer
		if is_instance_valid(stream) and stream.initialised and stream.pending.is_empty() and stream.retired.is_empty():
			await wait_frames(5)
			return true
	return false

func _find_or_create_manager() -> bool:
	for node in get_nodes_in_group("war_vegetation_visuals"):
		if game.world_root.is_ancestor_of(node): manager=node;break
	if not is_instance_valid(manager):
		manager=VISUALS.new();game.world_root.add_child(manager);manager.initialize(game.world_root)
	if not manager.available: return false
	return bool(manager.apply_level(0))

func configure_mode(mode: String) -> void:
	# Seed 0, t=210 is a real peak shower from WarWeather.intensity().
	# The ordinary WarWeather node updates its own GPUParticles3D, roof test,
	# ocean material, and the vegetation manager reads this same clock.
	game.weather_seed=0;WarWeather.seed=0;game.war_clock=float(MODES[mode])
	cycle.apply_time(game.war_clock,true)
	thermal.set_enabled(mode=="thermal")
	await create_timer(1.3 if mode=="rain" else .35).timeout
	await wait_frames(5)

func position_camera(target: Vector2,distance: float) -> Dictionary:
	var focus:=WarTerrain.point(target.x,target.y)+Vector3.UP*.22
	var point:=WarTerrain.point(target.x,target.y+distance)+Vector3.UP*1.8
	camera.global_position=point;camera.look_at(focus);camera.make_current()
	return {"target":focus,"camera":point,"horizontal_distance_m":distance,"actual_distance_m":point.distance_to(focus)}

func capture(variant: String,zone: String,mode: String,distance: float,pose: Dictionary) -> void:
	var ready: bool=await wait_stream()
	if not ready: fail("stream did not settle: "+variant+"/"+zone+"/"+mode+"/"+str(distance))
	await RenderingServer.frame_post_draw
	var screenshot:=root.get_texture().get_image()
	var filename:="%s-%s-%s-%dm.png"%[variant,zone,mode,int(distance)]
	var path:=output_dir.path_join(filename)
	var saved:=screenshot.save_png(ProjectSettings.globalize_path(path))==OK
	if not saved: fail("could not save "+filename)
	var rain_strength:=WarWeather.intensity(game.war_clock)
	var rain_node:=weather.rain
	var emitting:=is_instance_valid(rain_node) and rain_node.emitting
	if mode=="rain" and (rain_strength<.9 or not emitting or weather.roofed): fail("real rain was not active in "+filename)
	var stream: Node3D=manager.streamer
	var stats: Dictionary={}
	if is_instance_valid(stream):
		var patches:=0
		for node: Variant in stream.cells.values():
			if is_instance_valid(node) and node.multimesh: patches+=node.multimesh.instance_count
		stats={"cells":stream.cells.size(),"patches":patches,"level":stream.level,"pending":stream.pending.size()}
	# Sample luminance only as a coarse aid for finding empty/black captures.
	# This is not a material measurement or thermal temperature validation.
	var sum:=0.0;var samples:=0
	for x in range(0,screenshot.get_width(),maxi(1,screenshot.get_width()/32)):
		for y in range(0,screenshot.get_height(),maxi(1,screenshot.get_height()/18)):
			var colour:=screenshot.get_pixel(x,y);sum+=colour.r*.2126+colour.g*.7152+colour.b*.0722;samples+=1
	captures.append({"file":ProjectSettings.globalize_path(path),"saved":saved,"variant":variant,"level":manager.level,"zone":zone,"mode":mode,"clock":game.war_clock,"weather_seed":game.weather_seed,"daylight":cycle.daylight,"rain_intensity":rain_strength,"rain_emitting":emitting,"rain_amount_ratio":rain_node.amount_ratio if is_instance_valid(rain_node) else 0.,"roofed":weather.roofed,"thermal":thermal.enabled,"stream_ready":ready,"stream":stats,"pose":pose,"size":str(screenshot.get_size()),"mean_sampled_luminance":sum/maxi(1,samples)})

func run() -> void:
	quick="--quick" in OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless": push_error("Capture requires graphical rendering");quit(1);return
	seed(193);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	var stamp:=Time.get_datetime_string_from_system().replace(":","-")
	output_dir="res://work/nova-visual-captures/run-"+stamp
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))!=OK: push_error("capture directory unavailable");quit(2);return
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: fail("world not ready");finish();return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(3).timeout
	game.ui_focus.close_all();game.hud_layer.hide();game.menu_layer.hide();game.loading_screen.hide()
	# Freeze gameplay so current/new photographs see the same actors and clock.
	game.set_physics_process(false);game.set_process(false)
	if is_instance_valid(game.bot_director): game.bot_director.stop()
	for actor: GamePlayer in game.players.values(): actor.set_physics_process(false);actor.set_process(false)
	if is_instance_valid(game.vehicle_system): game.vehicle_system.set_physics_process(false);game.vehicle_system.set_process(false)
	cycle=game.world_root.find_child("WarDayNight",true,false) as WarDayNight
	weather=game.world_root.find_child("WarWeather",true,false) as WarWeather
	thermal=game.vehicle_system.get_node_or_null("Thermal") as WarThermal
	if not is_instance_valid(cycle) or not is_instance_valid(weather) or not is_instance_valid(thermal): fail("real day/night, weather or thermal system missing");finish();return
	cycle.set_process(false)
	camera=Camera3D.new();camera.far=3000.;camera.fov=70.;root.add_child(camera);camera.make_current()
	if not _find_or_create_manager(): fail("vegetation manager unavailable");finish();return
	var biome=BIOME.new()
	if not biome.load_map() or biome.region(ZONES.field)!=0 or biome.region(ZONES.burnt)!=1: fail("capture targets no longer match painted field/burnt regions");finish();return
	for variant: String in ["current","new"]:
		if not manager.apply_level(0 if variant=="current" else 2): fail("could not apply "+variant);continue
		for zone: String in ZONES:
			if quick and zone!="field": continue
			for distance: float in DISTANCES:
				if quick and distance!=20.: continue
				var pose:=position_camera(ZONES[zone],distance)
				for mode: String in MODES:
					if quick and mode!="day": continue
					await configure_mode(mode)
					await capture(variant,zone,mode,distance,pose)
	thermal.set_enabled(false);manager.apply_level(0);await wait_frames(5)
	if int(manager.level)!=0 or not manager.ground_slots.is_empty() or not manager.legacy_slots.is_empty(): fail("manager rollback incomplete after capture")
	finish()

func finish() -> void:
	var report:={"ok":errors.is_empty() and captures.size()==(2 if quick else 48),"errors":errors,"count":captures.size(),"captures":captures,"renderer":RenderingServer.get_current_rendering_method(),"presentation_only":true,"performance_validated":false,"scope":"Frozen local WarGame, actual day/night, WarWeather rain particles and WarThermal. Scripted cameras and snapshots are not gameplay, multiplayer or performance validation.","thermal_limit":"The existing thermal overlay maps scene luminance to grey and replaces actor/vehicle materials. Grass remains a lit scene surface; this does not validate physical heat, night readability, or player spotting fairness."}
	var path:=output_dir.path_join("report.json")
	NavalStorage.write_json(path,report)
	print("NOVA_VISUAL_CAPTURES ",JSON.stringify({"ok":report.ok,"count":captures.size(),"errors":errors,"report":ProjectSettings.globalize_path(path)}))
	if is_instance_valid(game): game.queue_free()
	if is_instance_valid(camera): camera.queue_free()
	await process_frame;quit(0 if report.ok else 1)
