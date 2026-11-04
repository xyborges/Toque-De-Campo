extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scripts/main.gd").new();game.set_meta("test_mode",true);root.add_child(game);await process_frame
	game.menu_layer.show();game.main_menu._credits();await process_frame;await process_frame
	var panel: PanelContainer=game.main_menu.credits_panel;var failures: Array[String]=[];var text:=""
	for label: Label in panel.find_children("*","Label",true,false): text+=label.text+"\n"
	if not panel.visible or not text.contains("Nayckron") or not text.contains("qubodup"): failures.append("audio attributions missing from visible credits")
	if not Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(panel.get_global_rect()): failures.append("credits overflow the viewport")
	var id:=panel.get_instance_id();game.ui_focus.close_top();game.main_menu._credits()
	if game.main_menu.credits_panel.get_instance_id()!=id: failures.append("credits recreated on every open")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/audio169-credits.png")
	NavalStorage.write_json("res://tests/audio169-credits-results.json",{"checks":3,"failures":failures});print(JSON.stringify(failures));game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
