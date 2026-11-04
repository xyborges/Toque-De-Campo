extends SceneTree
var game: Node3D
var failures: Array[String] = []
var checks := 0
var folder := "res://tests/screens/ui"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(label: String) -> void:
	await create_timer(0.28).timeout
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(label+".png")))
func click(b: Control) -> void:
	if b.focus_mode!=Control.FOCUS_NONE: b.grab_focus()
	await process_frame
	var point := b.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await create_timer(0.4).timeout
	check(game.mode=="menu","initial menu does not start a match")
	for id in ["play","arsenal","person","shop","settings"]:
		await click(game.main_menu.tabs[id])
		check(game.main_menu.pages[id].is_visible_in_tree(),"tab opens "+id)
		check(game.mode=="menu" and game.world_root==null,"tab preserves menu "+id)
		await capture("main-"+id)
	game.main_menu.show_page("play")
	for id in ["office","naval","desert"]:
		check(ResourceLoader.exists("res://assets/ui/modes/%s.jpg" % id),"local photograph "+id)
	for resolution in [Vector2i(800,600),Vector2i(1920,1080),Vector2i(1280,800)]:
		root.size = resolution
		await create_timer(0.3).timeout
		check(game.main_menu.play_button.get_global_rect().end.x<=root.get_visible_rect().size.x+1,"deploy inside viewport "+str(resolution))
		await capture("main-play-%dx%d" % [resolution.x,resolution.y])
	game.ui_focus.open(game.loading_screen)
	game.loading_screen.detail.text = "Conectando ao servidor..."
	check(game.loading_screen.is_visible_in_tree(),"shared loading screen opens")
	await capture("loading")
	game.ui_focus.close_all()

	for id in ["office","naval","desert"]:
		await click(game.main_menu.mode_buttons[id])
		check(game.mode=="menu" and game.main_menu.selected_mode==id,"mode card selects without launching "+id)
	await click(game.main_menu.play_cards.get_child(0).get_child(0))
	check(game.main_menu.selected_mode=="office" and game.mode=="menu","photograph selects mode without launching")
	check(game.main_menu.theme==GameUI.THEME,"shared menu theme resource")
	check(GameUI.THEME.get_stylebox("fill","ProgressBar").bg_color==FieldTheme.ACCENT,"health bars use login accent")
	game.ui_focus.open(game.settings_panel)
	await capture("infantry-settings")
	game.ui_focus.close_all()
	game.main_menu._select_mode("office")
	await click(game.main_menu.play_button)
	await create_timer(0.7).timeout
	check(game.mode=="training" and is_instance_valid(game.local_player),"explicit deploy starts offline")
	check(game.infantry_hud.theme==GameUI.THEME,"infantry HUD theme")
	check(game.ammo_label.text.contains("FAL"),"HUD shows equipped weapon")
	await capture("offline-hud")
	game.local_player.ammo.fal = 8
	game.local_player.start_reload()
	game.update_hud()
	check(game.infantry_hud.reload_bar.visible,"actual reload progress is visible")
	var before: float = game.infantry_hud.reload_bar.value
	await create_timer(0.3).timeout
	check(game.infantry_hud.reload_bar.value>before,"reload indicator advances with actual timer")
	await capture("offline-reload")
	game.ui_focus.open(game.pause_panel)
	await capture("offline-pause")
	game._toggle_shop()
	await capture("infantry-shop")
	game.show_menu()
	await process_frame
	game.menu_layer.hide()
	var naval := NavalMode.new()
	root.add_child(naval)
	await process_frame
	naval.network.account = {"username":"Visual QA","id":"visual","coins":9000,"owned":["light","heavy"],"selected":"heavy"}
	for id in ["home","create","browse","fleet","shop","join","settings","pause"]:
		if id in ["fleet","shop"]: naval._refresh_fleet(id)
		if id=="browse": naval._refresh_rooms()
		naval.focus.close_all()
		naval._open(id)
		check(naval.pages[id].is_visible_in_tree(),"naval opens "+id)
		await capture("naval-"+id)
	check(naval.focus.shield.theme==GameUI.THEME,"naval shares login theme")
	naval.network.room = {"id":"abc","name":"Águas abertas","members":[{"peer":1,"name":"Comandante","ship":"heavy"},{"peer":2,"name":"Convidado","ship":"light"}],"limit":6,"owner":1,"state":"WAITING"}
	naval._refresh_lobby()
	naval.focus.close_all()
	naval._open("lobby")
	await capture("naval-lobby")
	var login := naval.login_screen
	check(login.theme==GameUI.THEME,"login consumes identical shared theme")
	check(GameLoginScreen.ACCENT==Color("b7cca1") and GameLoginScreen.INK==Color("e7ede8"),"login palette preserved")
	naval.focus.close_all()
	naval._open("account")
	await capture("login-preserved")
	naval.queue_free()
	game.queue_free()
	await process_frame
	var file := FileAccess.open("res://tests/ui-standardization-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"photographs":3}))
	file.close()
	quit(0 if failures.is_empty() else 1)
