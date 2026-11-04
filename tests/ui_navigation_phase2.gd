extends SceneTree
var failed: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failed.append(label)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await process_frame
	await process_frame
	game.ui_focus.open(game.settings_panel)
	game.ui_focus.back()
	check(not game.ui_focus.blocked(),"main settings back")
	game.ui_focus.open(game.pause_panel)
	game.pause_panel.confirm_leave()
	check(game.ui_focus.stack.size()==2,"exit confirmation opens")
	game.ui_focus.back()
	check(game.ui_focus.stack.back()==game.pause_panel,"cancel exit restores pause")
	game.ui_focus.back()
	check(not game.ui_focus.blocked(),"escape resumes pause")
	game.open_naval()
	await process_frame
	await process_frame
	var naval: NavalMode=game.naval_mode
	check(is_instance_valid(naval),"naval loaded")
	if is_instance_valid(naval):
		naval.focus.close_all()
		naval._open("home")
		naval._open("fleet")
		naval._open("shop")
		check(naval.focus.stack.size()==2 and naval.focus.stack[0]==naval.pages.home and naval.focus.stack[1]==naval.pages.shop,"naval routes do not accumulate")
		naval._go_back()
		check(naval.focus.stack.size()==1 and naval.focus.stack.back()==naval.pages.home,"naval back returns home")
		naval._open("settings")
		naval._go_back()
		check(naval.focus.stack.size()==1 and naval.focus.stack.back()==naval.pages.home,"naval settings back returns home")
		naval.focus.close_all()
		naval._open("settings")
		check(naval.focus.stack.size()==2 and naval.focus.stack[0]==naval.pages.home,"naval settings direct anchors home")
		naval._go_back()
		check(naval.focus.stack.size()==1 and naval.focus.stack.back()==naval.pages.home,"naval direct settings back")
		naval._close_mode()
		await process_frame
		await process_frame
		check(game.naval_mode==null and game.mode=="menu","naval exits to main menu")
	game.queue_free()
	await process_frame
	print("NAV_UI_FAILURES=",failed.size()," ",failed)
	quit(0 if failed.is_empty() else 1)
