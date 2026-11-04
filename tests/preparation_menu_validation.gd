extends SceneTree
var errors: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	var game: Node=load("res://scripts/main.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	await process_frame;await process_frame
	var menu:=game.main_menu as GameMainMenu
	check(is_instance_valid(menu.preparation_preview.actor),"entry has a character")
	for mode in ["war","desert","office","br","naval","war"]:
		menu._select_mode(mode);await process_frame
		check(menu.selected_mode==mode,"mode selected: "+mode)
		check(menu.preparation_panel.visible==(mode in ["war","desert","office"]),"correct personalization scope: "+mode)
		if mode in ["war","desert","office"]:
			check(menu.preparation_editor.approved().ok,"valid loadout: "+mode)
			menu._preparation_slot("helmet");menu._preparation_slot("vest");menu._preparation_slot("primary")
	menu._select_mode("war")
	for team in [0,1]:
		menu.preparation_team.select(team);menu._configure_preparation()
		check(menu.preparation_editor.team==team,"team selection reaches existing validator")
		for index in menu.preparation_class.item_count:
			menu.preparation_class.select(index);menu._configure_preparation()
			check(menu.preparation_editor.approved().ok,"valid team/class loadout")
	menu.preparation_preview._highlight("helmet")
	check(menu.preparation_preview.highlighted.size()>0,"hover selects actual head mesh")
	menu.preparation_preview._highlight("")
	check(menu.preparation_preview.highlighted.is_empty(),"hover exit restores material overlays")
	await create_timer(.25).timeout
	var head: MeshInstance3D=menu.preparation_preview.actor.avatar_parts.head
	var pixel: Vector2=menu.preparation_preview.camera.unproject_position(head.global_position)
	var motion:=InputEventMouseMotion.new();motion.position=pixel*menu.size/Vector2(menu.preparation_preview.view.size);motion.global_position=motion.position
	root.push_input(motion,true);await process_frame
	check(menu.preparation_preview.hovered=="helmet","mouse events reach character through the empty center of the menu")
	if DisplayServer.get_name()!="headless":
		await process_frame;RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://work/preparation-menu-1280.png")
	menu.preparation_preview._highlight("")
	game.menu_layer.hide()
	var login:=GameLoginScreen.new();login.service=game.main_accounts;root.add_child(login)
	login.size=root.get_visible_rect().size
	login.set_process(false);login.curtain.color.a=0.
	await process_frame;await process_frame
	var helmets:=login.scenery.view.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return str(mesh.get_meta("protection_slot",""))=="helmet")
	check(not helmets.is_empty(),"login uses the shared gameplay helmet")
	for mesh: MeshInstance3D in helmets:check(mesh.get_aabb().size.x<.50,"login helmet keeps natural head width")
	if DisplayServer.get_name()!="headless":
		await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/login-helmet-corrected.png")
	login.queue_free()
	print("PREPARATION_MENU_VALIDATION ",JSON.stringify({"checks":checks,"ok":errors.is_empty(),"errors":errors}))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
