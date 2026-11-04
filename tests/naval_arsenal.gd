extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var branch := Node.new()
	root.add_child(branch)
	var net := NavalNetwork.new()
	branch.add_child(net);net.require_accounts=false
	var room := {"id":"arsenal","match":"arsenal","state":"IN_PROGRESS","members":[],"stats":{}}
	var battle := NavalMatch.new()
	branch.add_child(battle)
	battle.build(net,room)
	battle.set_physics_process(false)
	var index := 0
	for kind in NavalCatalog.SHIPS:
		index += 1
		var identity := str(index).sha256_text()
		net.accounts[identity] = {"id":identity,"owned":[kind],"coins":30000}
		battle.add_player(index,{"identity":identity,"name":kind,"ship":kind})
		var ship: NavalShip = battle.ships[index]
		ship.global_position = Vector3(index*65,0,0)
		check(ship.hp == NavalCatalog.SHIPS[kind].hp and ship.turrets.size() == NavalCatalog.SHIPS[kind].weapons.size(),kind+" health and allowed weapons")
		check(ship.get_node_or_null("HullCollision") != null and ship.get_node_or_null("BridgeCollision") != null,kind+" hull and upper cabin colliders")
	await physics_frame
	await physics_frame
	var ship: NavalShip = battle.ships[3]
	ship.global_position = Vector3.ZERO
	ship.rotation = Vector3.ZERO
	ship.heading = 0.0
	await physics_frame
	var cabin := ship.get_node("BridgeCollision") as CollisionShape3D
	var top: Vector3 = cabin.global_position+Vector3.UP*(cabin.shape.size.y*0.4)
	var ray := PhysicsRayQueryParameters3D.create(top+Vector3(0,0,-30),top+Vector3(0,0,30),2)
	var hit := battle.world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == ship,"240HP destroyer upper cabin receives projectiles")
	for weapon in ship.turrets:
		ship.selected = weapon
		var gun: NavalTurret = ship.turrets[weapon]
		for heading in [0.0,0.7,-1.8,PI]:
			ship.rotation = Vector3(0,heading,0)
			ship.heading = heading
			ship.velocity = Vector3(8,0,-11)
			var target := ship.to_global(Vector3(0,0,-350))
			for frame in range(180): gun.step(target,ship.velocity,1.0/60.0)
			var shot := gun.launch(ship.velocity,10.0)
			check(shot.origin.distance_to(gun.muzzle.global_position)<0.0001,weapon+" actual muzzle at heading "+str(heading))
			check((shot.velocity-ship.velocity).normalized().dot(-gun.muzzle.global_basis.z)>0.9999,weapon+" inherits both hull velocity axes")
			var solution := NavalBallistics.solve(shot.origin,target,weapon,ship.velocity)
			var actual := NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,solution.time,weapon,10.0)
			check(Vector2(actual.x-target.x,actual.z-target.z).length()<0.5,weapon+" converges to aim while hull rotated/moving")
			var predicted := NavalBallistics.prediction(battle.world.get_world_3d(),shot,[ship.get_rid()])
			var simulated := shot.duplicate()
			var end := minf(float(shot.life),float(shot.range)/shot.velocity.length())
			var impact: Dictionary = {}
			while float(simulated.age)<end:
				var next := minf(float(simulated.age)+NavalCatalog.STEP,end)
				impact = NavalBallistics.segment(battle.world.get_world_3d(),simulated,next,[ship.get_rid()])
				simulated.age = next
				if not impact.is_empty(): break
			check(predicted.hit == not impact.is_empty() and (impact.is_empty() or predicted.impact.distance_to(impact.position)<0.001),weapon+" guide matches actual impact")
		ship.rotation = Vector3.ZERO
		ship.velocity = Vector3.ZERO
		for frame in range(180): gun.step(Vector3(0,0,-350),Vector3.ZERO,1.0/60.0)
		ship.ammo[weapon] = 0
		check(not battle.try_fire(ship),weapon+" cannot fire empty")
		check(ship.start_reload(),weapon+" starts server reload")
		check(not battle.try_fire(ship),weapon+" cannot fire while reloading")
		ship.latest_input = battle.time
		for frame in range(ceil(float(NavalCatalog.WEAPONS[weapon].reload)/NavalCatalog.STEP)+2):
			ship.simulate(NavalCatalog.STEP,battle.time)
		check(ship.reload_left <= 0 and ship.ammo[weapon] == NavalCatalog.WEAPONS[weapon].ammo,weapon+" reload restores full magazine")
		ship.firing = true
		ship.latest_input = -10.0
		ship.simulate(NavalCatalog.STEP,1.0)
		check(not ship.firing,weapon+" stale control stops firing")
	# Rotation compensation and independent gun mounts.
	ship.rotation = Vector3.ZERO
	var front: NavalTurret = ship.turrets.lightMG
	for i in range(180): front.step(Vector3(200,0,-300),Vector3.ZERO,1.0/60.0)
	var before := -front.muzzle.global_basis.z.normalized()
	ship.rotation.y = 0.9
	for i in range(180): front.step(Vector3(200,0,-300),Vector3.ZERO,1.0/60.0)
	check(before.dot(-front.muzzle.global_basis.z.normalized())>0.999,"turret compensates hull rotation to world target")
	var camera := NavalCamera.new()
	battle.world.add_child(camera)
	camera.mouse(Vector2(30,0))
	check(camera.orbit_yaw < 0,"mouse right looks right")
	var old := camera.orbit_pitch
	camera.mouse(Vector2(0,-30))
	check(camera.orbit_pitch>old,"mouse up looks up")
	var raw := var_to_bytes({"ships":battle.ships.values().map(func(s: NavalShip): return s.snapshot())})
	var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	check(bytes_to_var(compressed.decompress(raw.size(),FileAccess.COMPRESSION_ZSTD)) is Dictionary,"bounded snapshot codec roundtrip")
	var install := ProjectSettings.globalize_path("res://work/naval-profile-fixture")
	DirAccess.make_dir_recursive_absolute(install)
	FileAccess.open(install.path_join("installed.json"),FileAccess.WRITE).store_string("{}")
	var first := NavalStorage.portable_profiles(install.path_join("releases/first/ToqueDeCampo.exe"))
	var updated := NavalStorage.portable_profiles(install.path_join("releases/updated/ToqueDeCampo.exe"))
	check(first == updated and first == install.path_join("profiles"),"updater versions share the same fallback profile directory")
	var report := {"checks":checks,"failures":failures,"snapshot_bytes":raw.size(),"compressed_bytes":compressed.size()}
	FileAccess.open("res://tests/naval-arsenal-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	branch.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
