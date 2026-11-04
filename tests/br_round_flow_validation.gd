extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var checks:=0
var failures: Array[String]=[]
var game: BattleRoyaleGame
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame
	game.flat_world()
	for id in [1,2,3]:
		var actor:=game._spawn_player(id,id==1,false,Vector3(id*4,0,0))
		actor.set_physics_process(false);actor.set_process(false);game._stage_infantry(actor)
	game.phase="waiting";game.round_start_clock=130.
	game._step_br_authority(.1)
	check(game.phase=="waiting" and game.local_player.hp==0,"waiting players staged, no manual spawn")
	check(game._state_for(1).death_notice=="","waiting participant is not reported as eliminated")
	game.test_clock=130.;game._step_br_authority(.1)
	check(game.phase=="active" and game.br_generation==1 and game.br_round.alive_ids().size()==3,"30-second countdown starts one round")
	for actor: BRPlayer in game.players.values():
		check(actor.hp==100. and actor.weapon_id=="fists" and actor.loadout.is_empty() and actor.ammo.is_empty() and actor.reserves.is_empty(),"each participant starts fully healthy and unarmed")
	var actor:=game.players[1] as BRPlayer;var target:=game.players[2] as BRPlayer
	actor.global_position=Vector3.ZERO;target.global_position=Vector3(0,0,-1)
	actor._animate_walk();target._animate_walk()
	game.punch_history.clear();game.punch_history.record(game.players,130.)
	var current: Dictionary=game.punch_history.contact(game.players,1,Vector3(0,1.30,0),Vector3(0,1.30,-1.35),130.,0.)
	check(not current.is_empty() and game._impact_character(current.collider)==target,"punch requires swept contact with a real regional box")
	target.global_position.x=2.5;target._animate_walk();game.punch_history.record(game.players,130.12)
	var rewound:=game.punch_history.contact(game.players,1,Vector3(0,1.30,0),Vector3(0,1.30,-1.35),130.12,.12)
	check(not rewound.is_empty() and game._impact_character(rewound.collider)==target,"bounded latency rewind restores short valid contact")
	check(game.punch_history.contact(game.players,1,Vector3(0,1.30,0),Vector3(0,1.30,-1.35),130.12,0.).is_empty(),"current contact misses displaced target")
	target.life_id+=1
	check(game.punch_history.contact(game.players,1,Vector3(0,1.30,0),Vector3(0,1.30,-1.35),130.12,.12).is_empty(),"history from another life never causes a hit")
	target.life_id-=1
	var before:=int(game.br_round.participants[1].shots)
	game._server_accept_shot(1,1,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,"fists",0)
	game._server_accept_shot(1,2,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,"fists",0)
	check(game.br_round.participants[1].shots==before+1,"server punch cadence rejects a second simultaneous request")
	target.global_position=Vector3(0,0,-1);target._animate_walk()
	actor.punch_clock=.20;actor._pose_fists();game.test_clock=130.16;game.punch_history.clear()
	game.resolve_br_punch(actor)
	check(target.hp<100.,"active animation window inflicts an actual short punch hit")
	var wall:=StaticBody3D.new();game.world_root.add_child(wall);wall.position=Vector3(0,1.4,-.40)
	var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(2.,2.,.15);wall_shape.shape=wall_box;wall.add_child(wall_shape)
	await physics_frame;await physics_frame
	var protected_hp:=target.hp;game.test_clock=130.20;game.resolve_br_punch(actor)
	check(target.hp==protected_hp,"current solid wall blocks a rewound punch")
	wall.free();await physics_frame
	var gear:=game.br_inventory.add_loot({"kind":"weapon","weapon":"fal","magazine":2,"position":Vector3(.5,0,0)})
	game._br_action(1,"pickup",{"id":gear},actor.life_id,game.br_generation)
	check(actor.weapon_id=="fal" and actor.punch_clock==0.,"equip interrupts the previous punch window")
	game._apply_hit(2,{"collider":actor.hit_regions.chest,"position":actor.global_position},1000.,"chest","fal",Vector3.RIGHT)
	check(actor.hp==0 and game.phase=="active" and game.spectating_id==2,"death chooses killer spectator without respawn")
	game.test_clock=131.1;game.spectator_tpp=false;game._update_spectator(0.)
	check(game.spectator.current and game.spectator_hidden_owner==2 and not game.spectator_hidden.is_empty(),"FPP spectator hides only target body from its camera")
	var first_visual: GeometryInstance3D=game.spectator_hidden.keys()[0]
	var original:=int(game.spectator_hidden[first_visual]);game.spectator_tpp=true;game._update_spectator(0.)
	check(game.spectator_hidden.is_empty() and first_visual.layers==original,"TPP restores all target render layers")
	game._apply_hit(2,{"collider":game.players[3].hit_regions.chest,"position":game.players[3].global_position},1000.,"chest","fal",Vector3.RIGHT)
	check(game.phase=="finished" and game.br_round.winner==2 and is_equal_approx(game.restart_at,191.1),"last survivor starts exactly 60-second intermission")
	check(game._state_for(2).death_notice=="" and not str(game._state_for(1).death_notice).is_empty(),"winner result has no death notice while victim retains cause")
	var winner:=game.players[2] as BRPlayer;var old_weapon:=winner.weapon_id
	game._equip_server(winner,"fists");game._server_reload(2,winner.weapon_id)
	check(winner.weapon_id==old_weapon and winner.reload_left==0.,"finished round ignores equip and reload requests")
	game._server_accept_shot(2,99,winner.life_id,winner.camera_pivot.global_position,Vector3.FORWARD,winner.weapon_id,0)
	check(int(game.shot_sequences.get(2,0))==99,"rejected phase-transition shot still acknowledges prediction")
	game.test_clock=190.9;game._step_br_authority(.1)
	check(game.phase=="finished" and game.br_generation==1,"no early restart")
	game.test_clock=191.1;game._step_br_authority(.1)
	check(game.phase=="waiting" and is_equal_approx(game.round_start_clock,221.1) and actor.hp==0.,"intermission timer stages cohort for fresh30second countdown")
	# Keep this contact-focused fixture at three humans; bot-fill behavior has
	# its own production queue suite, which checks all twelve participants.
	while game.players.size()>3:game._remove_queue_bot()
	game.test_clock=game.round_start_clock;game._step_br_authority(.1)
	check(game.phase=="active" and game.br_generation==2 and actor.hp==100 and actor.weapon_id=="fists","postintermission queue starts fresh round with no residual equipment")
	# Every final-circle victim resolves before determining the winner.
	for member: GamePlayer in game.players.values():member.hp=1.;member.global_position=Vector3(100,0,100)
	game.br_zone.started_at=game._now()-925.;game.zone_clock=1.;game._step_br_authority(.016)
	check(game.phase=="finished" and game.br_round.alive_ids().is_empty() and game.br_round.winner==-1,"same environmental tick can eliminate all without arbitrary survivor")
	game.test_clock=game.restart_at;game._step_br_authority(.1)
	while game.players.size()>3:game._remove_queue_bot()
	game.test_clock=game.round_start_clock;game._step_br_authority(.1)
	game._peer_disconnected(3)
	check(not game.players.has(3) and not game.br_round.is_alive(3) and game.phase=="active","disconnect eliminates survivor and removes actor")
	game._peer_disconnected(2)
	check(game.phase=="finished" and game.br_round.winner==1,"last opponent disconnect awards remaining survivor")
	game.test_clock=game.restart_at;game._step_br_authority(.1)
	check(game.phase=="waiting" and game.round_start_clock>game._now() and game.players.size()==12,"one remaining human returns to30second queue with server bots")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Production authority with deterministic clock:30second wait, unarmed spawn, punch contacts/rewind/life/cadence, spectating, victory,60second results then30second rematch, same-tick zone tie and disconnect. Flat scene, no FPS claim."}
	NavalStorage.write_json("res://work/br-round-flow-validation.json",report);print("BR_ROUND_FLOW_VALIDATION ",JSON.stringify(report))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
