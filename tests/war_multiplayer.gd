extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
var grenade_events:=0
var saw_vehicle_shot:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(test: Callable,label: String,seconds:=12.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if game.grenades_system: grenade_events=maxi(grenade_events,game.grenades_system.events.size())
		if game.war_fx:
			for index in game.war_fx.active_slots:
				if str(game.war_fx.rounds[index].weapon)=="autocannon": saw_vehicle_shot=true
		if test.call(): return true
	failures.append("timeout: "+label);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func pose(actor: GamePlayer,point: Vector3,target: Vector3) -> void:
	point=WarTerrain.point(point.x,point.z)+Vector3.UP*.2
	var direction:=(target-(point+Vector3.UP*1.68)).normalized()
	var yaw_value:=atan2(-direction.x,-direction.z);var pitch_value:=asin(clampf(direction.y,-1,1))
	actor.position=point;actor.velocity=Vector3.ZERO;actor.yaw=yaw_value;actor.rotation.y=yaw_value;actor.pitch=pitch_value
	actor.camera_pivot.rotation.x=pitch_value;actor._animate_walk()
	game._broadcast("qa_pose",[actor.peer_id,point,yaw_value,pitch_value])
func run() -> void:
	game=load("res://tests/war_network_fixture.gd").new();game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	else:
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed,"deployment",55.):
			game.ui_focus.close_all();game.vehicle_system.set_physics_process(false)
			await client_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures,"grenade_events":grenade_events,"vehicle_projectile_seen":saw_vehicle_shot}
	NavalStorage.write_json("res://tests/war-multiplayer-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==3,"three clients",55.): return
	var actors: Dictionary={}
	for actor: GamePlayer in game.players.values(): actors[str(actor.name)]=actor
	var alpha:=actors.alpha as WarPlayer;var bravo:=actors.bravo as WarPlayer;var medic:=actors.medic as WarPlayer
	var alpha_id:=alpha.peer_id
	check(game._deploy(alpha.peer_id,0,"soldier","fal","rpg","base"),"soldier deployment validated")
	check(game._deploy(bravo.peer_id,1,"antitank","fal","rpg","base"),"opposing antitank deployment validated")
	check(game._deploy(medic.peer_id,0,"medic","fal","rpg","base"),"medic deployment respects team balance")
	await create_timer(.7).timeout
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	pose(alpha,vehicle.global_position+Vector3(-4,0,0),vehicle.global_position)
	pose(bravo,vehicle.global_position+Vector3(4,0,0),vehicle.global_position)
	phase("enter")
	if not await wait_for(func():return vehicle.driver==alpha.peer_id,"exclusive vehicle entry"): return
	await create_timer(.3).timeout
	check(bravo.vehicle_id.is_empty() and vehicle.driver==alpha.peer_id,"enemy cannot take an occupied friendly APC")
	var start:=vehicle.global_position;var ammo:=vehicle.ammo
	phase("drive")
	if not await wait_for(func():return vehicle.global_position.distance_to(start)>1 and vehicle.ammo<ammo,"movement and mounted fire"): return
	check(vehicle.ammo<ammo and game.war_fx.counter>0,"APC consumes ammunition and spawns authoritative projectiles")
	phase("exit")
	if not await wait_for(func():return vehicle.driver==0 and alpha.vehicle_id.is_empty(),"validated exit"): return
	check(alpha.global_position.y>=WarTerrain.height_at(alpha.position.x,alpha.position.z)-.1,"vehicle exit restores infantry above terrain")
	pose(alpha,Vector3(-560,0,25),WarTerrain.point(-560,12)+Vector3.UP)
	pose(medic,Vector3(-558,0,25),WarTerrain.point(-560,25)+Vector3.UP)
	phase("grenade")
	if not await wait_for(func():return not game.grenades_system.events.is_empty(),"five-second grenade",9): return
	check(alpha.grenades==1,"War uses shared grenade inventory and server fuse")
	# Isolate the healing check from damage caused during the previous scenario.
	pose(alpha,Vector3(-280,0,-210),WarTerrain.point(-280,-230)+Vector3.UP)
	pose(medic,Vector3(-278,0,-210),WarTerrain.point(-280,-210)+Vector3.UP)
	alpha.hp=100
	game.members[alpha.peer_id].shield=0
	game._apply_hit(bravo.peer_id,{"collider":alpha.hit_regions.chest},30,"chest","glock")
	print("HEAL_START ",{"hp":alpha.hp,"alpha":alpha.position,"medic":medic.position,"charges":game.members[medic.peer_id].charges})
	phase("heal")
	if not await wait_for(func():return alpha.hp>=100,"medic healing"):
		print("HEAL_FAILURE ",{"hp":alpha.hp,"alpha":alpha.position,"medic":medic.position,"charges":game.members[medic.peer_id].charges,"healing":game.vehicle_system.healing})
		return
	check(int(game.match_stats.rows[medic.peer_id].support)>0,"actual ally healing awards bounded support points")
	phase("ammo")
	if not await wait_for(func():return int(game.members[alpha.peer_id].charges)==2 and game.reports.has("ammo-resource-hud"),"soldier resupply resource replication"): return
	check(int(game.members[alpha.peer_id].charges)==2,"soldier resupply consumes the authoritative class stock independently of grenades")
	vehicle.hp=float(vehicle.spec.hp);vehicle.speed=0;vehicle.velocity=Vector3.ZERO
	var target:=vehicle.global_position+Vector3.UP*1.3
	pose(bravo,vehicle.global_position+Vector3(0,0,24),target)
	game.members[bravo.peer_id].last_gadget=-100;phase("rpg")
	if not await wait_for(func():return vehicle.hp<float(vehicle.spec.hp),"RPG hit",10): return
	check(game.members[bravo.peer_id].charges==2,"RPG launch consumes one server-side class charge")
	check(bravo.weapon_id=="rpg" and bravo.gadget_equipped and is_instance_valid(bravo.launcher_muzzle),"server equips the real RPG model and its barrel before accepting a launch")
	# Keep the later disconnect shooter outside the Stinger's real 5 m blast.
	# The previous fixture left the medic beside the drone operator and then
	# tried to fire his FAL after the explosion had correctly killed him.
	pose(medic,Vector3(-278,0,-240),WarTerrain.point(-280,-210)+Vector3.UP)
	# The AA launcher belongs to the opposite team. Start a new validated life
	# for bravo, changing the two fixture allies together to preserve balance.
	for member_actor in [alpha,medic]:
		game.members[member_actor.peer_id].team=1;member_actor.apply_identity(1,member_actor.war_class)
		game._broadcast("war_identity",[member_actor.peer_id,game.members[member_actor.peer_id]])
	bravo.hp=0;bravo.deployed=false;game.members[bravo.peer_id].deployed=false;game.members[bravo.peer_id].ready_at=0
	check(game._deploy(bravo.peer_id,0,"antitank","fal","stinger","base"),"AA scenario uses a new team 1 antitank life, never both launchers together")
	game.vehicle_system.launch_drone(alpha.peer_id)
	if not await wait_for(func():return not game.vehicle_system.drones.is_empty(),"drone launch"): return
	var drone:=game.vehicle_system.drones.values()[0] as WarDrone
	pose(bravo,alpha.global_position+Vector3(0,0,22),drone.global_position)
	phase("lock")
	if not await wait_for(func():return float(game.vehicle_system.locks.get(bravo.peer_id,{}).get("progress",0))>=1,"Stinger server lock"): return
	game.members[bravo.peer_id].last_gadget=-100;phase("stinger")
	if not await wait_for(func():return game.vehicle_system.drones.is_empty(),"Stinger destroys enemy drone",10): return
	print("POST_STINGER ",{"medic_hp":medic.hp,"medic_deployed":medic.deployed,"medic_position":medic.global_position,"alpha_hp":alpha.hp})
	check(int(game.match_stats.rows[bravo.peer_id].points)>=75,"drone destruction awards verified enemy event points")
	check(medic.hp>0 and game._eligible(medic.peer_id),"later disconnect shooter remains alive outside the prior explosion scenario")
	# Restore the original fixture teams for the friendly Guarani reentry.
	for member_actor in [alpha,medic,bravo]:
		var restored_team:=1 if member_actor==bravo else 0
		game.members[member_actor.peer_id].team=restored_team;member_actor.apply_identity(restored_team,member_actor.war_class)
		game._broadcast("war_identity",[member_actor.peer_id,game.members[member_actor.peer_id]])
	pose(alpha,vehicle.global_position+Vector3(-4,0,0),vehicle.global_position)
	phase("reenter")
	if not await wait_for(func():return vehicle.driver==alpha.peer_id,"reentry"): return
	phase("disconnect")
	if not await wait_for(func():return game.players.size()==2,"disconnect inside APC"): return
	check(vehicle.driver==0 and not game.vehicle_system.controls.has(alpha_id),"disconnect releases driver reservation and control immediately")
	phase("continue")
	if not await wait_for(func():return game.reports.has("remaining-combat"),"remaining player can fire and reload"): return
	check(int(medic.ammo.fal)==29 and medic.reload_left>0 and medic.reload_weapon=="fal","remaining FAL shot and reload are accepted by the authoritative server")
	if not await wait_for(func():return game.reports.has("remaining-reload-completed"),"remaining player finishes reload",10): return
	check(int(medic.ammo.fal)==30 and medic.reload_left==0,"remaining FAL reload completes with a full server magazine")
	check(not game.match_stats.rows.has(alpha_id) and game.match_stats.rows.size()==2,"scoreboard removes the disconnected player")
	phase("finish");await create_timer(.6).timeout
func client_flow() -> void:
	var actor:=game.local_player as WarPlayer
	var handled: Dictionary={};var sequence:=0;var previous:=""
	var deadline:=Time.get_ticks_msec()+80000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if game.grenades_system: grenade_events=maxi(grenade_events,game.grenades_system.events.size())
		if game.war_fx:
			for index in game.war_fx.active_slots:
				if str(game.war_fx.rounds[index].weapon)=="autocannon": saw_vehicle_shot=true
		var current:=str(game.phase)
		if current=="finish": return
		if current=="drive" and role=="alpha":
			sequence+=1
			var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
			game.vehicle_system.rpc_id(1,"control",sequence,{"throttle":.5,"steer":.1,"aim":vehicle.global_position+Vector3(0,2,-80),"fire":true,"occupancy":vehicle.control_epoch,"vehicle":vehicle.vehicle_id,"life":actor.life_id})
		if handled.has(current): continue
		handled[current]=true;previous=current
		if current=="enter":
			if role in ["alpha","bravo"]: game.vehicle_system.rpc_id(1,"command","enter",{"id":"v_guarani"})
		elif current=="exit" and role=="alpha": game.vehicle_system.rpc_id(1,"command","exit",{})
		elif current=="grenade" and role=="alpha":
			actor.equip_quick_slot(3);game.prime_grenade(actor)
			if not await wait_for(func():return not actor.grenade_held_id.is_empty(),"grenade prime"): return
			await create_timer(.35).timeout;game.request_grenade(actor)
		elif current=="heal" and role=="medic":
			game.request_gadget()
			if not await wait_for(func():return int(game.members.get(actor.peer_id,{}).get("charges",4))==3,"medic class stock replicated to owner",3): return
			game.war_ui._refresh_equipment(game.infantry_hud);game.infantry_hud.refresh()
			check(game.infantry_hud.equipment_state.text.begins_with("×3") and game.infantry_hud.equipment_title.text.begins_with("G · KIT MÉDICO"),"medical HUD consumes only server-confirmed resources")
		elif current=="ammo" and role=="alpha":
			game.vehicle_system.request_command("ammo",{})
			if not await wait_for(func():return int(game.members.get(actor.peer_id,{}).get("charges",3))==2,"soldier class stock replicated to owner",3): return
			game.war_ui._refresh_equipment(game.infantry_hud);game.infantry_hud.refresh()
			check(game.infantry_hud.equipment_title.text.begins_with("H · REABASTECER") and game.infantry_hud.equipment_state.text.begins_with("×2") and game.infantry_hud.equipment_state.text.contains("PRONTO EM"),"soldier HUD receives the server charge and cooldown while keeping grenade inventory separate")
			game.rpc_id(1,"qa_report","ammo-resource-hud")
		elif current in ["rpg","lock"] and role=="bravo":
			game.select_gadget("rpg" if current=="rpg" else "stinger")
			await create_timer(.25).timeout
			if current=="rpg":
				game.vehicle_system.rpc_id(1,"command","select",{"gadget":"stinger","enabled":true})
				await create_timer(.2).timeout
				check(actor.weapon_id=="rpg","a forged online opposite-team equip cannot replace the valid RPG")
				game.request_gadget()
				if not await wait_for(func():return int(game.members.get(actor.peer_id,{}).get("charges",3))==2,"RPG class stock replicated to owner",3): return
				game.war_ui._refresh_equipment(game.infantry_hud);game.infantry_hud.refresh()
				check(game.infantry_hud.ammo.text=="RPG-7\n×2 DISPONÍVEIS" and not game.infantry_hud.slot_views[2].selected,"online RPG HUD shows server charges rather than the stowed FAL")
		elif current=="stinger" and role=="bravo":
			check(actor.weapon_id=="stinger" and is_instance_valid(actor.launcher_muzzle),"Stinger selection is a real equipped weapon in the owning client")
			game.request_gadget()
			if not await wait_for(func():return int(game.members.get(actor.peer_id,{}).get("charges",3))==2,"Stinger class stock replicated to owner",3): return
			game.war_ui._refresh_equipment(game.infantry_hud);game.infantry_hud.refresh()
			check(game.infantry_hud.ammo.text=="STINGER\n×2 DISPONÍVEIS" and game.infantry_hud.equipment_state.text.begins_with("×2 CARGAS"),"online Stinger shows the team 1 life stock independently of the previous RPG life")
		elif current=="reenter" and role=="alpha": game.vehicle_system.rpc_id(1,"command","enter",{"id":"v_guarani"})
		elif current=="disconnect" and role=="alpha":
			check(saw_vehicle_shot and grenade_events==1,"client sees mounted fire and one shared grenade explosion")
			game.show_menu();await create_timer(.2).timeout;return
		elif current=="continue" and role=="medic":
			print("POST_DISCONNECT_COMBAT ",{"hp":actor.hp,"deployed":actor.deployed,"weapon":actor.weapon_id,"ammo":actor.ammo,"limbs":actor.limbs,"controls":game.gameplay_input_allowed(),"grenade":actor._grenade_active(),"vehicle":actor.vehicle_id,"reload":actor.reload_weapon})
			actor.equip_quick_slot(2);await create_timer(.3).timeout
			var reserve_before:=int(actor.reserves.fal)
			actor.fire_cooldown=0;actor.fire()
			if not await wait_for(func():return actor.ammo.fal<30,"FAL shot after disconnect"): return
			actor.start_reload()
			if not await wait_for(func():return actor.reload_left>0,"FAL reload after disconnect"): return
			game.rpc_id(1,"qa_report","remaining-combat")
			if not await wait_for(func():return actor.reload_left==0 and int(actor.ammo.fal)==30,"FAL reload completion after disconnect",9): return
			check(int(actor.reserves.fal)==reserve_before-1,"remaining client completes a timed FAL reload using one actual reserve round")
			game.rpc_id(1,"qa_report","remaining-reload-completed")
		elif current=="continue":
			check(game.match_stats.rows.size()<=3,"client receives authoritative scoreboard membership")
	failures.append("client scenario timed out at "+previous)
