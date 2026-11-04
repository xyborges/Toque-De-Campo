extends SceneTree
var game: Node3D
var role:="old"
var failures: Array[String]=[]
var previous:=0
var saw_grenade:=false
var saw_explosion:=false
var saw_number:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func wait_for(test: Callable, seconds:=12.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(game.grenades_system):
			saw_grenade=saw_grenade or not game.grenades_system.rounds.is_empty()
			saw_explosion=saw_explosion or not game.grenades_system.events.is_empty()
		if is_instance_valid(game.damage_numbers): saw_number=saw_number or not game.damage_numbers.active.is_empty()
		if test.call(): return true
	return false
func run() -> void:
	game=load("res://scripts/main.gd").new();game.name="ToqueDeCampo";root.add_child(game)
	await process_frame
	if not await wait_for(func(): return not is_instance_valid(game.naval_mode) and game.menu_layer.visible): failures.append("account startup did not finish")
	await game.join_game("pvp")
	if not await wait_for(func(): return is_instance_valid(game.local_player) and game.players.size()==2 and game.pvp_spawn_confirmed):
		failures.append("authenticated players did not join")
	else:
		if role=="old":
			previous=game.local_player.peer_id
			FileAccess.open("res://work/ubuntu-reconnect-ready.txt",FileAccess.WRITE).store_string(str(previous))
			if not await wait_for(func(): return not game.online,20): failures.append("old signed session was not replaced")
			if game.mode!="menu" or not game.players.is_empty(): failures.append("replaced session did not reset to menu")
		else:
			if not await wait_for(func(): return FileAccess.file_exists("res://work/ubuntu-reconnect-ready.txt")): failures.append("old session marker missing")
			previous=int(FileAccess.get_file_as_string("res://work/ubuntu-reconnect-ready.txt"))
			if role=="observer":
				if not await wait_for(func(): return game.online and game.players.size()==2 and not game.players.has(previous),20): failures.append("observer retained old avatar or lost connection")
			else:
				var actor: GamePlayer=game.local_player
				if actor.peer_id==previous or game.players.has(previous): failures.append("replacement has stale identity")
				actor.yaw=0;actor.rotation.y=0;actor.pitch=0;actor.camera_pivot.rotation=Vector3.ZERO
				game.rpc_id(1,"server_player_state",actor.global_position,0.,0.,actor.weapon_id,false,0,actor.life_id)
				await create_timer(.25).timeout
				game.rpc_id(1,"server_grenade_request",actor.life_id,1,actor.camera_pivot.global_position,Vector3.FORWARD)
			if not await wait_for(func(): return saw_grenade and saw_explosion,12): failures.append("central grenade spawn/explosion did not replicate")
			if role=="new" and game.local_player.grenades!=1: failures.append("central grenade count was not decremented")
			await create_timer(.4).timeout
	var result: Dictionary={"role":role,"failures":failures,"online":game.online,"players":game.players.size(),"grenade":saw_grenade,"explosion":saw_explosion,"replaced_id":previous}
	NavalStorage.write_json("res://tests/ubuntu-reconnect-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();await create_timer(.4).timeout;game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
