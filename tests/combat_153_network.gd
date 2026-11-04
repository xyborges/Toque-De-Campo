extends SceneTree
var game: Node3D
var role:="server"
var failures: Array[String]=[]
var saw_damage_number:=false
var saw_damage:=false
var saw_grenade:=false
var observed_events: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func wait_for(test: Callable,seconds:=8.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(game.grenades_system):
			if not game.grenades_system.rounds.is_empty(): saw_grenade=true
			if not game.grenades_system.events.is_empty(): observed_events=game.grenades_system.events.keys()
		if is_instance_valid(game.damage_numbers) and not game.damage_numbers.active.is_empty(): saw_damage_number=true
		if is_instance_valid(game.local_player) and game.local_player.hp<100: saw_damage=true
		if test.call(): return true
	failures.append("timeout: "+str(game.phase))
	return false
func run() -> void:
	game=load("res://tests/combat_153_network_fixture.gd").new();game.name="ToqueDeCampo";game.set_meta("test_mode",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		game.dedicated_pvp=true;game.host_game("pvp");await server_flow()
	else:
		game.join_game("pvp")
		await wait_for(func(): return game.players.size()==2 and is_instance_valid(game.local_player))
		if role=="shooter": await shooter_flow()
		else: await target_flow()
	var result: Dictionary={"role":role,"failures":failures,"grenade_seen":saw_grenade,"explosions":observed_events,"damage_number":saw_damage_number,"received_damage":saw_damage}
	NavalStorage.write_json("res://tests/combat-153-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.15).timeout
	quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func(): return game.players.size()==2): return
	await create_timer(.5).timeout
	var shooter: GamePlayer
	var target: GamePlayer
	for actor: GamePlayer in game.players.values():
		if actor.name=="shooter": shooter=actor
		else: target=actor
	shooter.grenade_selected=true;shooter._animate_walk()
	var launch: Dictionary=game.grenades_system.launch_state(shooter,Vector3.FORWARD)
	var prediction: Dictionary=game.grenades_system.predict(launch)
	target.global_position=Vector3(prediction.position)+Vector3(3,0,0);target.global_position.y=0
	game._broadcast("remote_player_respawn",[target.peer_id,target.global_position,target.life_id])
	game._broadcast("qa_phase",["grenade"])
	if not await wait_for(func(): return game.reports.has("grenade"),12): return
	game._broadcast("qa_phase",["disconnect"])
	if not await wait_for(func(): return game.players.size()==1): return
	game._broadcast("qa_phase",["waiting"])
	if not await wait_for(func(): return game.reports.has("waiting")): return
	if not await wait_for(func(): return game.players.size()==2): return
	game._broadcast("qa_phase",["resume"])
	if not await wait_for(func(): return game.reports.has("resumed"),18): return
	game._broadcast("qa_phase",["finish"])
	await create_timer(.5).timeout
func shooter_flow() -> void:
	var actor: GamePlayer=game.local_player
	actor.yaw=0;actor.rotation.y=0;actor.pitch=0;actor.camera_pivot.rotation=Vector3.ZERO;actor._animate_walk()
	if not await wait_for(func(): return game.phase=="grenade"): return
	game.request_grenade(actor)
	await wait_for(func(): return not observed_events.is_empty(),11)
	if actor.grenades!=1: failures.append("grenade inventory not synchronized")
	if not saw_damage_number: failures.append("shooter did not receive authoritative blast damage number")
	game.rpc_id(1,"qa_report","grenade",{})
	if not await wait_for(func(): return game.phase=="waiting"): return
	game.infantry_hud.refresh()
	if not game.infantry_hud.waiting.visible: failures.append("waiting notice missing after opponent leaves")
	for weapon in ["fal","sniper"]:
		actor.weapon_id=weapon;actor._refresh_weapon();actor.shot_sequence+=1
		actor.pending_shots[actor.shot_sequence]=weapon;actor.ammo[weapon]=0
		game.rpc_id(1,"server_shot_request",actor.shot_sequence,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,weapon,0)
		await wait_for(func(): return actor.pending_shots.is_empty())
		if int(actor.ammo[weapon])!=int(GameWeapons.ITEMS[weapon].mag): failures.append("predicted empty magazine stuck after disconnect: "+weapon)
	game.rpc_id(1,"qa_report","waiting",{})
	if not await wait_for(func(): return game.phase=="resume"): return
	for weapon in ["fal","sniper"]:
		game.request_equip(actor,weapon)
		await wait_for(func(): return actor.weapon_id==weapon)
		await create_timer(.2).timeout;actor.fire_cooldown=0;actor.fire()
		await wait_for(func(): return actor.pending_shots.is_empty())
		if int(actor.ammo[weapon])!=int(GameWeapons.ITEMS[weapon].mag)-1: failures.append("fire failed after rejoin: "+weapon)
		actor.start_reload()
		await wait_for(func(): return actor.reload_left>0)
		await wait_for(func(): return actor.reload_left<=0,7)
		# The local countdown may finish one transport tick before the reliable
		# authoritative inventory. Completion means both timer and inventory.
		await wait_for(func(): return int(actor.ammo[weapon])==int(GameWeapons.ITEMS[weapon].mag),2)
		if int(actor.ammo[weapon])!=int(GameWeapons.ITEMS[weapon].mag): failures.append("reload failed after rejoin: "+weapon)
	game.rpc_id(1,"qa_report","resumed",{})
	await wait_for(func(): return game.phase=="finish")
func target_flow() -> void:
	await wait_for(func(): return game.phase=="disconnect",15)
	if not saw_grenade or not saw_damage or observed_events.is_empty(): failures.append("remote grenade/damage/explosion did not replicate")
	if saw_damage_number: failures.append("victim received enemy damage reward numbers")
	game.show_menu();await create_timer(2).timeout
	game.join_game("pvp")
	await wait_for(func(): return game.players.size()==2 and is_instance_valid(game.local_player))
	await wait_for(func(): return game.phase=="finish",24)
