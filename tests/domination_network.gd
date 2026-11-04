extends SceneTree
var game: Node3D
var role:="server"
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(test: Callable,seconds:=10.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if test.call(): return true
	failures.append("timeout "+str(game.phase));return false
func report(label: String) -> void: game.rpc_id(1,"qa_report",role+":"+label,{})
func announce(label: String) -> void: game._broadcast("qa_phase",[label])
func move_actor(actor: GamePlayer,point: Vector3) -> void:
	actor.life_id+=1;actor.position=point;actor.velocity=Vector3.ZERO;actor.network_target=point;actor.has_network_state=false
	game.state_clocks.erase(actor.peer_id);game._broadcast("remote_player_respawn",[actor.peer_id,point,actor.life_id])
func run() -> void:
	game=load("res://tests/domination_network_fixture.gd").new();game.name="ToqueDeCampo";game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		game.dedicated_pvp=true;game.host_game("pvp");game.domination.set_physics_process(false);await server_flow()
	else:
		game.join_game("pvp")
		if await wait_for(func():return game.players.size()==2 and is_instance_valid(game.local_player)):
			game.set_physics_process(false);game.local_player.set_physics_process(false)
			if role=="shooter": await shooter_flow()
			else: await target_flow()
	var result: Dictionary={"role":role,"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/domination-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2): return
	var shooter: GamePlayer;var target: GamePlayer
	for actor: GamePlayer in game.players.values():
		if actor.name=="shooter": shooter=actor
		else: target=actor
	announce("ready")
	if not await wait_for(func():return game.reports.size()==2): return
	move_actor(shooter,Vector3(0,.16,12));move_actor(target,Vector3(10,.16,12));announce("old_state")
	if not await wait_for(func():return game.reports.has("shooter:old_sent")): return
	await create_timer(.25).timeout;check(shooter.position.distance_to(Vector3(0,.16,12))<.01,"stale previous-life movement cannot undo respawn")
	announce("buried_state")
	if not await wait_for(func():return game.reports.has("shooter:buried_sent")): return
	await create_timer(.25).timeout;check(shooter.position.y>DesertTerrain.height_at(shooter.position.x,shooter.position.z),"server corrects a below-ground movement state")
	move_actor(shooter,Vector3(0,.16,-7));move_actor(target,Vector3(10,.16,12));game.domination.set_physics_process(true);announce("capture")
	if not await wait_for(func():return int(game.domination.scores.get(shooter.peer_id,0))>=1): return
	check(game.domination.owner_id==shooter.peer_id,"real-time server capture awards the sole occupant")
	if not await wait_for(func():return game.reports.has("shooter:captured") and game.reports.has("target:captured")): return
	move_actor(shooter,Vector3(-3.35,.16,-5.3))
	for weapon in shooter.ammo: shooter.ammo[weapon]=0;shooter.reserves[weapon]=0
	shooter.grenades=0;game.sync_inventory(shooter);announce("supply")
	if not await wait_for(func():return game.reports.has("shooter:supply")): return
	check(shooter.ammo.fal==30 and shooter.ammo.glock==12 and shooter.ammo.sniper==5 and shooter.reserves.fal==180 and shooter.grenades==2,"network supply refills authoritative magazines, reserves and grenades")
	check(game.domination.supply_wait(shooter.peer_id)>18,"network supply cooldown stays on authority")
	move_actor(target,Vector3(0,.16,-5));announce("contest")
	await create_timer(.3).timeout;var score: int=game.domination.scores[shooter.peer_id]
	await create_timer(1.3).timeout;check(game.domination.contested and int(game.domination.scores[shooter.peer_id])==score,"two real clients inside stop control points")
	if not await wait_for(func():return game.reports.has("shooter:contest") and game.reports.has("target:contest")): return
	move_actor(shooter,Vector3(0,.16,12));announce("opponent")
	if not await wait_for(func():return int(game.domination.scores.get(target.peer_id,0))>=1): return
	if not await wait_for(func():return game.reports.has("shooter:opponent") and game.reports.has("target:opponent")): return
	announce("leave")
	if not await wait_for(func():return game.players.size()==1 and game.domination.phase=="waiting"): return
	var clock: float=game.domination.remaining;await create_timer(1).timeout
	check(is_equal_approx(clock,game.domination.remaining) and game.domination.owner_id==0,"disconnect removes owner and pauses round timer")
	announce("waiting")
	if not await wait_for(func():return game.reports.has("shooter:waiting")): return
	announce("finish");await create_timer(.4).timeout
func shooter_flow() -> void:
	var actor: GamePlayer=game.local_player
	if not await wait_for(func():return game.phase=="ready"): return
	report("ready")
	if not await wait_for(func():return game.phase=="old_state"): return
	game.rpc_id(1,"server_player_state",actor.position+Vector3.RIGHT,0.,0.,actor.weapon_id,false,0,actor.life_id-1);report("old_sent")
	if not await wait_for(func():return game.phase=="buried_state"): return
	game.rpc_id(1,"server_player_state",actor.position-Vector3.UP*.7,0.,0.,actor.weapon_id,false,0,actor.life_id);report("buried_sent")
	if not await wait_for(func():return game.phase=="capture"): return
	check(actor.position.y>=DesertTerrain.height_at(actor.position.x,actor.position.z),"client receives safe authoritative position")
	await observe_capture(actor.peer_id);report("captured")
	if not await wait_for(func():return game.phase=="supply" and actor.ammo.fal==0): return
	game.request_supplies(actor)
	if not await wait_for(func():return actor.ammo.fal==30 and actor.reserves.fal==180 and actor.grenades==2): return
	check(actor.ammo.glock==12 and actor.ammo.sniper==5,"restocked inventory reaches client")
	game.rpc_id(1,"server_supply_request",actor.life_id);report("supply")
	if not await wait_for(func():return game.phase=="contest" and game.domination.contested): return
	check(game.domination.occupants.size()==2,"client HUD receives contested occupants");report("contest")
	if not await wait_for(func():return game.phase=="opponent"): return
	var enemy_id:=0
	for id in game.players:
		if int(id)!=actor.peer_id: enemy_id=int(id)
	await observe_capture(enemy_id);report("opponent")
	if not await wait_for(func():return game.phase=="waiting"): return
	game.infantry_hud.refresh();check(game.infantry_hud.waiting.visible and game.domination.phase=="waiting","last player sees waiting notice and paused objective");report("waiting")
	await wait_for(func():return game.phase=="finish")
func target_flow() -> void:
	if not await wait_for(func():return game.phase=="ready"): return
	report("ready")
	if not await wait_for(func():return game.phase=="capture"): return
	var enemy_id:=0
	for id in game.players:
		if int(id)!=game.local_player.peer_id: enemy_id=int(id)
	await observe_capture(enemy_id);report("captured")
	if not await wait_for(func():return game.phase=="contest" and game.domination.contested): return
	check(game.domination.occupants.size()==2,"observer receives contested objective state");report("contest")
	if not await wait_for(func():return game.phase=="opponent"): return
	await observe_capture(game.local_player.peer_id);report("opponent")
	if not await wait_for(func():return game.phase=="leave"): return
	game.show_menu();await create_timer(2).timeout
func observe_capture(id: int) -> void:
	if not await wait_for(func():return game.domination.owner_id==id and int(game.domination.scores.get(id,0))>=1): return
	game.infantry_hud.refresh();game.update_hud()
	check(game.infantry_hud.domination_panel.visible and game.infantry_hud.domination_title.text.contains("DOMINAÇÃO"),"HUD displays server domination and scores")
	await create_timer(.1).timeout;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/update-155-domination-network-"+role+"-"+str(id)+".png")
