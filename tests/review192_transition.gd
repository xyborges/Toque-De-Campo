extends SceneTree
var role:="operator"
var app
var game: WarGame
var folder:="res://work/review192-net"
var checks:=0
var failures: Array[String]=[]
var max_trails:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func save(key: String,value: Dictionary={}) -> void: NavalStorage.write_json(folder.path_join(key+".json"),value)
func exists(key: String) -> bool: return FileAccess.file_exists(folder.path_join(key+".json"))
func wait_for(test: Callable,label: String,seconds:=45.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	failures.append("timeout "+label);print("FAIL timeout ",label);return false
func press(value: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=value;root.push_input(event,true)
func run() -> void:
	if role=="warserver": await war_server()
	elif role=="desertserver": await desert_server()
	else: await client()
	var report:={"role":role,"checks":checks,"failures":failures,"dtls":true,"maximum_visible_trail_instances":max_trails}
	save(role+"-report",report);print(JSON.stringify(report))
	if is_instance_valid(app): app.show_menu();app.queue_free()
	if is_instance_valid(game) and not is_instance_valid(app): game.show_menu();game.queue_free()
	await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
func desert_server() -> void:
	app=load("res://tests/review192_transition_app.gd").new();app.set_meta("test_mode",true);root.add_child(app);app.host_game("pvp")
	app.profile.owned=GameWeapons.INFANTRY_IDS.duplicate()
	save("desert-ready")
	await wait_for(func():return exists("operator-in-desert") and exists("guest-in-desert"),"two initial Desert clients",100)
	check(app.multiplayer.get_peers().size()==2 and app.players.size()>=2,"Desert authority has both real connected clients")
	save("leave-desert")
	await wait_for(func():return exists("finish"),"transition and War session finish",180)
func war_server() -> void:
	game=WarGame.new();game.set_meta("war_host",true);game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	save("war-ready")
	if not await wait_for(func():return game.members.size()>=1 and game.members.values().any(func(s):return s.deployed),"first War deployment",110): save("finish");return
	var operator: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="operator": operator=actor
	if not is_instance_valid(operator): failures.append("missing operator");save("finish");return
	var apc:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	apc.global_position=operator.global_position+Vector3(0,0,-4.5);apc.velocity=Vector3.ZERO;apc.speed=0;apc.heading=0;apc.rotation=Vector3.ZERO
	save("apc-nearby")
	if not await wait_for(func():return exists("operator-alone"),"solo waiting is checked",35):save("finish");return
	check(apc.driver==operator.peer_id and apc.ammo==apc.capacity(),"solo operator cannot consume or create APC rounds")
	save("guest-enter-war")
	if not await wait_for(func():return game._battle_active(),"second team deploys",100):save("finish");return
	save("war-active")
	if not await wait_for(func():return exists("operator-fired"),"native APC burst",35):save("finish");return
	check(apc.shot_sequence>=3 and apc.ammo<apc.capacity(),"authority creates actual APC rounds after the second team joins")
	if not await wait_for(func():return operator.vehicle_id.is_empty(),"operator disembarks",25):save("finish");return
	if not await wait_for(func():return operator.prone and exists("prone-observed"),"authority and observer receive prone",35):save("finish");return
	check(absf(operator.body_collision.rotation.x-PI*.5)<.01,"authority uses the actual prone capsule")
	check(await wait_for(func():return operator.pitch<-.35,"server receives prone downward aim",8) and operator.pitch>=-.381,"authority applies prone aim limit")
	save("prone-authority")
	if not await wait_for(func():return not operator.prone,"operator stands again",10):save("finish");return
	save("prone-standing")
	var guest: WarPlayer
	for actor: WarPlayer in game.players.values():
		if actor!=operator: guest=actor
	game.vehicle_system.launch_drone(guest.peer_id)
	var drone:=game.vehicle_system.find_target(guest.vehicle_id) as WarDrone
	if not is_instance_valid(drone): failures.append("drone fixture launch denied");save("finish");return
	drone.global_position=operator.global_position+Vector3(0,35,-150);drone.destination=drone.global_position;drone.operator_origin=drone.global_position;drone.velocity=Vector3.ZERO
	save("stinger-target")
	if not await wait_for(func():return exists("operator-stinger-fired"),"Stinger round and tracer",30):save("finish");return
	var sight:=PhysicsRayQueryParameters3D.create(operator.camera_pivot.global_position,operator.launcher_muzzle.global_position,1,game._collision_excludes(operator.peer_id,false))
	print("STINGER_AUTHORITY ",{"weapon":operator.weapon_id,"gadget":operator.gadget_equipped,"class":operator.war_class,"charges":game.members[operator.peer_id].charges,"lock":game.vehicle_system.locks.get(operator.peer_id,{}),"eye":operator.camera_pivot.global_position,"muzzle":operator.launcher_muzzle.global_position,"obstruction":str(game.get_world_3d().direct_space_state.intersect_ray(sight)),"position":operator.position,"stance":operator.prone})
	check(int(game.members[operator.peer_id].charges)<3,"real locked Stinger consumes one authoritative launcher charge")
	if not await wait_for(func():return operator.prone,"prone death fixture",8): save("finish");return
	var life:=operator.life_id;game.members[operator.peer_id].shield=0.
	game._apply_hit(guest.peer_id,{"collider":operator.hit_regions.chest,"position":operator.global_position},1000,"chest","tank",Vector3.FORWARD)
	if not await wait_for(func():return exists("operator-deployment-map"),"manual death map",20):save("finish");return
	check(operator.hp==0 and operator.life_id==life,"authority waits for human confirmation after the eight-second gate")
	save("confirm-spawn")
	if not await wait_for(func():return operator.hp>0 and operator.life_id==life+1,"confirmed new life",20):save("finish");return
	check(str(game.members[operator.peer_id].spawn)=="base","confirmed respawn uses selected base")
	save("finish")
func client() -> void:
	if not await wait_for(func():return exists("desert-ready") and exists("war-ready"),"services boot",90):return
	app=load("res://tests/review192_transition_app.gd").new();app.set_meta("test_mode",true);root.add_child(app)
	app.profile.owned=GameWeapons.INFANTRY_IDS.duplicate();app.nickname_input.text=role;app.address_input.text="127.0.0.1";app.join_game("pvp")
	if not await wait_for(func():return is_instance_valid(app.local_player),"Desert connection",60):return
	check(app.online and app.multiplayer.multiplayer_peer is ENetMultiplayerPeer,"client enters actual Desert transport before switching")
	# Exercise cleanup with a local pending grenade/trigger presentation.
	app.local_player.grenade_selected=true;app.local_player.trigger_held=true
	save(role+"-in-desert")
	if not await wait_for(func():return exists("leave-desert"),"Desert departure"):return
	app.show_menu();await process_frame;await process_frame
	check(not app.online and app.world_root==null and app.players.is_empty() and app.local_player==null and not app.player_in_vehicle,"leaving Desert clears actors, world, transport and vehicle flags")
	if role=="guest" and not await wait_for(func():return exists("guest-enter-war"),"wait before joining opponent",100):return
	app.open_war(false);game=app.war_mode;game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"War join after Desert",90):return
	var team:=0 if role=="operator" else 1
	game.request_deploy(team,"antitank",WarRules.TEAM_RIFLES[team],WarRules.launcher_for_team(team),"base")
	if not await wait_for(func():return game.local_player.deployed and game.local_player.hp>0,"War deployment",25):return
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(not game.local_player.grenade_selected and game.local_player.grenade_held_id.is_empty() and not game.local_player.trigger_held,"new mode receives no previous grenade or held trigger")
	if role=="guest":
		if not await wait_for(func():return exists("operator-prone"),"operator requests prone",70):return
		var other: WarPlayer
		for peer: WarPlayer in game.players.values():
			if peer!=game.local_player: other=peer
		check(is_instance_valid(other) and await wait_for(func():return other.prone,"remote prone posture",10),"observer receives the operator's prone posture")
		check(absf(other.body_collision.rotation.x-PI*.5)<.01,"observer's collision follows the replicated low body")
		check(await wait_for(func():return other.pitch<-.34,"observer receives prone downward aim",8) and other.pitch>=-.381,"observer sees bounded prone aim")
		save("prone-observed")
		if await wait_for(func():return exists("finish"),"observer remains online through combat",100): check(game.war_fx.counter>0,"remote observer receives real projectile events")
		return
	if not await wait_for(func():return exists("apc-nearby"),"APC arranged"):return
	print("BOARD_LOCAL ",{"actor":game.local_player.position,"vehicle":game.vehicle_system.vehicles.v_guarani.position,"team":game.local_player.war_team,"notice":game.last_notice,"near":str(game.vehicle_system._nearby(game.local_player))})
	if not await wait_for(func():return game.vehicle_system._nearby(game.local_player)!=null,"APC state reaches native client",12):return
	game.request_interact()
	if not await wait_for(func():return game.vehicle_system._local_is_operator(),"APC operator allocation",12):return
	press(true);await create_timer(.5).timeout;press(false);game.war_ui._process(.11)
	check(game.war_ui.waiting_panel.visible and "AGUARDANDO" in game.vehicle_system.hud_text(),"solo APC explicitly shows the battle gate")
	save("operator-alone")
	if not await wait_for(func():return exists("war-active"),"enemy joins",100):return
	game.vehicle_system.orbit_yaw=0;game.vehicle_system.orbit_pitch=.10
	press(true)
	var until:=Time.get_ticks_msec()+1800
	while Time.get_ticks_msec()<until:
		await process_frame
		max_trails=maxi(max_trails,game.war_fx.trails.visible_instance_count)
	press(false)
	check(game.war_fx.counter>=3 and max_trails>0,"native APC fire produces actual visible tracer instances after changing modes")
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(folder.path_join("apc-burst.png"))
	save("operator-fired")
	game.request_interact()
	if not await wait_for(func():return game.local_player.vehicle_id.is_empty(),"safe APC exit",15):return
	await firearm("fal",6,true)
	await firearm("glock",4,false)
	var prone_actor:=game.local_player as WarPlayer
	check(prone_actor.set_posture(2,true),"native client can enter prone after vehicle exit and combat")
	prone_actor.pitch=prone_actor.clamp_aim_pitch(-1.2)
	save("operator-prone")
	if not await wait_for(func():return exists("prone-authority"),"prone acknowledged by authority and observer",12):return
	check(prone_actor.set_posture(0,true),"native client can return to standing")
	if not await wait_for(func():return exists("prone-standing"),"authority restores standing",12):return
	if not await wait_for(func():return exists("stinger-target") and game.vehicle_system.drones.size()>0,"enemy drone"):return
	var actor:=game.local_player as WarPlayer
	game.select_gadget("stinger")
	var drone:=game.vehicle_system.drones.values()[0] as WarDrone
	var direction: Vector3=(drone.global_position-actor.camera_pivot.global_position).normalized()
	actor.yaw=atan2(-direction.x,-direction.z);actor.rotation.y=actor.yaw;actor.pitch=asin(direction.y);actor.camera_pivot.rotation.x=actor.pitch;actor._update_view();actor.cycle_weapon_aim()
	if not await wait_for(func():return game.vehicle_system.lock_progress>=1.,"Stinger acquires target",8):return
	await create_timer(.4).timeout
	var shots: int=game.war_fx.counter
	press(true);await create_timer(.1).timeout;press(false)
	check(await wait_for(func():return game.war_fx.counter>shots,"Stinger actual projectile",4),"locked Stinger creates a synchronized missile")
	check(game.war_fx.trails.visible_instance_count>0,"Stinger missile has a visible native trail")
	print("STINGER_CLIENT ",{"weapon":actor.weapon_id,"gadget":actor.gadget_equipped,"charges":game.members[actor.peer_id].charges,"lock":game.vehicle_system.lock_progress,"notice":game.last_notice,"input":game.gameplay_input_allowed(),"eye":actor.camera_pivot.global_position,"muzzle":actor.launcher_muzzle.global_position})
	check(actor.set_posture(2,true),"operator can lower posture before a combat death")
	save("operator-stinger-fired")
	if not await wait_for(func():return actor.hp<=0,"combat death",10):return
	if not await wait_for(func():return game.war_ui.deployment.visible and game.deployment_ready(),"death map after eight seconds",14):return
	check(actor.hp==0 and not actor.deployed,"dead native client stays undeployed and cannot fire")
	save("operator-deployment-map")
	if not await wait_for(func():return exists("confirm-spawn"),"server ready for confirmation",8):return
	game.war_ui.spawn_select.select(0);game.war_ui.invalid_spawn=false;game.war_ui._deploy()
	check(await wait_for(func():return actor.hp==100 and actor.deployed,"manual confirmation",12),"map confirmation restores a playable life")
	check(not actor.prone and actor.stance.prone_weight==0 and actor.body_collision.shape.height==1.75,"new life clears the dead body's prone posture on the native client")
	await wait_for(func():return exists("finish"),"authority completes",10)

func firearm(id: String,slot: int,automatic: bool) -> void:
	var actor:=game.local_player as WarPlayer
	actor.equip_slot(slot);actor.aiming=false;actor.iron_sights=false
	# Look out of the parking space: shooting through the adjacent APC hull
	# is correctly stopped by the eye-to-muzzle obstruction sweep.
	var away: Vector3=actor.global_position-game.vehicle_system.vehicles.v_guarani.global_position;away.y=0
	actor.yaw=atan2(-away.x,-away.z);actor.rotation.y=actor.yaw;actor.pitch=.1;actor.camera_pivot.rotation.x=.1
	game.third_person=automatic;actor._update_view()
	await create_timer(.45).timeout
	var before:=int(actor.ammo.get(id,0));var shots:=actor.shot_sequence;var actual:=0;var traced:=0
	if automatic:
		press(true)
		var until:=Time.get_ticks_msec()+750
		while Time.get_ticks_msec()<until:
			await process_frame
			for index in game.war_fx.active_slots:
				var p: Dictionary=game.war_fx.rounds[index]
				if p.owner==actor.peer_id and p.weapon==id:
					actual+=1
					if p.tracer and game.war_fx.trails.visible_instance_count>0: traced+=1
		press(false)
	else:
		for click in 3:
			press(true)
			var until:=Time.get_ticks_msec()+100
			while Time.get_ticks_msec()<until:
				await process_frame
				for index in game.war_fx.active_slots:
					var p: Dictionary=game.war_fx.rounds[index]
					if p.owner==actor.peer_id and p.weapon==id:
						actual+=1
						if p.tracer and game.war_fx.trails.visible_instance_count>0: traced+=1
			press(false);await create_timer(.25).timeout
	await create_timer(.5).timeout
	print("FIREARM_METRICS ",{"weapon":id,"equipped":actor.weapon_id,"before":before,"after":actor.ammo.get(id,0),"shots":actor.shot_sequence-shots,"actual_projectile_frames":actual,"traced_frames":traced,"input":game.gameplay_input_allowed(),"vehicle_flag":game.player_in_vehicle})
	check(actor.weapon_id==id and actor.shot_sequence>=shots+3 and int(actor.ammo.get(id,0))<before and actual>0 and traced>0,id+": actual synchronized fire and visible tracers after Desert, APC, exit and weapon change")
	check(actor.pending_shots.is_empty(),id+": accepted rounds reconcile the predicted inventory")
	actor.start_reload()
	check(await wait_for(func():return int(actor.ammo.get(id,0))==int(GameWeapons.ITEMS[id].mag) and actor.reload_left<=0,id+" reload",10),id+": authoritative reload completes and restores the magazine")
