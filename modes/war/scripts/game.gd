extends "res://scripts/main.gd"
class_name WarGame
signal closed
var accounts_service: NavalAccounts
var war_ui: WarUI
var members: Dictionary = {}
var objective_states := WarRules.fresh_objectives()
var tickets := [WarRules.START_TICKETS,WarRules.START_TICKETS]
var match_left := WarRules.DURATION
var match_ended := false
var winner := -1
var join_ready := false
var loading_baselines: Dictionary={}
var baseline_transfer:=""
var baseline_loading:=false
var world_build_ms:=0.
var simulation_peak_ms:=0.
var simulation_samples:=0
var simulation_total_ms:=0.
var simulation_report_at:=0.
var war_clock := 0.0
var weather_seed:=0
var world_prebuilt:=false
var preparing_world:=false
var war_tick := 0
var snapshot_clock := 0.0
var received_snapshot_generation:=-2
var received_snapshot_time:=-INF
const STATE_STALE_USEC:=550000
const STATE_RECOVERY_INTERVAL_USEC:=500000
var state_recovery_sessions: Dictionary={}
var state_recovery_serial:=0
var state_recovery_pending:=0
var state_recovery_check_at:=0
var state_recovery_request_at:=0
var state_recovery_started_at:=0
var operation_received_at:=0
var state_recovery_sent:=0
var state_recovery_received:=0
var ticket_clock := 0.0
var last_notice := "Conectando ao setor..."
var network_api: SceneMultiplayer
var vehicle_system: Node
var war_fx: Node
var combat_audio: WarAudio
var combat_effects: WarEffects
var soundscape: WarSoundscape
var testing := false
var reward_jobs: Array[Dictionary]=[]
var rewarding:=false
var round_restart_left:=WarRules.ROUND_BREAK_SECONDS
var closing:=false
var authority_round_generation:=-1
var handled_round_start_generation:=-1
var offline_operation:=false
var operation_id:=WarOperation.UKRAINE
var offline_participants:=WarRules.OFFLINE_PARTICIPANTS
var bot_director: Node
var power_grid: WarPowerGrid
var supply_points: Dictionary={}
var life_sync_wait:=0.0
var death_deployment_life:=-1
var frame_pacing:=preload("res://scripts/frame_pacing.gd").new()

func _ready() -> void:
	name = "WarGame"
	operation_id=WarOperation.from_args(operation_id)
	WarRules.configure(operation_id)
	WarTerrain.configure(operation_id)
	objective_states=WarRules.fresh_objectives()
	set_meta("war_mode",true)
	set_meta("war_operation",operation_id)
	testing = NavalAccounts.testing() or (bool(get_meta("war_test",false)) and OS.has_feature("editor"))
	dedicated_pvp = "--war-server" in OS.get_cmdline_user_args() or bool(get_meta("war_host",false))
	network_api = SceneMultiplayer.new()
	network_api.server_relay = false
	network_api.allow_object_decoding = false
	get_tree().set_multiplayer(network_api,get_path())
	_setup_input()
	_load_profile()
	main_accounts = accounts_service
	if main_accounts==null:
		main_accounts = NavalAccounts.new()
		add_child(main_accounts)
	_build_audio()
	_build_ui()
	_build_modal_ui()
	_setup_voice()
	menu_layer.hide()
	get_window().focus_exited.connect(_focus_changed)
	war_ui = WarUI.new()
	war_ui.game = self
	hud_layer.add_child(war_ui)
	if testing and get_meta("war_visual_preview",false): return
	if offline_operation or dedicated_pvp: weather_seed=randi_range(1,2000000);WarWeather.seed=weather_seed
	if offline_operation: _start_offline.call_deferred()
	elif dedicated_pvp: host_game("pvp")
	else:
		war_ui.deployment.show()
		join_game.call_deferred("pvp")

func _save_profile() -> void: pass # Loadouts are scoped to this mode; central accounts remain authoritative.
func _new_player() -> GamePlayer: return WarPlayer.new()
func _network_capacity() -> int: return WarRules.CAPACITY
func _network_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--war-port="): return int(arg.trim_prefix("--war-port="))
	return WarRules.operation_port()
func _health_file() -> String: return "war-afghan-status.json" if operation_id==WarOperation.AFGHAN else "war-status.json"
func _health_status() -> Dictionary:
	var bots:=[0,0];var humans:=[0,0];var spectators:=0
	for state: Dictionary in members.values():
		var team:=int(state.team)
		if team not in [0,1]:spectators+=1;continue
		if bool(state.get("bot",false)):bots[team]+=1
		else:humans[team]+=1
	return {"connections":multiplayer.get_peers().size(),"updated":pvp_health_at,"bots":bots[0]+bots[1],"bot_teams":bots,"humans":humans[0]+humans[1]+spectators,"human_teams":humans,"loading":loading_baselines.size(),"phase":"results" if match_ended else "active","version":str(ProjectSettings.get_setting("application/config/version",""))}
func _central_pvp() -> bool: return not testing and not offline_operation

func join_game(kind: String) -> void:
	if kind!="pvp": super.join_game(kind);return
	if online or preparing_world: return
	if not world_prebuilt:
		preparing_world=true
		loading_screen.status.text="PREPARANDO GUERRA · "+WarRules.map_name().to_upper()
		loading_screen.detail.text="Carregando terreno e operação…"
		ui_focus.open(loading_screen)
		await get_tree().process_frame
		if not is_inside_tree() or closing: return
		# Build BEFORE creating the ENet client. A slow machine must not stop
		# acknowledging an already established connection while making terrain.
		mode="pvp";map_kind="desert"
		_enter_match_world();world_prebuilt=true
		await _warm_vegetation()
		preparing_world=false;loading_screen.hide();ui_focus.close_all()
	super.join_game(kind)

func _set_loading_timeout(id: int,loading: bool) -> void:
	var transport:=multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport==null or not id in multiplayer.get_peers(): return
	var peer:=transport.get_peer(id)
	if peer: peer.set_timeout(64 if loading else 32,30000 if loading else 5000,60000 if loading else 20000)

const BASELINE_ACTOR_EVENTS:=["remote_add_player","remote_player_left","war_identity","war_spawn_pose","remote_equipped","remote_inventory","remote_player_respawn","remote_protection_state","remote_weapon_optics","remote_grenade_selection","remote_damage","remote_reload_started","war_posture_state","war_recovery_pose"]
func _broadcast(method: String, arguments: Array) -> void:
	if loading_baselines.is_empty():super._broadcast(method,arguments);return
	if not online or not multiplayer.is_server():return
	var actor_event:=method in BASELINE_ACTOR_EVENTS and not arguments.is_empty()
	var replaceable:=method in ["war_bot_states","remote_player_state","war_snapshot","remote_match_stats","remote_shot_packet"]
	if not actor_event and not replaceable:super._broadcast(method,arguments);return
	if method=="remote_player_state":
		arguments=arguments.duplicate();arguments.append(network_diagnostics.next_pose_sequence(int(arguments[0]),int(arguments[7])))
	if network_diagnostics.enabled:network_diagnostics.observe_broadcast(method,arguments,multiplayer.get_peers().size()-loading_baselines.size())
	for id in multiplayer.get_peers():
		if loading_baselines.has(id):
			if actor_event:loading_baselines[id].queue(int(arguments[0]))
		elif _network_peer_ready(id):callv("rpc_id",[id,method]+arguments)

func _peer_connected(id: int) -> void:
	_set_loading_timeout(id,true)
	super._peer_connected(id)
	if pvp_challenges.has(id): pvp_challenges[id].expires=Time.get_ticks_msec()+60000

func _start_offline() -> void:
	loading_screen.status.text="PREPARANDO GUERRA OFFLINE · "+WarRules.map_name().to_upper()
	loading_screen.detail.text="Carregando terreno, blindados e rotas dos bots..."
	loading_screen.show()
	await get_tree().process_frame
	if not is_inside_tree() or closing: return
	network_api.multiplayer_peer=OfflineMultiplayerPeer.new()
	online=false;mode="pvp";map_kind="desert"
	_enter_match_world()
	await _warm_vegetation()
	var base: Vector3=WarRules.BASES[0]
	var actor:=_spawn_player(1,true,false,WarTerrain.point(base.x+35.,base.z)) as WarPlayer
	actor.name=str(profile.nickname)
	var look:=_appearance_payload();actor.set_meta("appearance",look)
	actor.apply_body_proportions(look.get("proportions",{}))
	members[1]={"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"respawn_pending":false,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	bot_director=load("res://modes/war/scripts/bot_director.gd").new()
	bot_director.setup(self);world_root.add_child(bot_director)
	join_ready=true;last_notice=""
	loading_screen.hide()
	menu_layer.hide();hud_layer.show();open_deployment()
func _build_lighting() -> void: pass # WarWorld owns its environment.
func _warm_vegetation() -> void:
	var controller:=world_root.get_node_or_null("VegetationVisuals") if is_instance_valid(world_root) else null
	if controller and controller.available:await controller.warmup()
func _build_desert() -> void:
	var render_visuals:=not dedicated_pvp and DisplayServer.get_name()!="headless"
	WarWorld.build(world_root,render_visuals)
	if render_visuals and GameOptions.vegetation_preview_available(self):
		var vegetation=load("res://modes/war/scripts/vegetation_visuals.gd").new()
		world_root.add_child(vegetation)
		if operation_id==WarOperation.AFGHAN:
			var afghan:=world_root.get_node_or_null("AfeganistaoWar")
			vegetation.initialize(afghan if afghan else world_root,"afghan")
		else:
			vegetation.initialize(world_root)
		# The enabled release defaults to medium; legacy rendering remains a
		# QA-only comparison selected explicitly with the preview flag.
		vegetation.apply_level(GameOptions.vegetation_level())

func _step_projectiles(_delta: float) -> void: pass # WarProjectiles owns the fixed-step sweep and pooled rendering.

func _spawn_projectile(owner_id: int,origin: Vector3,direction: Vector3,id: String,melee: bool,authoritative: bool,shot_id := "") -> void:
	if melee:
		if authoritative: _resolve_melee(owner_id,origin,direction,CombatRules.weapon(id),shot_id)
	elif war_fx: war_fx.spawn(owner_id,origin,direction,id,authoritative,shot_id)

func _muzzle_flash(at: Vector3) -> void:
	if war_fx: war_fx.flash(at)

func play_weapon_sound(id: String,at: Vector3,emitter := 0,elapsed:=0.0) -> void:
	if combat_audio: combat_audio.play(emitter,id,at,elapsed)

func _present_shot(packet: Dictionary) -> bool:
	var key:=str(packet.shot_id)
	if seen_shots.has(key): return false
	seen_shots[key]=true
	if seen_shots.size()>512: seen_shots.erase(seen_shots.keys()[0])
	var actor:=players.get(int(packet.owner)) as WarPlayer
	if is_instance_valid(actor):
		if not actor.is_local or multiplayer.is_server(): actor.present_fire()
		if actor.melee_rig and (not actor.is_local or multiplayer.is_server()):
			var offset: float=float(packet.get("melee_offset",0))+(0.0 if multiplayer.is_server() else _melee_network_delay(1))
			if offset>0: actor.melee_rig.advance(minf(offset,.18));actor._update_weapon_pose()
		if CombatRules.weapon(str(packet.weapon)).kind=="firearm": _muzzle_flash(packet.origin)
		if not (actor.is_local and online and not multiplayer.is_server() and int(packet.sequence)<=int(actor.get_meta("predicted_audio_sequence",0))):
			play_weapon_sound(str(packet.weapon),packet.origin,int(packet.owner),0.0 if not online or multiplayer.is_server() else _melee_network_delay(1))
	return true

func _present_impact(id: String,point: Vector3,_normal: Vector3,blood: bool) -> void:
	if seen_impacts.has(id): return
	seen_impacts[id]=true
	if seen_impacts.size()>1024: seen_impacts.erase(seen_impacts.keys()[0])
	if war_fx: war_fx.cancel_shot(id)
	if combat_effects: combat_effects.impact(point,blood)

func _build_ui() -> void:
	# Reuse the infantry HUD without constructing a second login/main menu.
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuUI"
	add_child(menu_layer)
	nickname_input = LineEdit.new()
	nickname_input.text = str(profile.nickname)
	menu_layer.add_child(nickname_input)
	address_input = LineEdit.new()
	address_input.text = NavalCatalog.SERVER
	menu_layer.add_child(address_input)
	status_label = Label.new()
	menu_layer.add_child(status_label)
	appearance_panel = PanelContainer.new()
	appearance_panel.add_child(VBoxContainer.new())
	menu_layer.add_child(appearance_panel)
	appearance_panel.hide()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	infantry_hud = GameInfantryHUD.new()
	infantry_hud.game = self
	hud_layer.add_child(infantry_hud)
	hp_label = infantry_hud.hp
	ammo_label = infantry_hud.ammo
	health_bar = infantry_hud.health
	rank_label = infantry_hud.rank
	lobby_panel = infantry_hud.lobby
	aim_dot = infantry_hud.dot
	damage_overlay = infantry_hud.damage
	message_label = infantry_hud.notice
	infantry_hud.shop.text = "IMPLANTAÇÃO · M"
	for connection in infantry_hud.shop.pressed.get_connections(): infantry_hud.shop.pressed.disconnect(connection.callable)
	infantry_hud.shop.pressed.connect(open_deployment)
	shop_panel = PanelContainer.new()
	var shop_content := VBoxContainer.new()
	shop_content.name = "ShopContent"
	shop_panel.add_child(shop_content)
	hud_layer.add_child(shop_panel)
	shop_panel.hide()

func _build_audio() -> void:
	GameAudioSettings.ensure()
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter:=AudioEffectLimiter.new();limiter.ceiling_db=-.7;limiter.threshold_db=-6
		AudioServer.add_bus_effect(0,limiter)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	sound_player = AudioStreamPlayer3D.new()
	sound_player.bus = "Efeitos"
	add_child(sound_player)

func _enter_match_world() -> void:
	var build_started:=Time.get_ticks_usec()
	if world_prebuilt and is_instance_valid(world_root): map_kind="war";return
	super._enter_match_world()
	map_kind = "war"
	war_fx = load("res://modes/war/scripts/projectiles.gd").new()
	war_fx.game = self
	world_root.add_child(war_fx)
	vehicle_system = load("res://modes/war/scripts/vehicles.gd").new()
	vehicle_system.game = self
	world_root.add_child(vehicle_system)
	metal_sparks=GameMetalSparks.new();world_root.add_child(metal_sparks)
	combat_effects=WarEffects.new()
	world_root.add_child(combat_effects)
	combat_audio=WarAudio.new()
	combat_audio.game=self
	world_root.add_child(combat_audio)
	soundscape=WarSoundscape.new();soundscape.game=self;world_root.add_child(soundscape)
	power_grid=WarPowerGrid.new();power_grid.game=self;world_root.add_child(power_grid)
	for id in WarRules.OBJECTIVES:
		var point: Vector3=WarRules.OBJECTIVES[id].position
		var at:=WarTerrain.point(point.x+6.,point.z+5.)
		if operation_id==WarOperation.UKRAINE and id in ["D","E"]: at.y=maxf(at.y,point.y)
		var crate:=WarMapContent.instantiate(world_root,"res://modes/war/library/caixa_municao.tscn",at,not dedicated_pvp and DisplayServer.get_name()!="headless")
		crate.name="Supply_"+id;supply_points[id]=at
	# Construct the shared bot route grid while the authority is loading the
	# world, rather than stopping the live match on its first deployment.
	if not testing or bool(get_meta("online_bots_test",false)):_prepare_online_bots()
	world_build_ms=(Time.get_ticks_usec()-build_started)*.001
	GameDiagnostics.record("war_world_ready",{"milliseconds":world_build_ms,"authority":multiplayer.is_server(),"online":online})

@rpc("authority","call_remote","reliable")
func war_pole_broken(id: String,at: float,yaw: float) -> void:
	if is_instance_valid(power_grid): power_grid.receive(id,at,yaw)

@rpc("authority","call_remote","reliable")
func war_poles_state(states: Array) -> void:
	if not is_instance_valid(power_grid): return
	for state: Array in states: power_grid.receive(str(state[0]),float(state[1]),float(state[2]))

func environment_blast(point: Vector3,amount: float,radius: float) -> void:
	if is_instance_valid(power_grid): power_grid.blast(point,amount,radius)

func _connected_to_server() -> void:
	_set_loading_timeout(1,true)
	super._connected_to_server()
	baseline_loading=true;join_ready=false
	ui_focus.open(loading_screen)

func _spawn_player(id: int,local: bool,npc := false,position := Vector3.ZERO) -> GamePlayer:
	var actor := super._spawn_player(id,local,npc,position) as WarPlayer
	actor.hp = 0.0
	actor.deployed = false
	actor.body_root.hide()
	actor.weapon_root.hide()
	actor._set_hitboxes_enabled(false)
	actor.body_collision.set_deferred("disabled",true)
	WarUniform.refresh_materials(actor,maxi(0,actor.war_team))
	return actor

@rpc("authority","call_remote","reliable")
func remote_add_player(id: int,nickname: String,appearance: Dictionary,pos: Vector3) -> void:
	super.remote_add_player(id,nickname,appearance,pos)
	var actor:=players.get(id) as WarPlayer
	if not is_instance_valid(actor): return
	actor.set_meta("appearance",appearance)
	actor.apply_body_proportions(appearance.get("proportions",{}))
	WarUniform.refresh_materials(actor,maxi(0,actor.war_team))

func _appearance_payload() -> Dictionary:
	var data := super._appearance_payload()
	data["war_protocol"] = WarRules.PROTOCOL
	data["map_content"] = load("res://scripts/maps/definition.gd").identity(WarRules.map_content())
	data["war_operation"] = operation_id
	return data

func _send_pvp_join() -> void:
	if pvp_join_sent or pvp_join_nonce.is_empty() or not is_instance_valid(local_player): return
	var key := main_accounts.device_key()
	var proof := Crypto.new().sign(HashingContext.HASH_SHA256,(pvp_join_nonce+str(pvp_ticket.get("payload",""))).sha256_buffer(),key)
	pvp_join_sent = true
	rpc_id(1,"server_join_request",str(profile.nickname),_appearance_payload(),pvp_ticket,key.save_to_string(true),proof)

@rpc("any_peer","call_remote","reliable")
func server_join_request(nickname: String,appearance: Dictionary,ticket: Dictionary = {},public_pem := "",proof := PackedByteArray()) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"join",.25,2): return
	if players.has(id) and not bool(members.get(id,{}).get("bot",false)): return
	if str(appearance.get("war_operation",WarOperation.UKRAINE))!=operation_id or not load("res://scripts/maps/definition.gd").compatible(WarRules.map_content(),appearance.get("map_content")):
		GameDiagnostics.record("admission_rejected",{"peer":id,"mode":"war","reason":"map_content"})
		_notice(id,"Atualize o mapa pelo launcher.");return
	if int(appearance.get("war_protocol",0))!=WarRules.PROTOCOL:
		GameDiagnostics.record("admission_rejected",{"peer":id,"mode":"war","reason":"protocol"})
		_notice(id,"Atualize o Toque de Campo pelo launcher para entrar nesta operação.")
		return
	var account := {}
	if not testing:
		if var_to_bytes(appearance).size()>4096 or var_to_bytes(ticket).size()>18000 or public_pem.length()>6000 or proof.size()>1024: return
		account = NavalAccounts.verify_ticket(ticket,public_pem.sha256_text())
		var challenge: Dictionary = pvp_challenges.get(id,{})
		var key := CryptoKey.new()
		if account.is_empty() or challenge.is_empty() or Time.get_ticks_msec()>int(challenge.expires) or key.load_from_string(public_pem,true)!=OK:
			GameDiagnostics.record("admission_rejected",{"peer":id,"mode":"war","reason":"account_or_challenge"});return
		if not Crypto.new().verify(HashingContext.HASH_SHA256,(str(challenge.nonce)+str(ticket.get("payload",""))).sha256_buffer(),proof,key): return
		for actor in players.values():
			if actor.get_meta("account_id","")==account.id: return
		nickname = str(account.username)
	# Only an authenticated human may displace a bot. A joining peer can
	# coincidentally receive a bot's numeric id, so release that id first.
	if players.has(id) and is_instance_valid(bot_director): bot_director.remove_bot(id)
	var humans:=0
	for member: Dictionary in members.values():
		if not member.get("bot",false):humans+=1
	if humans>=WarRules.HUMAN_CAPACITY:_notice(id,"Operação cheia.");return
	if players.size()>=WarRules.CAPACITY:
		if not is_instance_valid(bot_director) or not bot_director.evict_one(): return
	pvp_challenges.erase(id)
	var player := _spawn_player(id,false,false,WarTerrain.point(-560,0))
	player.name = nickname.left(24)
	GameDiagnostics.record("war_admitted",{"peer":id,"account":str(account.get("id","")).sha256_text().left(16)})
	player.set_meta("account_id",str(account.get("id","test_"+str(id))))
	player.set_meta("coins",int(account.get("coins",0)))
	var look: Dictionary=account.get("appearance",{}) if not testing else appearance
	player.set_meta("appearance",look)
	player.apply_body_proportions({});player.apply_body_colors(look.get("colors",{}))
	members[id] = {"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.0,"respawn_pending":false,"shield":0.0,"gadget":"rpg","pending":{},"last_gadget":-100.0}
	var transfer:=WarJoinTransfer.new()
	loading_baselines[id]=transfer
	for actor_id in players:transfer.queue(int(actor_id))
	if is_instance_valid(vehicle_system):
		for drone_id in vehicle_system.drones:transfer.queue_drone(str(drone_id))
	rpc_id(id,"war_baseline_begin",transfer.token,players.size())
	while not transfer.dirty.is_empty() or not transfer.drones.is_empty():
		if not _baseline_current(id,transfer):return
		if not transfer.expired(Time.get_ticks_msec()).is_empty():_fail_baseline(id,transfer,"total");return
		var pair:=transfer.take_pair();var began:=Time.get_ticks_usec()
		for other_id in pair:_send_war_actor_baseline(id,int(other_id))
		if pair.is_empty():
			pair=transfer.take_drone_pair()
			for drone_id in pair:
				var drone:=vehicle_system.drones.get(drone_id) as WarDrone
				if is_instance_valid(drone):vehicle_system.rpc_id(id,"baseline_drone",drone.snapshot())
				else:vehicle_system.rpc_id(id,"drone_removed",str(drone_id))
		transfer.actor_ms+=(Time.get_ticks_usec()-began)*.001
		if not await _send_baseline_chunk(id,transfer,pair.size(),players.size()):return
	# No await between draining mutations and releasing the peer. Future changes
	# now use normal replication, so no join/leave/identity transition is lost.
	loading_baselines.erase(id)
	state_recovery_sessions[id]={"token":transfer.token,"sequence":0}
	_set_loading_timeout(id,false)
	_broadcast("remote_add_player",[id,player.name,look,player.global_position])
	_broadcast("war_identity",[id,members[id]])
	rpc_id(id,"remote_wallet",int(player.get_meta("coins",0)),player.owned)
	if vehicle_system: vehicle_system.send_initial(id,false)
	if is_instance_valid(power_grid): rpc_id(id,"war_poles_state",power_grid.snapshot())
	rpc_id(id,"remote_match_stats",match_stats.snapshot())
	_send_war_snapshot()
	rpc_id(id,"war_baseline_complete",transfer.token)
	GameDiagnostics.record("war_baseline_ready",{"peer":id,"actors":players.size(),"batches":transfer.batches,"actor_ms":transfer.actor_ms,"wait_ms":transfer.wait_ms,"elapsed_ms":Time.get_ticks_msec()-transfer.started})

func _baseline_current(id: int,transfer: WarJoinTransfer) -> bool:
	return is_inside_tree() and not closing and loading_baselines.get(id)==transfer and not transfer.failed and id in multiplayer.get_peers()

func _send_war_actor_baseline(recipient: int,id: int) -> void:
	var actor:=players.get(id) as WarPlayer
	if not is_instance_valid(actor) or not members.has(id):rpc_id(recipient,"remote_player_left",id);return
	rpc_id(recipient,"remote_add_player",id,actor.name,actor.get_meta("appearance",{}),actor.global_position)
	if id!=recipient:_send_player_baseline(recipient,actor)
	rpc_id(recipient,"remote_grenade_selection",id,actor.grenade_selected and actor.hp>0)
	rpc_id(recipient,"war_identity",id,members[id])
	if id!=recipient:rpc_id(recipient,"war_baseline_pose",[id,actor.global_position,actor.yaw,actor.pitch,actor.weapon_id,actor.hp,actor.crouched,actor.life_id,actor.kills,actor.deaths,2 if actor.iron_sights else (1 if actor.aiming else 0),actor.lean,network_diagnostics.next_pose_sequence(id,actor.life_id)])
	if actor.reload_left>0:rpc_id(recipient,"remote_reload_started",id,actor.reload_weapon,actor.reload_total,actor.reload_left,actor.life_id,actor.reload_revision)

func _fail_baseline(id: int,transfer: WarJoinTransfer,reason: String) -> void:
	if loading_baselines.get(id)!=transfer:return
	transfer.failed=true
	GameDiagnostics.record("war_baseline_timeout",{"peer":id,"reason":reason,"batches":transfer.batches,"elapsed_ms":Time.get_ticks_msec()-transfer.started})
	if id in multiplayer.get_peers():
		rpc_id(id,"war_notice","Não foi possível concluir a entrada. Tente novamente.")
		# Allow the reliable notice to be polled before closing only this peer.
		await get_tree().create_timer(.25).timeout
		if is_inside_tree() and not closing and id in multiplayer.get_peers() and loading_baselines.get(id)==transfer:(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)

func _send_baseline_chunk(id: int,transfer: WarJoinTransfer,count: int,total: int) -> bool:
	var nonce:=transfer.begin_chunk()
	rpc_id(id,"war_baseline_chunk",transfer.token,nonce,count,total)
	while _baseline_current(id,transfer):
		var reason:=transfer.expired(Time.get_ticks_msec())
		if not reason.is_empty():_fail_baseline(id,transfer,reason);return false
		if transfer.acknowledged:
			transfer.wait_ms+=Time.get_ticks_msec()-transfer.waiting_since;return true
		await get_tree().process_frame
	return false

@rpc("authority","call_remote","reliable")
func war_baseline_begin(transfer: String,_total: int) -> void:
	baseline_transfer=transfer;baseline_loading=true;join_ready=false
	loading_screen.status.text="ENTRANDO NA OPERAÇÃO"
	loading_screen.detail.text="Preparando jogadores…"
	ui_focus.open(loading_screen)

@rpc("authority","call_remote","reliable")
func war_baseline_pose(state: Array) -> void:
	if state.size()==13:callv("remote_player_state",state)

@rpc("authority","call_remote","reliable")
func war_baseline_chunk(transfer: String,nonce: String,_count: int,_total: int) -> void:
	if not baseline_loading or transfer!=baseline_transfer:return
	loading_screen.detail.text="Preparando jogadores · %d"%players.size()
	await get_tree().process_frame
	await get_tree().process_frame
	if closing or not online or multiplayer.multiplayer_peer is OfflineMultiplayerPeer or transfer!=baseline_transfer:return
	rpc_id(1,"server_war_baseline_ack",transfer,nonce)

@rpc("any_peer","call_remote","reliable")
func server_war_baseline_ack(transfer: String,nonce: String) -> void:
	if not multiplayer.is_server():return
	var state:=loading_baselines.get(multiplayer.get_remote_sender_id()) as WarJoinTransfer
	if state:state.accept(transfer,nonce)

@rpc("authority","call_remote","reliable")
func war_baseline_complete(transfer: String) -> void:
	if not baseline_loading or transfer!=baseline_transfer:return
	_set_loading_timeout(1,false)
	baseline_loading=false;join_ready=true;loading_screen.hide();ui_focus.close_all()
	state_recovery_serial=0;state_recovery_pending=0
	state_recovery_started_at=Time.get_ticks_usec()
	state_recovery_request_at=0;state_recovery_check_at=0
	if not is_instance_valid(local_player) or not local_player.deployed:ui_focus.open(war_ui.deployment)
	GameDiagnostics.record("war_baseline_ready",{"actors":players.size()})

@rpc("authority","call_remote","reliable")
func war_identity(id: int,data: Dictionary) -> void:
	members[id] = data.duplicate(true)
	var actor := players.get(id) as WarPlayer
	if not is_instance_valid(actor): return
	var newly_deployed:=bool(data.deployed) and not actor.deployed
	actor.apply_identity(int(data.team),str(data.role))
	actor.deployed = bool(data.deployed)
	if newly_deployed: actor.stance.reset(actor)
	if actor.deployed: actor.set_posture(int(data.get("posture",0)),false,true)
	actor.vehicle_id = str(data.vehicle)
	actor.set_utility(str(data.get("utility","")) if actor.deployed and actor.vehicle_id.is_empty() else "")
	# Older state has no zoom field. Apply only after occupancy and mode so
	# a late snapshot cannot activate binoculars inside a vehicle.
	var identity_zoom: Variant=data.get("utility_zoom",0)
	actor.set_utility_zoom(clampi(int(identity_zoom),0,2) if identity_zoom is int else 0)
	actor.gadget = str(data.get("gadget","rpg"))
	if not actor.vehicle_id.is_empty():
		if not actor.vehicle_id.begins_with("drone_"): actor.stance.reset(actor)
		actor.grenade_selected=false;actor.grenade_aiming=false;actor.clear_aim()
		actor.set_gadget(false,actor.gadget)
		actor.cancel_reload()
		actor.body_root.visible=actor.vehicle_id.begins_with("drone_");actor.weapon_root.hide()
		if is_instance_valid(actor.view_root): actor.view_root.hide()
		if is_instance_valid(actor.grenade_view): actor.grenade_view.hide()
	if actor.deployed:
		var weapon_before_identity:=actor.weapon_id
		var approved:=GameLoadouts.validate(data.get("loadout",GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,actor.war_class,actor.war_team)),"war",GameWeapons.INFANTRY_IDS,actor.war_class,actor.war_team,true)
		if approved.ok:
			# Preserve the current equipped item and grenade count on seat/class
			# identity refreshes. Only a new life grants fresh inventory.
			var equipped:=actor.weapon_id;var count:=actor.grenades
			GameLoadouts.apply(actor,approved,true)
			if equipped in actor.active_weapons(): actor.weapon_id=equipped
			actor.grenades=mini(count,2) if actor.grenades_enabled else 0
		if actor.weapon_id!=weapon_before_identity:
			actor._refresh_weapon()
	var aboard := not actor.vehicle_id.is_empty() and not actor.vehicle_id.begins_with("drone_")
	var occupied: Node3D=vehicle_system.find_target(actor.vehicle_id) if is_instance_valid(vehicle_system) else null
	var exposed_transport:=is_instance_valid(occupied) and occupied is WarVehicle and bool(occupied.spec.get("transport",false))
	var armoured := aboard and not exposed_transport
	actor._set_hitboxes_enabled(actor.deployed and actor.hp>0 and not armoured)
	actor.body_collision.set_deferred("disabled",not actor.deployed or actor.hp<=0 or aboard)
	if actor.deployed and actor.hp>0 and actor.vehicle_id.is_empty():
		# Boarding hides the entire world rig. Restore it on every observer
		# when an authoritative exit arrives, respecting the local FPP/TPP view.
		actor._update_view()
	if not actor.deployed:
		actor.body_root.hide()
		actor._set_hitboxes_enabled(false)
	if id==multiplayer.get_unique_id():
		if not baseline_loading:join_ready = true
		last_notice = "Escolha sua implantação."
		war_ui.refresh_spawns()

func request_deploy(team: int,role: String,weapon: String,gadget: String,spawn_id: String,loadout: Dictionary={}) -> void:
	if offline_operation: _deploy(1,team,role,weapon,gadget,spawn_id,loadout)
	else: rpc_id(1,"war_deploy",team,role,weapon,gadget,spawn_id,loadout)

func _send_deployment_state(id: int) -> void:
	if not members.has(id) or not players.has(id): return
	if id in multiplayer.get_peers():
		rpc_id(id,"war_deployment_state",int(players[id].life_id),float(members[id].ready_at),Dictionary(members[id].get("pending",{})),war_clock)

@rpc("authority","call_remote","reliable")
func war_deployment_state(life: int,ready_at: float,pending: Dictionary,server_time:=-1.0) -> void:
	var id:=multiplayer.get_unique_id()
	if not members.has(id) or not players.has(id) or int(players[id].life_id)!=life: return
	if server_time>=0.0: war_clock=server_time
	members[id].ready_at=ready_at;members[id].pending=pending.duplicate(true)
	# This reliable state can arrive immediately before the death damage RPC.
	members[id].respawn_pending=ready_at>0.0

func _deployment_team_allowed(id: int,team: int) -> bool:
	if team not in [0,1] or not members.has(id): return false
	var teams: Dictionary={}
	var others:=0
	for peer in members:
		if bool(members[peer].get("bot",false)) and not bool(members[id].get("bot",false)): continue
		teams[peer]=members[peer].team
		if int(peer)!=id and int(members[peer].team)==team: others+=1
	# A dead member already owns this slot. A disconnected opponent must not
	# turn respawning in that reserved team into an illegal new team entry.
	if offline_operation:
		return others<ceili(offline_participants*.5)
	if bool(members[id].get("bot",false)): return others<WarRules.TEAM_LIMIT
	if int(members[id].team)==team: return others<WarRules.TEAM_LIMIT
	return WarRules.choose_team(team,teams,id)>=0

func _valid_deployment_spawn(team: int,spawn_id: String) -> bool:
	return spawn_id=="base" or (objective_states.has(spawn_id) and bool(WarRules.OBJECTIVES[spawn_id].active) and int(objective_states[spawn_id].owner)==team)

func sync_class_resources(id: int) -> void:
	if not multiplayer.is_server() or not members.has(id) or not players.has(id): return
	if id in multiplayer.get_peers():
		rpc_id(id,"war_class_resources",id,int(members[id].charges),float(members[id].last_gadget),int(players[id].life_id))

@rpc("authority","call_remote","reliable")
func war_class_resources(id: int,charges: int,last_used: float,life: int) -> void:
	if not members.has(id) or not players.has(id) or int(players[id].life_id)!=life: return
	var maximum:=int(WarRules.CLASSES[str(members[id].role)].charges)
	members[id].charges=clampi(charges,0,maximum)
	members[id].last_gadget=last_used

@rpc("any_peer","call_remote","reliable")
func war_deploy(team: int,role: String,weapon: String,gadget: String,spawn_id: String,loadout: Dictionary={}) -> void:
	if not multiplayer.is_server(): return
	if not network_guard.allow(multiplayer.get_remote_sender_id(),"deploy",4,3): return
	if var_to_bytes(loadout).size()>4096: return
	_deploy(multiplayer.get_remote_sender_id(),team,role,weapon,gadget,spawn_id,loadout)

func _deploy(id: int,team: int,role: String,weapon: String,gadget: String,spawn_id: String,loadout: Dictionary={}) -> bool:
	if loading_baselines.has(id):return false
	if not members.has(id) or not players.has(id) or match_ended or not WarRules.CLASSES.has(role): return false
	var state: Dictionary = members[id]
	var actor := players[id] as WarPlayer
	if not _deployment_team_allowed(id,team): _notice(id,"Equipe cheia ou desequilibrada. Escolha a outra equipe.");return false
	if (loadout.is_empty() and weapon not in WarRules.primary_for(role,team)) or gadget not in ["rpg","stinger"]: _notice(id,"Equipamento indisponível.");return false
	if loadout.is_empty():
		loadout=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,role,team);loadout.primary=weapon
	var approved:=GameLoadouts.validate(loadout,"war",GameWeapons.INFANTRY_IDS,role,team)
	if not approved.ok: _notice(id,str(approved.error));return false
	weapon=str(approved.equipped)
	if role=="antitank" and not WarRules.launcher_allowed(team,gadget):
		_notice(id,"Sua equipe utiliza "+str(GameWeapons.ITEMS[WarRules.launcher_for_team(team)].name)+".");return false
	if role!="antitank": gadget=WarRules.launcher_for_team(team)
	if not _valid_deployment_spawn(team,spawn_id): _notice(id,"Ponto indisponível. Escolha uma base ou setor da sua equipe.");return false
	var chosen := {"team":team,"role":role,"weapon":weapon,"gadget":gadget,"spawn":spawn_id,"life":actor.life_id,"loadout":approved.slots.duplicate()}
	if actor.deployed and actor.hp>0:
		state.pending = chosen
		_send_deployment_state(id)
		_notice(id,"Equipamento salvo para o próximo respawn.")
		return true
	if war_clock<float(state.ready_at): _notice(id,"Aguarde %.1f s para implantar." % (float(state.ready_at)-war_clock));return false
	state.merge({"team":team,"role":role,"weapon":weapon,"deployed":true,"posture":0,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":int(WarRules.CLASSES[role].charges),"gadget":gadget,"spawn":spawn_id,"shield":war_clock+4.0,"pending":{},"ready_at":0.0,"respawn_pending":false,"drone_used":false,"utility":"","utility_zoom":0,"loadout":approved.slots.duplicate()},true)
	actor.apply_identity(team,role)
	actor.deployed = true
	actor.vehicle_id = ""
	actor.set_utility("")
	GameLoadouts.apply(actor,approved,true)
	if str(approved.equipment).is_empty(): state.charges=0
	actor.weapon_id = weapon
	actor.set_gadget(false,gadget)
	actor.stance.reset(actor)
	super._reset_server_player(actor)
	state.life=actor.life_id
	actor.body_collision.set_deferred("disabled",false)
	var forward := (Vector3(0,0,75)-actor.global_position).normalized()
	actor.yaw = atan2(-forward.x,-forward.z)
	actor.rotation.y=actor.yaw
	# The authority needs the same new model/muzzle as its observers. Remote
	# actors otherwise kept their initial AK geometry after a FAL deployment.
	actor._refresh_weapon();actor._update_weapon_pose()
	_broadcast("war_identity",[id,state])
	_broadcast("war_spawn_pose",[id,actor.yaw])
	_broadcast("remote_equipped",[id,weapon])
	if actor.is_local:
		if is_instance_valid(death_view): death_view.stop()
		actor.camera.make_current()
		actor._update_view()
	if offline_operation and id==1:
		if is_instance_valid(bot_director): bot_director.populate.call_deferred(team)
	elif online and multiplayer.is_server() and not bool(state.get("bot",false)) and _battle_active() and (not testing or bool(get_meta("online_bots_test",false))):
		_start_online_bots.call_deferred()
	_notice(id,"Implantação confirmada.")
	return true

@rpc("authority","call_remote","reliable")
func war_spawn_pose(id: int,yaw: float) -> void:
	var actor := players.get(id) as WarPlayer
	if is_instance_valid(actor):
		actor.yaw=yaw;actor.rotation.y=yaw
		if actor.is_local: actor._update_view()

func find_spawn(id: int) -> Vector3:
	var data: Dictionary = members.get(id,{"team":0,"spawn":"base"})
	var team := maxi(0,int(data.team))
	var p: Vector3 = WarRules.BASES[team]
	var spawn_id:=str(data.get("spawn","base"))
	if spawn_id!="base" and _valid_deployment_spawn(team,spawn_id):
		# A friendly captured sector takes precedence over offline bot-lane
		# staging. Previously every offline bot ignored its selected rally flag.
		p=WarRules.OBJECTIVES[spawn_id].position
	elif offline_operation and bool(data.get("bot",false)):
		var lane:=clampi(int(data.get("bot_lane",0)),0,8)
		if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
			if lane<4:
				# Vehicle crews must start close enough to board from either base.
				p=WarRules.BASES[team]+Vector3((lane%2)*7-4,0,-8+(lane/2)*8)
			else:
				var base: Vector3=WarRules.BASES[team]
				var front: Vector3=WarRules.OBJECTIVES["D" if team==0 else "B"].position
				p=base.lerp(front,.12+.06*lane)+Vector3((lane%3-1)*7,0,((lane/3)-1)*6)
		elif lane<4: p=WarRules.BASES[team]+Vector3((lane%2)*5-3,0,-10+(lane/2)*7)
		else: p=Vector3(-190 if team==0 else 190,0,-180+(lane-4)*57)
	var best := p
	var score := -INF
	for offset: Vector2 in [Vector2(0,9),Vector2(-9,12),Vector2(9,12),Vector2(-16,6),Vector2(16,6),Vector2(0,20)]:
		var candidate := WarTerrain.point(p.x+offset.x,p.z+offset.y)+Vector3.UP*.12
		if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN and (not BRAfghanMap.accessible(candidate) or BRAfghanMap.is_water(candidate)): continue
		var distance := 100000.0
		for other in players.values():
			if other.peer_id!=id and other.hp>0: distance = minf(distance,other.global_position.distance_squared_to(candidate))
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .35;capsule.height = 1.8
		query.shape = capsule
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,candidate+Vector3.UP*.94)
		if is_inside_tree() and not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		if distance>score: score=distance;best=candidate
	return best

func _reset_server_player(_actor: GamePlayer) -> void: pass # Respawn is an explicit validated deployment.

func _pvp_reward(killer: String,victim: String,event: String,peer: int) -> void:
	if testing or offline_operation or killer.is_empty() or victim.is_empty(): return
	reward_jobs.append({"killer":killer,"victim":victim,"event":event,"peer":peer})
	if not rewarding: _reward_queue()

func _reward_queue() -> void:
	rewarding=true
	while not reward_jobs.is_empty() and is_inside_tree():
		var job: Dictionary=reward_jobs.pop_front()
		var ids: Array=[job.killer,job.victim]
		for actor in players.values():
			var account_id:=str(actor.get_meta("account_id",""))
			if not account_id.is_empty() and not ids.has(account_id) and ids.size()<12: ids.append(account_id)
		var registered:=await main_accounts.call_api("match_register",{"match":pvp_match_id,"players":ids,"mode":"war"})
		if not registered.get("ok",false): continue
		var result:=await main_accounts.call_api("reward",{"match":pvp_match_id,"event":pvp_match_id+":"+str(job.event),"killer":job.killer,"victim":job.victim})
		if not result.get("ok",false): continue
		var wallet:=await main_accounts.call_api("match_wallet",{"match":pvp_match_id,"account":job.killer})
		if wallet.get("ok",false) and players.has(job.peer):
			players[job.peer].set_meta("coins",int(wallet.account.coins))
			if job.peer in multiplayer.get_peers(): rpc_id(int(job.peer),"remote_wallet",int(wallet.account.coins),players[job.peer].owned)
	rewarding=false

func _on_player_died(victim: GamePlayer,killer_id: int) -> void:
	_stats_death(victim)
	_record_match_death(victim)
	var killer:=players.get(killer_id) as GamePlayer
	if multiplayer.is_server() and is_instance_valid(killer) and killer!=victim and not killer.is_npc:
		var event:="%d:%d:%d"%[match_generation,victim.peer_id,victim.life_id]
		if offline_operation and killer==local_player: war_elimination(event,_friendly_hit(killer,victim))
		elif killer_id in multiplayer.get_peers(): rpc_id(killer_id,"war_elimination",event,_friendly_hit(killer,victim))
	if multiplayer.is_server() and _friendly_hit(killer,victim):
		_register_match_stat(killer)
		if match_stats.teamkill(killer_id,victim.peer_id,victim.life_id,WarRules.TEAMKILL_PENALTY):
			_combat_notice(killer_id,"FOGO AMIGO · Você matou %s. −%d PONTOS"%[str(victim.name).left(24),WarRules.TEAMKILL_PENALTY])
			_combat_notice(victim.peer_id,"FOGO AMIGO · Você foi morto por seu aliado %s."%str(killer.name).left(24))
	if is_instance_valid(grenades_system): grenades_system.drop_owner(victim.peer_id)
	victim.death_sound = randi_range(0,5)
	if members.has(victim.peer_id):
		var state: Dictionary = members[victim.peer_id]
		state.utility="";state.utility_zoom=0
		if victim is WarPlayer: victim.set_utility("")
		state.ready_at = war_clock+WarRules.PLAYER_RESPAWN_SECONDS
		state.respawn_pending = true
		state.deployed=false
		victim.set("deployed",false)
		victim.respawn_left=0.0 # The War deployment system owns respawn in online and offline matches.
		if multiplayer.is_server():
			if int(state.team)>=0: tickets[int(state.team)] = maxi(0,int(tickets[int(state.team)])-1)
			if vehicle_system: vehicle_system.release(victim.peer_id,true)
			_send_deployment_state(victim.peer_id)
	# A presentation error must never prevent authority from scheduling the
	# next life or releasing an occupied seat. Corpses are local presentation.
	if DisplayServer.get_name()!="headless": spawn_ragdoll(victim.global_position,killer_id,victim)
	# Keep the player's camera active so they can look around while waiting.
	if victim.is_local: _open_after_death(victim.life_id)

func _open_after_death(life: int) -> void:
	if not is_inside_tree() or not is_instance_valid(local_player) or local_player.life_id!=life or local_player.hp>0: return
	if is_instance_valid(death_view): death_view.stop()
	local_player.camera.make_current()
	if not ui_focus.blocked(): Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

@rpc("authority","call_remote","reliable")
func war_elimination(event_id: String,friendly: bool) -> void:
	if is_instance_valid(combat_audio): combat_audio.confirm_elimination(event_id,friendly)

@rpc("authority","call_remote","reliable")
func remote_damage(victim_id: int,state: Dictionary) -> void:
	var actor:=players.get(victim_id) as WarPlayer
	if not is_instance_valid(actor) or int(state.get("life",-1))!=actor.life_id: return
	var was_alive:=is_instance_valid(actor) and actor.hp>0
	super.remote_damage(victim_id,state)
	if is_instance_valid(actor) and actor.hp<=0:
		actor.set_utility("")
		actor.deployed=false
		actor.respawn_left=0.0
		if members.has(victim_id):
			members[victim_id].utility="";members[victim_id].utility_zoom=0
			members[victim_id].deployed=false
			members[victim_id].respawn_pending=true
			if was_alive and float(members[victim_id].get("ready_at",0.0))<=0.0: members[victim_id].ready_at=war_clock+WarRules.PLAYER_RESPAWN_SECONDS
	if was_alive and is_instance_valid(actor) and actor.is_local and actor.hp<=0: _open_after_death(actor.life_id)

func _peer_disconnected(id: int) -> void:
	loading_baselines.erase(id)
	state_recovery_sessions.erase(id)
	# Revoke controls and capture eligibility synchronously, then spread visual
	# node/resource destruction over later frames via the shared retire queue.
	if vehicle_system and multiplayer.is_server():
		vehicle_system.release(id,true)
		for drone: WarDrone in vehicle_system.drones.values().duplicate():
			if drone.owner_id==id:
				drone.destroyed=true;drone.collision_layer=0
				vehicle_system._broadcast("drone_removed",[drone.drone_id]);vehicle_system.drones.erase(drone.drone_id);_retire_avatar(drone)
		vehicle_system.controls.erase(id)
		vehicle_system.sequences.erase(id)
		vehicle_system.healing.erase(id)
		vehicle_system.locks.erase(id)
	if war_fx: war_fx.discard_owner(id)
	if is_instance_valid(soundscape): soundscape.forget_owner(id)
	members.erase(id)
	super._peer_disconnected(id)
	if multiplayer.is_server():
		var humans:=0
		for member: Dictionary in members.values():
			if not bool(member.get("bot",false)): humans+=1
		if humans==0 and is_instance_valid(bot_director): bot_director.clear_online()
		if humans==0: reset_operation()

func _server_accept_shot(id: int,sequence: int,life: int,camera_origin: Vector3,direction: Vector3,weapon: String,aim_level := -1) -> void:
	if water_restricted(players.get(id)) or not _eligible(id) or not _battle_active():
		var rejected:=players.get(id) as GamePlayer
		if is_instance_valid(rejected) and rejected.life_id==life:
			shot_sequences[id]=maxi(sequence,int(shot_sequences.get(id,0)))
			sync_inventory(rejected)
		return
	var actor := players[id] as WarPlayer
	if actor.gadget_equipped or not actor.utility_mode.is_empty(): return
	# A client cannot submit a shot below the same prone limit it sees.
	if actor.prone and direction.is_finite() and direction.length_squared()>.9 and asin(clampf(direction.normalized().y,-1.,1.))<-.41:
		sync_inventory(actor)
		return
	members[id].shield = 0.0
	super._server_accept_shot(id,sequence,life,camera_origin,direction,weapon,aim_level)

func _eligible(id: int) -> bool:
	return players.has(id) and members.has(id) and bool(members[id].deployed) and int(members[id].team)>=0 and players[id].hp>0 and str(members[id].vehicle).is_empty()

func request_posture(actor: WarPlayer,value: int) -> void:
	if members.has(actor.peer_id): members[actor.peer_id].posture=value
	if online and not multiplayer.is_server(): rpc_id(1,"war_posture_request",actor.life_id,value)
	else: _broadcast("war_posture_state",[actor.peer_id,actor.life_id,value])

@rpc("any_peer","call_remote","reliable")
func war_posture_request(life: int,value: int) -> void:
	var id:=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not network_guard.allow(id,"stance",8,4) or not _eligible(id): return
	var actor:=players[id] as WarPlayer
	if life!=actor.life_id or actor.in_water(): return
	actor.set_posture(value)
	members[id].posture=2 if actor.prone else (1 if actor.crouched else 0)
	_broadcast("war_posture_state",[id,life,2 if actor.prone else (1 if actor.crouched else 0)])

@rpc("authority","call_remote","reliable")
func war_posture_state(id: int,life: int,value: int) -> void:
	var actor:=players.get(id) as WarPlayer
	if is_instance_valid(actor) and actor.life_id==life and actor.hp>0:
		actor.set_posture(value,false,true)

func _server_reload(id: int,weapon: String) -> void:
	if not _eligible(id): return
	if not (players[id] as WarPlayer).utility_mode.is_empty(): return
	super._server_reload(id,weapon)

func _equip_server(actor: GamePlayer,weapon: String) -> void:
	if not is_instance_valid(actor) or not _eligible(actor.peer_id) or water_restricted(actor): return
	if actor is WarPlayer and not actor.utility_mode.is_empty(): vehicle_system._set_utility(actor.peer_id,"")
	super._equip_server(actor,weapon)

func melee_sweep(actor: GamePlayer,previous: PackedVector3Array,current: PackedVector3Array) -> void:
	if not is_instance_valid(actor) or not _eligible(actor.peer_id) or water_restricted(actor): return
	super.melee_sweep(actor,previous,current)

func _battle_active() -> bool:
	var teams := [0,0]
	for state in members.values():
		if online and not bool(state.get("bot",false)) and int(state.team)>=0: return not match_ended
		if not online and int(state.team)>=0: teams[int(state.team)]+=1
	return teams[0]>0 and teams[1]>0 and not match_ended

func _start_online_bots() -> void:
	if not _battle_active():return
	_prepare_online_bots()

func _prepare_online_bots() -> void:
	if offline_operation or not online or not multiplayer.is_server() or closing or is_instance_valid(bot_director):return
	var started:=Time.get_ticks_usec()
	bot_director=load("res://modes/war/scripts/bot_director.gd").new()
	bot_director.setup(self,true);world_root.add_child(bot_director)
	GameDiagnostics.record("war_bots_prepared",{"milliseconds":(Time.get_ticks_usec()-started)*.001})

@rpc("authority","call_remote","unreliable")
func war_bot_states(batch: Array) -> void:
	# A global unreliable-ordered stream mixes different bots and payload
	# sizes. Let the receiver order each actor/life by its own sequence.
	if batch.size()>4: return
	for state in batch:
		if state is Array and state.size()==13 and state[12] is int and int(state[12])>0: callv("remote_player_state",state)

func _step_state_recovery() -> void:
	# ENet can temporarily suppress unreliable traffic while reliable commands
	# still arrive. Recover only current, stale state; never queue movement history.
	if not online or closing or multiplayer.is_server() or not join_ready or baseline_loading or state_recovery_started_at==0:return
	var now:=Time.get_ticks_usec()
	if now<state_recovery_check_at or state_recovery_pending!=0:return
	state_recovery_check_at=now+200000
	if now-state_recovery_started_at<STATE_STALE_USEC or now<state_recovery_request_at:return
	var stale: Array[int]=[]
	for key in players:
		var actor:=players[key] as WarPlayer
		if not is_instance_valid(actor) or actor.is_local or not actor.deployed or actor.hp<=0:continue
		if now-int(actor.last_snapshot_time*1000000.)>=STATE_STALE_USEC:stale.append(int(key))
		if stale.size()>=WarRules.CAPACITY:break
	if stale.is_empty() and now-operation_received_at<STATE_STALE_USEC:return
	state_recovery_serial+=1;state_recovery_pending=state_recovery_serial
	state_recovery_request_at=now+STATE_RECOVERY_INTERVAL_USEC
	rpc_id(1,"server_war_state_recovery",baseline_transfer,state_recovery_pending,stale)

func _state_recovery_payload(id: int,token: String,sequence: int,ids: Array) -> Array:
	# Admission binds the token to this connection. Loading and unauthenticated
	# peers cannot request a second baseline or allocate arbitrary avatars.
	if closing or loading_baselines.has(id) or not members.has(id) or bool(members[id].get("bot",false)) or ids.size()>WarRules.CAPACITY:return []
	var session: Dictionary=state_recovery_sessions.get(id,{})
	if session.is_empty() or token!=str(session.token) or sequence<=int(session.sequence) or sequence>2147483647:return []
	if not network_guard.allow(id,"state_recovery",2,1):return []
	session.sequence=sequence
	var poses: Array=[];var seen: Dictionary={}
	for key in ids:
		if not key is int or key==id or seen.has(key):continue
		seen[key]=true
		var actor:=players.get(key) as WarPlayer
		if not is_instance_valid(actor) or not actor.deployed or actor.hp<=0 or not members.has(key):continue
		poses.append([key,actor.global_position,actor.yaw,actor.pitch,actor.weapon_id,actor.hp,actor.crouched,actor.life_id,actor.kills,actor.deaths,2 if actor.iron_sights else (1 if actor.aiming else 0),actor.lean,network_diagnostics.next_pose_sequence(key,actor.life_id)])
	state_recovery_sent+=1
	return [_war_snapshot_payload(),poses]

@rpc("any_peer","call_remote","reliable")
func server_war_state_recovery(token: String,sequence: int,ids: Array) -> void:
	if not multiplayer.is_server():return
	var id:=multiplayer.get_remote_sender_id()
	var payload:=_state_recovery_payload(id,token,sequence,ids)
	if not payload.is_empty():rpc_id(id,"war_state_recovery",token,sequence,payload[0],payload[1])

@rpc("authority","call_remote","reliable")
func war_state_recovery(token: String,sequence: int,operation: Array,poses: Array) -> void:
	if closing or baseline_loading or not join_ready or token!=baseline_transfer or sequence!=state_recovery_pending or sequence<=0:return
	state_recovery_pending=0
	if operation.size()!=9 or poses.size()>WarRules.CAPACITY:return
	# The usual generation/life/sequence checks also apply to reliable recovery.
	# An old response must not rewind a newer unreliable update or revive a corpse.
	if int(operation[8])<authority_round_generation:return
	callv("war_snapshot",operation)
	for pose in poses:
		if pose is Array and pose.size()==13 and pose[12] is int and int(pose[12])>0:callv("remote_player_state",pose)
	state_recovery_received+=1

func scoreboard_context() -> Dictionary:
	var objectives: Array[String]=[]
	for id in WarRules.OBJECTIVES:
		var owner:=int(objective_states[id].owner)
		objectives.append(id+" · "+("NEUTRO" if owner<0 else WarRules.team_name(owner).to_upper()))
	if match_ended: objectives.append("EMPATE" if winner<0 else "VITÓRIA · "+WarRules.team_name(winner).to_upper())
	return {"mode":"GUERRA · CONQUISTA"+(" · OFFLINE" if offline_operation else ""),"map":WarRules.map_name().to_upper(),"seconds":match_left,"time_label":"RESTANTE","network":online and not offline_operation,"teams":true,"tickets":"%s · %d TICKETS     |     %s · %d TICKETS"%[WarRules.team_name(0).to_upper(),int(tickets[0]),WarRules.team_name(1).to_upper(),int(tickets[1])],"objectives":"     ".join(objectives)}

func _defending_objective(attacker: GamePlayer,victim: GamePlayer) -> bool:
	var team:=int(attacker.get("war_team"))
	for id in WarRules.OBJECTIVES:
		if int(objective_states[id].owner)!=team: continue
		var point: Vector3=WarRules.OBJECTIVES[id].position
		if attacker.global_position.distance_to(WarTerrain.point(point.x,point.z))<WarRules.CAPTURE_RADIUS and victim.global_position.distance_to(WarTerrain.point(point.x,point.z))<WarRules.CAPTURE_RADIUS: return true
	return false

func _apply_hit(owner_id: int,hit: Dictionary,damage: float,fallback_region := "chest",weapon := "ak",direction := Vector3.ZERO) -> void:
	var object: Node = hit.get("collider")
	if is_instance_valid(power_grid) and power_grid.hit(object,damage,direction): return
	if vehicle_system and vehicle_system.damage_from_hit(owner_id,object,damage,weapon,direction): return
	var target := object
	while is_instance_valid(target) and not target is GamePlayer: target = target.get_parent()
	if not target is GamePlayer: return
	if members.has(target.peer_id):
		if war_clock<float(members[target.peer_id].shield): return
	var before: float=target.hp
	var controlled_drone: String=target.vehicle_id if target.vehicle_id.begins_with("drone_") else ""
	super._apply_hit(owner_id,hit,damage,fallback_region,weapon,direction)
	if target.hp<before and not controlled_drone.is_empty() and vehicle_system:
		# Death already releases the operator. Nonlethal damage does too.
		if target.vehicle_id==controlled_drone: vehicle_system.release(target.peer_id,true)

func _friendly_hit(attacker: GamePlayer,target: GamePlayer) -> bool:
	return is_instance_valid(attacker) and is_instance_valid(target) and attacker!=target and members.has(attacker.peer_id) and members.has(target.peer_id) and int(members[attacker.peer_id].team)>=0 and int(members[attacker.peer_id].team)==int(members[target.peer_id].team)

func _combat_notice(id: int,message: String) -> void:
	if offline_operation and is_instance_valid(local_player) and id==local_player.peer_id: war_combat_notice(message)
	elif id in multiplayer.get_peers(): rpc_id(id,"war_combat_notice",message)

@rpc("authority","call_remote","reliable")
func war_combat_notice(message: String) -> void:
	if is_instance_valid(war_ui): war_ui.show_combat_notice(message)

@rpc("any_peer","call_remote","unreliable")
func server_player_state(pos: Vector3,new_yaw: float,new_pitch: float,_weapon: String,is_crouched: bool,aim_level := 0,state_life:=1,state_sequence:=0,state_lean:=0.0) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"motion",40,8): return
	if not _eligible(id) or not CombatRules.finite_vector(pos) or not is_finite(new_yaw) or not is_finite(new_pitch) or not is_finite(state_lean) or absf(state_lean)>1.: return
	var actor: WarPlayer = players[id]
	if actor.life_id!=state_life: return
	network_diagnostics.observe_input(id,state_life,state_sequence)
	var stance_speed:=.24 if actor.prone else (.53 if actor.crouched else 1.6)
	var bounded:=network_guard.movement(id,actor.life_id,state_sequence,actor.global_position,pos,WarRules.WALK_SPEED*stance_speed*actor.infantry_protection.multiplier()+2.0)
	if not bounded.accepted: return
	if not Vector3(bounded.position).is_equal_approx(pos):
		pos=bounded.position
		rpc_id(id,"remote_position_correction",pos)
	var ground := WarTerrain.height_at(pos.x,pos.z)
	if absf(pos.x)>WarTerrain.HALF-5 or absf(pos.z)>WarTerrain.HALF-5: return
	var over_water:=WarRules.CURRENT_OPERATION==WarOperation.UKRAINE and ground<-.6
	var water_surface:=WarCoast.wave(pos,war_clock) if over_water else -INF
	if over_water:
		# Permit a dry pier as well as swimming, but not flying above the sea.
		var platform_ray:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.3,pos-Vector3.UP*1.5,1,[actor.get_rid()])
		var on_platform:=not get_world_3d().direct_space_state.intersect_ray(platform_ray).is_empty()
		if not on_platform and (pos.y<water_surface-1.4 or pos.y>water_surface+.3): return
	elif pos.y<ground-2 or pos.y>ground+5: return
	var contact_height:=minf(.9,actor.camera_pivot.position.y)
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*contact_height,pos+Vector3.UP*contact_height,1,[actor.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		rpc_id(id,"remote_position_correction",actor.global_position)
		return
	if actor.crouched!=is_crouched: actor._set_crouched(is_crouched)
	actor.aiming = aim_level>0
	actor.iron_sights = aim_level==2
	actor.receive_network_state(pos,wrapf(new_yaw,-PI,PI),actor.clamp_aim_pitch(new_pitch))
	actor.network_lean=GameInfantryPose.limit_lean(actor,state_lean);actor.lean=actor.network_lean
	actor.camera_pivot.position.x=actor.lean*GameInfantryPose.LEAN_DISTANCE
	actor._animate_walk()
	# Relay the validated pose in this tick instead of parking it until the
	# next 50 ms broadcast. Vehicle occupants use their seat snapshots.
	_broadcast("remote_player_state",[id,actor.global_position,actor.yaw,actor.pitch,actor.weapon_id,actor.hp,actor.crouched,actor.life_id,actor.kills,actor.deaths,2 if actor.iron_sights else (1 if actor.aiming else 0),actor.lean])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_N and is_instance_valid(war_ui):
		war_ui.toggle_map();get_viewport().set_input_as_handled();return
	if is_instance_valid(local_player) and local_player.hp<=0:
		if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not ui_focus.blocked():
			local_player.apply_look(event.relative)
		return
	# Preserve the ordinary look path, including the vehicle operator's camera.
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	_step_state_recovery()
	frame_pacing.tick(self)
	if baseline_loading and is_instance_valid(loading_screen):loading_screen.detail.text="Preparando jogadores · %d"%players.size()

func _physics_process(delta: float) -> void:
	var tick_started:=Time.get_ticks_usec()
	if offline_frozen:
		# The offline result panel pauses the world, but its intermission must
		# keep counting or the operation could never start the next round.
		if offline_operation and match_ended:
			war_clock+=delta;round_restart_left=maxf(0.,round_restart_left-delta)
			if round_restart_left<=0: reset_operation()
		return
	super._physics_process(delta)
	war_clock += delta
	war_tick += 1
	if is_instance_valid(local_player) and local_player.hp<=0 and bool(members.get(local_player.peer_id,{}).get("respawn_pending",false)) and deployment_wait_left()<=0 and death_deployment_life!=local_player.life_id and not match_ended:
		death_deployment_life=local_player.life_id
		open_deployment()
	if online and not multiplayer.is_server() and is_instance_valid(local_player) and local_player.hp<=0 and deployment_wait_left()<=0 and bool(members.get(local_player.peer_id,{}).get("deployed",false)):
		life_sync_wait+=delta
		if life_sync_wait>1.0:
			life_sync_wait=0;rpc_id(1,"war_recover_life",local_player.life_id)
	else: life_sync_wait=0
	if not (online or offline_operation) or not multiplayer.is_server(): return
	_process_queued_deployments()
	if match_ended:
		round_restart_left=maxf(0.,round_restart_left-delta)
		if round_restart_left<=0: reset_operation()
	if _battle_active():
		match_left = maxf(0,match_left-delta)
		for id in WarRules.OBJECTIVES:
			if not WarRules.OBJECTIVES[id].active: continue
			var counts := [0,0]
			var point: Vector3 = WarRules.OBJECTIVES[id].position
			for peer in members:
				if not _eligible(peer): continue
				var p: Vector3 = players[peer].global_position
				if Vector2(p.x-point.x,p.z-point.z).length()<WarRules.CAPTURE_RADIUS: counts[int(members[peer].team)]+=1
			var previous_owner:=int(objective_states[id].owner)
			var side:=0 if counts[0]>counts[1] else 1
			objective_states[id] = WarRules.capture(objective_states[id],counts,delta)
			if previous_owner!=int(objective_states[id].owner):
				for peer in members:
					if not _eligible(peer) or int(members[peer].team)!=side: continue
					var at: Vector3=players[peer].global_position
					if Vector2(at.x-point.x,at.z-point.z).length()>=WarRules.CAPTURE_RADIUS: continue
					_register_match_stat(players[peer])
					match_stats.award(peer,75 if int(objective_states[id].owner)<0 else 150,"objective:"+str(id)+":"+str(war_tick),"objective")
		ticket_clock += delta
		if ticket_clock>=2:
			ticket_clock = 0
			var held := [0,0]
			for id in WarRules.OBJECTIVES:
				var team := int(objective_states[id].owner)
				if team>=0: held[team]+=1
			if held[0]!=held[1]:
				var losing := 1 if held[0]>held[1] else 0
				tickets[losing] = maxi(0,int(tickets[losing])-absi(held[0]-held[1]))
		if tickets[0]<=0 or tickets[1]<=0 or match_left<=0:
			match_ended = true
			winner = -1 if tickets[0]==tickets[1] else (0 if tickets[0]>tickets[1] else 1)
			round_restart_left=WarRules.ROUND_BREAK_SECONDS
			_broadcast("war_round_ended",[winner,round_restart_left,match_generation])
			if offline_operation: war_round_ended(winner,round_restart_left,match_generation)
	snapshot_clock += delta
	if NetworkCadence.due(snapshot_clock,.2):
		snapshot_clock = NetworkCadence.consume(snapshot_clock,.2)
		_send_war_snapshot()

	var elapsed:=(Time.get_ticks_usec()-tick_started)*.001
	simulation_peak_ms=maxf(simulation_peak_ms,elapsed);simulation_total_ms+=elapsed;simulation_samples+=1
	if war_clock-simulation_report_at>=10.:
		simulation_report_at=war_clock
		GameDiagnostics.record("war_simulation",{"mean_ms":simulation_total_ms/maxi(1,simulation_samples),"peak_ms":simulation_peak_ms,"engine_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,"population":_health_status(),"rtt_ms":_transport_rtt()})
		simulation_peak_ms=0.;simulation_total_ms=0.;simulation_samples=0

func _transport_rtt() -> Dictionary:
	var values: Array=[]
	var transport:=multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport:
		for id in multiplayer.get_peers():
			var peer:=GameNetworkPeers.connected(transport,id)
			if peer:values.append(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return network_diagnostics.stats(values)

func _process_queued_deployments() -> void:
	if not multiplayer.is_server() or match_ended: return
	for id in members:
		var actor:=players.get(id) as WarPlayer
		var state: Dictionary=members[id]
		if not is_instance_valid(actor) or actor.hp>0 or not bool(state.get("respawn_pending",false)) or war_clock<float(state.get("ready_at",0.0)): continue
		# Humans review the map/loadout and explicitly confirm deployment.
		# Offline bots retain their authoritative automatic return.
		if not bool(state.get("bot",false)): continue
		var queued: Dictionary=state.get("pending",{})
		# A menu selection is optional. If the player did not open M, restore
		# the last server-validated class, loadout and spawn after the 8 s wait.
		var selection: Dictionary=queued if not queued.is_empty() and int(queued.get("life",-1))==actor.life_id else state
		var team:=int(selection.get("team",state.get("team",-1)))
		if team not in [0,1] or not _deployment_team_allowed(id,team):
			team=int(state.get("team",-1))
		if team not in [0,1] or not _deployment_team_allowed(id,team):
			team=-1
			for candidate in [0,1]:
				if _deployment_team_allowed(id,candidate): team=candidate;break
		if team not in [0,1]:
			state.pending={};state.respawn_pending=false
			_notice(id,"Não há vaga disponível para reaparecer.")
			continue
		var role:=str(selection.get("role","soldier"))
		if not WarRules.CLASSES.has(role): role="soldier"
		var loadout: Dictionary=Dictionary(selection.get("loadout",{})).duplicate(true)
		var weapon:=str(selection.get("weapon",WarRules.primary_for(role,team)[0]))
		if loadout.is_empty():
			loadout=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,role,team)
			if weapon in WarRules.primary_for(role,team): loadout.primary=weapon
		var approved:=GameLoadouts.validate(loadout,"war",GameWeapons.INFANTRY_IDS,role,team)
		if not bool(approved.get("ok",false)):
			role="soldier";loadout=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,role,team)
			approved=GameLoadouts.validate(loadout,"war",GameWeapons.INFANTRY_IDS,role,team)
		weapon=str(approved.equipped) if bool(approved.get("ok",false)) else str(WarRules.primary_for(role,team)[0])
		var gadget:=WarRules.launcher_for_team(team)
		if role=="antitank" and WarRules.launcher_allowed(team,str(selection.get("gadget",gadget))): gadget=str(selection.get("gadget",gadget))
		var spawn_id:=str(selection.get("spawn",state.get("spawn","base")))
		if bool(state.get("bot",false)) and is_instance_valid(bot_director):
			# Authoritative bot rally selection is recalculated after each death.
			# Humans keep their saved deployment/menu choice unchanged.
			spawn_id=bot_director.preferred_spawn(id)
		if not _valid_deployment_spawn(team,spawn_id): spawn_id="base"
		state.pending={}
		var accepted:=_deploy(id,team,role,weapon,gadget,spawn_id,approved.slots if bool(approved.get("ok",false)) else loadout)
		if not accepted:
			_send_deployment_state(id)
			_notice(id,"Não foi possível reaparecer com a seleção salva.")
		return # Spread simultaneous respawns over frames instead of rebuilding 12 rigs together.

@rpc("any_peer","call_remote","reliable")
func war_recover_life(life: int) -> void:
	if not multiplayer.is_server(): return
	var id:=multiplayer.get_remote_sender_id();var actor:=players.get(id) as WarPlayer
	if not is_instance_valid(actor) or not members.has(id) or life>actor.life_id or not network_guard.allow(id,"life_sync",.5,2): return
	if actor.hp<=0:
		_send_deployment_state(id);return
	# Resend the already-authorized life; this never creates a new spawn,
	# bypasses the delay, or accepts client-supplied health/ammunition.
	rpc_id(id,"remote_player_respawn",id,actor.global_position,actor.life_id)
	rpc_id(id,"war_identity",id,members[id])
	rpc_id(id,"remote_equipped",id,actor.weapon_id)
	sync_inventory(actor)

func _war_snapshot_payload() -> Array:
	return [war_clock,match_left,tickets,objective_states,match_ended,winner,weather_seed,round_restart_left,match_generation]

func _send_war_snapshot() -> void:
	for id in members:
		var actor:=players.get(id) as WarPlayer
		if is_instance_valid(actor): members[id].posture=2 if actor.prone else (1 if actor.crouched else 0)
	_broadcast("war_snapshot",_war_snapshot_payload())

func reset_operation() -> void:
	var selections: Dictionary={}
	for id in members:
		var state: Dictionary=members[id]
		if not bool(state.get("bot",false)) and int(state.get("team",-1)) in [0,1]:
			var pending: Dictionary=state.get("pending",{})
			selections[id]=(pending if not pending.is_empty() else state).duplicate(true)
	match_generation+=1
	match_stats.clear()
	if is_instance_valid(grenades_system): grenades_system.reset_round()
	match_left=WarRules.DURATION;tickets=[WarRules.START_TICKETS,WarRules.START_TICKETS]
	objective_states=WarRules.fresh_objectives();match_ended=false;winner=-1;ticket_clock=0;round_restart_left=WarRules.ROUND_BREAK_SECONDS
	shot_clocks.clear();shot_sequences.clear();melee_attacks.clear()
	for id in members:
		var actor:=players.get(id) as WarPlayer
		if not is_instance_valid(actor): continue
		members[id].deployed=false;members[id].vehicle="";members[id].vehicle_seat=-1;members[id].vehicle_role="";members[id].ready_at=0;members[id].respawn_pending=false;members[id].drone_used=false;members[id].pending={};members[id].utility="";members[id].utility_zoom=0;actor.set_utility("")
		actor.deployed=false;actor.vehicle_id="";actor.hp=0;actor.kills=0;actor.deaths=0;actor.trigger_held=false;actor.cancel_reload();actor.cancel_melee()
		actor._set_hitboxes_enabled(false);actor.body_root.hide();actor.weapon_root.hide()
		actor.body_collision.set_deferred("disabled",true)
		_broadcast("war_identity",[id,members[id]])
	if vehicle_system:
		vehicle_system.reset_occupancy()
		vehicle_system.controls.clear();vehicle_system.sequences.clear();vehicle_system.locks.clear();vehicle_system.healing.clear()
		for vehicle in vehicle_system.vehicles.values(): vehicle_system._respawn_vehicle(vehicle)
		for drone in vehicle_system.drones.values():
			vehicle_system._broadcast("drone_removed",[drone.drone_id]);_retire_avatar(drone)
		vehicle_system.drones.clear()
	if war_fx:
		for shot: Dictionary in war_fx.rounds:
			if not shot.is_empty(): shot.active=false
	if is_instance_valid(bot_director): bot_director.reset()
	for id in selections:
		var selection: Dictionary=selections[id]
		var team:=int(selection.get("team",-1));var role:=str(selection.get("role","soldier"))
		if team in [0,1] and WarRules.CLASSES.has(role):
			var loadout: Dictionary=Dictionary(selection.get("loadout",{})).duplicate(true)
			var approved:=GameLoadouts.validate(loadout,"war",GameWeapons.INFANTRY_IDS,role,team)
			if not approved.ok:
				loadout=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,role,team)
				approved=GameLoadouts.validate(loadout,"war",GameWeapons.INFANTRY_IDS,role,team)
			if approved.ok and _deploy(id,team,role,str(approved.equipped),WarRules.launcher_for_team(team),"base",approved.slots): _register_match_stat(players[id])
			else: _notice(id,"Selecione um ponto de implantação para retornar.")
	_broadcast("war_round_started",[match_generation])
	if offline_operation: war_round_started(match_generation)

func _accept_round_generation(generation: int) -> bool:
	# Reliable round transitions and unreliable periodic state use different
	# channels. An old result snapshot must never reopen the previous round's
	# modal over a new life, vehicle or deployment screen.
	if closing or not is_inside_tree(): return false
	if generation<0: return authority_round_generation<0
	if generation<authority_round_generation: return false
	authority_round_generation=generation
	return true

@rpc("authority","call_remote","reliable")
func war_round_ended(victor: int,remaining: float,generation: int=-1) -> void:
	if not _accept_round_generation(generation): return
	match_ended=true;winner=victor;round_restart_left=clampf(remaining,0.,WarRules.ROUND_BREAK_SECONDS)
	if is_instance_valid(local_player): local_player.trigger_held=false
	if vehicle_system: vehicle_system.clear_trigger()
	if is_instance_valid(war_ui): war_ui.show_round_end()

@rpc("authority","call_remote","reliable")
func war_round_started(generation: int=-1) -> void:
	if generation>=0 and generation==handled_round_start_generation: return
	if not _accept_round_generation(generation): return
	if generation>=0: handled_round_start_generation=generation
	match_ended=false;winner=-1;round_restart_left=WarRules.ROUND_BREAK_SECONDS
	if not multiplayer.is_server(): match_stats.clear()
	if is_instance_valid(grenades_system): grenades_system.reset_round()
	if is_instance_valid(death_view): death_view.stop()
	if is_instance_valid(local_player): local_player.trigger_held=false
	if vehicle_system: vehicle_system.clear_trigger()
	if is_instance_valid(war_fx):
		for shot: Dictionary in war_fx.rounds:
			if not shot.is_empty(): shot.active=false
	for corpse in get_tree().get_nodes_in_group("death_ragdolls"):
		if is_instance_valid(world_root) and is_instance_valid(corpse) and world_root.is_ancestor_of(corpse) and not corpse.is_queued_for_deletion(): corpse.queue_free()
	last_notice="Nova operação."
	if is_instance_valid(war_ui): war_ui.close_round_end()
	if is_instance_valid(local_player) and local_player.deployed and local_player.hp>0:
		ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	else: open_deployment()

@rpc("authority","call_remote","unreliable")
func war_snapshot(time: float,left: float,remaining: Array,objectives_state: Dictionary,ended: bool,victor: int,climate:=0,restart_remaining:=60.,generation: int=-1) -> void:
	# Operation state has its own generation/clock; a bot pose on the same
	# transport must never discard a valid operation update.
	if not is_finite(time) or (generation==received_snapshot_generation and time<=received_snapshot_time):return
	if not _accept_round_generation(generation): return
	received_snapshot_generation=generation;received_snapshot_time=time
	operation_received_at=Time.get_ticks_usec()
	weather_seed=climate;WarWeather.seed=climate
	war_clock = time
	match_left = left
	tickets = remaining
	objective_states = objectives_state
	match_ended = ended
	winner = victor
	round_restart_left=clampf(restart_remaining,0.,WarRules.ROUND_BREAK_SECONDS)
	if ended and is_instance_valid(war_ui) and not war_ui.round_panel.visible: war_ui.show_round_end()

func _update_lobby_text() -> void:
	if is_instance_valid(lobby_panel): lobby_panel.hide()

func update_hud() -> void:
	super.update_hud()
	if is_instance_valid(infantry_hud):
		infantry_hud.shop.text = "IMPLANTAÇÃO · M"
		infantry_hud.match_info.text = "GUERRA · CONQUISTA"
	if is_instance_valid(lobby_panel): lobby_panel.hide()

func gameplay_input_allowed() -> bool:
	return join_ready and not match_ended and is_instance_valid(local_player) and local_player.hp>0 and local_player.deployed and not ui_focus.blocked() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED

func open_deployment() -> void:
	if not is_instance_valid(war_ui): return
	if not war_ui.deployment.visible: war_ui.restore_selection()
	war_ui.refresh_spawns()
	# The periodic HUD refresh can still hold the previous living button state.
	# Apply the current authority gate before showing the panel.
	war_ui.deploy_button.disabled=not deployment_ready()
	ui_focus.open(war_ui.deployment)

func close_deployment() -> void:
	if not is_instance_valid(local_player) or not local_player.deployed or local_player.hp<=0: return
	ui_focus.close_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

@rpc("authority","call_remote","reliable")
func war_notice(message: String) -> void:
	if is_instance_valid(war_ui): war_ui.set_submitting(false)
	last_notice = message
	if message=="Implantação confirmada.": close_deployment()

func _notice(id: int,message: String) -> void:
	if offline_operation and id==1: war_notice(message);return
	if id in multiplayer.get_peers(): rpc_id(id,"war_notice",message)

func deployment_message() -> String:
	if match_ended: return "EMPATE" if winner<0 else "VITÓRIA · "+WarRules.team_name(winner).to_upper()
	var left:=deployment_wait_left()
	if left>0: return "REIMPLANTAÇÃO EM %.1f s"%left
	return last_notice

func deployment_wait_left() -> float:
	if not is_instance_valid(local_player) or local_player.hp>0: return 0.0
	var state: Dictionary=members.get(local_player.peer_id,{})
	return clampf(float(state.get("ready_at",0))-war_clock,0.0,WarRules.PLAYER_RESPAWN_SECONDS)

func deployment_ready() -> bool:
	return join_ready and not match_ended and deployment_wait_left()<=0.0

func context_text() -> String:
	if not _battle_active(): return "Aguardando ao menos um jogador em cada equipe."
	return ("TREINO OFFLINE · %d BOTS    "%bot_director.bots.size() if offline_operation and bot_director else "")+(vehicle_system.context_text() if vehicle_system else "")

func vehicle_hud_text() -> String:
	return vehicle_system.hud_text() if vehicle_system else ""

func request_interact() -> void:
	if vehicle_system: vehicle_system.request_interact()
func vehicle_look(relative: Vector2) -> void:
	if vehicle_system: vehicle_system.look(relative)
func toggle_thermal() -> void:
	if vehicle_system: vehicle_system.toggle_thermal()
func select_gadget(id: String) -> void:
	if vehicle_system: vehicle_system.select_gadget(id)
func request_gadget() -> void:
	if not is_instance_valid(local_player) or not local_player.vehicle_id.is_empty() or water_restricted(local_player): return
	if is_instance_valid(local_player) and local_player.war_class=="soldier": local_player.equip_grenade();return
	if vehicle_system: vehicle_system.request_gadget()

func grenade_allowed(actor: GamePlayer) -> bool:
	if water_restricted(actor): return false
	return is_instance_valid(actor) and actor.get("war_class")=="soldier" and actor.grenades_enabled and _eligible(actor.peer_id) and _battle_active()

@rpc("any_peer","call_remote","reliable")
func server_prime_grenade(life: int,sequence: int) -> void:
	super.server_prime_grenade(life,sequence)
	var id:=multiplayer.get_remote_sender_id()
	if members.has(id) and players.has(id) and not players[id].grenade_held_id.is_empty(): members[id].shield=0.0

@rpc("authority","call_remote","reliable")
func remote_wallet(balance: int,owned_weapons: Array) -> void:
	profile.coins=maxi(0,balance);profile.owned=owned_weapons.duplicate()
	if is_instance_valid(main_accounts) and not main_accounts.profile.is_empty(): main_accounts.profile.coins=profile.coins
	update_hud()

func war_safe_reset(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id): return
	var actor:=players[id] as WarPlayer
	if actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty(): return
	# A legitimate low coastal position is not a redeployment request.
	if actor.global_position.y>=WarTerrain.height_at(actor.global_position.x,actor.global_position.z)-10: return
	actor.global_position=find_spawn(id);actor.velocity=Vector3.ZERO
	if online: _broadcast("war_recovery_pose",[id,actor.global_position,actor.life_id])

@rpc("authority","call_remote","reliable")
func war_recovery_pose(id: int,point: Vector3,life: int) -> void:
	var actor:=players.get(id) as WarPlayer
	if not is_instance_valid(actor) or actor.life_id!=life or actor.hp<=0: return
	actor.global_position=point;actor.network_target=point;actor.velocity=Vector3.ZERO

func show_menu() -> void:
	if closing: return
	closing=true
	if is_instance_valid(voice):voice.shutdown()
	if is_instance_valid(bot_director): bot_director.stop()
	pvp_connection_generation+=1
	match_generation+=1
	match_started=false
	_focus_changed()
	for actor: GamePlayer in players.values():
		actor.trigger_held=false
		actor.pending_shots.clear()
		actor.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(world_root): world_root.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(vehicle_system): vehicle_system.fire_held=false
	_stop_world_audio()
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	online = false
	player_in_vehicle=false
	mode="menu"
	set_physics_process(false)
	set_process(false)
	set_process_unhandled_input(false)
	if is_instance_valid(hud_layer): hud_layer.hide()
	if ui_focus: ui_focus.close_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit.call_deferred()

func _exit_tree() -> void:
	status_writer.close()
	_stop_world_audio()
	if network_api:
		if network_api.multiplayer_peer: network_api.multiplayer_peer.close()
		get_tree().set_multiplayer(null,get_path())

func aim_settings_context() -> String:
	if is_instance_valid(vehicle_system):
		var own: Node3D=vehicle_system.find_target(vehicle_system._own_id())
		if own is WarVehicle: return "war:"+own.kind
		if own is WarDrone: return "war:drone"
	return super.aim_settings_context()

func water_restricted(actor: GamePlayer) -> bool:
	return is_instance_valid(actor) and actor is WarPlayer and actor.in_water()
