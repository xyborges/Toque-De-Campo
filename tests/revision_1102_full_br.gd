extends SceneTree
class ProfileBrain extends BRBotBrain:
	var decisions_us:=0
	var decisions:=0
	var path_us:=0
	func _decide(game: BattleRoyaleGame,actor: BRPlayer,now: float) -> void:
		var stamp:=Time.get_ticks_usec();super._decide(game,actor,now);decisions_us+=Time.get_ticks_usec()-stamp;decisions+=1
	func _set_target(game: BattleRoyaleGame,actor: BRPlayer,to: Vector3,now: float) -> void:
		var stamp:=Time.get_ticks_usec();super._set_target(game,actor,to,now);path_us+=Time.get_ticks_usec()-stamp
class ProfileActor extends BRPlayer:
	var physics_us:=0
	var poses_us:=0
	var calls:=0
	func _physics_process(delta: float) -> void:
		var stamp:=Time.get_ticks_usec();super._physics_process(delta);physics_us+=Time.get_ticks_usec()-stamp;calls+=1
	func _animate_walk() -> void:
		var stamp:=Time.get_ticks_usec();super._animate_walk();poses_us+=Time.get_ticks_usec()-stamp
class ProfileGame extends BattleRoyaleGame:
	var physics_us:=0
	var calls:=0
	func _new_player() -> GamePlayer:return ProfileActor.new()
	func _physics_process(delta: float) -> void:
		var stamp:=Time.get_ticks_usec();super._physics_process(delta);physics_us+=Time.get_ticks_usec()-stamp;calls+=1
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var game:=ProfileGame.new()
	game.bot_brain=ProfileBrain.new();game.set_meta("test_mode",true);root.add_child(game)
	for frame in 8:await physics_frame
	check(is_instance_valid(game.navigation) and game.navigation.ready,"full prepared map/navigation loaded")
	game.offline_operation=false
	for id in [2,3]:
		var actor:=game._spawn_player(id,false,false,game.find_spawn(id));actor.name="QA %d"%id
		game.br_inventory.add_player(id);game._stage_infantry(actor)
	game._fill_queue_bots()
	check(game.players.size()==31,"full map contains three humans and 28 authority bots")
	game.round_start_clock=game._now();game.start_br_round()
	check(game.phase=="active" and game.br_round.participants.size()==31,"31 accessible spawns allow round to start")
	check(game.br_inventory.world_loot.size()>100,"reachable contextual loot generated")
	check(game.motorbikes.bikes.size()>=8,"motorcycles placed near map settlements/roads")
	var start: Dictionary={}
	for actor: BRPlayer in game.players.values():
		if actor.br_bot:start[actor.peer_id]=actor.global_position
	var start_tick:=Engine.get_physics_frames();var stamp:=Time.get_ticks_usec()
	await create_timer(45.).timeout
	var actor_cpu:=0;var pose_cpu:=0
	for item: ProfileActor in game.players.values():actor_cpu+=item.physics_us;pose_cpu+=item.poses_us
	var physics_ticks:=maxi(1,Engine.get_physics_frames()-start_tick)
	var profile:={"wall_seconds":(Time.get_ticks_usec()-stamp)*.000001,"ticks":physics_ticks,"actors_ms_per_tick":actor_cpu*.001/physics_ticks,"game_ms_per_tick":game.physics_us*.001/physics_ticks,"pose_ms_per_tick":pose_cpu*.001/physics_ticks,"decisions_ms_per_tick":game.bot_brain.decisions_us*.001/physics_ticks,"path_ms_per_tick":game.bot_brain.path_us*.001/physics_ticks}
	var moved:=0;var armed:=0;var largest_physics_ms:=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
	for id in start:
		var actor: BRPlayer=game.players[id]
		if actor.global_position.distance_to(start[id])>2.:moved+=1
		if not actor.loadout.is_empty():armed+=1
	check(moved>=20,"at least twenty bots progress along physical routes")
	check(armed>0,"bots acquire actual world weapons")
	var report:={"checks":checks,"failures":failures,"ok":failures.is_empty(),"participants":game.players.size(),"moving_bots":moved,"armed_bots":armed,"bikes":game.motorbikes.bikes.size(),"loot":game.br_inventory.world_loot.size(),"last_physics_ms":largest_physics_ms,"script_profile":profile,"bot_sample":game.players[100000].global_position,"bot_target":game.players[100000].bot_target,"scope":"Complete production Afghan map, prepared navigation and 28 server bot actors for 45 seconds. Local authority with three human stand-ins; networking verified separately. No FPS or sustained server-capacity claim."}
	NavalStorage.write_json("res://work/revision-1102-full-br.json",report);print("FULL_BR_1102 ",JSON.stringify(report))
	game.leave_match();await process_frame;game.free();await process_frame
	quit(0 if failures.is_empty() else 1)
