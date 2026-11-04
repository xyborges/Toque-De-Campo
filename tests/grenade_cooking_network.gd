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
func wait_for(test: Callable,seconds:=12.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if test.call(): return true
	failures.append("timeout "+str(game.phase));return false
func run() -> void:
	game=load("res://tests/combat_153_network_fixture.gd").new();game.name="ToqueDeCampo";game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		game.dedicated_pvp=true;game.host_game("pvp");await server_flow()
	else:
		game.join_game("pvp")
		if await wait_for(func():return game.players.size()==2 and is_instance_valid(game.local_player)):
			if role=="shooter": await shooter_flow()
			else: await target_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/grenade-cooking-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2): return
	var shooter: GamePlayer
	for actor: GamePlayer in game.players.values():
		if actor.name=="shooter": shooter=actor
	game._equip_server(shooter,"fal")
	game.environment_seconds=180
	game._broadcast("remote_environment_time",[180.0]);game._broadcast("qa_phase",["select"])
	if not await wait_for(func():return game.reports.has("selected")): return
	game._broadcast("qa_phase",["prime"])
	if not await wait_for(func():return not shooter.grenade_held_id.is_empty()): return
	var first:=shooter.grenade_held_id
	var ammo: int=shooter.ammo.fal
	game._server_accept_shot(shooter.peer_id,123,shooter.life_id,shooter.camera_pivot.global_position,Vector3.FORWARD,"fal")
	check(shooter.ammo.fal==ammo,"authority rejects firearm while holding armed grenade")
	await create_timer(2).timeout;game._broadcast("qa_phase",["throw"])
	if not await wait_for(func():return game.grenades_system.events.has(first)): return
	check(shooter.grenades==1,"one reserved grenade consumed for entire cooking/throw sequence")
	game._broadcast("qa_phase",["death_prime"])
	if not await wait_for(func():return not shooter.grenade_held_id.is_empty()): return
	var second:=shooter.grenade_held_id
	await create_timer(1.1).timeout;shooter.take_damage(200,"chest",0)
	check(game.grenades_system.rounds.has(second) and not game.grenades_system.rounds[second].held,"death drops armed grenade on authority")
	game._broadcast("qa_phase",["death_drop"])
	if not await wait_for(func():return game.grenades_system.events.has(second)): return
	check(not game.grenades_system.rounds.has(second),"death drop detonates once and is removed")
	if not await wait_for(func():return game.reports.has("observer_done")): return
	game._broadcast("qa_phase",["finish"]);await create_timer(.5).timeout
func shooter_flow() -> void:
	var actor: GamePlayer=game.local_player
	if not await wait_for(func():return game.phase=="select"): return
	actor.equip_grenade()
	if not await wait_for(func():return game.phase=="prime"): return
	game.prime_grenade(actor)
	if not await wait_for(func():return not actor.grenade_held_id.is_empty()): return
	var id:=actor.grenade_held_id
	check(actor.grenades==1,"reserved inventory reaches firing client")
	if not await wait_for(func():return game.phase=="throw"): return
	game.request_grenade(actor)
	if not await wait_for(func():return game.grenades_system.rounds.has(id) and not game.grenades_system.rounds[id].held): return
	check(float(game.grenades_system.rounds[id].left)<3.1,"two seconds cooking are preserved after launch")
	if not await wait_for(func():return game.phase=="death_prime"): return
	game.prime_grenade(actor)
	if not await wait_for(func():return not actor.grenade_held_id.is_empty()): return
	if not await wait_for(func():return game.phase=="finish",14): return
func target_flow() -> void:
	var actor: GamePlayer
	for other: GamePlayer in game.players.values():
		if not other.is_local: actor=other
	if not await wait_for(func():return actor.grenade_selected): return
	actor._update_grenade_pose();actor._update_view()
	check(not actor.weapon_root.visible and actor.avatar_parts.head.visible and actor.avatar_parts.torso.visible,"observer sees complete body holding grenade without gun")
	check(absf(float(game.environment_seconds)-180)<3,"server environment clock reaches observer")
	game.rpc_id(1,"qa_report","selected",{})
	if not await wait_for(func():return not actor.grenade_held_id.is_empty()): return
	var first:=actor.grenade_held_id
	check(game.grenades_system.rounds[first].held and actor.grenade_fuse_left>4.3,"observer sees grenade in hand and shared fuse")
	if not await wait_for(func():return game.grenades_system.rounds.has(first) and not game.grenades_system.rounds[first].held): return
	check(actor.grenade_throw_left>0 and float(game.grenades_system.rounds[first].left)<3.1,"throw animation and remaining fuse reach observer")
	if not await wait_for(func():return game.grenades_system.events.has(first)): return
	if not await wait_for(func():return not actor.grenade_held_id.is_empty()): return
	var second:=actor.grenade_held_id
	if not await wait_for(func():return game.grenades_system.rounds.has(second) and bool(game.grenades_system.rounds[second].drop)): return
	check(float(game.grenades_system.rounds[second].left)<4.1,"death drop keeps the same remaining fuse on observer")
	if not await wait_for(func():return game.grenades_system.events.has(second)): return
	check(game.grenades_system.events.size()==2,"observer receives exactly two explosion events")
	game.rpc_id(1,"qa_report","observer_done",{})
	await wait_for(func():return game.phase=="finish")
