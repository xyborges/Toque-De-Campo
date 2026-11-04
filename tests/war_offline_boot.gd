extends SceneTree

var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func wait_for(condition: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())
func check(ok: bool,label_text: String) -> void:
	print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	check(await wait_for(func():return is_instance_valid(app.war_mode) and app.war_mode.join_ready,35),"normal executable entry opens offline deployment without login or a server")
	if is_instance_valid(app.war_mode) and app.war_mode.join_ready:
		var game=app.war_mode
		check(game.offline_operation and not game.online and game.network_api.multiplayer_peer is OfflineMultiplayerPeer,"executable uses a local authority with no network transport")
		game.request_deploy(0,"soldier","fal","rpg","base")
		check(await wait_for(func():return game.players.size()==12,15),"normal executable operation deploys one human and eleven bots")
		check(not app.boot_login_pending and not app.menu_layer.visible,"login and main menu do not cover the offline operation")
		if DisplayServer.get_name()!="headless":
			await create_timer(1).timeout;RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("toque-war-offline-pack.png"))
	app.queue_free();await process_frame;await process_frame
	print("WAR_OFFLINE_BOOT "+JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
