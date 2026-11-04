extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var actor:=game.local_player as WarPlayer;actor.weapon_id="fal";actor.aiming=false;actor.iron_sights=false
	var total:=0
	for group: Dictionary in GameAimSensitivity.groups().values():
		for id in group: total+=1;check(is_equal_approx(GameAimSensitivity.factor(id),1.0),"default sensitivity retained: "+str(id))
	check(total>=27,"all infantry, launcher, grenade, vehicle, drone and naval profiles are exposed")
	var yaw_start:=actor.yaw;actor.apply_look(Vector2(20,0));var baseline:=absf(actor.yaw-yaw_start)
	GameAimSensitivity.set_values("weapon:fal",.5,.4)
	yaw_start=actor.yaw;actor.apply_look(Vector2(20,0));check(absf(absf(actor.yaw-yaw_start)/baseline-.5)<.001,"personal FAL normal sensitivity changes immediately")
	actor.aiming=true;yaw_start=actor.yaw;actor.apply_look(Vector2(20,0));check(absf(absf(actor.yaw-yaw_start)/baseline-.1)<.001,"aim sensitivity composes with the existing natural zoom reduction")
	actor.aiming=false;GameAimSensitivity.flush();GameAimSensitivity.cache_path="";GameAimSensitivity.profiles={}
	check(is_equal_approx(GameAimSensitivity.factor("weapon:fal"),.5),"saved sensitivity reloads from the persistent profile file")
	check(not GameAimSensitivity.set_values("weapon:fal",NAN,1) and not GameAimSensitivity.set_values("unknown",1,1),"invalid and nonfinite settings are rejected")
	var camera:=NavalCamera.new();root.add_child(camera)
	GameAimSensitivity.set_values("naval:heavy",.5,1);GameAimSensitivity.set_values("navalweapon:missile",.4,1)
	camera.mouse(Vector2(20,0),"heavy","missile")
	check(absf(camera.orbit_yaw+.0064)<.00001,"naval camera combines selected ship and selected armament profiles")
	var panel:=game.aim_settings_panel;panel.present(game.ui_focus,"weapon:fal");await process_frame;await process_frame
	check(game.ui_focus.blocked() and panel.visible and panel.current=="weapon:fal","sensitivity is accessible through the live in-game settings panel")
	var count:=get_node_count()
	for value in range(70,90): panel.normal.value=value
	await create_timer(.4).timeout
	check(count==get_node_count() and not GameAimSensitivity.dirty,"slider changes reuse their timer/widgets and flush safely")
	var rectangle:=panel.get_global_rect();check(rectangle.position.x>=0 and rectangle.position.y>=0 and rectangle.end.x<=root.size.x and rectangle.end.y<=root.size.y,"settings panel remains inside the current viewport")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/aim-settings168.png")
	game.ui_focus.close_top();check(not game.ui_focus.blocked(),"returning from settings restores the previous in-game focus stack")
	var report: Dictionary={"checks":checks,"failures":failures,"profiles":total};NavalStorage.write_json("res://tests/aim-settings168-results.json",report);print(JSON.stringify(report))
	camera.queue_free();game.show_menu();game.queue_free();await process_frame;await create_timer(.4).timeout;quit(0 if failures.is_empty() else 1)
