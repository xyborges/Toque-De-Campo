extends SceneTree
var game: WarGame
var samples: Array[float]=[]
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func capture(label: String) -> void:
	await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/war-review-"+label+".png")
func aim_at(target: Vector3) -> void:
	var actor:=game.local_player as WarPlayer
	var direction: Vector3=(target-actor.camera_pivot.global_position).normalized()
	actor.yaw=atan2(-direction.x,-direction.z);actor.rotation.y=actor.yaw
	actor.pitch=asin(clampf(direction.y,-1,1));actor.camera_pivot.rotation.x=actor.pitch
	actor._update_view()
func run() -> void:
	game=WarGame.new()
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_visual_preview",true)
	root.add_child(game)
	game.online=false;game.mode="pvp";game.map_kind="desert";game._enter_match_world()
	game._spawn_player(1,true,false,WarTerrain.point(-270,-165)+Vector3.UP*.15)
	var actor:=game.local_player as WarPlayer
	actor.hp=100;actor.deployed=true;actor.war_team=0;actor.war_class="soldier";actor.apply_identity(0,"soldier");actor._set_hitboxes_enabled(true)
	# Override the deferred disable queued when an undeployed avatar spawned.
	actor.body_collision.set_deferred("disabled",false)
	actor.owned=["fal","glock","sniper","axe"]
	game.join_ready=true;game.third_person=true
	game.ui_focus.close_all();game.war_ui.deployment.hide()
	game.war_ui.context.text=""
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	aim_at(WarTerrain.point(-250,-130)+Vector3.UP*1.7)
	await capture("shoulder")
	actor.global_position=WarTerrain.point(-145,-90)+Vector3.UP*.15
	aim_at(WarTerrain.point(-100,-100)+Vector3.UP*1)
	await capture("trench")
	actor.global_position=WarTerrain.point(-78,60)+Vector3.UP*.15
	aim_at(WarTerrain.point(5,85)+Vector3.UP*1.7)
	await capture("village")
	for i in 240:
		await process_frame
		samples.append(root.get_process_delta_time())
	var camera:=Camera3D.new();camera.fov=38
	game.world_root.add_child(camera)
	actor.global_position=WarTerrain.point(-78,60)+Vector3.UP*.15
	actor.yaw=0;actor.rotation.y=0;actor.pitch=0;actor.set_physics_process(false)
	camera.global_position=actor.global_position+Vector3(1.5,1.25,-3.7)
	camera.look_at(actor.global_position+Vector3.UP*1.1);camera.make_current()
	await capture("character-front")
	var total:=0.0
	for sample in samples: total+=sample
	samples.sort()
	var worst_count:=maxi(1,int(samples.size()*.01));var slow:=0.0
	for i in worst_count: slow+=samples[samples.size()-1-i]
	var result: Dictionary={"failures":failures,"frames":samples.size(),"average_fps":samples.size()/total,"one_percent_low":worst_count/slow,"p95_frame_ms":samples[int(samples.size()*.95)]*1000,"max_frame_ms":samples.back()*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"note":"Single local visual review, not the required 12-player benchmark"}
	NavalStorage.write_json("res://tests/war-visual-review.json",result);print(JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit()
