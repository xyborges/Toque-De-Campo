extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.start_offline("training")
	game.set_physics_process(false)
	for actor in game.players.values(): actor.set_physics_process(false)
	game.third_person = true
	var actor: GamePlayer = game.local_player
	await physics_frame
	await physics_frame
	actor.position = Vector3(0,.04,6.35)
	actor.rotation.y = 0
	actor.pitch = 0
	actor.camera_pivot.rotation = Vector3.ZERO
	actor._update_view()
	actor._update_camera_collision(.016)
	check(actor.camera.global_position.z<6.79,"TPP camera stops before the service door")
	await capture("camera-door")
	check(actor.camera_distance<1.0,"obstacle pulls camera toward the shoulder immediately")
	check(not actor.body_root.visible and actor.view_root.visible,"close obstruction hides avatar interior and uses existing first-person hands")
	check(game.third_person,"obstruction does not change the selected view mode")
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = .14
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY,actor.camera.global_position)
	check(game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"near-plane camera volume is clear of the wall")
	var previous := actor.camera_distance
	actor.position.z = 3.0
	actor._update_camera_collision(.016)
	check(actor.camera_distance>previous and actor.camera_distance<1.5,"camera returns smoothly when the wall clears")
	for i in range(80): actor._update_camera_collision(.016)
	check(absf(actor.camera_distance-Vector3(.52,.22,2).length())<.005,"camera regains the original shoulder distance")
	check(actor.body_root.visible and actor.weapon_root.visible and not actor.view_root.visible,"TPP body and weapon recover after clearing the obstacle")
	actor.position = Vector3(11,.04,-34.8)
	actor.rotation.y = PI
	actor.camera_pivot.rotation = Vector3.ZERO
	actor._update_view()
	check(actor.camera.global_position.z> -35.8,"camera respects cabinet geometry inside administration")
	await capture("camera-cabinet")
	actor.position = Vector3(0,.04,-41)
	actor.rotation.y = 0
	actor.camera_pivot.rotation.x = -1.2
	actor._update_view()
	check(actor.camera.global_position.y<3.40,"looking down cannot push the camera through the annex ceiling")
	actor.position = Vector3(0,.04,2)
	actor.camera_pivot.rotation.x = 1.25
	actor._update_view()
	check(actor.camera.global_position.y>.15,"looking up cannot push the camera below the floor")
	game.third_person = false
	actor.camera_pivot.rotation = Vector3.ZERO
	actor._update_view()
	check(actor.camera.position.length()<.001,"FPP remains aligned with the original eye position")
	game.third_person = true
	actor.iron_sights = true
	actor._update_view()
	check(actor.camera.position.length()<.001,"iron sights retain the FPP eye position")
	actor.iron_sights = false
	actor._update_view()
	check(actor.camera.position.z>1.5,"leaving sights restores the selected TPP mode")
	game.show_menu()
	game.queue_free()
	await process_frame
	var world := NavalWorld.new()
	root.add_child(world)
	world.build(false,17391)
	var ship := NavalShip.new()
	world.add_child(ship)
	ship.build("heavy",1,"camera-test","Camera")
	ship.position = Vector3(700,0,700)
	var camera := NavalCamera.new()
	world.add_child(camera)
	camera.initialized = true
	camera.orbit_pitch = .65
	await physics_frame
	await physics_frame
	camera.follow(ship,0.0)
	check(camera.position.y>=1.14,"naval camera stays above water at maximum upward aim")
	var k := EnvironmentKit.new(world,false)
	k.box("CameraObstacle",Vector3(700,10,722),Vector3(40,20,.3),"concrete",true)
	camera.orbit_pitch = -.12
	await physics_frame
	await physics_frame
	camera.follow(ship,0.0)
	check(camera.position.z<721.4,"naval camera volume stops before a solid obstacle")
	world.queue_free()
	await process_frame
	NavalStorage.write_json("res://tests/camera-collision-results.json",{"checks":checks,"failures":failures})
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screens/extended-look/"+label+".png"))
