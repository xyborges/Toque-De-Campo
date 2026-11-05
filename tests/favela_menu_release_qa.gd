extends SceneTree
## Smoke for the Favela menu launch in a *candidate*, not a production release.
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func run() -> void:
	var previous: Variant=ProjectSettings.get_setting("gameplay/war_enabled",false)
	ProjectSettings.set_setting("gameplay/war_enabled",true)
	var game=load("res://tests/war_menu_fixture.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: GameMainMenu=game.main_menu
	check(is_instance_valid(menu) and menu.mode_buttons.has("war_favela"),"Favela card appears in the JOGAR menu")
	if not is_instance_valid(menu) or not menu.mode_buttons.has("war_favela"):
		_finish(game,previous)
		return
	# Activate the actual card signal rather than invoking the selection method directly.
	menu.mode_buttons["war_favela"].pressed.emit()
	check(menu.selected_mode=="war_favela","Favela selected without starting a background game")
	check(menu.hero_title.text=="FAVELA" and menu.hero_detail.text.contains("Conquista urbana"),"Correct Favela title and description")
	check(menu.play_button.text=="JOGAR COM BOTS","Favela primary action is explicitly offline")
	check(not menu.war_offline_button.visible,"No duplicated Favela offline button")
	check(menu.preparation_roles.visible and menu.preparation_panel.visible,"Class, team and loadout preparation available")
	check(menu.preparation_team.get_item_text(0)=="Polícia" and menu.preparation_team.get_item_text(1)=="Bandidos","Correct Favela teams")
	check(menu.preparation_editor.mode=="war","Existing Guerra loadout reused")
	for size in [Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=size
		await process_frame
		await process_frame
		menu.page_scroll.scroll_vertical=0
		await process_frame
		check(menu.mode_buttons["war_favela"].is_visible_in_tree() and root.get_visible_rect().encloses(menu.mode_buttons["war_favela"].get_global_rect()),"Favela card remains reachable at "+str(size))
	root.size=Vector2i(1280,800)
	await process_frame
	check(game.mode=="menu" and game.world_root==null and game.war_launches.is_empty(),"Selecting Favela does not initialize a hidden game")
	var definition=load("res://scripts/maps/definition.gd")
	var identity: Dictionary=definition.identity("favela")
	check(definition.current("favela") and definition.compatible("favela",identity),"Favela's prepared map identity is current")
	check(WarOperation.port(WarOperation.FAVELA)==3017 and WarOperation.port(WarOperation.FAVELA)!=3016,"Favela port is distinct from the BR broker")
	menu.play_button.pressed.emit()
	for i in 9:
		await process_frame
	check(game.war_launches==[true],"Pressing JOGAR COM BOTS dispatches an offline operation")
	check(game.mode=="menu" and game.world_root==null,"Fixture launch does not create an actual match in the background")
	menu._select_mode("war")
	check(menu.play_button.text=="CONECTAR ONLINE" and menu.war_offline_button.visible,"Ukraine Guerra still has both actions")
	menu._select_mode("war_afghan")
	check(menu.play_button.text=="CONECTAR ONLINE" and menu.war_offline_button.visible,"Afghanistan Guerra online and offline preserved")
	menu._select_mode("naval")
	check(menu.play_button.text=="VER SALAS NAVAIS","Naval button remains intact")
	menu._select_mode("br")
	check(menu.play_button.text=="INICIAR" and menu.war_offline_button.visible,"BR actions remain intact")
	_finish(game,previous)

func _finish(game: Node,previous: Variant) -> void:
	ProjectSettings.set_setting("gameplay/war_enabled",previous)
	if is_instance_valid(game):game.queue_free()
	print("FAVELA_MENU_RELEASE_QA ",JSON.stringify({"checks":checks,"failures":failures,"note":"candidate-only, no deployment"}))
	quit(0 if failures.is_empty() else 1)
