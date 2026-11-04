extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var branch := Node.new()
	root.add_child(branch)
	var network := NavalNetwork.new()
	branch.add_child(network)
	network.require_accounts = false
	network.accounts["qa"] = {"id":"qa","owned":["light","heavy"],"selected":"light"}
	var room := {"id":NavalCatalog.uid(),"match":NavalCatalog.uid(),"map_seed":1739,"members":[],"stats":{},"state":"IN_PROGRESS"}
	var battle := NavalMatch.new()
	branch.add_child(battle)
	battle.build(network,room)
	battle.add_player(11,{"identity":"qa","ship":"light","name":"Teste"})
	var ship: NavalShip = battle.ships[11]
	ship.global_position = Vector3(600,0,600)
	check(battle.can_change_ship(11,"heavy").is_empty(),"full undamaged ship may change")
	ship.hp -= 1
	check(not battle.can_change_ship(11,"heavy").is_empty(),"damaged ship cannot change")
	ship.hp = float(ship.spec.hp)
	ship.last_damage_at = battle.time
	check(not battle.can_change_ship(11,"heavy").is_empty(),"recent damage blocks change even after healing")
	battle.time += 11
	check(battle.can_change_ship(11,"heavy").is_empty(),"ten seconds without damage unlock change")
	var old_id := ship.ship_id
	battle.change_ship(11,"heavy")
	ship = battle.ships[11]
	check(ship.kind=="heavy" and ship.ship_id!=old_id and ship.turrets.size()==4,"change rebuilds real ship, hitboxes and weapons")
	check(ship.hp==240 and ship.global_position.distance_to(Vector3(600,0,600))<0.01,"change preserves position with correct full hull life")
	check(not battle.can_change_ship(11,"light").is_empty(),"change cooldown prevents continuous refill")
	var cam := NavalCamera.new()
	battle.world.add_child(cam)
	cam.global_position = Vector3(600,15,650)
	cam.look_at(Vector3(600,0,100))
	var aim := cam.aim_point(ship,0)
	var stable := true
	for t in range(50): stable = stable and cam.aim_point(ship,float(t)).distance_to(aim)<0.001
	check(stable,"fixed camera aim does not oscillate with wave time")
	var gun: NavalTurret = ship.turrets.lightMG
	ship.rotation = Vector3.ZERO
	ship.aim = Vector3(600,0,0)
	for i in range(180): gun.step(ship.aim,Vector3.ZERO,NavalCatalog.STEP)
	var errors: Array[float] = []
	for speed in [Vector3.ZERO,Vector3(4,0,-10),Vector3(-7,0,5)]:
		for i in range(60): gun.step(ship.aim,speed,NavalCatalog.STEP)
		var launch := gun.launch(speed,10)
		var predicted := NavalBallistics.prediction(battle.world.get_world_3d(),launch,[ship.get_rid()])
		errors.append(predicted.impact.distance_to(ship.aim))
	check(errors.all(func(value: float): return value<0.1),"guide hits stable desired sea point including inherited X/Z motion")
	var visual_world := NavalWorld.new()
	root.add_child(visual_world)
	visual_world.build(true,1739)
	check(visual_world.mountain_index==battle.world.mountain_index,"mountain layout matches authority from room seed")
	for i in range(250): visual_world.effect(Vector3.ZERO,Color.ORANGE,1.0,0.1)
	check(visual_world.effects.size()==128,"effect limit bounds simultaneous effects")
	visual_world._process(1.0)
	var pooled := visual_world.effect_pool.size()
	visual_world.effect(Vector3.ZERO,Color.ORANGE,1.0)
	check(visual_world.effect_pool.size()==pooled-1,"effects reuse pooled nodes and meshes")
	var tracer := NavalProjectileVisual.new()
	visual_world.add_child(tracer)
	tracer.build()
	tracer.setup("lightMG")
	var shot := {"origin":Vector3(0,3,0),"velocity":Vector3(4,0,-600),"gravity":12.0,"weapon":"lightMG","time":0.0}
	tracer.update_shot(shot,0.5,Vector3.ZERO)
	check(tracer.global_position.distance_to(NavalBallistics.position(shot.origin,shot.velocity,12,0.5,"lightMG",0))<0.001,"tracer tip shares exact projectile position and gravity")
	visual_world.queue_free()
	branch.queue_free()
	await process_frame
	var result := {"checks":checks,"failures":failures,"guide_errors":errors}
	FileAccess.open("res://tests/naval-upgrade-results.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
