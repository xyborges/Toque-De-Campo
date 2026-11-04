extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var maximum_error:=0.
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func rendered() -> void:
	await process_frame;RenderingServer.force_draw(false)
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/war_hud_fixture.gd").new();game.offline_operation=true
	game.set_meta("war_test",true);game.set_meta("war_visual_preview",true);game.set_meta("test_mode",true);root.add_child(game)
	game.online=false;game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	game.vehicle_system.set_physics_process(false);game.vehicle_system.set_process(false)
	var actor:=game._spawn_player(1,true,false,Vector3(-200,0,-180)) as WarPlayer
	actor.set_physics_process(false);actor.hp=100;actor.deployed=true;actor.war_team=0
	game.members[1]={"team":0,"role":"soldier","deployed":true,"vehicle":"","charges":3,"last_gadget":-100.,"pending":{},"ready_at":0.}
	game.join_ready=true;game.war_clock=100;game.ui_focus.close_all();game.war_ui.deployment.hide()
	var ui:=game.war_ui;ui.set_process(false)
	var camera:=Camera3D.new();camera.position=Vector3(-200,12,-180);camera.far=2000;game.world_root.add_child(camera);camera.make_current()
	var target: Vector3=ui.markers[0].world
	camera.look_at(target);ui._refresh_marker_labels();ui._process(.11);await rendered();await rendered()
	var records_before:=ui.markers.size();var nodes_before:=get_node_count();var cached_text: String=ui.markers[0].text
	for dimensions in [Vector2i(1024,768),Vector2i(1920,1080)]:
		root.size=dimensions;await rendered()
		for offset in [Vector3(5,2,0),Vector3(-7,-1,0),Vector3(10,5,0),Vector3(-12,-3,0)]:
			camera.look_at(target+offset)
			ui.clock=0;ui.marker_clock=0;ui._process(.001)
			await rendered()
			var expected: Vector2=ui.get_global_transform_with_canvas().affine_inverse()*camera.unproject_position(target)
			var actual: Vector2=ui.markers[0].at
			var error:=expected.distance_to(actual);maximum_error=maxf(maximum_error,error)
			check(ui.markers[0].visible and error<.1,"objective follows the current rendered camera below the state update interval: "+str(dimensions)+" / "+str(offset))
		check(ui.markers[0].text==cached_text,"per-render projection keeps objective text/distance cached: "+str(dimensions))
	check(ui.markers.size()==records_before and get_node_count()==nodes_before,"camera motion reuses objective records without creating scene nodes")
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png("res://work/war163-objective-projection.png")
	actor.hp=0;ui._process(.001);await rendered()
	check(ui.markers.all(func(marker):return not marker.visible),"dead player has no stale objective projection")
	actor.hp=100;game.ui_focus.open(game.pause_panel);ui._process(.001);await rendered()
	check(ui.markers.all(func(marker):return not marker.visible),"focused menus hide the objective projection")
	game.ui_focus.close_all();ui.deployment.show();game.members[1].pending={"team":0,"role":"medic","spawn":"rally","weapon":"fal","gadget":"rpg","life":actor.life_id}
	ui._process(.11)
	check(ui.saved_deployment.visible and ui.saved_deployment.text.contains("SALVO NO SERVIDOR") and ui.saved_deployment.text.contains("MÉDICO") and ui.saved_deployment.text.contains("EQUIPE 1") and ui.saved_deployment.text.contains("LINHA AVANÇADA"),"deployment panel identifies the server-confirmed class, team and spawn")
	ui.class_select.select(3);ui._process(.11)
	check(ui.saved_deployment.text.contains("MÉDICO"),"unsubmitted form changes are not presented as confirmed equipment")
	game.members[1].pending={};ui._process(.11);check(not ui.saved_deployment.visible,"no confirmation is invented when no pending loadout exists")
	actor.hp=0;game.members[1].ready_at=game.war_clock+3.5;ui._process(.11)
	check(ui.deploy_button.disabled and ui.deploy_button.text.contains("3,5 s") and ui.feedback.text.contains("REIMPLANTAÇÃO"),"death countdown disables deployment and exposes the authoritative wait")
	game.war_clock+=4;ui._process(.11)
	check(not ui.deploy_button.disabled and ui.deploy_button.text=="IMPLANTAR","deployment becomes available when the authoritative wait expires")
	actor.hp=100;actor.deployed=true;ui._process(.11)
	check(ui.deploy_button.text=="SALVAR PARA PRÓXIMO RESPAWN" and not ui.deploy_button.disabled,"living player can still save equipment for the next life")
	game.show_menu();game.queue_free();await process_frame;await process_frame
	var result: Dictionary={"checks":checks,"failures":failures,"maximum_projection_error_px":maximum_error,"native_render":DisplayServer.get_name()!="headless"}
	NavalStorage.write_json("res://tests/war163-hud-projection-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
