extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: errors.append(label)
func frames() -> void:
	for tick in 3: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames()
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	if img!=null: img.save_png("res://work/ui-regression-deep/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await frames()
	verify(game.mode=="menu" and game.world_root==null,"initial game is in main menu without a background match")
	var menu: GameMainMenu=game.main_menu
	for id in ["office","naval","desert","war","war_afghan","br"]:
		verify(menu.mode_buttons.has(id),"mode exists: "+id)
		if menu.mode_buttons.has(id):
			menu.mode_buttons[id].pressed.emit()
			await frames()
			verify(menu.selected_mode==id and game.mode=="menu" and game.world_root==null,"mode selection is non-destructive: "+id)
	menu._select_mode("war")
	await capture("modern-war-menu")
	menu.show_page("settings")
	var grids=menu.pages.settings.find_children("*","GridContainer",true,false)
	verify(grids.size()==1,"settings shortcut grid exists")
	if grids.size()==1:
		var buttons=grids[0].get_children()
		verify(buttons.size()==6,"settings exposes six categories")
		for index in mini(buttons.size(),6):
			buttons[index].pressed.emit()
			await frames()
			verify(game.settings_panel.tabs.current_tab==index and game.ui_focus.blocked(),"settings shortcut opens correct tab "+str(index))
			game.ui_focus.back()
			await frames()
			verify(not game.ui_focus.blocked(),"settings back returns to menu "+str(index))
	await capture("modern-settings")
	menu.show_page("play")
	menu._select_mode("office")
	game.start_offline("training")
	await frames()
	verify(game.mode=="menu" and game.world_root==null and game.ui_focus.blocked(),"offline opens deployment before creating world")
	var deploy: GameInfantryDeployment=game.deployment_panel
	verify(is_instance_valid(deploy) and deploy.visible,"deployment is visible")
	await capture("modern-deployment")
	deploy.confirm.pressed.emit()
	await frames()
	var actor: GamePlayer=game.local_player
	verify(game.mode=="training" and is_instance_valid(actor),"deploy creates a playable offline actor")
	if is_instance_valid(actor):
		var actor_id:=actor.get_instance_id()
		game.infantry_hud.refresh()
		verify(game.infantry_hud.hp.text.contains("100"),"infantry HUD reflects live health")
		await capture("modern-gameplay-hud")
		game.ui_focus.open(game.pause_panel)
		await frames()
		verify(game.ui_focus.stack.back()==game.pause_panel,"pause opens from combat")
		await capture("modern-pause")
		game.ui_focus.back()
		await frames()
		verify(not game.ui_focus.blocked() and actor.get_instance_id()==actor_id,"resume keeps the same player and closes overlays")
	game.show_menu()
	await frames()
	verify(game.mode=="menu" and game.menu_layer.visible and game.world_root==null,"return to menu clears world and restores navigation")
	game.queue_free()
	await process_frame
	print("MODERN_UI_FLOW ",JSON.stringify({"checks":checks,"failures":errors}))
	quit(0 if errors.is_empty() else 1)
