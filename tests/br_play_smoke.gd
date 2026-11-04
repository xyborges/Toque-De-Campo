extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game:=BattleRoyaleGame.new();game.set_meta("test_mode",true);root.add_child(game)
	for i in 6:await physics_frame
	var queue_ok: bool=game.phase=="waiting" and game.players.size()==8 and game._state_for(1).roster.size()==8
	var wait_left:=maxf(0.,game.round_start_clock-game._now())
	queue_ok=queue_ok and wait_left>28. and wait_left<=30.
	await create_timer(wait_left+.15).timeout
	for i in 180:await physics_frame
	var report:={"ok":queue_ok and game.phase=="active" and game.players.size()==8 and is_instance_valid(game.afghan_map) and game.br_inventory.world_loot.size()>100,"queue_valid":queue_ok,"wait_observed":wait_left,"phase":game.phase,"participants":game.players.size(),"loot":game.br_inventory.world_loot.size(),"round":game.br_generation,"scope":"Offline full Afghan map with seven real BR bots: real30second pairing timer and three seconds of normal combat physics; no FPS claim."}
	NavalStorage.write_json("res://work/br-play-smoke.json",report);print("BR_PLAY_SMOKE ",JSON.stringify(report))
	game.leave_match();await create_timer(.05).timeout;game.free();await process_frame;quit(0 if report.ok else 1)
