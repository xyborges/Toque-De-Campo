extends SceneTree
## Headless geometry and navigation checks for the Favela production map.
## Add -- --favela-bot-traversal --naval-test-accounts with an isolated data
## directory to run the two controlled crossings with the live WarBotDirector.
var failures: Array[String]=[]
var samples:=0
var capsule:=CapsuleShape3D.new()

func _initialize() -> void:
	if "--favela-bot-traversal" in OS.get_cmdline_user_args():
		_bot_traversal.call_deferred()
	else:
		_run.call_deferred()

func require(value: bool,message: String) -> void:
	if not value:failures.append(message)

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world:=Node3D.new()
	root.add_child(world)
	WarWorld.build(world,false)
	var map:=world.get_node("FavelaWar") as WarFavelaMap
	var transit:=WarBotTransit.new()
	transit.install_rooftops(map.roof_paths)
	capsule.radius=.30
	capsule.height=1.56
	await physics_frame
	await physics_frame

	var metrics: Dictionary=map.build_metrics
	require(int(metrics.compact_frontages)>850 and int(metrics.open_forecourts)>85,
		"Faltam frentes compactas ou recuos planejados")
	require(int(metrics.covered_passages)>30 and int(metrics.parked_cars)>0,
		"Passagens cobertas ou carros fora da via ausentes")
	require(int(metrics.service_drops)>80 and int(metrics.facade_modules)>15000 and int(metrics.roof_lean_tos)>200,
		"Faltam ligacoes individuais ou modulos de fachada")
	var stairs:=0
	var bridges:=0
	var supports:=0
	var clearance:=0
	for path: PackedVector3Array in map.roof_paths:
		if path.size()==4:
			bridges+=1
			var route:=transit.roof_path(path[0],path[-1])
			require(route.size()>=4 and route[-1].is_equal_approx(path[-1]),
				"Passarela desconectada do grafo: "+str(path[0]))
		else:
			stairs+=1
			var route:=transit.roof_path(path[0],path[-1])
			require(route.size()>=7 and route[-1].is_equal_approx(path[-1]),
				"Escada desconectada do grafo: "+str(path[0]))
		for segment in path.size()-1:
			var from:=path[segment]
			var to:=path[segment+1]
			var count:=maxi(1,ceili(from.distance_to(to)/.35))
			for step in count+1:
				var p:=from.lerp(to,float(step)/count)
				samples+=1
				var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.14,p-Vector3.UP*.36,1)
				var hit:=root.world_3d.direct_space_state.intersect_ray(ray)
				if hit.is_empty() or Vector3(hit.normal).y<.65:
					supports+=1
					if supports<=6:print("FAVELA_ARCH_NO_FLOOR ",p," stairs=",path.size()>4," step=",segment)
					continue
				var query:=PhysicsShapeQueryParameters3D.new()
				query.shape=capsule
				query.transform.origin=Vector3(hit.position)+Vector3.UP*.93
				query.collision_mask=1
				if not root.world_3d.direct_space_state.intersect_shape(query,1).is_empty():
					clearance+=1
					if clearance<=6:print("FAVELA_ARCH_NO_CLEARANCE ",p," stairs=",path.size()>4," step=",segment)
	require(stairs>=60 and bridges>=10,"Rede vertical incompleta")
	require(supports==0,"Amostras sem piso caminhavel: "+str(supports))
	require(clearance==0,"Amostras sem folga para infantaria: "+str(clearance))

	for objective: Dictionary in WarRules.OBJECTIVES.values():
		var route:=transit.path(WarRules.BASES[0],objective.position,true)
		require(route.size()>2,"Objetivo desconectado da rede de veiculos")
	var catalogs:=["janela_grade","janela_madeira","porta_entrada","sacada","laje_domestica",
		"laje_obra","escada_externa","carro_compacto","puxadinho_chapa"]
	for item: String in catalogs:
		var id:="favela_"+item
		var prefab:=WarPrefabFactory.create(id)
		require(prefab!=null and WarPrefabFactory.ITEMS.has(id) and prefab.get_meta("library_id","")==id,
			"Modulo nao catalogado: "+id)
		if prefab!=null:prefab.free()
	print("FAVELA_ARCHITECTURE ",JSON.stringify({"stairs":stairs,"bridges":bridges,
		"physical_samples":samples,"failures":failures}))
	quit(0 if failures.is_empty() else 1)


func _bot_traversal() -> void:
	var game:=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.offline_participants=3
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+45000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready:
		print("BOT_VERTICAL FAIL: loading")
		quit(1)
		return
	game.request_deploy(0,"soldier","fal","","base")
	while game.bot_director.bots.size()<2 and Time.get_ticks_msec()<deadline:
		await process_frame
	var director:=game.bot_director
	if director.bots.size()<2:
		print("BOT_VERTICAL FAIL: bot deployment")
		quit(1)
		return
	director.set_physics_process(false)
	var id: int=director.bots.keys()[0]
	var actor:=game.players[id] as WarPlayer
	var map:=game.world_root.get_node("FavelaWar") as WarFavelaMap
	var reached:=0
	for length in [9,4]:
		var chosen:=PackedVector3Array()
		var nearest:=INF
		for path: PackedVector3Array in map.roof_paths:
			if path.size()!=length:continue
			var dist:=path[0].distance_squared_to(WarTerrain.point(-190,-15))
			if dist<nearest:
				nearest=dist
				chosen=path
		if chosen.is_empty():continue
		actor.global_position=chosen[0]+Vector3.UP*.07
		actor.velocity=Vector3.ZERO
		var record: Dictionary=director.bots[id].duplicate()
		record.roof_path=PackedVector3Array()
		record.roof_goal=Vector3.INF
		var goal:=chosen[-1]
		for tick in 750:
			await physics_frame
			record.direction=director._route_direction(actor,goal,record)
			director._move(actor,record,1.0/60.0)
			if actor.global_position.distance_to(goal)<.58:
				reached+=1
				break
		print("BOT_VERTICAL ", "stairs" if length>4 else "bridge",
			" remaining_m=",snappedf(actor.global_position.distance_to(goal),.001))
	game.queue_free()
	await process_frame
	print("BOT_VERTICAL ",reached,"/2")
	quit(0 if reached==2 else 1)
