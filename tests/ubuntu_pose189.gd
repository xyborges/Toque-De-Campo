extends SceneTree
var role:="host"
var label:="baseline"
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var samples: Array[float]=[]
var rtt: Array[float]=[]
var processing: Array[float]=[]
var measuring:=false
var remote_stance_seen:=false
var last_frame:=0
var next_ping:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	run.call_deferred()
func _process(_delta: float) -> bool:
	var now:=Time.get_ticks_usec()
	if measuring:
		for remote: WarPlayer in game.players.values():
			if not remote.is_local and absf(remote.lean)>.6: remote_stance_seen=true
		if last_frame>0: samples.append((now-last_frame)*.001)
		processing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
		if now>next_ping:
			next_ping=now+500000
			var peer: ENetPacketPeer=(game.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
			var value:=peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
			if value>0: rtt.append(value)
	last_frame=now
	return false
func stat(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var copy:=values.duplicate();copy.sort();var sum:=0.
	for v in copy: sum+=v
	return {"n":copy.size(),"mean":sum/copy.size(),"median":copy[copy.size()/2],"p95":copy[mini(copy.size()-1,int(copy.size()*.95))],"max":copy[-1]}
func check(ok: bool,text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures.append(text)
func wait_for(test: Callable,text: String,seconds:=35.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	print("TIMEOUT ",text," ",game.last_notice," ",{"online":game.online,"ready":game.join_ready,"players":game.players.size(),"building":game.preparing_world,"sent":game.pvp_join_sent,"challenge":not game.pvp_join_nonce.is_empty(),"status":game.status_label.text,"transport":game.multiplayer.multiplayer_peer.get_connection_status()});failures.append(text);return false
func click(actor: WarPlayer) -> void:
	actor.fire()
func run() -> void:
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var accounts:=NavalAccounts.new();root.add_child(accounts)
	accounts.connection_state.connect(func(result,status):print("HTTP_RESULT ",result," ",status))
	var auth: Dictionary=await accounts.sign_in("login",str(credentials[role].username),str(credentials[role].password))
	check(auth.get("ok",false) and accounts.validated_session,"signed account login over pinned HTTPS")
	if failures.is_empty():
		game=load("res://tests/war187_live_client.gd").new();game.accounts_service=accounts;root.add_child(game)
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.players.size()>=2,"both accounts join central DTLS server",60):
			var team:=0 if role=="host" else 1
			game.request_deploy(team,"soldier",WarRules.primary_for("soldier",team)[0],WarRules.launcher_for_team(team),"base")
			if await wait_for(func():return game.local_player.deployed and game._battle_active(),"deploy both teams"):
				var actor:=game.local_player as WarPlayer;var rifle:=actor.weapon_id
				actor.set_process_unhandled_input(false);game.vehicle_system.set_process_input(false)
				game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor.pitch=.4;actor.camera_pivot.rotation.x=.4
				await create_timer(2.).timeout
				measuring=true;last_frame=Time.get_ticks_usec()
				for entry in [["lean_left",-1.],["lean_right",1.]]:
					Input.action_press(entry[0]);await create_timer(.45).timeout
					var allowed:=GameInfantryPose.limit_lean(actor,float(entry[1]))
					check(absf(actor.lean-allowed)<.04,"central session applies Q/E stance "+str(entry[0]))
					Input.action_release(entry[0]);await create_timer(.3).timeout
				actor.trigger_held=true
				await create_timer(1.).timeout;actor.trigger_held=false
				check(actor.ammo.get(rifle,0)<GameWeapons.ITEMS[rifle].mag,"central authority accepts held "+rifle+" fire")
				actor.start_reload();check(await wait_for(func():return actor.reload_left>0,"rifle reload begins",4),"central "+rifle+" reload accepted")
				check(await wait_for(func():return actor.reload_weapon.is_empty() and int(actor.ammo.get(rifle,0))==int(GameWeapons.ITEMS[rifle].mag),"rifle reload completes",10),"central "+rifle+" reload completed")
				actor.equip_quick_slot(1);await create_timer(.4).timeout;click(actor);await create_timer(.3).timeout;click(actor);await create_timer(.3).timeout
				actor.start_reload();check(await wait_for(func():return actor.reload_left>0,"Glock reload begins",4),"central Glock reload accepted on team "+str(team+1))
				check(await wait_for(func():return actor.reload_weapon.is_empty() and int(actor.ammo.get("glock",0))==12,"Glock reload completes",6),"central Glock reload completed on team "+str(team+1))
				if role=="host":
					game.vehicle_system.request_command("drone",{})
					check(await wait_for(func():return actor.vehicle_id.begins_with("drone_"),"drone control",4),"central drone link opens")
					await create_timer(.6).timeout;game.vehicle_system.request_command("exit",{})
					check(await wait_for(func():return actor.vehicle_id.is_empty() and actor.camera.current,"exit drone",4),"drone exit restores infantry camera")
					# A normal grenade cooks in the operator's hand: no debug damage RPC.
					actor.equip_grenade();await create_timer(.4).timeout;game.prime_grenade(actor)
					var life:=actor.life_id
					check(await wait_for(func():return actor.hp<=0,"grenade self-death",8),"central authority records a real grenade death")
					check(await wait_for(func():return actor.hp>0 and actor.life_id>life,"real respawn",12),"central authority respawns a new life")
					check(actor.camera.current and actor.position.distance_to(WarRules.BASES[team])<35,"new life restores base position and current camera")
					game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
					var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
					Input.action_press("move_forward")
					var until:=Time.get_ticks_msec()+8000
					while Time.get_ticks_msec()<until and actor.position.distance_to(vehicle.position)>4.8:
						var d: Vector3=vehicle.position-actor.position;actor.yaw=atan2(-d.x,-d.z);actor.rotation.y=actor.yaw;actor.pitch=0;await process_frame
					Input.action_release("move_forward")
					game.vehicle_system.request_command("enter",{"id":"v_guarani"})
					if await wait_for(func():return actor.vehicle_id=="v_guarani","real boarding",5):
						var manager:=game.vehicle_system as WarVehicles
						await wait_for(func():return manager.last_controlled==actor.vehicle_id,"camera transfer",3)
						manager.orbit_yaw=0;manager.orbit_pitch=.35;manager.aim_point=vehicle.position+Vector3(0,80,-250);manager.fire_held=true
						check(await wait_for(func():return vehicle.ammo<=25,"real APC fire",6),"APC fires after drone, death and respawn on Ubuntu")
						manager.fire_held=false;manager.request_command("exit",{})
						check(await wait_for(func():return actor.vehicle_id.is_empty() and actor.camera.current,"real APC exit",4),"APC exit restores infantry input and camera")
				else: await create_timer(40.).timeout
				measuring=false
				check(remote_stance_seen,"central DTLS observer receives remote lean")
				if DisplayServer.get_name()!="headless":
					RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/war187-live-"+label+".png")
	var result: Dictionary={"role":role,"label":label,"checks":checks,"failures":failures,"enet_rtt_ms":stat(rtt),"frame_interval_ms":stat(samples),"process_ms":stat(processing),"headless":DisplayServer.get_name()=="headless","dtls":true}
	NavalStorage.write_json("res://tests/ubuntu-war187-"+label+"-"+role+".json",result);print(JSON.stringify(result))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.4).timeout;accounts.queue_free();quit(0 if failures.is_empty() else 1)
