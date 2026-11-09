extends SceneTree
# Deterministic world-physics regression. Simulates a trapped infantryman
# and an occupied hostile APC without starting a networked release.
var game: WarGame
var director: WarBotDirector
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error("BOT_ESCAPE_ARMOR_FAIL "+label)

func _box(parent: Node3D,point: Vector3,size: Vector3,name_key: String) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=name_key
	body.position=point
	body.collision_layer=1
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size;shape.shape=box
	body.add_child(shape)
	parent.add_child(body)
	return body

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	WarRules.configure(WarOperation.UKRAINE)
	game=load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(game)
	await physics_frame
	director=WarBotDirector.new()
	director.game=game
	director.navigation=WarBotDirector.BotRoutes.new()
	director.navigation.setup(game)
	var actor:=game.local_player as WarPlayer
	actor.apply_identity(0,"soldier")
	actor.set_physics_process(false)
	actor.hp=100.;actor.deployed=true
	# The optic fixture spawns an undeployed actor at y=0 with disabled body
	# collision. Real Guerra respawn restores it on the terrain surface.
	actor.collision_layer=4
	actor.collision_mask=1|16
	actor.body_collision.set_deferred("disabled",false)
	actor.global_position=WarTerrain.point(0.,0.)+Vector3.UP*.17
	var start:=actor.global_position
	var flat:=_box(game.world_root,start+Vector3(0,-.65,-7),Vector3(70,1,70),"EscapeFlatFloor")
	await physics_frame
	# A long wall inserted AFTER navigation preparation reproduces an
	# unexpected collider/prop that an old nav cache cannot route around.
	var barrier:=_box(game.world_root,start+Vector3(0,1,-5),Vector3(10,2,1.8),"EscapeTestBarrier")
	var goal:=start+Vector3(0,0,-14)
	var record: Dictionary={"goal":goal,"objective":"C","target":0,"direction":Vector3.FORWARD,"line_clear":false,"last_position":start,"stuck":0.,"defend_all":false,"foot_path":[]}
	director.bots={1:record}
	director.bot_ids=[1]
	var first_escape:=false
	var min_distance:=INF
	var previous_escape_count:=0
	for tick in 840:
		game.war_clock+=1./60.
		var to_goal:=goal-actor.global_position;to_goal.y=0.
		record.direction=director._avoid(actor,to_goal.normalized())
		director._move(actor,record,1./60.)
		if int(director.diagnostics.foot_escapes)>previous_escape_count:
			previous_escape_count=int(director.diagnostics.foot_escapes)
			print("BOT_ESCAPE_WAYPOINT ",JSON.stringify({"tick":tick,"at":actor.global_position,"point":record.get("escape_point",Vector3.INF),"goal":goal}))
		if Vector3(record.get("escape_point",Vector3.INF)).is_finite():first_escape=true
		min_distance=minf(min_distance,actor.global_position.distance_to(goal))
		await physics_frame
	var obstacle_result={"start":start,"finish":actor.global_position,"goal":goal,"closest":min_distance,"foot_escapes":director.diagnostics.foot_escapes}
	print("BOT_ESCAPE_ROUTE ",JSON.stringify(obstacle_result))
	check(first_escape,"persistent escape activates when blocked by an unplanned wall")
	check(min_distance<5.,"infantry moves around the obstruction toward the goal")
	check(int(director.diagnostics.foot_escapes)<=10,"recovery uses bounded re-plans")
	# A defender holding a controlled flag must never be mistaken for trapped.
	var escapes_before:=int(director.diagnostics.foot_escapes)
	record.defend_all=true
	record.goal=actor.global_position+Vector3(0,0,5)
	record.direction=Vector3.ZERO
	record.escape_point=Vector3.INF
	for tick in 100:
		game.war_clock+=1./60.
		director._move(actor,record,1./60.)
		await physics_frame
	check(int(director.diagnostics.foot_escapes)==escapes_before,"intentional defense hold does not trigger escape")
	barrier.queue_free()
	await physics_frame
	# Armor response: with no anti-armor gear, an occupied APC ahead must
	# trigger a tactical retreat/cover action instead of an approach.
	var manager:=game.vehicle_system as WarVehicles
	for vehicle: WarVehicle in manager.vehicles.values():vehicle.global_position=start+Vector3(400,0,400)
	actor.global_position=start
	actor.velocity=Vector3.ZERO
	actor.war_team=0
	game.members[1].team=0
	var apc:=manager.vehicles["v_bmp2"] as WarVehicle
	apc.global_position=start+Vector3(0,0,-31)
	apc.team=1
	apc.hp=600.;apc.destroyed=false
	apc.driver=2
	var enemy:=game.players[2] as WarPlayer
	enemy.vehicle_id=apc.vehicle_id
	game.members[2].vehicle=apc.vehicle_id
	# A reachable side wall offers physical cover from the APC's gun.
	var cover:=_box(game.world_root,start+Vector3(7,1,-10),Vector3(4,3,3),"ArmorCoverWall")
	record={"goal":goal,"objective":"C","squad":"0:0","team":0,"slot":2,"target":0,"direction":Vector3.FORWARD,"line_clear":false,"last_position":start,"stuck":0.,"defend_all":false,"next_support":9999.,"next_grenade":9999.}
	director.bots={1:record}
	director.squads={"0:0":{"team":0,"members":[1],"objective":"C"}}
	await physics_frame
	var perceived:=director._visible_vehicle(actor,115.,true)
	check(is_instance_valid(perceived) and perceived==apc,"hostile occupied APC is perceived inside danger range")
	if is_instance_valid(perceived):
		director._think(1)
	check(str(record.get("armor_cover_vehicle",""))==apc.vehicle_id,"ordinary rifleman reacts through the actual bot decision loop")
	var reaction: Vector3=record.get("direction",Vector3.ZERO)
	var cover_point: Vector3=record.get("armor_cover_point",Vector3.INF)
	var retreat:=cover_point.is_finite() and cover_point.distance_to(apc.global_position)>start.distance_to(apc.global_position)
	print("BOT_APC_REACTION ",JSON.stringify({"direction":reaction,"cover":cover_point,"distance":apc.global_position.distance_to(start),"new_distance":apc.global_position.distance_to(cover_point) if cover_point.is_finite() else -1.,"evades":director.diagnostics.armor_evades}))
	check(retreat and reaction.length()>.1,"rifleman turns away from enemy APC rather than pushing forward")
	var shot_query:=PhysicsRayQueryParameters3D.create(apc.global_position+Vector3.UP*1.8,cover_point+Vector3.UP*1.3,1|16,[apc.get_rid(),actor.get_rid()])
	var shield:=game.get_world_3d().direct_space_state.intersect_ray(shot_query)
	check(not shield.is_empty() and shield.get("collider")==cover,"selected cover physically intercepts the APC's firing lane")
	check(int(director.diagnostics.armor_evades)>0,"tactical armor reaction is counted")
	# A parked/empty hostile hull is not an immediate threat.
	apc.driver=0
	check(director._visible_vehicle(actor,115.,true)==null,"unoccupied APC does not cause endless infantry retreat")
	cover.queue_free();flat.queue_free()
	director.free();game.queue_free()
	await process_frame
	print("BOT_ESCAPE_ARMOR_QA ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
