extends "res://tests/war_frame_pacing_network.gd"

## Reuse the existing real ENet/28-bot server+client QA without modifying
## its movement, authority, collision and vehicle validation. LOD diagnostics
## report from the observing client's non-authoritative animation scheduler.
var display_checked:=false
var benchmark_display: Dictionary={}
var benchmark_focused_frames:=0
var benchmark_unfocused_frames:=0

func _configure_display() -> void:
	if role!="client":return
	# Target exactly the visual quality/resolution requested for GTX 1650.
	GameOptions.ensure()
	GameOptions.values.merge(GameOptions.PRESETS["Médio"],true)
	GameOptions.values["scale"]=1.0
	GameOptions.values["fps"]=0
	GameOptions.values["vsync"]=false
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size=Vector2i(1920,1080)
	root.scaling_3d_scale=1.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0

func sample() -> void:
	if role=="client" and not display_checked:
		display_checked=true
		# Base networking fixture normally enables VSync; override at first
		# render callback, before any measured frame, for uncapped A/B.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		root.scaling_3d_scale=1.0
		var rendered: Vector2i=root.get_texture().get_size()
		var fullscreen:=DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		var screen_size:=DisplayServer.screen_get_size()
		benchmark_display={"window_mode":DisplayServer.window_get_mode(),
			"window_size":DisplayServer.window_get_size(),
			"screen_size":screen_size,"rendered":rendered,
			"scale":root.scaling_3d_scale,
			"quality":GameOptions.values.get("lod_quality"),
			"renderer":RenderingServer.get_current_rendering_method(),
			"fullscreen":fullscreen}
		print("WAR_CLIENT_LOD_BENCH_DISPLAY ",JSON.stringify(benchmark_display))
		if not fullscreen or screen_size!=Vector2i(1920,1080) or rendered!=Vector2i(1920,1080) or not is_equal_approx(root.scaling_3d_scale,1.0) or int(GameOptions.values.get("lod_quality",-1))!=1:
			failures.append("Benchmark not 1920x1080 fullscreen/100pct medium; refuse FPS comparison")
	if role=="client" and recording:
		if DisplayServer.window_is_focused():benchmark_focused_frames+=1
		else:benchmark_unfocused_frames+=1
	super.sample()

func run() -> void:
	_configure_display()
	await super.run()
	benchmark_display["focused_frames"]=benchmark_focused_frames
	benchmark_display["unfocused_frames"]=benchmark_unfocused_frames
	print("WAR_CLIENT_LOD_NETWORK ",JSON.stringify({
		"role":role,"failures":failures,
		"client_lod":WarClientVisualLOD.diagnostics(),
		"display":benchmark_display,
		"players":game.players.size() if is_instance_valid(game) else 0
	}))
