extends SceneTree
## Exercita o WarGame real offline: criacao, equipes, frota, terrain, respawn.
## Nao altera save de usuario nem publica a operacao.
var game: WarGame
var checks:=0
var failures: Array[String]=[]

func verify(condition: bool,description: String) -> void:
	checks+=1
	if not condition:
		failures.append(description)
		push_error("FAVELA_RUNTIME_FAIL "+description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	var bot_qa: bool="--favela-bots" in OS.get_cmdline_user_args()
	if bot_qa:game.offline_participants=29
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+45000
	while is_instance_valid(game) and not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not is_instance_valid(game) or not game.join_ready:
		print("FAVELA_RUNTIME ",JSON.stringify({"ok":false,"failure":"No join_ready","checks":checks}))
		quit(1)
		return
	if not bot_qa:game.set_physics_process(false)
	var manager:=game.vehicle_system as WarVehicles
	if not bot_qa:
		manager.set_physics_process(false)
		manager.set_process(false)
		if is_instance_valid(game.bot_director):game.bot_director.stop()
	verify(game.operation_id==WarOperation.FAVELA,"WarGame abriu operação errada")
	verify(game.world_root!=null and is_instance_valid(game.world_root.get_node_or_null("FavelaWar")),"Mundo Favela inexistente")
	verify(game.objective_states.size()==5,"Estados de captura ausentes")
	verify(game.supply_points.size()==5,"Caixas de suprimento ausentes")
	verify(manager.vehicles.size()==8,"Frota deve ter 2 Guaranis + 6 motos")
	for key in ["v_guarani_0","v_guarani_1"]:
		var vehicle:=manager.vehicles.get(key) as WarVehicle
		verify(is_instance_valid(vehicle),key+" não criado")
		if is_instance_valid(vehicle):
			verify(vehicle.team==0,key+" pertence a equipe errada")
			verify(vehicle.global_position.distance_to(WarRules.BASES[0])<45,key+" saiu da base")
	for key in manager.vehicles:
		var vehicle:=manager.vehicles[key] as WarVehicle
		var contact:=KinematicCollision3D.new()
		var overlapping:=vehicle.test_move(vehicle.global_transform,Vector3.ZERO,contact,.001,true)
		print("FAVELA_VEHICLE_SPAWN ",key," position=",vehicle.global_position," overlap=",overlapping," depth=",contact.get_depth() if overlapping else 0.0)
		verify(not overlapping or contact.get_depth()<.03,str(key)+" sobreposto à arquitetura")
		verify(vehicle.kind in ["guarani","bike_0","bike_1"],str(key)+" proibido")
		if vehicle.kind.begins_with("bike"):
			verify(vehicle.team==int(vehicle.kind.trim_prefix("bike_")),str(key)+" equipe incorreta")
	var loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",0)
	var deploy:=game._deploy(1,0,"soldier",str(loadout.primary),"","base",loadout)
	verify(deploy,"Implantação de soldado policial falhou")
	if deploy:
		var actor:=game.players[1] as WarPlayer
		verify(actor.war_team==0 and actor.deployed,"Policial não recebeu identidade")
		verify(not actor.gadget_equipped,"Policial iniciou com lançador")
		verify(actor.global_position.distance_to(WarRules.BASES[0])<60,"Policial nasceu longe da base")
	if bot_qa:
		var bot_deadline:=Time.get_ticks_msec()+20000
		while game.bot_director.bots.size()<28 and Time.get_ticks_msec()<bot_deadline:
			await process_frame
		verify(game.bot_director.bots.size()==28,"População de 28 bots não foi criada")
		var active:=0
		for id in game.bot_director.bots:
			var player:=game.players.get(id) as WarPlayer
			if is_instance_valid(player) and player.deployed and player.hp>0:active+=1
		verify(active>=26,"Bots não conseguiram implantar: "+str(active))
		for frame in 75:await physics_frame
		print("FAVELA_BOTS ",JSON.stringify({"count":game.bot_director.bots.size(),"deployed":active,"diagnostics":game.bot_director.diagnostics}))
	print("FAVELA_RUNTIME ",JSON.stringify({"ok":failures.is_empty(),
		"checks":checks,"failures":failures,"vehicles":manager.vehicles.size(),
		"world_build_ms":game.world_build_ms}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
