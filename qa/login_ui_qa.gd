extends Node
var mode: NavalMode
var game: Node3D
var failures: Array[String] = []
var checks := 0
var username := "qa_ui_"+NavalCatalog.uid().left(12)
var secret := NavalCatalog.uid()+"Az!"
var timeout_port := 0
var report_path := "res://tests/login-ui-results.json"
var screens_path := "res://tests/screens"
var requests := 0
var fps_samples: Array[float] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--login-report="): report_path = arg.trim_prefix("--login-report=")
		if arg.begins_with("--login-screens="): screens_path = arg.trim_prefix("--login-screens=")
		if arg.begins_with("--login-timeout-port="): timeout_port = int(arg.trim_prefix("--login-timeout-port="))
	run.call_deferred()
func check(value: bool,label: String) -> void:
	checks += 1
	var progress := FileAccess.open(report_path+".progress",FileAccess.WRITE)
	if progress: progress.store_string(str(checks)+" "+label)
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures.append(label)
func wait_for(condition: Callable,seconds := 12.0) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await get_tree().process_frame
		if condition.call(): return true
	return false
func key(code: Key,unicode_value := 0,shift := false) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.shift_pressed = shift
		event.pressed = down
		get_tree().root.push_input(event,true)
	await get_tree().process_frame
func type_text(text: String) -> void:
	for c in text: await key(KEY_NONE,c.unicode_at(0))
func click(item: Control) -> void:
	mode.login_screen.scroll.ensure_control_visible(item)
	await get_tree().process_frame
	var point := item.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_tree().root.push_input(event,true)
	await get_tree().process_frame
func capture(name: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path(screens_path.path_join(name+".png")))
func fill(screen: GameLoginScreen,pass_value: String) -> void:
	screen.username.text = username
	screen.password.text = pass_value
	screen.confirmation.text = pass_value
func run() -> void:
	mode = NavalMode.new()
	get_tree().root.add_child(mode)
	check(await wait_for(func(): return mode.login_screen.is_visible_in_tree() and not mode.account_busy),"login opens and accepts input")
	var screen := mode.login_screen
	mode.accounts_service.connection_state.connect(func(_result: int,_code: int): requests += 1)
	await click(screen.username)
	await type_text(username)
	check(screen.username.text==username,"username accepts typed keyboard input")
	await key(KEY_TAB)
	check(get_tree().root.gui_get_focus_owner()==screen.password,"Tab moves from username to password")
	await type_text(secret)
	check(screen.password.text==secret and screen.password.secret,"password accepts input and is hidden")
	await key(KEY_TAB,0,true)
	check(get_tree().root.gui_get_focus_owner()==screen.username,"Shift Tab returns to username")
	await click(screen.eye_button)
	check(not screen.password.secret and screen.password.text==secret,"eye reveals password without erasing it")
	await click(screen.eye_button)
	check(screen.password.secret and screen.password.text==secret,"eye hides password again")
	screen.username.clear()
	screen.password.text = secret
	var count := requests
	await click(screen.submit_button)
	check(not screen.user_error.text.is_empty() and screen.password.text==secret and requests==count,"empty validation stays local and preserves secret")
	screen.username.text = username
	screen.password.clear()
	await click(screen.submit_button)
	check(not screen.password_error.text.is_empty() and not screen.busy,"empty password has inline validation")
	fill(screen,secret)
	await click(screen.password)
	await key(KEY_ENTER)
	check(screen.busy and screen.submit_button.disabled,"Enter submits and blocks duplicate requests")
	for i in range(3): await click(screen.submit_button)
	check(await wait_for(func(): return not screen.busy),"incorrect credentials return to usable form")
	check(requests==count+1 and screen.state==GameLoginScreen.State.AUTH_ERROR and screen.password.text.is_empty() and screen.username.text==username,"real rejected login clears secret and preserves username; one request only")
	var backdrop_id := screen.scenery.get_instance_id()
	await click(screen.switch_button)
	check(await wait_for(func(): return not screen.busy),"registration transition completes")
	check(screen.register_mode and screen.confirm_group.is_visible_in_tree() and screen.scenery.get_instance_id()==backdrop_id,"registration reuses backdrop and one active form")
	fill(screen,secret)
	screen.confirmation.text = "different"
	count = requests
	await click(screen.submit_button)
	check(not screen.confirm_error.text.is_empty() and requests==count and screen.password.text==secret,"mismatching confirmation is local and does not clear password")
	fill(screen,secret)
	screen.username.text = "invalid name"
	await click(screen.submit_button)
	check(await wait_for(func(): return not screen.busy),"invalid registration receives real server refusal")
	check(screen.state==GameLoginScreen.State.AUTH_ERROR and screen.status.text.contains("Nome"),"registration shows permitted backend validation")
	fill(screen,secret)
	await click(screen.submit_button)
	check(await wait_for(func(): return mode.focus.stack.back()==mode.pages.home),"real registration transitions only after valid server response")
	check(mode.accounts_service.profile.username==username and int(mode.accounts_service.profile.coins)==0,"actual new account has zero coins and correct profile")
	check(screen.scenery.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden login stops rendering the 3D background")
	await mode._logout_account()
	await get_tree().create_timer(0.35).timeout
	check(screen.is_visible_in_tree() and not screen.register_mode and mode.accounts_service.token.is_empty(),"logout returns to login and revokes local session")
	# Real failed transport, then a real timeout from a TCP fixture withholding TLS.
	var original_url := mode.accounts_service.api_url
	mode.accounts_service.api_url = "https://127.0.0.1:1/accounts/api.php"
	fill(screen,secret)
	await click(screen.submit_button)
	check(await wait_for(func(): return not screen.busy),"unreachable service does not lock the form")
	check(screen.state==GameLoginScreen.State.CONNECTION_ERROR and (screen.status.text.contains("conectar") or screen.status.text.contains("demorou")),"transport failure gives a friendly connection message")
	if timeout_port>0:
		mode.accounts_service.api_url = "https://127.0.0.1:"+str(timeout_port)+"/accounts/api.php"
		fill(screen,secret)
		await click(screen.submit_button)
		check(await wait_for(func(): return not screen.busy,11),"real HTTP timeout releases the form")
		check(screen.status.text.contains("demorou") and screen.state==GameLoginScreen.State.CONNECTION_ERROR,"real timeout has a distinct message")
	else: check(false,"timeout fixture required")
	mode.accounts_service.api_url = original_url
	fill(screen,secret)
	screen.remember.button_pressed = false
	await click(screen.submit_button)
	check(await wait_for(func(): return mode.focus.stack.back()==mode.pages.home),"valid login works by mouse")
	var transient := NavalAccounts.new()
	get_tree().root.add_child(transient)
	check(transient.token.is_empty(),"unchecked remember option does not persist the session")
	transient.queue_free()
	await mode._logout_account()
	fill(screen,secret)
	screen.remember.button_pressed = true
	await click(screen.submit_button)
	check(await wait_for(func(): return mode.focus.stack.back()==mode.pages.home),"persistent login accepted")
	mode.queue_free()
	await get_tree().process_frame
	mode = NavalMode.new()
	get_tree().root.add_child(mode)
	check(await wait_for(func(): return not mode.focus.stack.is_empty() and mode.focus.stack.back()==mode.pages.home),"saved session is validated remotely and restores account")
	check(mode.accounts_service.profile.username==username,"restored session loads the same real profile")
	# Invalidate a cached token; cached profile alone must not open the menu.
	var good_token := mode.accounts_service.token
	mode.accounts_service.token = "0".repeat(64)
	mode.accounts_service.save_session()
	mode.queue_free()
	await get_tree().process_frame
	mode = NavalMode.new()
	get_tree().root.add_child(mode)
	check(await wait_for(func(): return mode.login_screen.state==GameLoginScreen.State.AUTH_ERROR),"expired session returns to login")
	check(mode.focus.stack.back()==mode.pages.account and mode.login_status.text.contains("expirou"),"cached profile cannot bypass server validation")
	# Revoke the temporary valid token left by the invalidation fixture.
	mode.accounts_service.token = good_token
	await mode.accounts_service.logout()
	screen = mode.login_screen
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.borderless = true
	get_tree().root.position = DisplayServer.screen_get_position(0)
	for resolution in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_size = resolution
		await get_tree().create_timer(0.2).timeout
		mode.focus._resize_panels()
		await get_tree().process_frame
		check(screen.size.is_equal_approx(Vector2(resolution)) and screen.scroll.size.x>=300 and screen.connection.get_global_rect().end.y<=resolution.y,"responsive form "+str(resolution))
		await capture("login-"+str(resolution.x)+"x"+str(resolution.y))
		await click(screen.switch_button)
		await get_tree().create_timer(0.35).timeout
		screen.scroll.ensure_control_visible(screen.submit_button)
		await get_tree().process_frame
		check(screen.submit_button.get_global_rect().get_center().y<=resolution.y,"registration submit reachable "+str(resolution))
		await key(KEY_ESCAPE)
		await get_tree().create_timer(0.35).timeout
	check(not screen.register_mode and screen.is_visible_in_tree(),"Escape returns to login without exposing gameplay")
	for i in range(120):
		await get_tree().process_frame
		fps_samples.append(get_tree().root.get_process_delta_time())
	fill(screen,secret)
	await click(screen.submit_button)
	await wait_for(func(): return mode.focus.stack.back()==mode.pages.home)
	mode.queue_free()
	await get_tree().process_frame
	# Test the actual application entry flow, not merely the isolated form.
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	check(await wait_for(func(): return not is_instance_valid(game.naval_mode) and game.menu_layer.visible),"game startup validates saved session before revealing main menu")
	check(game.profile.nickname==username and int(game.profile.coins)==0 and game.account_summary.text.contains(username),"main menu displays the authenticated account")
	await capture("login-main-menu")
	var playback: float = game.music_player.get_playback_position()
	game.open_naval()
	await wait_for(func(): return is_instance_valid(game.naval_mode) and game.naval_mode.focus.stack.back()==game.naval_mode.pages.home)
	check(game.naval_mode.accounts_service==game.main_accounts and game.naval_mode.menu_music==game.music_player and game.music_player.get_playback_position()>=playback,"modes share account session and continuous menu music")
	game.naval_mode._close_mode()
	await get_tree().process_frame
	game._main_logout()
	check(await wait_for(func(): return is_instance_valid(game.naval_mode) and game.naval_mode.login_screen.state==GameLoginScreen.State.LOGIN_IDLE),"main menu logout opens the new login gate")
	check(not game.menu_layer.visible and game.main_accounts.token.is_empty(),"logout cannot expose the main menu behind the form")
	await capture("login-final")
	game.queue_free()
	await get_tree().process_frame
	var total := 0.0
	for delta in fps_samples: total += delta
	var result := {"checks":checks,"failures":failures,"average_idle_fps":fps_samples.size()/maxf(total,0.001),"account_username":username,"real_server":"192.168.101.24","timeout_fixture":timeout_port>0}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result))
	for i in range(4): await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
