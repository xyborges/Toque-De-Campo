extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := find_button(child,label)
		if found: return found
	return null
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await process_frame
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await process_frame
	var credentials := NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var result: Dictionary = await game.main_accounts.sign_in("login",str(credentials.host.username),str(credentials.host.password))
	check(bool(result.get("ok",false)),"real account authenticated without exposing credentials")
	game.main_menu.show_page("shop")
	await process_frame
	await click(find_button(game.main_menu.pages.shop,"VER EMBARCAÇÕES"))
	await create_timer(1.8).timeout
	var naval: NavalMode = game.naval_mode
	check(not naval.focus.stack.is_empty() and naval.focus.stack.back()==naval.pages.shop,"ship shop remains open after session restoration")
	check(not naval.pages.browse.is_visible_in_tree(),"ship shop never redirects to rooms")
	if DisplayServer.get_name()!="headless":
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screens/menu-fixes-shop.png"))
	# Exercise the reported button, rather than calling the close handler.
	await click(find_button(naval.pages.shop,"VOLTAR"))
	await process_frame
	await process_frame
	check(not is_instance_valid(game.naval_mode) and game.menu_layer.visible,"single shop page Back restores the actual main menu")
	check(game.mode=="menu" and game.main_menu.pages.shop.is_visible_in_tree(),"menu retains its selected shop page")
	game.open_naval_page("settings")
	await create_timer(1.8).timeout
	naval = game.naval_mode
	check(naval.focus.stack.back()==naval.pages.settings,"naval options survive session restoration")
	for slider: HSlider in naval.pages.settings.find_children("*","HSlider",true,false):
		slider.value=slider.min_value
		slider.value=slider.max_value
		await process_frame
	check(is_instance_valid(naval) and naval.pages.settings.is_visible_in_tree(),"changing sensitivity and volume without a match keeps options alive")
	await click(find_button(naval.pages.settings,"VOLTAR"))
	await process_frame
	await process_frame
	check(not is_instance_valid(game.naval_mode) and game.menu_layer.visible,"naval options Back returns to main menu without a gray screen")
	game.open_naval()
	await create_timer(1.8).timeout
	check(game.naval_mode.focus.stack.back()==game.naval_mode.pages.home,"normal naval entry opens home")
	var music: GameMenuMusic = game.music_player
	music.set_login_active(false)
	# Include the original menu track: this was the logout-specific failure.
	music.stream = music.original
	music.play()
	await create_timer(0.2).timeout
	var stream_before := music.stream
	var position := music.get_playback_position()
	await game.naval_mode._logout_account()
	await create_timer(1.0).timeout
	check(music.stream==stream_before and music.get_playback_position()>position,"real logout preserves music stream and advancing playback")
	if DisplayServer.get_name()!="headless":
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screens/menu-fixes-login.png"))
	game.queue_free()
	await process_frame
	NavalStorage.write_json("res://tests/naval-menu-fixes-results.json",{"checks":checks,"failures":failures})
	quit(0 if failures.is_empty() else 1)
