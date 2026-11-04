extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures: Array[String]=[]
	var targets:=["res://scripts/ui/ui_kit.gd","res://scripts/ui/infantry_hud.gd","res://scripts/ui/naval_hud.gd","res://modes/battle_royale/ui/hud.gd","res://modes/war/scripts/ui.gd","res://scripts/ui/main_menu.gd","res://modes/battle_royale/ui/inventory_panel.gd","res://scripts/ui/pause_menu.gd"]
	for path in targets:
		var loaded=load(path)
		if not loaded is Script or not loaded.can_instantiate():failures.append("script "+path)
	var backpack:=BRInventoryPanel.new()
	root.add_child(backpack)
	await process_frame
	var horizontal:=backpack.find_child("InventoryHorizontalScroll",true,false)
	if not horizontal is ScrollContainer or horizontal.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_AUTO:failures.append("BR horizontal scroll")
	backpack.queue_free()
	await process_frame
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await process_frame
	await process_frame
	if not is_instance_valid(game.main_menu):
		print("MENU_FAIL missing menu")
		quit(1)
		return
	var grids=game.main_menu.pages.settings.find_children("*","GridContainer",true,false)
	if grids.size()!=1:
		print("SETTINGS_GRID_FAIL count=",grids.size())
		quit(1)
		return
	var buttons=grids[0].get_children()
	print("SETTINGS_BUTTON_COUNT=",buttons.size())
	if buttons.size()!=6:failures.append("button count")
	for index in mini(6,buttons.size()):
		var button: Button=buttons[index]
		button.pressed.emit()
		await process_frame
		var tab=game.settings_panel.tabs.current_tab
		print("TAB_CHECK ",button.text," expected=",index," actual=",tab)
		if tab!=index: failures.append(button.text)
		game.ui_focus.close_all()
	game.infantry_hud.apply_layout_variant("war")
	var hp_parent=game.infantry_hud.hp.get_parent().get_parent()
	print("WAR_HUD_LEFT=",hp_parent.offset_left)
	if hp_parent.offset_left!=24: failures.append("war layout")
	game.ui_focus.open(game.pause_panel)
	await process_frame
	if game.pause_panel.session_hint.text!="OFFLINE · PARTIDA PAUSADA": failures.append("offline pause status")
	game.online=true
	game.pause_panel._update_session_hint()
	if game.pause_panel.session_hint.text!="ONLINE · A PARTIDA CONTINUA": failures.append("online pause status")
	game.online=false
	game.ui_focus.close_all()
	print("MENU_SMOKE_FAILURES=",failures.size())
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
