extends SceneTree

var failures: Array[String] = []
var checks := 0
var game: Node3D
var below_clicks := 0
var above_clicks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, name_value: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + name_value)
	if not value: failures.append(name_value)

func click(control: Control) -> void:
	var position_value := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position_value
	motion.global_position = position_value
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position_value
		event.global_position = position_value
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
	await process_frame

func key(window: Window, code: Key, text_code := 0) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = text_code
		event.pressed = pressed
		window.push_input(event,true)

func run() -> void:
	root.title = "Toque de Campo · Teste de foco e menus"
	game = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	game._static_box(game.world_root,"Floor",Vector3(0,-0.25,0),Vector3(100,0.4,100),Color.GRAY)
	var actor: GamePlayer = game._spawn_player(1,true,false,Vector3.ZERO)
	var base: PanelContainer = game._modal_card("CAMADA INFERIOR")
	var content := base.find_child("Content",true,false) as VBoxContainer
	var bottom := Button.new()
	bottom.text = "NÃO DEVE RECEBER O CLIQUE"
	bottom.pressed.connect(func(): below_clicks += 1)
	content.add_child(bottom)
	var top: PanelContainer = game._modal_card("CAMADA SUPERIOR")
	var top_content := top.find_child("Content",true,false) as VBoxContainer
	var edit := LineEdit.new()
	edit.placeholder_text = "Digite aqui"
	top_content.add_child(edit)
	var upper := Button.new()
	upper.text = "CLIQUE SOMENTE AQUI"
	upper.pressed.connect(func(): above_clicks += 1)
	top_content.add_child(upper)
	game.ui_focus.open(base)
	for i in range(5): game.ui_focus.open(top)
	await process_frame
	await process_frame
	check(game.ui_focus.stack.size() == 2,"rapid open never duplicates modal")
	await click(upper)
	check(above_clicks == 1 and below_clicks == 0,"one real click only reaches upper control")
	check(actor.shot_sequence == 0,"UI click did not fire weapon")
	edit.grab_focus()
	key(root,KEY_W,119)
	Input.action_press("move_forward")
	for i in range(5): await physics_frame
	Input.action_release("move_forward")
	check(edit.text == "w","text field receives keyboard")
	check(Vector2(actor.velocity.x,actor.velocity.z).length() < 0.001,"typing cannot move actor")
	var before := actor.pitch
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(70,55)
	root.push_input(event,true)
	check(actor.pitch == before,"menu mouse cannot turn camera")
	game.ui_focus.open(game.settings_panel)
	await process_frame
	await process_frame
	var settings := game.settings_panel.find_child("Content",true,false) as VBoxContainer
	var option: OptionButton
	for child in settings.get_children():
		if child is OptionButton: option = child
	await click(option)
	var popup := option.get_popup()
	check(popup.visible,"native dropdown opens above modal")
	if "--native-input" in OS.get_cmdline_user_args():
		var deadline := Time.get_ticks_msec() + 90000
		while option.selected != 1 and Time.get_ticks_msec() < deadline: await process_frame
	else:
		popup.index_pressed.emit(1)
		popup.hide()
	await process_frame
	await process_frame
	check(option.selected == 1,"dropdown action selects requested resolution")
	check(not popup.visible and below_clicks == 0,"dropdown closes without clicking through")
	key(root,KEY_ESCAPE)
	await process_frame
	check(game.ui_focus.stack.back() == top,"Escape closes only the top modal")
	game.ui_focus.close_all()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"menu close leaves pointer free")
	# Purchases are idempotent even when an operation is replayed.
	actor.owned.erase("sniper")
	actor.kills = 40
	game.profile.owned.erase("sniper")
	game.profile.coins = 30000
	game.purchase_pending = "same-operation"
	game._server_purchase(1,"same-operation","sniper")
	var balance: int = game.profile.coins
	game._server_purchase(1,"same-operation","sniper")
	check(balance == 29300 and game.profile.coins == 29300,"purchase replay never charges twice")
	var owned_count := 0
	for id in actor.owned:
		if id == "sniper": owned_count += 1
	check(owned_count == 1,"purchase grants exactly one weapon")
	game.ui_focus.open(game.pause_panel)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/menu-focus-verified.png")
	FileAccess.open("res://tests/ui-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	print("UI_CHECKS=",checks," FAILURES=",failures.size())
	game.show_menu()
	game.queue_free()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
