extends "res://scripts/main.gd"
class_name BattleRoyaleGame

signal closed
const BR_PROTOCOL:=10
const BR_PORT:=3016
const BR_CAPACITY:=40
const HUMAN_CAPACITY:=12
const ONLINE_BOTS:=28
const QUEUE_SECONDS:=30.
const ROOM_REGISTRY=preload("res://modes/battle_royale/matchmaking/room_registry.gd")
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const ACTOR=preload("res://modes/battle_royale/scripts/player.gd")
const BOT_BRAIN=preload("res://modes/battle_royale/scripts/bot_brain.gd")
const PUNCH_HISTORY=preload("res://modes/battle_royale/state/punch_history.gd")
var accounts_service: NavalAccounts
var offline_operation:=true
var network_api: SceneMultiplayer
var phase:="waiting"
var seed_value:=712907
var br_round_seed:=0
var br_inventory:=BRInventory.new()
var br_round:=BRRound.new()
var br_zone:=BRZone.new()
var motorbikes: BRMotorbikes
var afghan_map: Node3D
var br_hud: Control
var loot_visuals: Node3D
var state_clock:=0.0
var zone_clock:=0.0
var round_start_clock:=-1.0
var restart_at:=-1.0
var snapshot: Dictionary={}
var own_inventory: Dictionary={}
var visible_loot: Array=[]
var zone_parameters: Dictionary={}
var server_time_offset:=0.0
var br_generation:=0
var spawn_positions: Dictionary={}
var distance_positions: Dictionary={}
var closing:=false
var connection_lost:=false
var spectator: Camera3D
var spectator_listener: AudioListener3D
var spectating_id:=-1
var spectator_tpp:=true
var heal_pending: Dictionary={}
var heal_restore: Dictionary={}
var spectator_after:=0.0
var navigation: RefCounted
var bot_brain:=BOT_BRAIN.new()
var punch_history:=PUNCH_HISTORY.new()
var spectator_hidden: Dictionary={}
var spectator_hidden_owner:=-1
var result_started_at:=-1.
var winner_name:=""
var navigation_error:=""
var zone_effect: BRZoneEffect
var assigned_port:=0
var room_id:=""
var room_reservation:=""
var queue_router: Node
var route_attempts:=0
var route_pending:=false
var queue_status:=""
var room_status_clock:=0.
var had_humans:=false
var room_sealed:=false
var corpses: Dictionary={}
var corpse_roots: Dictionary={}
var sync_ready: Dictionary={}
var sync_nonce: Dictionary={}
var sync_timed_out: Dictionary={}
var sync_failures: Array[Dictionary]=[]
var preparing_world:=false
var sync_limit:=-1.

func _ready() -> void:
	name="BattleRoyale"
	set_meta("battle_royale",true)
	set_meta("transport_channels",4)
	dedicated_pvp="--br-room" in OS.get_cmdline_user_args() or bool(get_meta("br_host",false))
	if dedicated_pvp: offline_operation=false
	network_api=SceneMultiplayer.new();network_api.server_relay=false;network_api.allow_object_decoding=false
	get_tree().set_multiplayer(network_api,get_path())
	_setup_input();_load_profile()
	main_accounts=accounts_service
	if main_accounts==null: main_accounts=NavalAccounts.new();add_child(main_accounts)
	_build_audio();_build_ui();_build_modal_ui()
	voice=BRVoiceRelay.new();add_child(voice);voice.configure(self)
	menu_layer.hide();infantry_hud.hide();rank_label.hide();lobby_panel.hide()
	br_hud=load("res://modes/battle_royale/ui/hud.gd").new();br_hud.game=self;hud_layer.add_child(br_hud)
	get_window().focus_exited.connect(_focus_changed)
	if not dedicated_pvp:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		queue_status="Preparando partida" if offline_operation else "Buscando partida"
		_show_queue_status()
	if offline_operation: _begin_local.call_deferred()
	elif dedicated_pvp: host_game.call_deferred("pvp")
	else: join_game.call_deferred("pvp")

func _save_profile() -> void: pass
func _central_pvp() -> bool: return not NavalAccounts.testing() and not get_meta("test_mode",false) and not offline_operation
func _network_capacity() -> int: return BR_CAPACITY
func _network_map_kind(_kind: String) -> String:return "afghan"
func _network_port() -> int:
	if assigned_port>0:return assigned_port
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--br-port="): return int(arg.trim_prefix("--br-port="))
	return BR_PORT
func _health_file() -> String: return "battle-royale-status.json"
func _new_player() -> GamePlayer: return ACTOR.new()
func _build_lighting() -> void:
	if DisplayServer.get_name()=="headless": return
	day_night=BRAfghanAtmosphere.install(world_root)
func _appearance_payload() -> Dictionary:
	var data:=super._appearance_payload();data.br_protocol=BR_PROTOCOL
	data.map_content=load("res://scripts/maps/definition.gd").identity("afghan")
	data.br_room_id=room_id;data.br_reservation=room_reservation
	return data

func join_game(kind: String) -> void:
	if route_pending or online or closing or preparing_world:return
	# Building the local scene must never block ENet keep-alives or consume a
	# reservation's pairing time. Prepare it before opening any connection.
	if not is_instance_valid(afghan_map):
		preparing_world=true;queue_status="Carregando mapa";_show_queue_status()
		await get_tree().process_frame
		mode="pvp";_enter_match_world();preparing_world=false
		if closing:return
		GameDiagnostics.record("br_map_ready",{"milliseconds":Time.get_ticks_msec()})
	# Dedicated QA fixtures can connect directly without a public match router.
	# This switch is unavailable to normal exported clients.
	if (OS.has_feature("editor") or OS.has_feature("qa")) and bool(get_meta("br_direct_connect",false)):
		super.join_game(kind);return
	route_pending=true;route_attempts+=1;queue_status="Buscando partida";_show_queue_status()
	if main_accounts.token.is_empty():main_accounts.load_session()
	var profile_response: Dictionary=await main_accounts.call_api("profile")
	if closing:return
	if not profile_response.get("ok",false):
		route_pending=false;queue_status=str(profile_response.get("error","Entre novamente na sua conta."));_show_queue_status();return
	queue_router=load("res://modes/battle_royale/matchmaking/router.gd").new()
	# SceneTree forbids nested custom MultiplayerAPI branches. Matchmaking
	# must remain a sibling of the game, which already owns its room API.
	get_tree().root.add_child(queue_router)
	var result: Dictionary=await queue_router.request_match(main_accounts,NavalCatalog.SERVER,BR_PROTOCOL,BR_PORT)
	_close_queue_router(false)
	if closing:return
	route_pending=false
	if not result.get("ok",false):queue_status=str(result.get("error","Não foi possível buscar uma partida."));_show_queue_status();return
	assigned_port=int(result.port);room_id=str(result.room_id);room_reservation=str(result.reservation)
	queue_status="Conectando à partida";_show_queue_status()
	super.join_game(kind)

func _show_queue_status() -> void:
	if not is_instance_valid(br_hud):return
	hud_layer.show();br_hud.show()
	br_hud.refresh({"phase":"waiting","total":0,"alive":0,"countdown":0.,"roster":[{"id":0,"name":str(profile.nickname),"bot":false,"local":true,"status":queue_status}],"can_start":false,"queue_status":queue_status,"zone":{}},{},[])
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _close_queue_router(cancel_pending:=true) -> void:
	if not is_instance_valid(queue_router):queue_router=null;return
	var router:=queue_router;queue_router=null
	if cancel_pending:router.cancel()
	router.close();router.queue_free()

@rpc("authority","call_remote","reliable")
func remote_br_queue_closed() -> void:
	if closing:return
	_retry_queue.call_deferred()

func _retry_queue() -> void:
	if closing:return
	if route_attempts>=3:
		queue_status="Não foi possível entrar. Saia e tente novamente.";_show_queue_status();return
	connection_lost=false;sync_ready.clear();sync_nonce.clear();sync_timed_out.clear();sync_failures.clear()
	_clear_br_round()
	if multiplayer.multiplayer_peer:
		var old:=multiplayer.multiplayer_peer;multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();GameNetworkShutdown.retire(self,old)
	online=false;pvp_join_sent=false;pvp_join_nonce="";assigned_port=0
	br_generation=0;snapshot.clear();zone_parameters.clear();own_inventory.clear();visible_loot.clear()
	server_time_offset=0.;room_id="";room_reservation="";room_sealed=false;queue_status="Buscando partida"
	br_inventory.clear();br_round=BRRound.new();br_zone=BRZone.new();spawn_positions.clear();distance_positions.clear();heal_pending.clear();heal_restore.clear()
	pvp_spawn_confirmed=false;spectating_id=-1;round_start_clock=-1.;restart_at=-1.
	for actor: GamePlayer in players.values():actor.queue_free()
	players.clear();local_player=null
	if is_instance_valid(navigation):navigation.close();navigation=null
	if is_instance_valid(world_root):world_root.queue_free();world_root=null
	phase="waiting";join_game.call_deferred("pvp")

func _enter_match_world() -> void:
	map_kind="afghan"
	# The network callback reuses the world prepared before connecting. Restore
	# its identity before the early return, so on-foot recovery and boundaries
	# never fall back to the small Desert map's height field and 149 m limits.
	if is_instance_valid(afghan_map) and afghan_map.built:return
	super._enter_match_world()
	afghan_map=MAP.new();afghan_map.name="Afeganistao";afghan_map.render_visuals=DisplayServer.get_name()!="headless";afghan_map.seed=seed_value
	world_root.add_child(afghan_map);afghan_map.build()
	if DisplayServer.get_name()!="headless" and load("res://scripts/maps/definition.gd").grass_enabled("afghan"):
		var vegetation=load("res://modes/war/scripts/vegetation_visuals.gd").new()
		world_root.add_child(vegetation);vegetation.initialize(afghan_map,"afghan");vegetation.apply_level(2)
	motorbikes=BRMotorbikes.new();motorbikes.game=self;world_root.add_child(motorbikes)
	if multiplayer.is_server() and (offline_operation or dedicated_pvp):
		var navigation_script:=load("res://modes/battle_royale/navigation/navigation.gd")
		if navigation_script:
			navigation=navigation_script.new()
			if not navigation.install(afghan_map):navigation_error="Mapa em preparação"
	loot_visuals=load("res://modes/battle_royale/ui/loot_visuals.gd").new();loot_visuals.game=self;world_root.add_child(loot_visuals)
	loot_visuals.prepare()
	spectator=Camera3D.new();spectator.name="Spectator";world_root.add_child(spectator)
	spectator_listener=AudioListener3D.new();spectator.add_child(spectator_listener)
	zone_effect=BRZoneEffect.new();zone_effect.game=self;world_root.add_child(zone_effect)
	infantry_hud.hide();lobby_panel.hide();rank_label.hide();deployment_panel.hide()
	var shop:=hud_layer.find_child("ShopButton",true,false)
	if shop: shop.hide()
	if is_instance_valid(scoreboard): scoreboard.hide()
	if multiplayer.is_server():_publish_room_status()

func _spawn_player(id: int,local: bool,npc:=false,position:=Vector3.ZERO) -> GamePlayer:
	var actor:=super._spawn_player(id,local,false,position)
	actor.owned=["fists"];actor.loadout=[];actor.weapon_id="fists";actor.ammo.clear();actor.reserves.clear()
	actor.grenades_enabled=true;actor.grenades=0;actor.set_meta("br_generation",br_generation)
	actor.set_meta("weapon_optics",{})
	actor.set_meta("weapon_attachments",{})
	actor._refresh_weapon();actor._update_view()
	actor.remove_meta("br_protection_visual");BRProtectionAppearance.apply(actor,0,0)
	initial_loadout_pending=false
	return actor

func _begin_local() -> void:
	network_api.multiplayer_peer=OfflineMultiplayerPeer.new();online=false;mode="pvp"
	_enter_match_world()
	var actor:=_spawn_player(1,true,false,find_spawn(1));actor.name=str(profile.nickname);_stage_infantry(actor)
	_begin_queue()

func _human_ids() -> Array[int]:
	var result: Array[int]=[]
	for id in players:
		var actor:=players[id] as BRPlayer
		if is_instance_valid(actor) and not actor.br_bot:result.append(int(id))
	return result

func _queue_roster(recipient: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for id in players:
		var actor:=players[id] as BRPlayer
		if is_instance_valid(actor):result.append({"id":int(id),"name":str(actor.name),"bot":actor.br_bot,"local":int(id)==recipient,"status":"Pronto" if actor.br_bot or sync_ready.get(id,false) or offline_operation else "Sincronizando"})
	if not ROOM_REGISTRY.room_id().is_empty():
		var pending:=NavalStorage.read_json(ROOM_REGISTRY.room_folder().path_join("expected.json"))
		var joined: Array=[]
		for peer in _human_ids():joined.append(str(players[peer].get_meta("account_id","")))
		for entry: Dictionary in pending.get("players",[]):
			if str(entry.get("account","")) not in joined and float(entry.get("expires",0))>Time.get_unix_time_from_system():
				result.append({"id":-1-result.size(),"name":str(entry.get("name","Jogador")).left(24),"bot":false,"local":false,"status":"Conectando"})
	result.append_array(sync_failures)
	result.sort_custom(func(a: Dictionary,b: Dictionary):return int(a.bot)<int(b.bot) if a.bot!=b.bot else int(a.id)<int(b.id))
	return result

func _remove_queue_bot(preferred: int=-1) -> void:
	var candidates:=players.keys()
	if preferred in candidates:candidates.erase(preferred);candidates.push_front(preferred)
	for id in candidates:
		var actor:=players[id] as BRPlayer
		if not actor or not actor.br_bot:continue
		players.erase(id);br_inventory.remove_player(int(id));spawn_positions.erase(id)
		if online:_broadcast("remote_player_left",[int(id)])
		_retire_avatar(actor);return

func _fill_queue_bots() -> void:
	if not multiplayer.is_server() or phase!="waiting" or _human_ids().is_empty():return
	var target:=8 if offline_operation else ONLINE_BOTS+_human_ids().size()
	while players.size()>target:_remove_queue_bot()
	var bot_index:=0
	while players.size()<target:
		while players.has(100000+bot_index):bot_index+=1
		var id:=100000+bot_index
		var actor:=_spawn_player(id,false,false,find_spawn(id)) as BRPlayer
		actor.br_bot=true;actor.name="Sobrevivente %d"%(bot_index+1);_stage_infantry(actor)
		br_inventory.add_player(id)
		if online:_broadcast("remote_add_player",[id,str(actor.name),{"deployed":false,"br_bot":true},actor.global_position])
		bot_index+=1

func _begin_queue() -> void:
	if not multiplayer.is_server() or closing:return
	if _human_ids().is_empty():_cancel_empty_room();return
	phase="waiting";had_humans=true;queue_status=""
	_fill_queue_bots()
	# Joining or leaving never extends this room's fixed pairing window.
	if round_start_clock<0.:round_start_clock=_now()+QUEUE_SECONDS;sync_limit=round_start_clock+60.
	if is_instance_valid(ui_focus):ui_focus.close_all()
	if is_instance_valid(local_player):Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_send_br_states();_publish_room_status()

func _publish_room_status() -> void:
	if not multiplayer.is_server() or ROOM_REGISTRY.room_id().is_empty():return
	var accounts: Array=[]
	for id in _human_ids():accounts.append(str(players[id].get_meta("account_id","")))
	var deadline:=Time.get_unix_time_from_system()+round_start_clock-_now() if round_start_clock>0. else 0.
	# A started room remains closed even when its original cohort pairs again.
	var advertised: String="active" if room_sealed and phase=="waiting" else ("preparing" if phase=="waiting" and round_start_clock>0. and _now()>=round_start_clock else phase)
	ROOM_REGISTRY.publish_status(advertised,accounts,deadline,is_instance_valid(navigation) and navigation.ready and phase!="cancelled")

func _cancel_empty_room() -> void:
	if not multiplayer.is_server() or not _human_ids().is_empty():return
	if phase=="cancelled":return
	phase="cancelled";round_start_clock=-1.;restart_at=-1.
	if is_instance_valid(voice):voice.reset()
	for id in players.keys():_remove_queue_bot()
	_publish_room_status()
	if not ROOM_REGISTRY.room_id().is_empty():get_tree().quit.call_deferred()

func _queue_admission_open() -> bool:
	return phase=="waiting" and not room_sealed and _human_ids().size()<HUMAN_CAPACITY and (round_start_clock<0. or _now()<round_start_clock or (not ROOM_REGISTRY.room_id().is_empty() and _now()<sync_limit))

func find_spawn(id: int) -> Vector3:
	if spawn_positions.has(id): return spawn_positions[id]
	var candidates: Array=_navigation_candidates(false)
	if candidates.is_empty():return MAP.point(0.,0.)+Vector3.UP*.12
	var rng:=RandomNumberGenerator.new();rng.seed=(br_round_seed if br_round_seed!=0 else seed_value)+id*7919+br_generation*337
	var best: Vector3=candidates[rng.randi_range(0,candidates.size()-1)]
	var best_distance:=-1.0
	for i in 80:
		var p: Vector3=candidates[rng.randi_range(0,candidates.size()-1)]
		if not MAP.accessible(p): continue
		var separation:=INF
		for other in spawn_positions.values(): separation=minf(separation,p.distance_to(other))
		if separation>best_distance: best=p;best_distance=separation
		if separation>minf(220.,1000./sqrt(maxf(1,players.size()))): break
	spawn_positions[id]=best+Vector3.UP*.12
	return spawn_positions[id]

func _navigation_candidates(zone: bool) -> Array:
	if is_instance_valid(navigation) and navigation.ready:
		return navigation.zone_candidates() if zone else navigation.spawn_candidates()
	return MAP.spawn_candidates()

func start_br_round() -> void:
	if not multiplayer.is_server() or players.size()<2: return
	if phase=="waiting" and round_start_clock>0. and _now()<round_start_clock:return
	if not _cohort_ready():return
	if is_instance_valid(afghan_map) and (not is_instance_valid(navigation) or not navigation.ready):navigation_error="Mapa em preparação";return
	var prepared_spawns: Dictionary={}
	var loot_points: Array=MAP.loot_points()
	var extra_rural_loot: Array[Vector3]=[]
	if is_instance_valid(afghan_map):
		extra_rural_loot=preload("res://modes/battle_royale/map/afghan_density_stage3.gd").loot_points(afghan_map)
		loot_points.append_array(extra_rural_loot)
	# Only authority chooses a new round seed; geometry remains seeded separately.
	var round_seed: int=(seed_value ^ room_id.hash() ^ int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system())) & 0x7fffffff
	if is_instance_valid(navigation) and navigation.ready:
		prepared_spawns=navigation.choose_spawns(players.keys(),round_seed,90.)
		if prepared_spawns.size()!=players.size():navigation_error="Aguardando posições livres";return
		if navigation.zone_candidates().is_empty():navigation_error="Mapa em preparação";return
	_clear_br_round()
	GameDiagnostics.record("br_round_start",{"humans":_human_ids().size(),"participants":players.size(),"spawn_seed":round_seed,"new_rural_loot":extra_rural_loot.size()})
	br_generation+=1;br_round_seed=round_seed;phase="active";br_inventory.clear();spawn_positions.clear();distance_positions.clear();heal_pending.clear();heal_restore.clear()
	room_sealed=true
	br_round.begin(players.keys(),_now());br_zone.configure(seed_value+br_generation,_navigation_candidates(true));br_zone.begin(_now())
	winner_name=""
	for id in br_round.participants:br_round.participants[id].name=str(players[id].name)
	if not prepared_spawns.is_empty():spawn_positions=prepared_spawns
	navigation_error=""
	for actor: GamePlayer in players.values():
		br_inventory.add_player(actor.peer_id)
		actor.owned=["fists"];actor.loadout=[];actor.weapon_id="fists"
		super._reset_server_player(actor)
		actor.ammo.clear();actor.reserves.clear();actor.set_meta("br_generation",br_generation)
		actor.stance.reset(actor);actor.locomotion.reset(actor)
		actor.set_meta("br_protection_visual",Vector3i(-1,-1,-1));BRProtectionAppearance.apply(actor,0,0)
		actor.kills=0;actor.deaths=0;actor._refresh_weapon();actor._update_view();actor.reset_physics_interpolation()
		if not actor.br_bot:GameDiagnostics.record("br_spawn_authority",{"peer":actor.peer_id,"generation":br_generation,"map":map_kind,"position":actor.global_position,"ground_y":MAP.height_at(actor.global_position.x,actor.global_position.z)})
		actor.bot_clock=float(posmod(actor.peer_id,7))*.035;actor.bot_target=actor.global_position
		actor.set_meta("br_combat_target",-1);actor.set_meta("br_burst_remaining",0);actor.set_meta("br_burst_ready",0.);actor.set_meta("br_next_shot",0.)
		distance_positions[actor.peer_id]=actor.global_position
		if online: _broadcast("br_spawn",[actor.peer_id,actor.global_position,actor.life_id,br_generation])
	var contexts: Dictionary={};var buildings: Array=MAP.building_layout()
	for point: Vector3 in loot_points:
		var nearest:=INF;var context:="farm_crate"
		for building: Dictionary in buildings:
			var distance:=Vector2(point.x-building.position.x,point.z-building.position.z).length_squared()
			if distance<nearest and distance<225.:
				nearest=distance;context="storage" if int(building.variant)==2 else ("ruin" if int(building.variant)==4 else "home")
		contexts[point]=context
	for new_anchor: Vector3 in extra_rural_loot: contexts[new_anchor]="storage"
	br_inventory.register_loot((load("res://modes/battle_royale/state/default_loot.tres") as BRLootTable).generate(round_seed+443,loot_points,spawn_positions.values(),contexts))
	for actor: GamePlayer in players.values():_publish_protection(actor);_publish_optics(actor);_push_inventory(actor)
	if is_instance_valid(local_player):
		ui_focus.close_all();spectator.current=false;local_player.camera.current=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	round_start_clock=-1;restart_at=-1;zone_clock=0;result_started_at=-1.
	punch_history.record(players,_now())
	_send_br_states()
	_publish_room_status()

func _clear_br_round() -> void:
	if is_instance_valid(motorbikes):motorbikes.reset_round()
	if is_instance_valid(voice):voice.reset()
	for shot in projectiles:_release_projectile_visual(shot)
	projectiles.clear();melee_attacks.clear();seen_shots.clear();seen_impacts.clear()
	bot_brain.clear();punch_history.clear();_restore_spectator_body()
	corpses.clear();corpse_roots.clear()
	shot_sequences.clear();shot_clocks.clear()
	if is_instance_valid(grenades_system):grenades_system.reset_round()
	if is_instance_valid(loot_visuals):loot_visuals.clear()
	for body in get_tree().get_nodes_in_group("death_ragdolls"):
		if world_root.is_ancestor_of(body):body.queue_free()
	if is_instance_valid(death_view):death_view.stop()
	if is_instance_valid(local_player) and is_instance_valid(local_player.audio_listener):local_player.audio_listener.make_current()

@rpc("authority","call_remote","reliable")
func br_spawn(id: int,pos: Vector3,life: int,generation: int) -> void:
	if generation<br_generation: return
	if generation>br_generation:_clear_br_round()
	br_generation=generation;phase="active"
	if not players.has(id): return
	remote_player_respawn(id,pos,life)
	var actor: GamePlayer=players[id];actor.owned=["fists"];actor.loadout=[];actor.weapon_id="fists";actor.ammo.clear();actor.reserves.clear();actor.respawn_left=0
	actor.set_meta("br_generation",generation);actor.stance.reset(actor);actor.locomotion.reset(actor)
	actor.set_meta("weapon_optics",{})
	actor.set_meta("weapon_attachments",{})
	actor.set_meta("br_vest",0);actor.set_meta("br_helmet",0);actor.set_meta("br_backpack",0)
	actor.set_meta("br_protection_visual",Vector3i(-1,-1,-1));BRProtectionAppearance.apply(actor,0,0)
	actor._refresh_weapon();actor._update_view();actor.reset_physics_interpolation()
	if actor.is_local:
		pvp_spawn_confirmed=true;ui_focus.close_all();spectator.current=false;actor.camera.current=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		GameDiagnostics.record("br_spawn_local",{"peer":id,"generation":generation,"map":map_kind,"position":actor.global_position,"ground_y":MAP.height_at(pos.x,pos.z)})

func _stage_infantry(actor: GamePlayer) -> void:
	actor.hp=0;actor.respawn_left=0;actor.velocity=Vector3.ZERO;actor.trigger_held=false
	actor.cancel_reload();actor.clear_aim();actor.body_root.hide();actor.weapon_root.hide();actor._hide_dead_presentations();actor._set_hitboxes_enabled(false)
	if actor.body_collision: actor.body_collision.set_deferred("disabled",true)

@rpc("authority","call_remote","reliable")
func remote_infantry_staging(id: int,_life: int,_wait: float) -> void:
	if players.has(id): _stage_infantry(players[id])

func _connected_to_server() -> void:
	super._connected_to_server()
	ui_focus.close_all();deployment_panel.hide();infantry_hud.hide();lobby_panel.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _peer_connected(id: int) -> void:
	GameDiagnostics.record("br_peer_connected",{"peer":id,"phase":phase})
	super._peer_connected(id)
	# A client builds the full Afghan map before submitting its challenge.
	# Admission still expires at the room/token cutoff; allow slower machines
	# enough time to prepare their local scene without weakening that cutoff.
	if pvp_challenges.has(id):pvp_challenges[id].expires=Time.get_ticks_msec()+60000

@rpc("any_peer","call_remote","reliable")
func server_join_request(nickname: String,appearance: Dictionary,ticket: Dictionary={},public_pem:="",proof:=PackedByteArray()) -> void:
	if not multiplayer.is_server(): return
	var id:=multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"br_join",.25,2):return
	if not load("res://scripts/maps/definition.gd").compatible("afghan",appearance.get("map_content")):
		GameDiagnostics.record("br_admission_rejected",{"peer":id,"reason":"map_content"})
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id);return
	if int(appearance.get("br_protocol",0))!=BR_PROTOCOL:
		GameDiagnostics.record("br_admission_rejected",{"peer":id,"reason":"protocol"})
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id);return
	if not _queue_admission_open():
		GameDiagnostics.record("br_admission_rejected",{"peer":id,"reason":"room_closed","phase":phase})
		rpc_id(id,"remote_br_queue_closed")
		get_tree().create_timer(.5).timeout.connect(func():
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer and id in multiplayer.get_peers():(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		);return
	if not ROOM_REGISTRY.room_id().is_empty():
		if str(appearance.get("br_room_id",""))!=ROOM_REGISTRY.room_id() or not _claim_room_admission(id,appearance,ticket,public_pem,proof):
			GameDiagnostics.record("br_admission_rejected",{"peer":id,"reason":"reservation_or_proof"})
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id);return
	if players.has(id) and bool(players[id].get("br_bot")):_remove_queue_bot(id)
	elif players.size()>=BR_CAPACITY:_remove_queue_bot()
	super.server_join_request(nickname,appearance,ticket,public_pem,proof)
	if not players.has(id):
		_fill_queue_bots();_send_br_states();return
	br_inventory.add_player(id)
	_begin_queue()
	_send_br_baseline(id)
	_push_inventory(players[id])
	sync_ready[id]=false;sync_nonce[id]=Crypto.new().generate_random_bytes(12).hex_encode()
	rpc_id(id,"br_prepare_ready",str(sync_nonce[id]),br_generation)
	GameDiagnostics.record("br_admitted",{"peer":id,"account":str(players[id].get_meta("account_id","")).sha256_text().left(16),"phase":phase})
	_send_br_states()

func _claim_room_admission(id: int,appearance: Dictionary,ticket: Dictionary,public_pem: String,proof: PackedByteArray) -> bool:
	if var_to_bytes(appearance).size()>4096 or var_to_bytes(ticket).size()>18000 or public_pem.length()>6000 or proof.size()>1024:return false
	var challenge: Dictionary=pvp_challenges.get(id,{})
	if challenge.is_empty() or Time.get_ticks_msec()>int(challenge.expires):return false
	var account:=NavalAccounts.verify_ticket(ticket,public_pem.sha256_text());var key:=CryptoKey.new()
	if account.is_empty() or key.load_from_string(public_pem,true)!=OK:return false
	if not Crypto.new().verify(HashingContext.HASH_SHA256,(str(challenge.nonce)+str(ticket.get("payload",""))).sha256_buffer(),proof,key):return false
	return ROOM_REGISTRY.claim_admission(str(account.id),str(appearance.get("br_reservation","")))

@rpc("authority","call_remote","reliable")
func br_prepare_ready(nonce: String,generation: int) -> void:
	queue_status="Sincronizando";_show_queue_status()
	await get_tree().physics_frame
	if closing or generation!=br_generation or not is_instance_valid(local_player) or not is_instance_valid(afghan_map) or not afghan_map.built:return
	rpc_id(1,"server_br_ready",nonce,generation)
	GameDiagnostics.record("br_ready_sent",{"generation":generation})

@rpc("any_peer","call_remote","reliable")
func server_br_ready(nonce: String,generation: int) -> void:
	if not multiplayer.is_server() or phase!="waiting":return
	var id:=multiplayer.get_remote_sender_id()
	if not players.has(id) or nonce!=str(sync_nonce.get(id,"")) or nonce.is_empty() or generation!=br_generation:return
	sync_ready[id]=true;sync_nonce.erase(id)
	GameDiagnostics.record("br_client_ready",{"peer":id,"generation":generation});_send_br_states()

func _cohort_ready() -> bool:
	if offline_operation or not online:return true
	var ready:=true
	for id in _human_ids():
		if sync_ready.get(id,false):continue
		ready=false
		if sync_limit>0. and _now()>=sync_limit and not sync_timed_out.has(id):
			sync_timed_out[id]=true
			GameDiagnostics.record("br_sync_timeout",{"peer":id})
			rpc_id(id,"br_join_error","A preparação demorou demais. Tente novamente.")
			get_tree().create_timer(.5).timeout.connect(func():
				if id in multiplayer.get_peers():(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
				if players.has(id):_peer_disconnected(id)
			)
	if sync_limit>0. and _now()<sync_limit and not ROOM_REGISTRY.pending_admissions().is_empty():ready=false
	if not ready:queue_status="Aguardando jogadores";return false
	queue_status="";return true

@rpc("authority","call_remote","reliable")
func br_join_error(message: String) -> void:
	queue_status=message.left(160);GameDiagnostics.record("br_join_error",{"message":queue_status});_show_queue_status()

func _server_disconnected() -> void:
	if closing:return
	GameDiagnostics.record("br_server_disconnected",{"phase":phase,"port":assigned_port,"generation":br_generation})
	online=false
	_freeze_disconnected_match()
	if is_instance_valid(voice):voice.reset()
	if queue_status.is_empty() or queue_status in ["Conectando à partida","Sincronizando"]:queue_status="Conexão encerrada. Saia e tente novamente."
	_show_queue_status()

func _connection_failed() -> void:
	GameDiagnostics.record("br_connection_failed",{"port":assigned_port});online=false
	_freeze_disconnected_match()
	queue_status="Não foi possível conectar. Verifique a rede/VPN.";_show_queue_status()

func _freeze_disconnected_match() -> void:
	# Losing ENet must never turn a former client into an offline authority.
	connection_lost=true;phase="waiting";round_start_clock=-1.;sync_limit=-1.
	for actor: GamePlayer in players.values():
		actor.trigger_held=false;actor.cancel_reload();actor.clear_aim();actor.velocity=Vector3.ZERO
		actor.set_physics_process(false)
	if is_instance_valid(motorbikes):motorbikes.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _send_br_baseline(id: int) -> void:
	rpc_id(id,"br_generation_baseline",br_generation,phase)
	for actor: GamePlayer in players.values():
		if br_round.participants.has(actor.peer_id): rpc_id(id,"br_actor_baseline",actor.peer_id,actor.hp,actor.life_id)
		rpc_id(id,"remote_weapon_attachment_state",actor.peer_id,actor.get_meta("weapon_attachments",{}),actor.life_id,br_generation)
		rpc_id(id,"remote_weapon_optics",actor.peer_id,actor.get_meta("weapon_optics",{}),actor.life_id)
		rpc_id(id,"br_protection_state",actor.peer_id,actor.life_id,br_generation,int(actor.get_meta("br_vest",0)),int(actor.get_meta("br_helmet",0)),int(actor.get_meta("br_backpack",0)))
		rpc_id(id,"remote_infantry_posture",actor.peer_id,actor.life_id,int(actor.get_meta("br_generation",br_generation)),2 if actor.prone else (1 if actor.crouched else 0))
	for record: Dictionary in corpses.values():rpc_id(id,"br_corpse_state",_corpse_packet(record))

func _send_player_baseline(recipient: int,actor: GamePlayer) -> void:
	# The ordinary mode broadcasts inventory for its original arsenal. In BR,
	# magazine/reserve and carried weapons belong only to their owner.
	rpc_id(recipient,"remote_player_respawn",actor.peer_id,actor.global_position,actor.life_id)
	rpc_id(recipient,"remote_equipped",actor.peer_id,actor.weapon_id)
	if recipient==actor.peer_id:callv("rpc_id",[recipient,"remote_inventory"]+_inventory_packet(actor))
	if actor.hp<=0:
		rpc_id(recipient,"remote_infantry_staging",actor.peer_id,actor.life_id,0.)

@rpc("authority","call_remote","reliable")
func br_generation_baseline(generation: int,value: String) -> void:
	br_generation=generation;phase=value

@rpc("authority","call_remote","reliable")
func br_actor_baseline(id: int,health: float,life: int) -> void:
	if not players.has(id): return
	var actor: GamePlayer=players[id];actor.life_id=life;actor.hp=health;actor.respawn_left=0
	actor.set_meta("br_generation",br_generation)
	actor.body_root.visible=health>0;actor.weapon_root.visible=health>0;actor._set_hitboxes_enabled(health>0)
	if actor.body_collision: actor.body_collision.set_deferred("disabled",health<=0)

func _peer_disconnected(id: int) -> void:
	if is_instance_valid(voice):voice.forget(id)
	if phase=="active" and br_round.is_alive(id):
		var actor:=players.get(id) as GamePlayer
		if actor: actor.last_impact_weapon="disconnect";actor.hp=0;_on_player_died(actor,0)
	if is_instance_valid(motorbikes):motorbikes.release(id,true)
	if phase=="waiting" and players.has(id):
		sync_failures.append({"id":id,"name":str(players[id].name),"bot":false,"local":false,"status":"Erro" if not sync_ready.get(id,false) else "Saiu"})
		if sync_failures.size()>4:sync_failures.pop_front()
	GameDiagnostics.record("br_peer_disconnected",{"peer":id,"phase":phase,"ready":sync_ready.get(id,false)})
	sync_ready.erase(id);sync_nonce.erase(id);sync_timed_out.erase(id)
	super._peer_disconnected(id)
	br_inventory.remove_player(id);heal_pending.erase(id)
	bot_brain.paths.erase(id);bot_brain.destinations.erase(id);bot_brain.progress.erase(id)
	if _human_ids().is_empty() and had_humans:_cancel_empty_room()
	elif phase=="waiting":_fill_queue_bots();_send_br_states();_publish_room_status()

func _server_accept_shot(id: int,sequence: int,life: int,camera_origin: Vector3,direction: Vector3,weapon: String,aim_level:=-1,zero_range:=0) -> void:
	var actor:=players.get(id) as BRPlayer
	if not is_instance_valid(actor) or not br_round.is_alive(id) or phase!="active":
		if is_instance_valid(actor):_reject_br_shot(actor,sequence,life)
		return
	if actor.prone and direction.is_finite() and direction.length_squared()>.9 and asin(clampf(direction.normalized().y,-1.,1.))<-.41:_reject_br_shot(actor,sequence,life);return
	if heal_pending.has(id):_reject_br_shot(actor,sequence,life);return
	if not actor.vehicle_id.is_empty():return
	if weapon=="fists":
		if CombatRules.limb_disability_enabled(self) and float(actor.limbs.armL)<=0 and float(actor.limbs.armR)<=0:return
		if actor.weapon_id!="fists" or actor.life_id!=life or actor.hp<=0 or not CombatRules.finite_vector(direction) or absf(direction.length()-1.)>.01 or not actor.shot_camera_valid(camera_origin,direction): return
		if direction.dot(actor.global_basis*Basis(Vector3.RIGHT,actor.pitch)*Vector3.FORWARD)<.88: return
		if sequence<=int(shot_sequences.get(id,0)): return
		var scheduled:=float(shot_clocks.get(id,-100))+.48
		if _now()+.02<scheduled: return
		shot_sequences[id]=sequence;shot_clocks[id]=maxf(_now(),scheduled)
		actor.set_meta("br_punch_rewind",minf(BRPunchHistory.MAX_REWIND,_melee_network_delay(id)))
		var packet:={"shot_id":"%d:%d:%d"%[id,life,sequence],"owner":id,"sequence":sequence,"life":life,"weapon":"fists","origin":actor.camera_pivot.global_position,"direction":direction,"blocked":false,"simulation":"melee"}
		_present_shot(packet)
		if online: _broadcast("remote_shot_packet",[packet])
		br_round.record_shot(id,weapon);return
	var before:=int(actor.ammo.get(weapon,0))
	super._server_accept_shot(id,sequence,life,camera_origin,direction,weapon,aim_level,zero_range)
	if int(actor.ammo.get(weapon,0))<before: br_round.record_shot(id,weapon)
	else:_reject_br_shot(actor,sequence,life)

func _reject_br_shot(actor: GamePlayer,sequence: int,life: int) -> void:
	# A predicted client shot must retire even when rejected during a phase
	# transition or an aim check. Keeping it pending would subtract that round
	# from every later inventory acknowledgement and eventually lock firing.
	if life==actor.life_id and sequence>int(shot_sequences.get(actor.peer_id,0)):shot_sequences[actor.peer_id]=sequence
	sync_inventory(actor)

func _confirm_impact(owner_id: int,hit: Dictionary,item: Dictionary,shot_id: String,direction: Vector3) -> void:
	if phase!="active":return
	if not GameWeapons.is_launcher(str(item.get("id",""))):super._confirm_impact(owner_id,hit,item,shot_id,direction);return
	var point: Vector3=hit.position
	remote_br_explosion(shot_id,point)
	if online:_broadcast("remote_br_explosion",[shot_id,point])
	br_round.defer_end=true
	for target: GamePlayer in players.values():
		if not br_round.is_alive(target.peer_id):continue
		var center:=target.global_position+Vector3.UP*.9;var distance:=center.distance_to(point)
		if distance>8.:continue
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3(hit.get("normal",Vector3.UP))*.06,center,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		var region: Area3D=target.hit_regions.get("chest")
		if region:_apply_hit(owner_id,{"collider":region,"position":center},float(item.damage)*(1.-distance/8.),"chest",str(item.id),(center-point).normalized())
	br_round.defer_end=false;br_round.resolve_end(_now())
	if br_round.ended:_finish_br_round()
	_send_br_states()

@rpc("authority","call_remote","reliable")
func remote_br_explosion(id: String,point: Vector3) -> void:
	for shot in projectiles:
		if str(shot.get("shot_id",""))==id:shot.life=0.
	if is_instance_valid(grenades_system):grenades_system.present_explosion(id,point)

func _present_shot(packet: Dictionary) -> bool:
	if str(packet.get("weapon",""))!="fists": return super._present_shot(packet)
	var key:=str(packet.shot_id)
	if seen_shots.has(key): return false
	seen_shots[key]=true
	if seen_shots.size()>512:seen_shots.erase(seen_shots.keys()[0])
	var actor:=players.get(int(packet.owner)) as BRPlayer
	if actor and not (actor.is_local and online and not multiplayer.is_server()): actor.play_fire_animation("fists")
	if actor and not (actor.is_local and online and not multiplayer.is_server()):play_weapon_sound("fists",actor.camera_pivot.global_position,int(packet.owner))
	return true

func resolve_br_punch(actor: BRPlayer) -> void:
	if phase!="active" or not br_round.is_alive(actor.peer_id) or actor.weapon_id!="fists": return
	var hand: Node3D=actor.avatar_parts.arm_l.get_node("HandL") if actor.punch_side==0 else actor.avatar_parts.arm_r.get_node("HandR")
	var origin: Vector3=actor.camera_pivot.global_position+Vector3.DOWN*.20
	var direction:=actor.global_basis*Basis(Vector3.RIGHT,actor.pitch)*Vector3.FORWARD
	var end: Vector3=hand.global_position
	if end.distance_to(origin)>1.45: end=origin+direction*1.45
	var hit:=punch_history.contact(players,actor.peer_id,origin,end,_now(),float(actor.get_meta("br_punch_rewind",0)))
	if hit.is_empty():return
	var wall:=PhysicsRayQueryParameters3D.create(origin,hit.position,1,_collision_excludes(actor.peer_id,false))
	if not get_world_3d().direct_space_state.intersect_ray(wall).is_empty(): return
	_apply_hit(actor.peer_id,hit,14.,"chest","fists",direction)
	if is_instance_valid(combat_feedback): combat_feedback.play("hurt",hit.position)

func _apply_hit(owner_id: int,hit: Dictionary,damage: float,fallback_region:="chest",weapon:="ak",direction:=Vector3.ZERO) -> void:
	if phase!="active": return
	var collider: Node=hit.get("collider")
	if is_instance_valid(collider) and collider.has_meta("br_bike"):
		var bike:=collider as WarVehicle
		if bike and not bike.destroyed:
			bike.hp=maxf(0.,bike.hp-damage)
			if bike.hp<=0.:
				bike.destroyed=true;bike.collision_layer=0
				for occupant: int in bike.occupant_ids(): motorbikes.release(occupant,true)
		return
	var victim:=_impact_character(hit.get("collider"))
	if not victim or not br_round.is_alive(victim.peer_id): return
	var before:=victim.hp
	# Damage is recorded before the death callback finalizes placement.
	var region:=str(hit.collider.get_meta("hit_region",fallback_region))
	var actual:=minf(before,br_inventory.protected_damage(victim.peer_id,damage*float(CombatRules.DAMAGE.get(region,1.)),region,false))
	br_round.record_damage(owner_id,victim.peer_id,actual)
	super._apply_hit(owner_id,hit,damage,fallback_region,weapon,direction)
	if victim.hp>0:_push_inventory(victim);_publish_protection(victim)

func _on_player_died(victim: GamePlayer,killer_id: int) -> void:
	if is_instance_valid(motorbikes):motorbikes.release(victim.peer_id,true)
	if is_instance_valid(voice):voice.silence(victim.peer_id)
	victim.respawn_left=0;victim.trigger_held=false;victim.cancel_reload();victim.clear_aim();heal_pending.erase(victim.peer_id)
	if not multiplayer.is_server(): return
	if not br_round.is_alive(victim.peer_id):return
	_sync_backpack(victim,true)
	var corpse_loot:=br_inventory.drop_all(victim.peer_id,victim.global_position)
	var killer:=players.get(killer_id) as GamePlayer
	var result:=br_round.eliminate(victim.peer_id,killer_id,victim.last_impact_weapon,killer.global_position.distance_to(victim.global_position) if killer else 0.,_now())
	if result.get("ok",false):br_round.participants[victim.peer_id].killer_name=str(killer.name) if killer else ""
	victim.death_sound=randi_range(0,5);spawn_ragdoll(victim.global_position,killer_id,victim)
	_register_corpse(victim,corpse_loot)
	victim.loadout=[];victim.owned=["fists"];victim.ammo.clear();victim.reserves.clear();victim.grenades=0;_push_inventory(victim)
	if result.get("ok",false) and victim.is_local: spectating_id=killer_id;spectator_after=_now()+.85
	if br_round.ended:_finish_br_round()
	_send_br_states()

func _finish_br_round() -> void:
	if phase=="finished":return
	phase="finished";restart_at=_now()+60.;result_started_at=_now()
	winner_name=str(br_round.participants.get(br_round.winner,{}).get("name",""))
	heal_pending.clear();heal_restore.clear()
	for actor: GamePlayer in players.values():
		actor.cancel_reload();actor.trigger_held=false;actor.velocity=Vector3.ZERO;actor.clear_aim();actor.punch_clock=0

func _corpse_key(source: GamePlayer) -> String:
	return "%d:%d:%d"%[br_generation,source.peer_id,source.life_id]

func spawn_ragdoll(pos: Vector3,_killer_id: int,source: GamePlayer=null) -> void:
	if not is_instance_valid(source) or not is_instance_valid(world_root) or source.death_presented==source.life_id:return
	source.death_presented=source.life_id;_play_death_sound(source.death_sound,pos)
	if is_instance_valid(corpse_roots.get(_corpse_key(source))):return
	var torso:=BRCorpseAppearance.create(world_root,source,pos)
	if torso:
		corpse_roots[_corpse_key(source)]=torso.get_parent()
		if source.is_local and is_instance_valid(death_view):death_view.follow(torso,pos,-source.global_basis.z)

func _register_corpse(source: GamePlayer,loot_id: int) -> void:
	var key:=_corpse_key(source);var item: Dictionary=br_inventory.world_loot.get(loot_id,{})
	var gear: Dictionary={};var remaining: Array[int]=[];var levels:={"vest":0,"helmet":0,"pack":0}
	for part: Dictionary in item.get("contents",[]):
		remaining.append(int(part.part_id))
		if str(part.kind) in ["vest","helmet","pack"]:gear[part.kind]=int(part.part_id);levels[part.kind]=int(part.level)
	if not item.is_empty():item.corpse_key=key
	var record:={"key":key,"peer_id":source.peer_id,"life":source.life_id,"generation":br_generation,"position":source.global_position,"gear":gear,"remaining":remaining,"loot_id":loot_id,"revision":1,"settled":false,"transforms":{},"created_at":_now(),"levels":levels}
	corpses[key]=record;_present_corpse(record)
	if online:_broadcast("br_corpse_state",[_corpse_packet(record)])

func _corpse_packet(record: Dictionary) -> Dictionary:
	var packet:=record.duplicate(true);packet.erase("created_at");return packet

func _present_corpse(record: Dictionary) -> void:
	var body:=corpse_roots.get(str(record.key)) as Node3D
	if not is_instance_valid(body):
		# A baseline also survives the former player's disconnection.
		var source:=ACTOR.new();source.game=self;source.peer_id=int(record.peer_id);source.is_local=false
		world_root.add_child(source);source.set_physics_process(false);source.set_process(false);source.global_position=record.position
		var levels: Dictionary=record.get("levels",{});BRProtectionAppearance.apply(source,int(levels.get("vest",0)),int(levels.get("helmet",0)),int(levels.get("pack",0)))
		var torso:=BRCorpseAppearance.create(world_root,source,record.position)
		source.get_parent().remove_child(source);source.queue_free()
		if not torso:return
		body=torso.get_parent();corpse_roots[record.key]=body
	BRCorpseAppearance.bind_loot(body,int(record.loot_id),record.gear)
	BRCorpseAppearance.present(body,record.remaining)
	if bool(record.get("settled",false)):
		body.freeze_corpse()
		for name_text in record.get("transforms",{}):
			var part:=body.get_node_or_null(str(name_text)) as RigidBody3D
			if part:part.global_transform=record.transforms[name_text]

@rpc("authority","call_remote","reliable")
func br_corpse_state(record: Dictionary) -> void:
	if int(record.get("generation",-1))!=br_generation or var_to_bytes(record).size()>18000 or corpses.size()>BR_CAPACITY or not is_instance_valid(world_root):return
	var key:=str(record.get("key",""))
	if key.length()>96 or key.is_empty() or not record.get("position") is Vector3 or not Vector3(record.position).is_finite():return
	if int(corpses.get(key,{}).get("revision",0))>=int(record.get("revision",0)):return
	corpses[key]=record.duplicate(true);_present_corpse(record)

func _sync_corpse_contents(loot_id: int) -> void:
	for record: Dictionary in corpses.values():
		if int(record.loot_id)!=loot_id:continue
		var remaining: Array[int]=[]
		for part: Dictionary in br_inventory.world_loot.get(loot_id,{}).get("contents",[]):remaining.append(int(part.part_id))
		record.remaining=remaining;record.revision=int(record.revision)+1
		_present_corpse(record)
		if online:_broadcast("br_corpse_state",[_corpse_packet(record)])
		return

func _settle_corpses() -> void:
	for record: Dictionary in corpses.values():
		if bool(record.settled) or _now()-float(record.created_at)<6.25:continue
		var body:=corpse_roots.get(str(record.key)) as Node3D
		if not is_instance_valid(body):continue
		body.freeze_corpse();record.settled=true;record.transforms={};record.revision=int(record.revision)+1
		for part in body.get_children():
			if part is RigidBody3D:record.transforms[str(part.name)]=part.global_transform
		var torso:=body.get_node_or_null("Torso") as Node3D
		if torso:record.position=torso.global_position;br_inventory.move_loot(int(record.loot_id),record.position)
		if online:_broadcast("br_corpse_state",[_corpse_packet(record)])

func _server_reload(id: int,weapon: String) -> void:
	if phase!="active" or not br_round.is_alive(id):return
	if heal_pending.has(id):return
	super._server_reload(id,weapon)

func _equip_server(actor: GamePlayer,weapon: String) -> void:
	if phase!="active" or not br_round.is_alive(actor.peer_id):return
	if actor.weapon_id!=weapon:heal_pending.erase(actor.peer_id);actor.punch_clock=0
	super._equip_server(actor,weapon)

@rpc("authority","call_remote","reliable")
func remote_damage(victim_id: int,state: Dictionary) -> void:
	super.remote_damage(victim_id,state)
	if players.has(victim_id):
		players[victim_id].respawn_left=0
		if players[victim_id].is_local and bool(state.dead): spectating_id=int(state.killer);spectator_after=_now()+.85

func _award_kill() -> void: pass
func _pvp_reward(_killer: String,_victim: String,_event: String,_peer: int) -> void: pass
func _record_match_death(_victim: GamePlayer) -> void: pass
func _reset_server_player(_actor: GamePlayer) -> void: pass
func finish_respawn(_actor: GamePlayer) -> void: pass
func defer_respawn_selection(_actor: GamePlayer) -> bool: return true
func _schedule_remote_respawn(_id: int) -> void: pass
@rpc("any_peer","call_remote","reliable")
func server_respawn_request() -> void: pass
func _accept_infantry_deploy(_id: int,_slots: Dictionary,_zone: String,_life: int) -> bool: return false
func open_infantry_deployment() -> void: pass
func _toggle_shop() -> void: pass

func _sync_backpack(actor: GamePlayer,allow_dead:=false) -> void:
	if actor.hp<=0 and not allow_dead:return
	br_inventory.sync_from_actor(actor.peer_id,actor.loadout,actor.ammo,actor.reserves)
	br_inventory.members[actor.peer_id].grenades=maxi(0,actor.grenades)

func _apply_backpack(actor: GamePlayer) -> void:
	var data:=br_inventory.snapshot(actor.peer_id)
	actor.loadout=data.get("weapons",[]).duplicate();actor.owned=["fists"]+actor.loadout+(["binoculars"] if data.get("binoculars",false) else [])
	actor.ammo=data.get("magazines",{}).duplicate();actor.reserves=data.get("reserve_by_weapon",{}).duplicate()
	actor.grenades_enabled=true;actor.grenades=int(data.get("grenades",0))
	if actor.weapon_id not in actor.active_weapons(): _equip_server(actor,"fists")
	_publish_protection(actor)
	_publish_optics(actor)
	sync_inventory(actor)

func _publish_optics(actor: GamePlayer) -> void:
	var data:=br_inventory.snapshot(actor.peer_id)
	var selection: Dictionary=data.get("attachments",{})
	var configuration: Dictionary=data.get("weapon_attachments",{})
	if actor.get_meta("weapon_attachments",{})==configuration and actor.get_meta("weapon_optics",{})==selection:return
	actor.set_meta("weapon_attachments",configuration.duplicate(true));actor.set_meta("weapon_optics",selection.duplicate());actor.refresh_weapon_optics()
	if online:_broadcast("remote_weapon_attachment_state",[actor.peer_id,configuration,actor.life_id,br_generation])

func sync_inventory(actor: GamePlayer) -> void:
	if online and multiplayer.is_server() and _network_peer_ready(actor.peer_id):
		rpc_id(actor.peer_id,"remote_equipment",actor.peer_id,actor.loadout,true,actor.grenades)
		callv("rpc_id",[actor.peer_id,"remote_inventory"]+_inventory_packet(actor))
	if multiplayer.is_server() and br_inventory.members.has(actor.peer_id):_push_inventory(actor)

func _publish_protection(actor: GamePlayer) -> void:
	var gear: Dictionary=br_inventory.snapshot(actor.peer_id).get("protection",{})
	var vest:=int(gear.get("vest",{}).get("level",0));var helmet:=int(gear.get("helmet",{}).get("level",0))
	var backpack:=int(br_inventory.snapshot(actor.peer_id).get("backpack",0))
	BRProtectionAppearance.apply(actor,vest,helmet,backpack)
	var changed: bool=actor.get_meta("br_vest",-1)!=vest or actor.get_meta("br_helmet",-1)!=helmet or actor.get_meta("br_backpack",-1)!=backpack
	actor.set_meta("br_vest",vest);actor.set_meta("br_helmet",helmet);actor.set_meta("br_backpack",backpack)
	if online and changed:_broadcast("br_protection_state",[actor.peer_id,actor.life_id,br_generation,vest,helmet,backpack])

@rpc("authority","call_remote","reliable")
func br_protection_state(id: int,life: int,generation: int,vest: int,helmet: int,backpack: int) -> void:
	var actor:=players.get(id) as GamePlayer
	if not actor or generation!=br_generation or actor.life_id!=life:return
	BRProtectionAppearance.apply(actor,vest,helmet,backpack);actor.set_meta("br_vest",vest);actor.set_meta("br_helmet",helmet);actor.set_meta("br_backpack",backpack)

func _push_inventory(actor: GamePlayer) -> void:
	_sync_backpack(actor)
	var data:=br_inventory.snapshot(actor.peer_id)
	if actor.is_local: own_inventory=data
	elif online and _network_peer_ready(actor.peer_id): rpc_id(actor.peer_id,"br_private_inventory",data,br_generation)

@rpc("authority","call_remote","reliable")
func br_private_inventory(data: Dictionary,generation: int) -> void:
	if generation!=br_generation or not local_player: return
	own_inventory=data;local_player.loadout=data.get("weapons",[]).duplicate();local_player.owned=["fists"]+local_player.loadout+(["binoculars"] if data.get("binoculars",false) else [])
	local_player.grenades_enabled=true;local_player.grenades=int(data.get("grenades",0))
	var selection: Dictionary=data.get("attachments",{})
	var configuration: Dictionary=data.get("weapon_attachments",{})
	if local_player.get_meta("weapon_optics",{})!=selection or local_player.get_meta("weapon_attachments",{})!=configuration:
		local_player.set_meta("weapon_attachments",configuration.duplicate(true));local_player.set_meta("weapon_optics",selection.duplicate());local_player.refresh_weapon_optics()
	var gear: Dictionary=data.get("protection",{})
	BRProtectionAppearance.apply(local_player,int(gear.get("vest",{}).get("level",0)),int(gear.get("helmet",{}).get("level",0)),int(data.get("backpack",0)))
	# Magazines/reload acknowledgements keep using the proven combat RPC.

func br_interact(loot_id: int,part_id:=-1) -> void:
	_request_br("pickup",{"id":loot_id,"part":part_id})
func request_br_drop(weapon: String) -> void: _request_br("drop",{"weapon":weapon})
func request_br_heal() -> void: _request_br("heal",{})
func request_br_drop_ammo(calibre: String,amount: int) -> void:_request_br("drop_ammo",{"calibre":calibre,"amount":amount})
func request_br_drop_protection(kind: String) -> void:_request_br("drop_protection",{"kind":kind})
func request_br_drop_pack() -> void:_request_br("drop_pack",{})
func request_br_drop_heal() -> void:_request_br("drop_heal",{})
func request_br_optic(weapon: String,optic: String) -> void:_request_br("optic",{"weapon":weapon,"optic":optic})
func request_br_drop_optic(optic: String) -> void:_request_br("drop_optic",{"optic":optic})
func request_br_attachment(weapon: String,socket: String,attachment: String,uid: int=-1,position: float=0.) -> void:
	_request_br("attachment",{"weapon":weapon,"socket":socket,"attachment":attachment,"uid":uid,"position":position})
func request_br_drop_attachment(attachment: String,uid: int=-1) -> void:_request_br("drop_attachment",{"attachment":attachment,"uid":uid})
func request_br_use_ammo(calibre: String,weapon: String) -> void:_request_br("use_ammo",{"calibre":calibre,"weapon":weapon})
func request_br_ground_use(loot_id: int,part: int=-1) -> void:_request_br("ground_use",{"id":loot_id,"part":part})
func _infantry_posture_allowed(actor: GamePlayer) -> bool:
	return phase=="active" and is_instance_valid(actor) and br_round.is_alive(actor.peer_id) and super._infantry_posture_allowed(actor)
func request_br_start() -> void:
	if offline_operation and phase=="waiting":_begin_queue()

func request_br_select_slot(index: int) -> void:
	if not is_instance_valid(local_player) or phase!="active" or local_player.hp<=0 or index<0 or index>=local_player.loadout.size():return
	request_equip(local_player,str(local_player.loadout[index]))
func _request_br(action: String,data: Dictionary) -> void:
	if not local_player: return
	if action=="heal":
		local_player.trigger_held=false;local_player.cancel_reload();local_player.clear_aim()
		local_player.set_meta("br_heal_requested_until",Time.get_ticks_msec()+500)
	if online and not multiplayer.is_server(): rpc_id(1,"server_br_action",action,data,local_player.life_id,br_generation)
	else: _br_action(local_player.peer_id,action,data,local_player.life_id,br_generation)

@rpc("any_peer","call_remote","reliable")
func server_br_action(action: String,data: Dictionary,life: int,generation: int) -> void:
	if not multiplayer.is_server(): return
	var id:=multiplayer.get_remote_sender_id()
	if var_to_bytes(data).size()>512 or not network_guard.allow(id,"br_action",8,5): return
	_br_action(id,action,data,life,generation)

func _br_action(id: int,action: String,data: Dictionary,life: int,generation: int) -> bool:
	var actor:=players.get(id) as GamePlayer
	if not actor or phase!="active" or actor.hp<=0 or not br_round.is_alive(id) or life!=actor.life_id or generation!=br_generation: return false
	_sync_backpack(actor)
	var result: Dictionary={}
	if action in ["pickup","ground_use"]:
		var accessory_floor:=br_inventory.next_accessory_uid
		var item: Dictionary=br_inventory.world_loot.get(int(data.get("id",-1)),{})
		if item.is_empty(): return false
		var line:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,item.position+Vector3.UP*.15,1,_collision_excludes(id,false))
		if not get_world_3d().direct_space_state.intersect_ray(line).is_empty(): return false
		var part: Dictionary=item
		if item.kind=="container" and int(data.get("part",-1))>=0:
			part={}
			for entry: Dictionary in item.contents:
				if int(entry.part_id)==int(data.part):part=entry;break
			if part.is_empty():return false
		if action=="ground_use" and part.get("kind","")=="heal" and actor.hp>=100.:return _br_action_failed(actor,"Vida completa")
		if action=="ground_use" and part.get("kind","")=="weapon" and actor.loadout.size()>=2:
			var old_weapon:=actor.weapon_id if actor.weapon_id in actor.loadout else str(actor.loadout[0])
			result=br_inventory.pickup_replace(id,int(data.id),actor.global_position,old_weapon,int(data.get("part",-1)))
			if result.get("ok",false):actor.cancel_reload();actor.trigger_held=false
		else:result=br_inventory.pickup(id,int(data.id),actor.global_position,3.,int(data.get("part",-1)))
		if result.get("ok",false):br_round.record_pickup(id);_sync_corpse_contents(int(data.id))
		if result.get("ok",false) and action=="ground_use":
			_apply_backpack(actor)
			match str(part.get("kind","")):
				"weapon":
					var equipped:=str(result.get("weapon",""))
					if equipped.is_empty():
						for candidate in actor.loadout:
							if GameWeapons.canonical(candidate)==GameWeapons.canonical(str(part.weapon)):equipped=candidate
					_equip_server(actor,equipped)
				"binoculars":_equip_server(actor,"binoculars")
				"heal":_br_action(id,"heal",{},life,generation)
				"ammo":
					for weapon in _inventory_weapon_order(actor):
						if BRInventory.calibre_for(str(weapon))==str(part.calibre):_equip_server(actor,str(weapon));_server_reload(id,str(weapon));break
				"attachment","optic":
					var module:=str(part.get("attachment",part.get("optic","")))
					var acquired_uid:=-1
					for entry: Dictionary in br_inventory.snapshot(id).accessory_items:
						if str(entry.id)==module and int(entry.uid)>=accessory_floor:acquired_uid=int(entry.uid);break
					for weapon in _inventory_weapon_order(actor):
						var config: Dictionary=br_inventory.snapshot(id).weapon_attachments.get(weapon,{})
						var installed:=false
						for socket in GameAttachmentState.sockets(str(weapon),config):
							if GameAttachmentState.can_install(str(weapon),config,str(socket),module).get("ok",false):
								installed=_br_action(id,"attachment",{"weapon":weapon,"socket":socket,"attachment":module,"uid":acquired_uid},life,generation);break
						if installed:break
	elif action=="drop":
		actor.cancel_reload();actor.trigger_held=false
		result=br_inventory.drop_weapon(id,str(data.get("weapon","")),_drop_position(actor))
	elif action=="drop_ammo":
		actor.cancel_reload();actor.trigger_held=false
		result=br_inventory.drop_ammo(id,str(data.get("calibre","")),int(data.get("amount",0)),_drop_position(actor))
	elif action=="drop_protection":result=br_inventory.drop_protection(id,str(data.get("kind","")),_drop_position(actor))
	elif action=="drop_pack":result=br_inventory.drop_pack(id,_drop_position(actor))
	elif action=="drop_binoculars":
		var inv: Dictionary=br_inventory.members[id]
		if not inv.get("binoculars",false):return false
		br_inventory.add_loot({"kind":"binoculars","position":_drop_position(actor)});inv.binoculars=false;result={"ok":true}
	elif action=="drop_heal":heal_pending.erase(id);result=br_inventory.drop_heal(id,1,_drop_position(actor))
	elif action=="optic":
		result=br_inventory.equip_optic(id,str(data.get("weapon","")),str(data.get("optic","")))
		if result.get("ok",false):
			actor.cancel_reload();actor.trigger_held=false;actor.clear_aim();heal_pending.erase(id)
	elif action=="drop_optic":result=br_inventory.drop_optic(id,str(data.get("optic","")),_drop_position(actor))
	elif action=="attachment":
		if actor.reload_left>0. or actor.fire_cooldown>0. or heal_pending.has(id) or actor._grenade_active():return _br_action_failed(actor,"Aguarde a ação atual")
		result=br_inventory.equip_attachment(id,str(data.get("weapon","")),str(data.get("socket","")),str(data.get("attachment","")),int(data.get("uid",-1)),float(data.get("position",0.)))
		if result.get("ok",false):actor.clear_weapon_aim();actor.trigger_held=false
	elif action=="drop_attachment":result=br_inventory.drop_attachment(id,str(data.get("attachment","")),_drop_position(actor),int(data.get("uid",-1)))
	elif action=="use_ammo":
		var weapon:=str(data.get("weapon",""));var calibre:=str(data.get("calibre",""))
		if weapon not in actor.loadout or BRInventory.calibre_for(weapon)!=calibre or actor.reload_left>0. or actor.fire_cooldown>0.:return false
		_equip_server(actor,weapon);_server_reload(id,weapon);return actor.reload_left>0.
	elif action=="heal":
		if actor.hp>=100:return _br_action_failed(actor,"Vida completa")
		if heal_pending.has(id) or heal_restore.has(id):return _br_action_failed(actor,"Curativo em uso")
		if int(br_inventory.snapshot(id).get("medkits",0))<1:return _br_action_failed(actor,"Sem curativo")
		if not actor.vehicle_id.is_empty() or actor._grenade_active():return _br_action_failed(actor,"Ação indisponível")
		actor.cancel_reload();actor.trigger_held=false;actor.clear_aim();sync_inventory(actor)
		heal_pending[id]={"finish":_now()+4.,"life":life,"hp":actor.hp,"position":actor.global_position}
		GameDiagnostics.record("br_heal_started",{"peer":id,"life":life});_send_br_states();return true
	else: return false
	if not result.get("ok",false):return _br_action_failed(actor,str({"capacity":"Sem espaço na mochila","missing":"Item indisponível","compatibility":"Acessório incompatível","socket":"Encaixe incompatível","category":"Encaixe incompatível","occupied":"Encaixe ocupado"}.get(str(result.get("reason","")),"Não foi possível usar o item")))
	var first_pickup: bool=action=="pickup" and actor.loadout.is_empty() and actor.weapon_id=="fists"
	_apply_backpack(actor)
	if first_pickup and not actor.loadout.is_empty():_equip_server(actor,str(actor.loadout[0]))
	_send_br_states();return true

func _inventory_weapon_order(actor: GamePlayer) -> Array:
	var ordered:=actor.loadout.duplicate()
	if actor.weapon_id in ordered:ordered.erase(actor.weapon_id);ordered.push_front(actor.weapon_id)
	return ordered

func _br_action_failed(actor: GamePlayer,message: String) -> bool:
	if actor.is_local:br_item_feedback(message)
	elif online and _network_peer_ready(actor.peer_id):rpc_id(actor.peer_id,"br_item_feedback",message)
	return false

@rpc("authority","call_remote","reliable")
func br_item_feedback(message: String) -> void:
	if is_instance_valid(br_hud):
		br_hud.show_action_notice(message)
		if br_hud.inventory_panel is BRInventoryPanel:br_hud.inventory_panel.show_notice(message.left(96))

func _drop_position(actor: GamePlayer) -> Vector3:
	var start:=actor.global_position+Vector3.UP*.35
	var desired:=start-actor.global_basis.z*.8
	var blocked:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,desired,1,[actor.get_rid()]))
	if not blocked.is_empty():desired=Vector3(blocked.position)+Vector3(blocked.normal)*.12
	var floor_hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(desired+Vector3.UP*.4,desired-Vector3.UP*2.,1,[actor.get_rid()]))
	return Vector3(floor_hit.position)+Vector3.UP*.05 if not floor_hit.is_empty() else actor.global_position+Vector3.UP*.08

func interact_nearest() -> void:
	if not local_player: return
	if is_instance_valid(motorbikes) and motorbikes.interact():return
	var best:=-1;var distance:=3.0
	for item: Dictionary in visible_loot:
		var d:=local_player.global_position.distance_to(item.position)
		if d<distance: best=int(item.id);distance=d
	if best>0:
		var record: Dictionary={}
		for item: Dictionary in visible_loot:
			if int(item.id)==best:record=item;break
		if record.get("kind","")=="container":
			if not br_hud.inventory_panel.is_visible_in_tree():ui_focus.open(br_hud.inventory_panel)
			br_hud._update_nearby()
		else:br_interact(best)

func _now() -> float: return Time.get_ticks_msec()*.001

func _physics_process(delta: float) -> void:
	if closing or connection_lost: return
	super._physics_process(delta)
	if not is_instance_valid(world_root): return
	if multiplayer.is_server():_step_br_authority(delta)
	state_clock+=delta
	if state_clock>=.25:
		state_clock=0
		if multiplayer.is_server(): _send_br_states()
		_refresh_br_ui()
	_update_spectator(delta)

func _step_br_authority(delta: float) -> void:
	if not multiplayer.is_server():return
	_settle_corpses()
	room_status_clock+=delta
	if room_status_clock>=.5:room_status_clock=0.;_publish_room_status()
	if had_humans and _human_ids().is_empty():_cancel_empty_room();return
	if phase=="waiting" and round_start_clock>0 and _now()>=round_start_clock:start_br_round()
	if phase=="finished" and restart_at>0 and _now()>=restart_at:
		restart_at=-1.;round_start_clock=-1.
		_clear_br_round()
		for actor: GamePlayer in players.values():_stage_infantry(actor)
		_begin_queue()
	if phase!="active":return
	punch_history.record(players,_now())
	zone_clock+=delta
	if zone_clock>=1.:
		var step:=minf(zone_clock,1.25);zone_clock=0
		# All survivors see this same environmental tick. Delay the winner
		# decision until every victim is resolved, including a final-circle tie.
		br_round.defer_end=true
		for actor: GamePlayer in players.values():
			if not br_round.is_alive(actor.peer_id):continue
			br_round.record_distance(actor.peer_id,actor.global_position.distance_to(distance_positions.get(actor.peer_id,actor.global_position)));distance_positions[actor.peer_id]=actor.global_position
			if br_zone.outside(actor.global_position,_now()):
				var amount:=br_zone.damage_per_second(_now())*step
				br_round.record_damage(0,actor.peer_id,minf(actor.hp,amount))
				actor.last_impact_weapon="zone";actor.take_damage(amount,"chest",0);_send_zone_damage(actor)
		br_round.defer_end=false;br_round.resolve_end(_now())
		if br_round.ended:_finish_br_round();_send_br_states();return
	for id in heal_pending.keys():
		var actor:=players.get(id) as GamePlayer;var job: Dictionary=heal_pending[id]
		if not actor or actor.hp<=0 or actor.hp<float(job.hp) or actor.life_id!=int(job.life):
			heal_pending.erase(id);GameDiagnostics.record("br_heal_cancelled",{"peer":id,"reason":"damage_or_life_change"})
			if actor and actor.hp>0:_br_action_failed(actor,"Curativo interrompido")
			continue
		if _now()>=float(job.finish):
			var amount:=br_inventory.use_medkit(id,actor.hp)
			if amount>0.:
				GameDiagnostics.record("br_heal_applied",{"peer":id,"life":actor.life_id})
				heal_restore[id]={"remaining":amount,"life":actor.life_id,"hp":actor.hp,"next":_now()}
			_push_inventory(actor)
			heal_pending.erase(id)

	for id in heal_restore.keys():
		var actor:=players.get(id) as GamePlayer;var job: Dictionary=heal_restore[id]
		if not actor or actor.hp<=0 or actor.life_id!=int(job.life) or actor.hp<float(job.hp)-.01:
			heal_restore.erase(id);continue
		if _now()<float(job.next):continue
		var amount:=minf(2.,minf(float(job.remaining),100.-actor.hp))
		actor.hp+=amount;job.remaining-=amount;job.hp=actor.hp;job.next=_now()+.4
		_send_zone_damage(actor)
		if float(job.remaining)<=.001 or actor.hp>=100.:heal_restore.erase(id)

func _send_zone_damage(actor: GamePlayer) -> void:
	if not online: return
	_broadcast("remote_damage",[actor.peer_id,{"hp":actor.hp,"limbs":actor.limbs,"region":"chest","killer":0,"kills":0,"dead":actor.hp<=0,"life":actor.life_id,"direction":Vector3.ZERO,"weapon":actor.last_impact_weapon,"detached":"","death_sound":actor.death_sound}])

func _state_for(id: int) -> Dictionary:
	var win_actor:=players.get(br_round.winner) as GamePlayer
	var result:=br_round.result(id,_now());var killer:=players.get(int(result.get("killer",-1))) as GamePlayer
	var cause:=str(result.get("cause",""));var notice:="ELIMINADO" if not result.is_empty() and not bool(result.get("alive",true)) else ""
	if cause in ["zone","fall","disconnect"]:notice=str({"zone":"FORA DA ZONA","fall":"QUEDA","disconnect":"DESCONECTADO"}[cause])
	elif killer or not str(result.get("killer_name","")).is_empty():notice="%s · %s · %.0f m"%[str(killer.name) if killer else str(result.killer_name),str(GameWeapons.ITEMS.get(cause,{"name":cause}).get("name",cause)),float(result.get("kill_distance",0))]
	return {"phase":phase,"alive":br_round.alive_ids().size(),"total":br_round.participants.size() if phase!="waiting" else players.size(),"capacity":8 if offline_operation else BR_CAPACITY,"roster":_queue_roster(id) if phase=="waiting" else [],"elapsed":maxf(0,_now()-br_round.started_at),"zone":br_zone.snapshot(_now()),"winner_name":str(win_actor.name) if win_actor else winner_name,"local_id":id,"kills":int(result.get("kills",0)),"result":result,"death_notice":notice,"countdown":maxf(0,round_start_clock-_now()) if phase=="waiting" else maxf(0,restart_at-_now()),"generation":br_generation,"can_start":offline_operation and round_start_clock<0.,"queue_status":queue_status,"map_status":navigation_error,"heal_recovering":heal_restore.has(id),"heal_remaining":maxf(0.,float(heal_pending.get(id,{}).get("finish",0))-_now())}

func _send_br_states() -> void:
	for actor: GamePlayer in players.values():
		if actor.br_bot: continue
		var state:=_state_for(actor.peer_id)
		var loot: Array[Dictionary]=[]
		if actor.hp>0:loot=br_inventory.nearby(actor.global_position,80.)
		if actor.is_local: snapshot=state;visible_loot=loot;zone_parameters=state.zone
		elif online and _network_peer_ready(actor.peer_id): rpc_id(actor.peer_id,"br_state",state,loot)

@rpc("authority","call_remote","reliable")
func br_state(data: Dictionary,loot: Array) -> void:
	if int(data.get("generation",-1))<br_generation: return
	br_generation=int(data.generation);phase=str(data.phase);snapshot=data;visible_loot=loot;zone_parameters=data.zone
	if local_player:local_player.set_meta("br_heal_requested_until",0)
	server_time_offset=float(zone_parameters.get("server_time",_now()))-_now()
	if phase=="waiting":
		if is_instance_valid(ui_focus):ui_focus.close_all()
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if phase!="active" and local_player: local_player.trigger_held=false;local_player.clear_aim()

func _refresh_br_ui() -> void:
	if snapshot.is_empty() or not is_instance_valid(br_hud): return
	var data:=snapshot.duplicate(true);data.zone=BRZone.sample_snapshot(zone_parameters,_now()+server_time_offset)
	var target:=players.get(spectating_id) as GamePlayer
	data.spectating_name=str(target.name) if target and target.hp>0 else ""
	data.spectator_tpp=spectator_tpp
	# The spectator marker follows only the actor currently being observed.
	# No additional positions or inventories are exposed in the BR snapshot.
	if is_instance_valid(local_player) and local_player.hp<=0 and target and target.hp>0:
		data.view_position=target.global_position;data.view_yaw=target.yaw
	br_hud.refresh(data,own_inventory,visible_loot)
	if phase=="finished" and is_instance_valid(ui_focus) and br_hud.result_panel not in ui_focus.stack:
		ui_focus.close_all();ui_focus.open(br_hud.result_panel)
	if local_player and local_player.hp>0: loot_visuals.update_visible(visible_loot,local_player.global_position)

func _update_spectator(delta: float) -> void:
	if not is_instance_valid(local_player) or local_player.hp>0 or phase=="waiting":_restore_spectator_body();return
	if _now()<spectator_after:return
	var target:=players.get(spectating_id) as GamePlayer
	if not target or target.hp<=0:
		for other: GamePlayer in players.values():
			if other.hp>0: target=other;spectating_id=other.peer_id;break
	if not target or target.hp<=0:_restore_spectator_body();return
	if spectator_tpp:_restore_spectator_body()
	elif spectator_hidden_owner!=target.peer_id:
		_restore_spectator_body();spectator_hidden_owner=target.peer_id
		for visual: GeometryInstance3D in target.body_root.find_children("*","GeometryInstance3D",true,false):
			spectator_hidden[visual]=visual.layers;visual.layers=1<<19
		spectator.cull_mask&=~(1<<19)
	spectator.current=true
	var pivot:=target.camera_pivot.global_position
	var basis:=target.global_basis*Basis(Vector3.RIGHT,target.pitch)
	var desired:=pivot+basis*Vector3(.65,.35,3.2) if spectator_tpp else pivot
	var safe:=CameraObstruction.resolve(get_world_3d(),pivot,desired,[target.get_rid()],.12)
	spectator.global_position=safe.position;spectator.global_basis=basis
	if is_instance_valid(spectator_listener):spectator_listener.global_transform=Transform3D(basis,pivot);spectator_listener.make_current()
	spectator.fov=76.

func _restore_spectator_body() -> void:
	for visual in spectator_hidden:
		if is_instance_valid(visual):visual.layers=int(spectator_hidden[visual])
	spectator_hidden.clear();spectator_hidden_owner=-1

func spectate_next(step:=1) -> void:
	if not local_player or local_player.hp>0:return
	var living: Array[int]=[]
	for actor: GamePlayer in players.values():
		if actor.hp>0:living.append(actor.peer_id)
	living.sort()
	if living.is_empty():return
	var index:=living.find(spectating_id)
	spectating_id=living[posmod(index+step,living.size())]

func step_br_bot(actor: BRPlayer,delta: float) -> void:
	bot_brain.step(self,actor,delta)

@rpc("any_peer","call_remote","unreliable")
func server_player_state(pos: Vector3,new_yaw: float,new_pitch: float,_weapon: String,is_crouched: bool,aim_level:=0,state_life:=1,state_sequence:=0,state_lean:=0.0) -> void:
	if not multiplayer.is_server(): return
	var id:=multiplayer.get_remote_sender_id();var actor:=players.get(id) as GamePlayer
	if phase!="active" or not actor or not br_round.is_alive(id) or state_life!=actor.life_id or not network_guard.allow(id,"motion",40,8): return
	if not CombatRules.finite_vector(pos) or not is_finite(new_yaw) or not is_finite(new_pitch) or not is_finite(state_lean): return
	if absf(pos.x)>995 or absf(pos.z)>995 or pos.y<MAP.height_at(pos.x,pos.z)-.5 or pos.y>MAP.height_at(pos.x,pos.z)+15: return
	if not actor.vehicle_id.is_empty():
		actor.yaw=new_yaw;actor.pitch=actor.clamp_aim_pitch(new_pitch);return
	if heal_pending.has(id):pos=actor.global_position
	var bounded:=network_guard.movement(id,state_life,state_sequence,actor.global_position,pos,8.)
	if not bounded.accepted: return
	pos=bounded.position
	var wall:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.9,pos+Vector3.UP*.9,1,[actor.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(wall).is_empty(): rpc_id(id,"remote_position_correction",actor.global_position);return
	actor.receive_network_state(pos,wrapf(new_yaw,-PI,PI),actor.clamp_aim_pitch(new_pitch));actor.network_lean=clampf(state_lean,-1,1)
	actor.aiming=aim_level>0;actor.iron_sights=aim_level==2
	if actor.crouched!=is_crouched: actor._set_crouched(is_crouched)
	network_diagnostics.observe_input(id,state_life,state_sequence)

func gameplay_input_allowed() -> bool:
	return phase=="active" and super.gameplay_input_allowed()
func _update_lobby_text() -> void:
	if is_instance_valid(lobby_panel): lobby_panel.hide()
func update_hud() -> void:
	if is_instance_valid(infantry_hud): infantry_hud.hide()
func scoreboard_context() -> Dictionary:
	return {"mode":"BATTLE ROYALE","map":"DESERTO AFEGÃO","seconds":float(snapshot.get("elapsed",0)),"time_label":"DECORRIDO","network":online,"teams":false,"objectives":""}
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V and local_player and local_player.hp<=0:
		spectator_tpp=not spectator_tpp;get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_LEFT,KEY_RIGHT] and local_player and local_player.hp<=0:
		spectate_next(-1 if event.keycode==KEY_LEFT else 1);get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
func show_menu() -> void:
	leave_match()
func leave_match() -> void:
	if closing: return
	closing=true;_close_queue_router()
	if is_instance_valid(voice):voice.shutdown()
	_stop_world_audio()
	if is_instance_valid(music_player):music_player.stop()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_restore_spectator_body()
	if is_instance_valid(navigation):navigation.close()
	if multiplayer.multiplayer_peer:
		var old:=multiplayer.multiplayer_peer;multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();GameNetworkShutdown.retire(self,old)
	closed.emit()

func _exit_tree() -> void:
	_close_queue_router()
	if is_instance_valid(voice):voice.shutdown()
	_restore_spectator_body()
	if is_instance_valid(navigation):navigation.close()
	super._exit_tree()
