extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func ray(a: Vector3,b: Vector3,excludes: Array[RID]=[]) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,CombatRules.SHOT_MASK,excludes);q.collide_with_areas=true
	return game.get_world_3d().direct_space_state.intersect_ray(q)
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	var manager:=game.vehicle_system as WarVehicles;manager.set_process(false)
	var pilot:=game.local_player as WarPlayer;var enemy:=game.players[2] as WarPlayer
	pilot.position=Vector3(0,100,0);enemy.position=Vector3(20,100,0)
	game.members[1].drone_used=false;pilot.set_meta("drone_enabled",true)
	manager.launch_drone(1)
	check(pilot.vehicle_id.begins_with("drone_"),"drone launch is reserved by authority")
	var drone:=manager.find_target(pilot.vehicle_id) as WarDrone
	drone.position=Vector3(10,115,-10)
	await physics_frame
	var point: Vector3=pilot.hit_regions.chest.global_position
	var body_hit:=ray(point+Vector3(5,0,0),point-Vector3(2,0,0))
	var body:=body_hit.get("collider") as Node
	check(is_instance_valid(body) and body.has_meta("hit_region") and pilot.is_ancestor_of(body),"live body hitboxes remain physically shootable during remote control")
	game._apply_hit(2,body_hit,10,"chest","glock",Vector3.LEFT)
	check(pilot.hp<100 and pilot.vehicle_id.is_empty() and drone.falling,"a real body hit damages the operator and cuts the control link")
	var old:=drone.position
	for i in 15: drone.simulate(1./60.,{"lift":1.,"fire":true})
	check(drone.position.y<old.y and drone.velocity.y<0,"falling drone loses altitude despite stale flight input")
	var replica:=WarDrone.new();replica.drone_id="replica";manager.add_child(replica);replica.receive(drone.snapshot())
	check(replica.falling and replica.driver==0,"observers receive the same falling state")
	replica.queue_free()
	await physics_frame
	var drone_hit:=ray(drone.position+Vector3(3,0,0),drone.position-Vector3(3,0,0))
	check(not drone_hit.is_empty() and drone_hit.collider==drone,"falling drone also retains projectile contact")
	manager.damage_from_hit(2,drone_hit.get("collider"),100,"ak",Vector3.LEFT)
	check(drone.destroyed and not manager.drones.has(drone.drone_id),"a bullet can destroy a drone and retire its collider")
	# A live TV missile has a pooled physical volume. Infantry swept rays
	# must collide with it, without making it collide with itself.
	var fx:=game.war_fx as WarProjectiles
	var extra: Dictionary=WarRules.TV_MISSILE.duplicate();extra.guided=true;extra.tv_vehicle="v_guarani";extra.tv_life=pilot.life_id;extra.tv_epoch=0;extra.tv_linked=false
	extra.speed=30.;extra.gravity=0.
	check(fx.spawn(1,Vector3(0,120,0),Vector3.FORWARD,"tv",true,"qa-tv-intercept",extra),"TV round enters the shared projectile pool")
	var shot:=fx.find_round("qa-tv-intercept")
	await physics_frame
	fx._step(shot,1./60.)
	check(shot.active,"missile excludes its own physical hitbox")
	fx._physics_process(0.)
	await physics_frame
	var missile_hit:=ray(Vector3(shot.position)+Vector3(3,0,0),Vector3(shot.position)-Vector3(3,0,0))
	check(not missile_hit.is_empty() and missile_hit.collider.has_meta("tv_shot_id"),"a bullet ray physically contacts the TV missile")
	game._confirm_impact(2,missile_hit,{"id":"glock","damage":30.},"qa-intercept-bullet",Vector3.LEFT)
	check(not shot.active and not manager.tv.flights.has("qa-tv-intercept"),"validated missile hit destroys the round and removes its camera link")
	var collider: Area3D=fx.tv_colliders[int(fx.by_id["qa-tv-intercept"])]
	check(collider.collision_layer==0,"destroyed TV missile cannot block subsequent bullets")
	# Destruction is idempotent; no second impact or point award.
	var before:=manager.blast_events.size();fx.intercept_tv("qa-tv-intercept",2,100)
	check(manager.blast_events.size()==before,"late repeated hits do not explode a destroyed missile again")
	fx._physics_process(.1)
	var count:=fx.tv_colliders.size()
	fx.spawn(1,Vector3(0,120,0),Vector3.FORWARD,"tv",true,"qa-tv-blast",extra)
	check(fx.tv_colliders.size()==count,"TV physical volume is reused with its projectile slot")
	manager.explode(2,Vector3(1,120,0),100,4,"tank","qa-blast")
	check(not fx.find_round("qa-tv-blast").active,"an explosive hit also intercepts a TV missile")
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/bugs187-air-results.json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
