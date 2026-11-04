extends SceneTree

var game: WarGame
var errors: Array[String]=[]

func check(value: bool,message: String) -> void:
	if not value: errors.append(message)

func _initialize() -> void:
	run.call_deferred()

func wait_for(test: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if test.call(): return true
	return false

func real_hit(pole: WarPowerPole,height: float) -> Dictionary:
	var space:=game.world_root.get_world_3d().direct_space_state
	var centre:=pole.global_position+Vector3.UP*height
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var query:=PhysicsRayQueryParameters3D.create(centre-direction,centre+direction,1)
		var hit:=space.intersect_ray(query)
		if not hit.is_empty() and hit.collider==pole: return hit
	return {}

func run() -> void:
	game=load("res://tests/war_pole_contact_fixture.gd").new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.power_grid),120.): errors.append("world readiness");finish();return
	if not game.setup_contact_adapter(): errors.append("adapter setup");finish();return
	await physics_frame
	var original: String=game.real_power_state();var first_id: String=game.pole_ids[1]
	var pole:=game.power_grid.poles[first_id] as WarPowerPole
	var hit:=real_hit(pole,1.8)
	if hit.is_empty(): errors.append("could not find clear real pole ray");finish();return
	var inactive: Dictionary=game.contact_adapter.shot(hit,120.,Vector3.RIGHT)
	check(not inactive.handled and game.pole_model.broken.is_empty(),"adapter must start disabled")
	game.contact_adapter.enabled=true
	game._confirm_impact(0,hit,{"id":"fal","damage":60.},"qa-pole-shot-1",Vector3.RIGHT)
	check(game.pole_model.broken.is_empty(),"first server shot accumulates without breaking")
	game._confirm_impact(0,hit,{"id":"fal","damage":60.},"qa-pole-shot-2",Vector3.RIGHT)
	check(game.contact_adapter.events.size()==1,"real projectile collision triggered fracture")
	if not game.contact_adapter.events.is_empty(): check(int(game.contact_adapter.events[0].height_cm)==180,"fracture height follows actual hit point")
	check(game.real_power_state()==original,"original power grid remains unchanged")
	var parent: Node3D=load("res://tests/war_pole_contact_parent.gd").new();parent.game=game;parent.adapter=game.contact_adapter;parent.lab=game.pole_lab;game.world_root.add_child(parent)
	# Search an unobstructed, reasonably level real-pole approach. This may
	# fail rather than fake a vehicle contact when a map change blocks it.
	var chosen: Dictionary={}
	var space:=game.world_root.get_world_3d().direct_space_state
	for id: String in game.pole_ids:
		if id==first_id: continue
		var target:=game.power_grid.poles[id] as WarPowerPole
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			var start: Vector3=target.global_position-direction*7.
			if absf(WarTerrain.height_at(start.x,start.z)-target.global_position.y)>.20: continue
			var query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*1.2,target.global_position+Vector3.UP*1.2,1)
			var approach:=space.intersect_ray(query)
			if not approach.is_empty() and approach.collider==target:
				chosen={"pole":target,"start":start,"direction":direction};break
		if not chosen.is_empty(): break
	if chosen.is_empty(): errors.append("no clear real-pole vehicle approach")
	else:
		var vehicle:=WarVehicle.new();vehicle.kind="guarani";vehicle.vehicle_id="qa_real_pole_vehicle";parent.add_child(vehicle)
		vehicle.global_position=chosen.start+Vector3.UP*.08
		var direction: Vector3=chosen.direction;vehicle.heading=atan2(-direction.x,-direction.z);vehicle.speed=8.
		for tick in 120:
			await physics_frame
			vehicle.simulate(1./60.,{"throttle":.4,"steer":0.,"aim":chosen.pole.global_position+Vector3.UP})
			if not parent.events.is_empty(): break
		check(parent.events.size()==1,"real vehicle collision triggered fracture")
		if not parent.events.is_empty(): check(int(parent.events[0].height_cm)>=70 and int(parent.events[0].height_cm)<=670,"contact height is bounded")
	parent.queue_free()
	check(game.real_power_state()==original,"vehicle test left original grid intact")
	check(game.pole_errors.is_empty(),"adapter reported no invalid contacts")
	finish()

func finish() -> void:
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"scope":"actual pole shapes and QA WarVehicle, test-only adapter; normal manager and grid unchanged"}))
	quit(0 if errors.is_empty() else 1)
