extends SceneTree
var game: WarGame
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.title="Toque de Campo — Teste interativo de lunetas"
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: push_error("interactive world did not load");return
	var loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",0);loadout.optic="scope4x"
	game.request_deploy(0,"soldier","fal","stinger","base",loadout)
	await create_timer(.5).timeout
	game.ui_focus.close_all();game.loading_screen.hide();game.local_player.camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.local_player.mouse_captured=true
	# No process/physics/input disabling: this is ordinary offline gameplay.
	game.closed.connect(func(): quit())
