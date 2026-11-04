extends SceneTree

var checks:=0
var failures: Array[String]=[]
var captures: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point
		root.push_input(event,true)
	await process_frame

func run() -> void:
	var previous: Variant=ProjectSettings.get_setting("gameplay/war_enabled",false)
	ProjectSettings.set_setting("gameplay/war_enabled",true)
	var game=load("res://tests/war_menu_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	await create_timer(.25).timeout;game.ui_focus.close_all()
	var menu: GameMainMenu=game.main_menu
	check(menu.mode_buttons.has("war") and game.mode=="menu" and game.world_root==null,"Guerra appears as an existing game mode without starting a background match")
	for dimensions in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(1024,768)]:
		root.size=dimensions;await process_frame;await process_frame
		menu.page_scroll.scroll_vertical=0
		await click(menu.mode_buttons.war)
		check(menu.selected_mode=="war" and game.mode=="menu" and game.world_root==null and game.war_launches.is_empty(),"selecting the Guerra card only opens choices: "+str(dimensions))
		menu.page_scroll.scroll_vertical=10000;await process_frame;await process_frame
		check(menu.play_button.text=="CONECTAR ONLINE" and menu.war_offline_button.is_visible_in_tree() and not menu.desert_training_button.visible,"Guerra exposes explicit online and offline actions: "+str(dimensions))
		var view:=root.get_visible_rect()
		var online:=menu.play_button.get_global_rect();var offline:=menu.war_offline_button.get_global_rect()
		check(view.encloses(online) and view.encloses(offline),"both Guerra actions remain reachable inside the viewport: "+str(dimensions))
		if DisplayServer.get_name()!="headless":
			RenderingServer.force_draw(false)
			var path:="res://work/war-menu-%dx%d.png"%[dimensions.x,dimensions.y]
			root.get_texture().get_image().save_png(path);captures.append(path)
	root.size=Vector2i(1280,800);await process_frame;await process_frame
	menu._select_mode("war");menu.page_scroll.scroll_vertical=10000;await process_frame;await process_frame
	await click(menu.play_button)
	check(game.war_launches==[false],"online button dispatches open_war(false)")
	await click(menu.war_offline_button)
	check(game.war_launches==[false,true],"offline button dispatches open_war(true)")
	check(game.mode=="menu" and game.world_root==null,"menu dispatch test does not authenticate, connect or create a match")
	menu._select_mode("office")
	check(not menu.war_offline_button.visible and menu.desert_training_button.visible,"office keeps its own offline training actions")
	menu._select_mode("naval")
	check(not menu.war_offline_button.visible and not menu.desert_training_button.visible and menu.play_button.text=="VER SALAS NAVAIS","naval retains its existing action without Guerra choices")
	menu._select_mode("desert")
	check(not menu.war_offline_button.visible and menu.play_button.text=="ENTRAR NO PVP","desert retains its existing PvP action")
	menu.show_page("play")
	check(game.war_launches.size()==2 and game.mode=="menu" and game.world_root==null,"opening JOGAR never deploys a character behind the menu")
	ProjectSettings.set_setting("gameplay/war_enabled",previous)
	game.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures,"scope":"Menu dispatch and responsive choices only; offline simulation is tested separately"}
	NavalStorage.write_json("res://tests/war-menu-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
