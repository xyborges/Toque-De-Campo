extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures.append(text)
func member(id: int) -> WarPlayer:
	var actor:=game._spawn_player(id,false,false,WarTerrain.point(-560,0)) as WarPlayer
	actor.set_physics_process(false)
	game.members[id]={"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.0,"shield":0.0,"gadget":"rpg","pending":{},"last_gadget":-100.0}
	return actor
func run() -> void:
	var teams: Dictionary={}
	for i in 12:
		var side:=i%2
		check(WarRules.choose_team(side,teams)==side,"balanced team slot "+str(i))
		teams[i+1]=side
	check(WarRules.choose_team(0,teams)==-1 and WarRules.choose_team(1,teams)==-1,"six-player team cap")
	check(WarRules.choose_team(0,{1:0})==-1,"no two versus zero deployment")
	check(not WarRules.OBJECTIVES.D.active and not WarRules.OBJECTIVES.E.active,"future objectives D and E stay inactive")
	var states:=WarRules.fresh_objectives()
	for i in 180: WarRules.capture(states.A,[1,0],.1)
	check(states.A.owner==0,"neutral sector captured by living numerical advantage")
	for i in 180: WarRules.capture(states.A,[0,1],.1)
	check(states.A.owner==-1,"enemy sector must first be neutralized")
	for i in 180: WarRules.capture(states.A,[0,1],.1)
	check(states.A.owner==1,"neutralized sector captured in second cycle")
	WarRules.capture(states.B,[1,0],4)
	var progress: float=states.B.progress
	WarRules.capture(states.B,[2,2],4)
	check(states.B.contested and is_equal_approx(states.B.progress,progress),"equal contest freezes capture")
	WarRules.capture(states.B,[0,0],4)
	check(is_equal_approx(states.B.progress,progress),"idle capture grace period")
	WarRules.capture(states.B,[0,0],3)
	check(states.B.progress<progress,"abandoned partial capture regresses")
	var slow: Dictionary=WarRules.fresh_objectives().A
	var fast: Dictionary=WarRules.fresh_objectives().A
	WarRules.capture(slow,[1,0],1);WarRules.capture(fast,[5,0],1)
	check(is_equal_approx(fast.progress,slow.progress*2),"numerical advantage is capped at double capture rate")
	game=WarGame.new();game.set_meta("war_host",true);game.set_meta("war_test",true);game.set_meta("test_mode",true)
	root.add_child(game)
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	await physics_frame
	var a:=member(701);var b:=member(702)
	check(game._deploy(701,0,"soldier","fal","rpg","base"),"server approves first legal deployment")
	check(not game._deploy(702,0,"soldier","fal","rpg","base"),"server rejects unbalanced deployment")
	check(game._deploy(702,1,"antitank","fal","rpg","base"),"server approves opposing deployment")
	check(game._battle_active(),"one player on each side activates conquest")
	game.local_player=a
	game.remote_wallet(240,["broom"])
	check(a.weapon_id=="fal" and "fal" in a.active_weapons(),"account wallet refresh preserves class rifle independently of shop inventory")
	game.local_player=null
	var packet: Dictionary={"id":"round-reset-check","owner":a.peer_id,"life":a.life_id,"sequence":1,"origin":a.position+Vector3.UP,"velocity":Vector3.ZERO,"fuse":4.,"held":true,"revision":0}
	game.grenades_system.spawn(packet)
	game.grenades_system.reset_round()
	game.grenades_system.spawn(packet)
	check(game.grenades_system.rounds.is_empty() and a.grenade_held_id.is_empty(),"round reset removes armed grenades and rejects delayed snapshots")
	check(a.get_meta("human_war_mesh",false) and b.get_meta("human_war_mesh",false),"server and clients use human rig geometry")
	check(a.avatar_parts.head.mesh.get_aabb().size.x<.4,"proportional human head replaces half-meter block")
	check(a.hit_regions.head.get_child(0).shape.size.x<.4,"head region matches new head silhouette")
	check(a.get_meta("war_class")=="soldier" and b.get_meta("war_class")=="antitank","class identity reaches actual avatar")
	for actor in [a,b]:
		var p: Vector3=actor.global_position
		var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*2,1)
		check(not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"deployment rests above real terrain "+str(actor.peer_id))
	var trench:=Vector2(-200,-65)
	var depth:=WarTerrain._base(trench.x,trench.y)-WarTerrain.height_at(trench.x,trench.y)
	check(depth>1.7,"trench is excavated into physical terrain")
	var crater: Vector3=WarTerrain.CRATERS[0]
	check(WarTerrain.height_at(crater.x,crater.z)<WarTerrain._base(crater.x,crater.z)-1.5,"crater is a physical depression")
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values():
		for angle in [-2.5,-1.0,0.0,1.4,2.9]:
			vehicle.rotation=Vector3(.06,angle,.03)
			var target: Vector3=vehicle.turret.global_position+Vector3(30,8,-80)
			vehicle.aim(0,target,true)
			var expected: Vector3=(target-vehicle.muzzle.global_position).normalized()
			var actual: Vector3=-vehicle.muzzle.global_basis.z.normalized()
			check(actual.dot(expected)>.9999,"actual muzzle follows world target: "+vehicle.kind+" heading "+str(angle))
		vehicle.aim(0,vehicle.global_position+Vector3(0,900,-1),true)
		check(is_equal_approx(vehicle.gun_pitch,vehicle.spec.pitch_max),"elevation respects upper limit: "+vehicle.kind)
		vehicle.ammo=0
		var reserve:=vehicle.reserve
		check(vehicle.start_reload(),"finite reserve reload begins: "+vehicle.kind)
		vehicle.simulate(float(vehicle.spec.reload)+.1,{})
		check(vehicle.ammo==vehicle.capacity() and vehicle.reserve==reserve-vehicle.capacity(),"reload transfers finite rounds: "+vehicle.kind)
	var drone:=WarDrone.new();drone.drone_id="test_drone";drone.operator_origin=WarTerrain.point(0,0);drone.position=drone.operator_origin+Vector3(700,10,0)
	game.world_root.add_child(drone)
	drone.simulate(.1,{})
	check(drone.global_position.distance_to(drone.operator_origin)<=500.01,"drone maximum control range")
	check(drone.battery<65,"drone battery drains under authority")
	for path in GameCombatAudioCatalog.EXPLOSIONS+GameCombatAudioCatalog.EXPLOSIONS_FAR+[GameCombatAudioCatalog.PISTOL]:
		check(GameCombatAudioCatalog.stream(path)!=null,"user-provided sound loads: "+path.get_file())
	var picks: Dictionary={}
	for kind in ["grenade","tank","drone"]: picks[GameCombatAudioCatalog.explosion_type(kind)]=true
	check(picks.size()==3,"all three supplied explosion types have distinct routing")
	check(GameCombatAudioCatalog.explosion_type("destroy")==GameCombatAudioCatalog.explosion_type("tank"),"vehicle destruction uses the tank ammunition sample")
	game.members[701].drone_used=true
	a.hp=0;game.members[701].ready_at=0
	check(game._deploy(701,0,"medic","fal","rpg","base") and not game.members[701].drone_used,"respawn refreshes class resources and per-life drone")
	check(game.members[701].charges==4,"medic receives class-specific resource count")
	game.match_ended=true;game.tickets=[0,250]
	game.reset_operation()
	check(game.tickets==[300,300] and not game.match_ended and not a.deployed and not b.deployed,"new operation resets tickets, deployment and equipment state")
	var result: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/war-systems-results.json",result);print(JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
