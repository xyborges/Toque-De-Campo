extends SceneTree
## P1j: three independent Godot/ENet processes. Server runs the P1g flag,
## shooter sends ordinary WarPlayer.fire() from TPP, victim must receive the
## replicated damage that was resolved against the server CollisionRig.
const MAPS=preload("res://scripts/maps/definition.gd")
const RANGE_ORIGIN:=Vector3(0,80,0)
var game
var role:="server"
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func wait_for(condition: Callable,label: String,seconds:=30.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	failures.append("timeout: "+label)
	return false

func phase(value: String) -> void:
	game.phase=value
	game._broadcast("qa_phase",[value])

func net_debug(label: String) -> void:
	var peer: MultiplayerPeer=game.multiplayer.multiplayer_peer
	var status:=-1
	if peer!=null: status=int(peer.get_connection_status())
	print("P1J_NET_DEBUG ",JSON.stringify({
		"label":label,
		"role":role,
		"online":bool(game.online),
		"peer_type":str(peer.get_class()) if peer!=null else "null",
		"connection_status":status,
		"unique_id":game.multiplayer.get_unique_id(),
		"peers":game.multiplayer.get_peers(),
		"port":game._network_port(),
		"status_text":game.status_label.text if is_instance_valid(game.status_label) else ""
	}))

func set_server_pose(actor: WarPlayer,point: Vector3,yaw_value: float,pitch_value: float) -> void:
	point+=Vector3.UP*.08
	actor.global_position=point
	actor.velocity=Vector3.ZERO
	actor.yaw=yaw_value
	actor.rotation.y=yaw_value
	actor.pitch=pitch_value
	actor.camera_pivot.rotation.x=pitch_value
	actor.network_target=point
	actor.network_yaw=yaw_value
	actor.network_pitch=pitch_value
	actor.set_meta("p1j_freeze",true)
	actor.next_pose_usec=0
	actor._animate_walk()
	actor._p1g_collision_tick()
	game._broadcast("qa_pose",[actor.peer_id,point,yaw_value,pitch_value])

func aim_at(shooter: WarPlayer,target: Vector3) -> Vector2:
	var direction:=(target-shooter.camera_pivot.global_position).normalized()
	return Vector2(atan2(-direction.x,-direction.z),asin(clampf(direction.y,-1.,1.)))

func run() -> void:
	if not NavalAccounts.testing() or WarOperation.from_args(WarOperation.UKRAINE)!=WarOperation.UKRAINE:
		push_error("P1j requires QA accounts and the default War operation")
		quit(1)
		return
	Engine.max_fps=60
	# The fixture substitutes a flat range for Ukraine terrain. Admit its
	# shared map identity even when the unused prepared terrain is stale.
	var identity:=MAPS.identity("ukraine")
	if int(identity.version)<=0 or str(identity.hash).length()!=64:
		push_error("P1j requires an existing Ukraine map identity")
		quit(1)
		return
	MAPS.checked["ukraine"]=true
	game=load("res://tests/true_fpp_p1j_network_fixture.gd").new()
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	game.set_meta("war_host",role=="server")
	root.add_child(game)
	game.nickname_input.text=role
	game.address_input.text="127.0.0.1"
	if role=="server":
		net_debug("server-after-ready")
		await server_flow()
	else:
		# WarGame._ready() schedules join_game after the world prebuild. Do not
		# issue a second manual join while the QA world is still being prepared.
		if await wait_for(func():return game.online and game.multiplayer.multiplayer_peer is ENetMultiplayerPeer,"client transport created",120.):
			net_debug("client-after-world-prebuild")
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join",120.):
			game.ui_focus.close_all()
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			game.rpc_id(1,"qa_report",role+"-connected")
			if await wait_for(func():return game.local_player.deployed,"server deployment",30.):
				game.rpc_id(1,"qa_report",role+"-ready")
				await client_flow()
	print("P1J_NETWORK ",JSON.stringify({"role":role,"pass":failures.is_empty(),"checks":checks,"failures":failures}))
	if is_instance_valid(game):
		game.show_menu()
		game.queue_free()
	await create_timer(.35).timeout
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() else 1)

func server_flow() -> void:
	check("--true-fpp-p1g-collision" in OS.get_cmdline_user_args(),"server process explicitly enables P1g pilot")
	# Clients build the full War world before creating their ENet peer. On the
	# GTX1650/i5 QA machine two cold clients can legitimately need >45 s.
	# This is fixture budget only; production transport timeouts are untouched.
	if not await wait_for(func():return game.reports.has("shooter-connected") and game.reports.has("victim-connected"),"two real ENet clients complete admission",120.): return
	var actors: Dictionary={}
	for actor: WarPlayer in game.players.values(): actors[str(actor.name)]=actor
	if not actors.has("shooter") or not actors.has("victim"):
		failures.append("server did not receive named shooter/victim actors")
		return
	var shooter:=actors.shooter as WarPlayer
	var victim:=actors.victim as WarPlayer
	check(game._deploy(shooter.peer_id,1,"soldier","g3","rpg","base"),"server deploys G3 shooter through normal validation")
	check(game._deploy(victim.peer_id,0,"soldier","fal","stinger","base"),"server deploys victim through normal validation")
	if not failures.is_empty(): return
	if not await wait_for(func():return game.reports.has("shooter-ready") and game.reports.has("victim-ready"),"both clients ready",30.): return
	game.members[shooter.peer_id].shield=0.
	game.members[victim.peer_id].shield=0.
	var base:=RANGE_ORIGIN
	set_server_pose(victim,base+Vector3(0,0,-9),0.,0.)
	await physics_frame
	victim._p1g_collision_tick()
	var chest:=victim.hit_regions.get("chest") as Area3D
	check(victim.p1g_authority_collision_pilot and is_instance_valid(victim.p1g_collision_rig) and victim.p1g_collision_rig.using_authority,"server victim uses P1g CollisionRig authority")
	check(is_instance_valid(chest) and chest.get_parent() is WarCollisionRigProxy,"server chest collider belongs to independent CollisionRig")
	if not failures.is_empty(): return
	var visual_live:=0
	for area: Area3D in victim.p1g_collision_rig.legacy_regions.values():
		if area.collision_layer!=0: visual_live+=1
	check(visual_live==0,"server victim has no legacy double-hit regions")
	set_server_pose(shooter,base,0.,0.)
	var aim:=aim_at(shooter,chest.global_position)
	set_server_pose(shooter,base,aim.x,aim.y)
	await create_timer(.4).timeout
	var ammo_before:=int(shooter.ammo.get("g3",0))
	phase("fire")
	if not await wait_for(func():return victim.hp<100. and not game.qa_hits.is_empty(),"authoritative proxy damage",8.): return
	print("P1J_HITS ",JSON.stringify(game.qa_hits))
	check(game.qa_hits.any(func(row):return int(row.owner)==shooter.peer_id and bool(row.proxy) and str(row.region)=="chest" and str(row.weapon)=="g3"),"server projectile resolves against proxy chest")
	check(victim.last_hit_region=="chest" and victim.hp<100.,"server damage pipeline records proxy chest hit")
	check(victim.p1g_collision_rig.using_authority and victim.hit_regions==victim.p1g_collision_rig.regions,"proxy remains authority after network damage")
	if not await wait_for(func():return game.qa_payloads.has("victim-damaged") and game.qa_payloads.has("shooter-fired"),"client replication reports",8.): return
	var victim_payload: Dictionary=game.qa_payloads["victim-damaged"]
	var shooter_payload: Dictionary=game.qa_payloads["shooter-fired"]
	check(str(victim_payload.get("region",""))=="chest","victim client receives exact chest region")
	check(absf(float(victim_payload.get("hp",-1))-victim.hp)<.01,"victim client HP matches server authority")
	check(ammo_before-int(shooter.ammo.get("g3",0))==1,"server consumes exactly one accepted G3 round")
	check(int(shooter_payload.get("ammo_after",-1))==int(shooter.ammo.get("g3",0)),"shooter ammo matches server")
	check(int(shooter_payload.get("pending",-1))==0,"shooter receives acknowledgement for the shot")
	check(game.multiplayer.get_peers().size()==2 and game.players.size()==2,"both ENet clients remain connected after proxy hit")
	phase("done")
	await create_timer(.7).timeout

func client_flow() -> void:
	if not await wait_for(func():return game.phase=="fire","fire phase",30.): return
	var actor:=game.local_player as WarPlayer
	if role=="shooter":
		game.third_person=true
		actor._update_view()
		await physics_frame
		actor._update_camera_collision(1./60.)
		check(actor.camera.get_parent()==actor.shoulder_arm and actor.camera.global_position.distance_to(actor.camera_pivot.global_position)>2.,"shooter uses effective TPP")
		check(game.gameplay_input_allowed() and actor.weapon_id=="g3","shooter can fire the deployed G3")
		if not failures.is_empty(): return
		actor.fire()
		if await wait_for(func():return actor.pending_shots.is_empty(),"server acknowledges G3 shot",5.):
			game.rpc_id(1,"qa_payload","shooter-fired",{"ammo_after":int(actor.ammo.get("g3",0)),"pending":actor.pending_shots.size()})
	elif role=="victim":
		var before:=actor.hp
		if await wait_for(func():return actor.hp<before,"replicated damage",8.):
			check(actor.last_hit_region=="chest","victim client applies replicated chest region")
			check(actor.hp>0.,"network gate keeps victim alive for comparison")
			game.rpc_id(1,"qa_payload","victim-damaged",{"hp":actor.hp,"region":actor.last_hit_region,"life":actor.life_id})
	await wait_for(func():return game.phase=="done","done phase",10.)
