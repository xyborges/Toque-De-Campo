extends SceneTree
var failures: Array[String] = []
var count := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	count += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var branch := Node.new()
	root.add_child(branch)
	var network := NavalNetwork.new()
	branch.add_child(network);network.require_accounts=false
	var room := {"id":"physics-room","match":"physics-match","state":"IN_PROGRESS","members":[],"stats":{}}
	var battle := NavalMatch.new()
	branch.add_child(battle)
	battle.build(network,room)
	battle.set_physics_process(false)
	for peer in [101,102]:
		var identity := str(peer).sha256_text()
		network.accounts[identity] = {"id":identity,"coins":30000,"owned":["light"],"selected":"light","transactions":{}}
		battle.add_player(peer,{"identity":identity,"ship":"light","name":str(peer)})
	var ship: NavalShip = battle.ships[101]
	var target: NavalShip = battle.ships[102]
	ship.global_position = Vector3.ZERO
	ship.heading = 0.0
	target.global_position = Vector3(300,0,-200)
	await physics_frame
	await physics_frame
	for i in range(90):
		battle.set_control(101,1.0,0.0,Vector3(0,0,-300),"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(ship.speed > 10.0 and ship.speed < 28.0,"progressive acceleration below maximum")
	check(ship.global_position.z < -12.0,"W moves forward on -Z")
	var old_speed := ship.speed
	for i in range(20):
		battle.set_control(101,0.0,0.0,Vector3(0,0,-300),"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(ship.speed > 0.0 and ship.speed < old_speed,"water drag is gradual")
	for i in range(130):
		battle.set_control(101,-1.0,0.0,Vector3(0,0,-300),"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(ship.speed < 0.0 and ship.speed >= -8.401,"S brakes and reverses at limited speed")
	ship.speed = 12.0
	ship.velocity = Vector3(0,0,-12)
	var old_heading := ship.heading
	for i in range(30):
		battle.set_control(101,1.0,1.0,Vector3(200,0,-300),"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(ship.heading > old_heading and ship.heading-old_heading < 1.5,"A port turn has bounded angular acceleration")
	var turret: NavalTurret = ship.turrets.lightMG
	var aim := ship.global_position+Vector3(160,0,-100)
	for i in range(90):
		battle.set_control(101,0.0,0.0,aim,"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(absf(turret.yaw) > 0.2,"turret rotates independently of hull")
	var direction := -turret.muzzle.global_basis.z.normalized()
	check(direction.dot((aim-turret.muzzle.global_position).normalized()) > 0.98,"barrel follows global aim after hull turn")
	var shot := turret.launch(ship.velocity,battle.time)
	check(shot.origin.is_equal_approx(turret.muzzle.global_position),"physical muzzle is launch origin")
	check((shot.velocity-direction*620.0).distance_to(ship.velocity) < 0.001,"launch inherits hull movement on X and Z")
	for weapon in NavalCatalog.WEAPONS:
		var origin := Vector3(0,2,0)
		var point := Vector3(200,0,-400)
		if weapon == "torpedo": point.y = origin.y
		var moving := Vector3(7,0,-12)
		var solution := NavalBallistics.solve(origin,point,weapon,moving)
		var velocity := NavalBallistics.velocity(solution.direction,weapon,moving)
		var predicted := NavalBallistics.position(origin,velocity,float(NavalCatalog.WEAPONS[weapon].gravity),float(solution.time),weapon,0)
		if weapon=="torpedo": predicted.y=origin.y
		check(solution.valid and predicted.distance_to(point) < 0.02,weapon+" solver includes inherited velocity")
	# Close-range island collision: drive into the convex coast.
	ship.global_position = Vector3(-260,0,-95)
	ship.heading = 0.0
	ship.speed = 28.0
	ship.velocity = Vector3(0,0,-28)
	await physics_frame
	for i in range(70):
		battle.set_control(101,1.0,0.0,Vector3(-260,0,-300),"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(ship.global_position.z > -145.0,"convex island stops hull penetration")
	# Ship-to-ship collision is handled by the same movement physics.
	ship.global_position = Vector3(0,0,20)
	ship.heading = 0.0
	ship.speed = 20.0
	ship.velocity = Vector3(0,0,-20)
	target.global_position = Vector3(0,0,0)
	target.speed = 0.0
	target.velocity = Vector3.ZERO
	await physics_frame
	for i in range(45):
		battle.set_control(101,1.0,0.0,Vector3(0,0,-300),"lightMG",false)
		battle.advance(NavalCatalog.STEP)
		await physics_frame
	check(ship.global_position.distance_to(target.global_position)>7.0,"ships cannot pass through each other")
	var report := {"checks":count,"failures":failures}
	FileAccess.open("res://tests/naval-physics-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	branch.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
