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
	game.start_offline("desert")
	game.set_physics_process(false)
	var actor: GamePlayer = game.local_player
	actor.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(game.world_root.get_meta("terrain_size")==300.0,"300 metre terrain with physical mesh")
	var world: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var physical_matches := true
	var min_height := INF
	var max_height := -INF
	for point in [Vector2(-121,-110),Vector2(101,115),Vector2(115,-81),Vector2(-107,91),Vector2(-72,-108),Vector2(81,78),Vector2(142,-110)]:
		var p := DesertTerrain.point(point.x,point.y)
		var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p-Vector3.UP*10,1))
		physical_matches = physical_matches and not hit.is_empty() and absf(hit.position.y-p.y)<.012
		min_height = minf(min_height,p.y)
		max_height = maxf(max_height,p.y)
	check(physical_matches,"visible terrain triangles and physical ground agree at distant samples")
	check(max_height-min_height>2.0,"physical dunes have meaningful height variation")
	var entrance := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.4,2),Vector3(0,1.4,-15),1))
	check(entrance.is_empty(),"outpost has a traversable front-to-back corridor")
	var solid := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(6.8,1.5,2),Vector3(6.8,1.5,-7),1))
	check(not solid.is_empty(),"outpost solid wall blocks bullets")
	var director: OfflineDirector = game.offline_director
	var goal := director.nearest(Vector3(0,0,20))
	for point in [Vector3(0,0,-7),Vector3(-5,0,-7),Vector3(5,0,-7),Vector3(-20,0,-3),Vector3(20,0,3)]:
		var id := director.nearest(point)
		check(not director.grid.get_id_path(id,goal).is_empty(),"NPC route to combat area from "+str(point))
	check(game.npcs.size()==12,"twelve NPCs spawn immediately on enlarged map")
	var spawns_clear := true
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.72
	capsule.radius = .31
	for i in DesertMap.SPAWN_PADS.size():
		var p := DesertMap.spawn_pad(i)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,p+Vector3.UP*.90)
		spawns_clear = spawns_clear and world.intersect_shape(query,1).is_empty()
	check(spawns_clear,"all PVP spawn capsules clear physical terrain and cover")
	var candidate: Variant = director.spawn_position()
	check(candidate!=null and absf(candidate.y-DesertTerrain.height_at(candidate.x,candidate.z)-.04)<.001,"NPC spawn samples the exact terrain elevation")
	actor.position = DesertTerrain.point(100,100)+Vector3.UP*.30
	for i in range(90):
		actor.velocity = Vector3(1,-4,0)
		actor.move_and_slide()
		await physics_frame
	check(actor.position.x>100 and absf(actor.position.y-DesertTerrain.height_at(actor.position.x,actor.position.z))<.12,"player walks on hills beyond the old 55 metre boundary")
	game.mode = "pvp"
	var authoritative_spawn := DesertMap.spawn_pad(4)
	game.remote_add_player(1,"Test",{},authoritative_spawn)
	check(actor.position.is_equal_approx(authoritative_spawn),"local avatar accepts the authoritative initial spawn")
	game.remote_add_player(1,"Test",{},DesertMap.spawn_pad(2))
	check(actor.position.is_equal_approx(authoritative_spawn),"duplicate join cannot move an already confirmed avatar")
	game.remote_add_player(81234,"Disconnected",{},authoritative_spawn)
	game.remote_player_left(81234)
	game.remote_player_state(81234,authoritative_spawn,0,0,"fal",100,false)
	check(not game.players.has(81234),"late unreliable snapshot cannot recreate a disconnected avatar")
	game.queue_free()
	await process_frame
	NavalStorage.write_json("res://tests/environment-desert-results.json",{"checks":checks,"failures":failures,"terrain_height_span":max_height-min_height})
	quit(0 if failures.is_empty() else 1)
