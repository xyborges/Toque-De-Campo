extends SceneTree
var errors: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: errors.append(label)
func run() -> void:
	var old: Variant=ProjectSettings.get_setting("gameplay/war_enabled",false)
	ProjectSettings.set_setting("gameplay/war_enabled",true)
	var game=load("res://tests/war_menu_fixture.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: GameMainMenu=game.main_menu
	check(menu!=null and menu.mode_buttons.has("war"),"war mode available in main menu")
	menu._select_mode("war")
	check(menu.selected_mode=="war" and game.mode=="menu","war selection keeps menu state")
	check(menu.play_button.text=="CONECTAR ONLINE" and menu.war_offline_button.visible,"war shows separate online and offline actions")
	menu.play_button.pressed.emit()
	check(game.war_launches==[false],"war online button routes correctly")
	menu.war_offline_button.pressed.emit()
	check(game.war_launches==[false,true],"war offline button routes correctly")
	check(game.world_root==null and game.mode=="menu","menu actions do not create background scene")
	menu._select_mode("naval")
	check(menu.play_button.text=="VER SALAS NAVAIS","naval entry unaffected by war")
	menu._select_mode("desert")
	check(menu.play_button.text=="ENTRAR NO PVP","desert entry unaffected by war")
	menu.show_page("play")
	check(game.war_launches.size()==2,"opening play page does not relaunch war")
	ProjectSettings.set_setting("gameplay/war_enabled",old)
	game.queue_free()
	await process_frame
	print("WAR_QUICK_FAILURES=",errors.size()," ",errors)
	quit(0 if errors.is_empty() else 1)
