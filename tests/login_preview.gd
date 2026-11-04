extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var mode := NavalMode.new()
	root.add_child(mode)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/login-desktop.png")
	mode.login_screen.change_form(true)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/register-desktop.png")
	print("AUTH_PREVIEW_READY ",mode.login_screen.size," state=",mode.login_screen.state)
	mode.queue_free()
	await process_frame
	quit()
