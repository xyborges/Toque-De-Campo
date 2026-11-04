extends SceneTree
var role := "host"
var screens := ""
var game: Node3D
var failures: Array[String] = []
var held_fal_shots:=0
var post_grenade_fal_shots:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--screens="): screens = arg.trim_prefix("--screens=")
	run.call_deferred()
func wait_for(condition: Callable, seconds := 8.0) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if condition.call(): return true
	return false
func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.name = "ToqueDeCampo"
	root.add_child(game)
	await process_frame
	await wait_for(func(): return not is_instance_valid(game.naval_mode) and game.menu_layer.visible)
	game.profile["equipped"] = "glock"
	await game.join_game("pvp")
	if not await wait_for(func(): return is_instance_valid(game.local_player) and game.players.size()==2):
		failures.append("two authenticated players did not join central PvP: "+game.status_label.text)
	else:
		if game.players.has(1): failures.append("dedicated server created a phantom player")
		if game.profile.nickname != str(game.main_accounts.profile.username): failures.append("account username did not load")
		if game.local_player.hp>0 or not game.local_player.active_weapons().is_empty(): failures.append("player spawned before loadout confirmation")
		var deployment:=game.deployment_panel as GameInfantryDeployment
		if not await wait_for(func(): return deployment.visible): failures.append("pre-spawn loadout did not open")
		deployment.editor.slots={"primary":"fal","sidearm":"glock","grenade":"grenade"};deployment.editor._rebuild();deployment.editor._changed();deployment.confirm.pressed.emit()
		if not await wait_for(func(): return game.local_player.hp>0 and game.local_player.weapon_id=="fal" and not game.ui_focus.blocked()): failures.append("confirmed loadout did not deploy")
		if not await wait_for(func():
			for player in game.players.values():
				if player.hp<=0: return false
			return true
		): failures.append("opponent did not confirm deployment")
		if role=="host":
			await create_timer(.5).timeout
			game.request_equip(game.local_player,"fal")
			await create_timer(0.6).timeout
			var actor: GamePlayer = game.local_player
			actor.yaw = 0.0
			actor.pitch = 0.0
			actor.rotation.y = 0.0
			game.send_player_state(actor)
			await create_timer(0.3).timeout
			game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			var before:=actor.shot_sequence;actor.fire_cooldown=0
			var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;actor._unhandled_input(press)
			await create_timer(.8).timeout;held_fal_shots=actor.shot_sequence-before
			if held_fal_shots<6 or not actor.trigger_held: failures.append("held FAL stopped during authoritative inventory acknowledgements")
			var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;actor._unhandled_input(release)
			actor.equip_grenade();await physics_frame;await physics_frame;actor.equip_slot(4);await create_timer(.2).timeout
			before=actor.shot_sequence;actor.fire_cooldown=0;actor._unhandled_input(press);actor._unhandled_input(release)
			if actor.shot_sequence!=before+1 or actor.grenade_aiming: failures.append("central Glock blocked after cancelling grenade")
			actor.equip_slot(3);await create_timer(.2).timeout
		if not await wait_for(func(): return game.seen_shots.size()>0): failures.append("authoritative shot did not replicate")
		await create_timer(0.5).timeout
		game.third_person=false;game.local_player._update_view()
		for actor: GamePlayer in game.players.values():
			if not actor.is_local:
				for part in actor.avatar_parts.values():
					if not part.visible: failures.append("remote body part hidden in FPP")
		if role=="host":
			game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			game.local_player.equip_quick_slot(3)
			await wait_for(func():return game.local_player.grenade_selected)
			game.prime_grenade(game.local_player)
			if not await wait_for(func():return not game.local_player.grenade_held_id.is_empty()): failures.append("central prime rejected")
			else:
				var grenade_id: String=game.local_player.grenade_held_id
				await create_timer(1.5).timeout
				var ammo: int=game.local_player.ammo.fal;game.local_player.fire_cooldown=0;game.local_player.fire()
				if game.local_player.ammo.fal!=ammo or game.local_player.view_root.visible: failures.append("armed grenade did not hide/block firearm")
				game.request_grenade(game.local_player)
				if not await wait_for(func():return game.grenades_system.events.has(grenade_id),9): failures.append("central cooked explosion missing")
				if game.local_player.grenades!=1: failures.append("central cooked grenade spent wrong count")
				game.local_player.equip_slot(3)
				var before: int=game.local_player.shot_sequence
				game.local_player.trigger_held=true;game.local_player.fire_cooldown=0;game.local_player.fire()
				await create_timer(.55).timeout
				post_grenade_fal_shots=game.local_player.shot_sequence-before;game.local_player.trigger_held=false
				if post_grenade_fal_shots<4: failures.append("central FAL blocked after grenade exploded")
		else:
			if not await wait_for(func():return not game.grenades_system.rounds.is_empty()): failures.append("central remote grenade missing")
			else:
				var grenade_id: String=game.grenades_system.rounds.keys()[0]
				var packet: Dictionary=game.grenades_system.rounds[grenade_id]
				var remote: GamePlayer=game.players[int(packet.owner)]
				if not packet.held or remote.weapon_root.visible: failures.append("remote preparation did not hide firearm")
				if not await wait_for(func():return game.grenades_system.rounds.has(grenade_id) and not game.grenades_system.rounds[grenade_id].held): failures.append("remote throw missing")
				else:
					if float(game.grenades_system.rounds[grenade_id].left)>3.6: failures.append("central cooking timer reset on throw")
				if not await wait_for(func():return game.grenades_system.events.has(grenade_id),9): failures.append("remote explosion missing")
				await create_timer(2).timeout
		await create_timer(.5).timeout
	if not screens.is_empty():
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(screens.path_join("pvp-desert-"+role+".png"))
	var result := {"role":role,"failures":failures,"players":game.players.size(),"shots":game.seen_shots.size(),"account_loaded":not game.main_accounts.profile.is_empty(),"held_fal_shots":held_fal_shots,"post_grenade_fal_shots":post_grenade_fal_shots}
	FileAccess.open("res://tests/ubuntu-pvp-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result))
	game.show_menu()
	game.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
