extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(condition: bool,label: String) -> void:
	print(("PASS " if condition else "FAIL ")+label)
	if not condition: failures.append(label)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await create_timer(0.8).timeout
	check(game.music_player.playing and game.music_player.volume_db > -25,"main menu plays provided music")
	check(game.music_player.stream is AudioStreamMP3 and not game.music_player.stream.loop,"menu music advances playlist at song completion")
	game.start_offline("training")
	await create_timer(0.8).timeout
	check(not game.music_player.playing,"music fades out in offline combat")
	game.show_menu()
	game.open_naval()
	await create_timer(0.8).timeout
	check(game.naval_mode.menu_music==game.music_player and game.music_player.playing,"naval owns music without duplicate playback")
	game.naval_mode._close_mode()
	await create_timer(0.8).timeout
	check(game.music_player.playing,"main menu music resumes on return")
	FileAccess.open("res://tests/menu-music-results.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"checks":5}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

