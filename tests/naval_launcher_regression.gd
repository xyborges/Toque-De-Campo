extends SceneTree
var failed: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func test(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failed.append(label)
func frames() -> void:
	for i in 3: await process_frame
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await frames()
	game.main_menu.show_page("shop")
	game.open_naval_page("shop")
	await frames()
	var naval: NavalMode=game.naval_mode
	test(naval!=null and naval.launch_subpage=="shop","direct shop tracks launcher")
	# Production opens this route after account/hosting restoration; test only UI semantics here.
	naval._open("shop")
	test(naval.focus.stack.size()==2 and naval.focus.stack.back()==naval.pages.shop,"direct shop route opens correct screen")
	naval._go_back()
	await frames()
	test(game.naval_mode==null and game.main_menu.pages.shop.is_visible_in_tree(),"direct shop back restores main shop")
	game.open_naval_page("settings")
	await frames()
	naval=game.naval_mode
	test(naval.launch_subpage=="settings" and naval.focus.stack.back()==naval.shared_settings,"direct settings opens")
	naval.shared_settings.leave()
	await frames()
	test(game.naval_mode==null and game.menu_layer.visible,"direct settings button back restores main")
	game.open_naval_page("settings")
	await frames()
	naval=game.naval_mode
	naval._go_back()
	await frames()
	test(game.naval_mode==null and game.menu_layer.visible,"direct settings ESC restores main")
	game.open_naval_page("shop")
	await frames()
	naval=game.naval_mode
	naval._open("fleet")
	test(naval.launch_subpage.is_empty(),"navigation to a different naval route forgets external launcher")
	naval._go_back()
	test(naval.focus.stack.size()==1 and naval.focus.stack.back()==naval.pages.home,"after moving inside naval, back returns to naval home")
	naval._go_back()
	await frames()
	test(game.naval_mode==null,"naval home back restores main")
	game.queue_free()
	await process_frame
	print("NAVAL_LAUNCHER_FAILURES=",failed.size()," ",failed)
	quit(0 if failed.is_empty() else 1)
