extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const NetworkCadence = preload("res://scripts/network_cadence.gd")
const WEAPON_ZEROING = preload("res://scripts/weapon_zeroing.gd")
const BASE_PORT := 3010
const MAX_PLAYERS := 6

var mode := "menu"
var dedicated_pvp := false
var main_accounts: NavalAccounts
var boot_login_pending := false
var account_summary: Label
var main_menu: GameMainMenu
var infantry_hud: GameInfantryHUD
var loading_screen: GameLoadingScreen
var launch_layer: CanvasLayer
var launch_curtain: GameLoadingScreen
var launch_epoch := 0
var pvp_connection_generation := 0
var initial_loadout_pending := false
var deployment_panel: GameInfantryDeployment
var deployment_wait_until:=0.0
var offline_frozen:=false
var pvp_spawn_confirmed := false
var pvp_ticket: Dictionary = {}
var pvp_challenges: Dictionary = {}
var pvp_join_nonce := ""
var pvp_join_sent := false
var pvp_account_pending := false
var pvp_match_id := ""
var pvp_health_at := 0.0
var status_writer:=preload("res://scripts/server_status_writer.gd").new()
var submitted_deaths: Dictionary = {}
var map_kind := "office"
var online := false
var naval_mode: NavalMode
var war_mode: Node
var third_person := true
var player_in_vehicle := false
var local_player: GamePlayer
var death_view: GameDeathCamera
var footsteps: WarSoundscape
var retirement_queue: Node
var players: Dictionary = {}
var npcs: Array[GamePlayer] = []
var projectiles: Array[Dictionary] = []
var shot_clocks: Dictionary = {}
var shot_sequences: Dictionary = {}
var seen_shots: Dictionary = {}
var seen_impacts: Dictionary = {}
var state_clocks: Dictionary = {}
var network_guard:=GameNetworkGuard.new()
var network_diagnostics:=preload("res://scripts/network_diagnostics.gd").new()
var movement_sequence:=0
var purchase_results: Dictionary = {}
var purchase_pending := ""
var operation_sequence := 0
var match_generation := 0
var ui_focus: GameUIFocus
var pause_panel: PanelContainer
var aim_settings_panel: GameAimSettingsPanel
var settings_panel: PanelContainer
var purchase_panel: PanelContainer
var purchase_label: Label
var purchase_target := ""
var scope_overlay: Control
var reload_clocks: Dictionary = {}
var effects: Array[Node3D] = []
var weapon_audio: GameWeaponAudio
var sound_pools: Dictionary = {}
var sound_streams: Dictionary = {}
var damage_numbers: GameDamageNumbers
var grenades_system: GameGrenades
var domination: DesertDomination
var match_stats:=GameMatchStats.new()
var score_clock:=0.0
var score_sent_revision:=-1
var scoreboard: GameScoreboard
var grenade_timers: GameGrenadeTimers
var grenade_snapshot_clock:=0.0
var combat_visuals: GameCombatVisuals
var day_night: GameDayNight
var environment_seconds:=0.0
var environment_sync_clock:=0.0
var environment_received:=false
var combat_feedback: GameCombatFeedback
var feedback_hp := 100.0
var character_save_serial := 0
var character_save_busy := false
var character_dirty := false
var sound_voice_count := 0
var metal_sparks: GameMetalSparks
var multi_kill_events: Dictionary={}
var world_root: Node3D
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var status_label: Label
var ammo_label: Label
var hp_label: Label
var health_bar: ProgressBar
var rank_label: Label
var message_label: Label
var damage_overlay: ColorRect
var aim_dot: ColorRect
var lobby_panel: PanelContainer
var shop_panel: PanelContainer
var appearance_panel: PanelContainer
var address_input: LineEdit
var nickname_input: LineEdit
var team_choice := 0
var match_started := false
var npc_spawn_clock := 0.0
var offline_elapsed := 0.0
var offline_director: OfflineDirector
var melee_attacks: Dictionary = {}
var last_net_state := 0.0
var last_server_broadcast := 0.0
var ship_root: Node3D
var ship_type := "heavy"
var ship_select: OptionButton
var naval_remote_ships: Dictionary = {}
var naval_hp: Dictionary = {}
var naval_shot_clocks: Dictionary = {}
var ship_yaw := 0.0
var ship_speed := 0.0
var ship_hp := 240.0
var ship_weapon := "lightMG"
var ship_ammo := {"lightMG":600,"heavyMG":240,"missile":6,"torpedo":8}
var ship_reload := 0.0
var ship_reload_weapon := ""
var ship_fire_wait := 0.0
var ship_camera: Camera3D
var ship_aim_yaw := 0.0
var ship_aim_pitch := 0.08
var naval_zoom := false
var naval_trigger_held := false
var ship_guides: Array[MeshInstance3D] = []
var music_player: AudioStreamPlayer
var menu_music_db := -21.0
var sound_player: AudioStreamPlayer3D
var save_data := ConfigFile.new()
var voice: BRVoiceRelay

func _setup_voice() -> void:
	set_meta("transport_channels",4)
	if is_instance_valid(voice):voice.shutdown();voice.queue_free()
	voice=BRVoiceRelay.new();add_child(voice);voice.configure(self)

var profile := {"nickname":"Jogador", "coins":0, "team":0, "skin":"#3477bd", "kills":0, "deaths":0, "proportions":{"head":1.0,"torso":1.0,"arms":1.0,"legs":1.0},"colors":GameCharacterColors.DEFAULTS.duplicate()}

func _ready() -> void:
	if "--br-server" in OS.get_cmdline_user_args():
		mode="br_matchmaking";set_physics_process(false)
		var broker: Node=load("res://modes/battle_royale/matchmaking/broker.gd").new()
		add_child(broker)
		var error: Error=broker.start_listening()
		if error!=OK:push_error("BR matchmaking: "+error_string(error));get_tree().quit(1)
		return
	if "--br-room" in OS.get_cmdline_user_args() or "--br-offline" in OS.get_cmdline_user_args():
		mode="br_service"
		set_physics_process(false)
		war_mode=load("res://modes/battle_royale/scripts/game.gd").new()
		war_mode.offline_operation="--br-offline" in OS.get_cmdline_user_args()
		add_child(war_mode)
		return
	dedicated_pvp = "--pvp-server" in OS.get_cmdline_user_args()
	if "--war-server" in OS.get_cmdline_user_args():
		mode="war_service"
		set_physics_process(false)
		war_mode=load("res://modes/war/scripts/game.gd").new()
		add_child(war_mode)
		return
	# Gameplay RPCs are client-to-server and server-to-client only.
	# Match the dedicated service in locally hosted sessions as well.
	multiplayer.server_relay = false
	if "--naval-server" in OS.get_cmdline_user_args():
		mode = "naval_service"
		set_physics_process(false)
		naval_mode = NavalMode.new()
		naval_mode.dedicated = true
		add_child(naval_mode)
		return
	if GameOptions.startup_renderer_guard():
		get_tree().quit()
		return
	main_accounts = NavalAccounts.new()
	add_child(main_accounts)
	_setup_input()
	_load_profile()
	GameOptions.startup(get_viewport())
	_build_audio()
	_build_ui()
	_build_modal_ui()
	_build_launch_curtain()
	_setup_voice()
	get_window().focus_exited.connect(_focus_changed)
	if dedicated_pvp: host_game("pvp")
	else:
		show_menu()
		if "--war-offline" in OS.get_cmdline_user_args():
			open_war.call_deferred(true)
		elif not get_meta("test_mode",false) and not NavalAccounts.testing():
			menu_layer.hide()
			_boot_login.call_deferred()

func _setup_input() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("crouch", KEY_CTRL)
	_bind_key("lean_left",KEY_Q)
	_bind_key("lean_right",KEY_E)
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.has_action("fire"): InputMap.add_action("fire")
	if not InputMap.action_has_event("fire",fire): InputMap.action_add_event("fire", fire)
	GameOptions.apply_controls()

func _bind_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey and keycode in [binding.keycode,binding.physical_keycode]: return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _load_profile() -> void:
	save_data.load(_profile_path())
	profile["equipped"] = str(save_data.get_value("profile","equipped","ak"))
	profile["loadout"]=save_data.get_value("profile","loadout",["broom","squeegee","axe","glock","ak","fal","sniper"])
	profile["grenades"]=bool(save_data.get_value("profile","grenades",true))
	profile.nickname = str(save_data.get_value("profile", "nickname", "Jogador"))
	profile.coins = int(save_data.get_value("profile", "coins", 0))
	profile.team = int(save_data.get_value("profile", "team", 0))
	profile.skin = str(save_data.get_value("profile", "skin", "#3477bd"))
	profile.kills = int(save_data.get_value("profile", "kills", 0))
	profile.deaths = int(save_data.get_value("profile", "deaths", 0))
	profile["owned"] = save_data.get_value("profile", "owned", ["broom", "squeegee", "axe", "glock", "ak", "fal", "sniper"])
	GameWeapons.migrate_profile(profile,int(save_data.get_value("profile","rifle_revision",0)))
	profile["rifle_revision"]=2
	profile["proportions"] = {"head":1.,"torso":1.,"arms":1.,"legs":1.}
	profile["colors"] = GameCharacterColors.normalize(save_data.get_value("profile","colors",{}))
	profile["appearance_account"]=str(save_data.get_value("profile","appearance_account",""))
	profile["ship"] = str(save_data.get_value("profile", "ship", "heavy"))
	profile["owned_ships"] = save_data.get_value("profile", "owned_ships", ["light", "combat", "heavy", "assault", "submarine"])
	if int(save_data.get_value("profile","rifle_revision",0))<2: _save_profile()

func _save_profile() -> void:
	if get_meta("test_mode",false) or dedicated_pvp: return
	for key in profile:
		save_data.set_value("profile", key, profile[key])
	save_data.save(_profile_path())

func _build_audio() -> void:
	GameAudioSettings.ensure()
	menu_music_db = -10.0 # The shared music bus migrates the previous menu gain.
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -0.7
		limiter.threshold_db = -6.0
		AudioServer.add_bus_effect(0,limiter)
	music_player = AudioStreamPlayer.new() if dedicated_pvp else GameMenuMusic.new()
	music_player.name = "Music"
	music_player.volume_db = -60.0
	add_child(music_player)
	sound_player = AudioStreamPlayer3D.new()
	sound_player.bus = "Efeitos"
	sound_player.add_to_group("spatial_sfx")
	sound_player.name = "WorldSound"
	sound_player.max_distance = 100.0
	sound_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(sound_player)

func _build_ui() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuUI"
	menu_layer.layer = 10
	add_child(menu_layer)
	main_menu = GameMainMenu.new()
	main_menu.game = self
	menu_layer.add_child(main_menu)
	account_summary = main_menu.account
	nickname_input = main_menu.nickname
	address_input = main_menu.address
	status_label = main_menu.status
	appearance_panel = PanelContainer.new()
	appearance_panel.anchor_left = 0.5
	appearance_panel.anchor_right = 0.5
	appearance_panel.anchor_top = 0.5
	appearance_panel.anchor_bottom = 0.5
	appearance_panel.offset_left = -240
	appearance_panel.offset_right = 240
	appearance_panel.offset_top = -190
	appearance_panel.offset_bottom = 190
	menu_layer.add_child(appearance_panel)
	var appearance_content := VBoxContainer.new()
	appearance_content.add_child(_title_label("PERSONAGEM"))
	for part in GameCharacterColors.DEFAULTS:
		var picker:=ColorPickerButton.new();picker.text={"skin":"Pele","shirt":"Camisa","pants":"Calça","boots":"Botas"}[part];picker.edit_alpha=false
		picker.color=Color(GameCharacterColors.normalize(profile.get("colors",{}))[part]);appearance_content.add_child(picker)
		picker.color_changed.connect(func(color: Color):
			profile.colors=GameCharacterColors.normalize(profile.get("colors",{}));profile.colors[part]=color.to_html(false);_save_profile();queue_character_save()
			if is_instance_valid(local_player):local_player.apply_body_colors(profile.colors)
		)
	var appearance_close := Button.new()
	appearance_close.text = "SALVAR E VOLTAR"
	appearance_close.pressed.connect(func(): ui_focus.close_top())
	appearance_content.add_child(appearance_close)
	appearance_panel.add_child(appearance_content)
	appearance_panel.visible = false

	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 1
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
	shop_panel = PanelContainer.new()
	shop_panel.anchor_left = 0.5
	shop_panel.anchor_right = 0.5
	shop_panel.anchor_top = 0.5
	shop_panel.anchor_bottom = 0.5
	shop_panel.offset_left = -260
	shop_panel.offset_right = 260
	shop_panel.offset_top = -270
	shop_panel.offset_bottom = 270
	hud_layer.add_child(shop_panel)
	var shop_content := VBoxContainer.new()
	shop_content.name = "ShopContent"
	shop_panel.add_child(shop_content)
	shop_panel.visible = false
	hud_layer.visible = false

func _toggle_shop() -> void:
	if shop_panel in ui_focus.stack:
		if ui_focus.stack.back() == shop_panel: ui_focus.close_top()
	else:
		_refresh_shop()
		ui_focus.open(shop_panel)

func _refresh_shop() -> void:
	var content: VBoxContainer = shop_panel.find_child("ShopContent",true,false)
	for child in content.get_children(): child.queue_free()
	var title := Label.new()
	title.text = "ARSENAL · %d MOEDAS · NÍVEL %d" % [int(profile.coins), 1 + int(profile.kills) / 5]
	content.add_child(title)
	var costs := {"broom":0,"squeegee":70,"axe":160,"glock":260,"ak":420,"fal":520,"sniper":700}
	var levels := {"broom":0,"squeegee":1,"axe":2,"glock":3,"ak":4,"fal":5,"sniper":6}
	for id in GameWeapons.INFANTRY_IDS:
		var button := Button.new()
		var name: String = GameWeapons.ITEMS[id].name
		if profile.owned.has(id): button.text = name + " · ADQUIRIDA"
		elif 1 + int(profile.kills) / 5 < levels[id]: button.text = name + " · NÍVEL " + str(levels[id])
		else: button.text = "COMPRAR · " + name + " · " + str(costs[id]) + " 🪙"
		button.disabled = profile.owned.has(id) or (1 + int(profile.kills) / 5 < levels[id]) or int(profile.coins) < costs[id]
		button.icon = GameUI.icon(id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",36)
		button.custom_minimum_size.y = 54
		button.pressed.connect(_confirm_purchase.bind(str(id),int(costs[id])))
		content.add_child(button)
	var close := Button.new()
	close.text = "FECHAR · ESC"
	close.pressed.connect(_toggle_shop)
	content.add_child(close)

func _buy_weapon(id: String, _cost: int) -> void:
	if not purchase_pending.is_empty(): return
	var confirm := purchase_panel.find_child("ConfirmPurchase",true,false) as Button
	if confirm:
		confirm.disabled = true
		confirm.text = "PROCESSANDO…"
	operation_sequence += 1
	purchase_pending = "%d:%d:%d" % [multiplayer.get_unique_id(),Time.get_ticks_msec(),operation_sequence]
	if online and not multiplayer.is_server(): rpc_id(1,"server_purchase",purchase_pending,id)
	else: _server_purchase(multiplayer.get_unique_id() if online else 1,purchase_pending,id)

func _add_menu_button(parent: VBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", FieldTheme.ACCENT)
	label.add_theme_font_size_override("font_size", 18)
	return label

func _set_body_proportion(part: String, value: float) -> void:
	profile.proportions = {"head":1.,"torso":1.,"arms":1.,"legs":1.}
	_save_profile()
	queue_character_save()
	if local_player: local_player.apply_body_proportions(profile.proportions)

func queue_character_save() -> void:
	if get_meta("test_mode",false) or dedicated_pvp or not is_instance_valid(main_accounts) or main_accounts.token.is_empty(): return
	character_save_serial+=1
	character_dirty=true
	var serial:=character_save_serial
	await get_tree().create_timer(.65).timeout
	if serial!=character_save_serial or character_save_busy or not is_inside_tree(): return
	character_save_busy=true
	while not main_accounts.token.is_empty():
		serial=character_save_serial
		var account_id: String=str(main_accounts.profile.get("id",""))
		var result: Dictionary=await main_accounts.call_api("appearance",{"appearance":{"skin":Color(str(profile.skin)).to_html(false),"proportions":{"head":1.,"torso":1.,"arms":1.,"legs":1.},"colors":GameCharacterColors.normalize(profile.get("colors",{}))}})
		if str(main_accounts.profile.get("id",""))!=account_id: break
		if serial==character_save_serial:
			if result.get("ok",false): character_dirty=false
			if is_instance_valid(main_menu): main_menu.status.text="PERSONAGEM SALVO NA CONTA" if result.get("ok",false) else "SALVO NESTE PC · NÃO FOI POSSÍVEL SINCRONIZAR A CONTA"
			break
	character_save_busy=false
	if character_dirty and serial!=character_save_serial: queue_character_save()

func _hud_stat(name: String, value: String) -> Label:
	var label := Label.new()
	label.text = name + "\n" + value
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", FieldTheme.INK)
	return label

func _panel_style(_color: Color, _radius: int) -> StyleBoxFlat:
	return FieldTheme.box()

func _build_launch_curtain() -> void:
	if DisplayServer.get_name() == "headless": return
	launch_layer = CanvasLayer.new()
	launch_layer.name = "LaunchCurtain"
	launch_layer.layer = 90
	add_child(launch_layer)
	launch_curtain = GameLoadingScreen.new()
	launch_layer.add_child(launch_curtain)
	launch_curtain.hide()

func _begin_launch(title: String, detail: String) -> int:
	launch_epoch += 1
	if is_instance_valid(launch_curtain):
		launch_curtain.present(title,detail)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return launch_epoch

func _end_launch(ticket: int) -> void:
	if ticket == launch_epoch and is_instance_valid(launch_curtain):
		launch_curtain.fade_away()

func launch_from_menu(selected: String, offline := false) -> void:
	if mode != "menu" or is_instance_valid(war_mode) or is_instance_valid(naval_mode): return
	if is_instance_valid(launch_curtain) and launch_curtain.visible: return
	var title := "PREPARANDO PARTIDA"
	var detail := "Preparando a operação..."
	match selected:
		"office": title = "PREPARANDO TREINO"; detail = "Abrindo o equipamento inicial..."
		"desert": title = "PREPARANDO DESERTO"; detail = "Iniciando treino..." if offline else "Conectando ao PVP..."
		"naval": title = "PREPARANDO FROTA"; detail = "Abrindo as salas navais..."
		"war": title = "PREPARANDO GUERRA"; detail = "Carregando a linha de frente..."
		"war_favela": title = "PREPARANDO FAVELA"; detail = "Carregando becos e lajes..."
		"war_afghan": title = "PREPARANDO AFEGÃO"; detail = "Carregando o vale afegão..."
		"br": title = "PREPARANDO BATTLE ROYALE"; detail = "Carregando mapa e pareamento..."
		_: return
	var ticket := _begin_launch(title,detail)
	# O primeiro frame precisa ser desenhado ANTES de qualquer construção pesada.
	if is_instance_valid(launch_curtain):
		await get_tree().process_frame
		await get_tree().process_frame
	if ticket != launch_epoch or mode != "menu": return
	match selected:
		"office": start_offline("training")
		"desert":
			if offline: start_offline("desert")
			else: join_game("pvp")
		"naval": open_naval()
		"war": open_war(offline,WarOperation.UKRAINE)
		"war_afghan": open_war(offline,WarOperation.AFGHAN)
		"war_favela": open_war(offline,WarOperation.FAVELA)
		"br": open_battle_royale(offline)
	# As telas próprias de espera/matchmaking continuam gerindo a partida.
	# A cortina global desaparece suavemente depois de a UI de destino existir.
	if is_instance_valid(launch_curtain):
		await get_tree().process_frame
		await get_tree().process_frame
	_end_launch(ticket)

func show_menu() -> void:
	var returning_from_game := mode != "menu" and not dedicated_pvp
	if is_instance_valid(voice):voice.reset()
	pvp_connection_generation += 1
	match_generation += 1
	_focus_changed()
	match_started = false
	match_stats.clear();score_clock=0;score_sent_revision=-1
	if is_instance_valid(scoreboard): scoreboard.hide()
	player_in_vehicle = false
	initial_loadout_pending = false
	offline_frozen=false;deployment_wait_until=0.0
	if is_instance_valid(deployment_panel): deployment_panel.pending=false
	pvp_join_sent = false
	pvp_join_nonce = ""
	pvp_ticket.clear()
	last_net_state = 0.0
	last_server_broadcast = 0.0
	shot_sequences.clear()
	shot_clocks.clear()
	reload_clocks.clear()
	state_clocks.clear()
	network_diagnostics.clear()
	seen_shots.clear()
	seen_impacts.clear()
	purchase_results.clear()
	purchase_pending = ""
	sound_pools.clear()
	weapon_audio=null
	sound_voice_count=0
	effects.clear()
	naval_remote_ships.clear()
	naval_hp.clear()
	naval_shot_clocks.clear()
	ship_guides.clear()
	ship_speed = 0.0
	ship_reload = 0.0
	ship_fire_wait = 0.0
	naval_zoom = false
	ship_camera = null
	death_view = null
	combat_feedback = null
	damage_numbers=null
	grenades_system=null
	domination=null
	grenade_snapshot_clock=0
	combat_visuals=null;day_night=null;environment_seconds=0;environment_sync_clock=0;environment_received=false
	feedback_hp = 100.0
	if is_instance_valid(scope_overlay): scope_overlay.hide()
	if is_instance_valid(damage_overlay): damage_overlay.color.a = 0.0
	_stop_world_audio()
	if ui_focus: ui_focus.close_all()
	online = false
	if multiplayer.connected_to_server.is_connected(_connected_to_server): multiplayer.connected_to_server.disconnect(_connected_to_server)
	if multiplayer.multiplayer_peer:
		var old_transport:=multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
		GameNetworkShutdown.retire(self,old_transport)
	mode = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer.visible = true
	if returning_from_game and (not is_instance_valid(launch_curtain) or not launch_curtain.visible):
		GameUI.scene_fade(menu_layer)
	if main_menu: main_menu.refresh()
	hud_layer.visible = false
	if world_root:
		world_root.queue_free()
		world_root = null
	for key in players:
		if is_instance_valid(players[key]): players[key].queue_free()
	players.clear()
	npcs.clear()
	projectiles.clear()
	ship_root = null
	local_player = null
	pvp_spawn_confirmed = false
	offline_director = null
	melee_attacks.clear()

func start_offline(which: String) -> void:
	deployment_panel.present(which)

func _begin_offline(which: String,slots: Dictionary={},spawn_zone:="auto") -> void:
	var ticket := -1
	if mode == "menu" and not get_meta("test_mode",false) and is_instance_valid(launch_curtain):
		ticket = _begin_launch("CARREGANDO TREINO","Preparando cenário e adversários...")
		await get_tree().process_frame
		await get_tree().process_frame
	_read_profile_ui()
	online = false
	if multiplayer.multiplayer_peer:
		var old_transport:=multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
		GameNetworkShutdown.retire(self,old_transport)
	mode = which
	map_kind = "office" if which == "training" else "desert"
	_enter_match_world()
	var actor:=_spawn_player(1,true,false,find_spawn(1))
	var approved:=GameLoadouts.validate(slots if not slots.is_empty() else GameLoadouts.defaults("offline_"+which,profile.owned),"offline_"+which,profile.owned)
	GameLoadouts.apply(actor,approved);actor.set_meta("spawn_zone",spawn_zone);actor.global_position=find_spawn(1);actor._refresh_weapon();actor._update_view()
	actor.infantry_protection.deploy(actor)
	GameOptions.apply(get_viewport(),world_root)
	offline_director = OfflineDirector.new()
	offline_director.setup(self)
	for i in range(8 if which == "training" else 12): _spawn_npc(i)
	if ticket >= 0 and is_instance_valid(launch_curtain):
		await get_tree().process_frame
		_end_launch(ticket)

func start_naval(_is_online: bool) -> void:
	open_naval()

func open_war(offline := false,operation := WarOperation.UKRAINE) -> void:
	if is_instance_valid(war_mode): return
	if not offline and not get_meta("test_mode",false) and main_accounts.token.is_empty():
		status_label.text="Entre na sua conta para jogar Guerra."
		_boot_login()
		return
	_read_profile_ui()
	show_menu()
	mode="war_v1"
	menu_layer.hide()
	hud_layer.hide()
	war_mode=load("res://modes/war/scripts/game.gd").new()
	war_mode.accounts_service=main_accounts
	war_mode.operation_id=WarOperation.normalize(str(operation))
	war_mode.offline_operation=offline
	war_mode.closed.connect(func(): _close_war.call_deferred())
	add_child(war_mode)

func _close_war() -> void:
	if not is_instance_valid(war_mode): return
	var old:=war_mode
	war_mode=null
	remove_child(old)
	old.queue_free()
	_apply_account_profile()
	show_menu()

func open_battle_royale(offline:=true) -> void:
	if is_instance_valid(war_mode): return
	if not offline and main_accounts.token.is_empty() and not NavalAccounts.testing():
		_boot_login();return
	_read_profile_ui();show_menu();mode="battle_royale"
	menu_layer.hide();hud_layer.hide()
	war_mode=load("res://modes/battle_royale/scripts/game.gd").new()
	war_mode.accounts_service=main_accounts;war_mode.offline_operation=offline
	war_mode.closed.connect(func(): _close_war.call_deferred())
	add_child(war_mode)

func open_naval(initial_page: String = "home") -> void:
	if is_instance_valid(naval_mode):
		if initial_page!="home": naval_mode._navigate(initial_page)
		return
	_read_profile_ui()
	show_menu()
	mode = "naval_v2"
	menu_layer.hide()
	hud_layer.hide()
	naval_mode = preload("res://modes/naval/scenes/NavalMode.tscn").instantiate()
	naval_mode.initial_page = initial_page
	naval_mode.accounts_service = main_accounts
	naval_mode.menu_music = music_player
	naval_mode.nickname = str(profile.nickname)
	naval_mode.server_address = address_input.text.strip_edges()
	naval_mode.closed.connect(func():
		var old := naval_mode
		menu_music_db = -10.0 # Music gain belongs to the shared audio preference.
		naval_mode = null
		remove_child(old)
		old.queue_free()
		_apply_account_profile()
		show_menu()
	)
	if boot_login_pending: naval_mode.account_connected.connect(_boot_authenticated,CONNECT_ONE_SHOT)
	add_child(naval_mode)

func _legacy_start_naval(is_online: bool) -> void:
	online = is_online
	mode = "naval"
	map_kind = "naval"
	ship_type = str(profile.get("ship", "heavy"))
	_limit_ship_weapon()
	_enter_match_world()
	_build_naval_world()
	if not is_online:
		_build_naval_camera()
	else:
		_spawn_player(multiplayer.get_unique_id(), true, false, Vector3.ZERO)

func _enter_match_world() -> void:
	_read_profile_ui()
	# Recover references if a menu callback reaches this method after a UI
	# layer was detached or the scene was re-entered by a network callback.
	if not is_instance_valid(menu_layer):
		menu_layer = get_node_or_null("MenuUI") as CanvasLayer
	if not is_instance_valid(hud_layer):
		hud_layer = get_node_or_null("HUD") as CanvasLayer
	if is_instance_valid(menu_layer):
		menu_layer.visible = false
	if is_instance_valid(hud_layer):
		hud_layer.visible = true
	_stop_world_audio()
	if world_root: world_root.queue_free()
	world_root = Node3D.new()
	world_root.name = "MatchWorld"
	world_root.add_to_group("game_world")
	add_child(world_root)
	sound_pools.clear()
	weapon_audio=null
	sound_voice_count=0
	if not get_meta("war_mode",false) and DisplayServer.get_name()!="headless":
		weapon_audio=GameWeaponAudio.new()
		world_root.add_child(weapon_audio)
		sound_pools=weapon_audio.pools
		sound_streams=weapon_audio.streams
	match_generation += 1
	match_stats.clear();score_clock=0;score_sent_revision=-1
	if not is_instance_valid(scoreboard) and is_instance_valid(hud_layer):
		scoreboard=GameScoreboard.new();scoreboard.game=self;hud_layer.add_child(scoreboard)
	shot_sequences.clear()
	shot_clocks.clear()
	seen_shots.clear()
	seen_impacts.clear()
	state_clocks.clear()
	melee_attacks.clear()
	offline_director = null
	offline_elapsed = 0.0
	npc_spawn_clock = 0.0
	local_player = null
	pvp_spawn_confirmed = false
	if ui_focus: ui_focus.close_all()
	get_viewport().gui_release_focus()
	players.clear()
	npcs.clear()
	projectiles.clear()
	match_started = true
	player_in_vehicle = false
	environment_seconds=0;environment_sync_clock=0;environment_received=false
	domination=null
	combat_visuals=GameCombatVisuals.new();world_root.add_child(combat_visuals)
	metal_sparks=GameMetalSparks.new();world_root.add_child(metal_sparks)
	_build_lighting()
	if map_kind == "office": _build_office()
	elif map_kind == "desert": _build_desert()
	death_view = GameDeathCamera.new()
	world_root.add_child(death_view)
	combat_feedback=GameCombatFeedback.new()
	world_root.add_child(combat_feedback)
	if not get_meta("war_mode",false):
		footsteps=WarSoundscape.new();footsteps.game=self;footsteps.footsteps_only=true;world_root.add_child(footsteps)
	feedback_hp=100.0
	damage_numbers=GameDamageNumbers.new();world_root.add_child(damage_numbers)
	grenades_system=GameGrenades.new();grenades_system.game=self;world_root.add_child(grenades_system)
	if not is_instance_valid(grenade_timers):
		grenade_timers=GameGrenadeTimers.new();grenade_timers.game=self;hud_layer.add_child(grenade_timers)
	if map_kind=="desert" and not get_meta("war_mode",false) and world_root.get_meta("layout_version","")=="desert-outpost-3":
		domination=DesertDomination.new();world_root.add_child(domination);domination.build(self)
	GameOptions.apply(get_viewport(),world_root)
	update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _read_profile_ui() -> void:
	if online and _central_pvp() and is_instance_valid(main_accounts) and not main_accounts.profile.is_empty():
		profile.nickname = str(main_accounts.profile.username)
	elif nickname_input and not nickname_input.text.strip_edges().is_empty():
		profile.nickname = nickname_input.text.strip_edges().left(20)
	_save_profile()

func _build_lighting() -> void:
	if DisplayServer.get_name()=="headless": return
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9b6ad")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	world_root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 0.58 if map_kind=="office" else 0.85
	sun.directional_shadow_max_distance = 120.0
	if map_kind=="desert":
		env.ambient_light_color = Color("c8bea5")
		env.ambient_light_energy = 0.32
		env.fog_enabled = true
		env.fog_density = 0.0012
		env.fog_sky_affect = 0.25
		env.tonemap_exposure = 0.88
		env.fog_light_color = Color("c6b698")
		(sky.sky_material as ProceduralSkyMaterial).sky_top_color = Color("668a9b")
		(sky.sky_material as ProceduralSkyMaterial).sky_horizon_color = Color("d3c2a1")
		(sky.sky_material as ProceduralSkyMaterial).ground_horizon_color = Color("d3c2a1")
	sun.shadow_enabled = true
	world_root.add_child(sun)
	day_night=GameDayNight.new();world_root.add_child(day_night);day_night.configure(env,sun,null,null,map_kind=="office")

func _static_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, collision := true) -> MeshInstance3D:
	var body := StaticBody3D.new() if collision else Node3D.new()
	body.name = name
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.84
	mesh.material_override = mat
	body.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	return mesh

func _static_cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, color: Color, collision := true, sides := 12) -> MeshInstance3D:
	var body := StaticBody3D.new() if collision else Node3D.new()
	body.name = name
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 1.06
	cylinder.height = height
	cylinder.radial_segments = sides
	mesh.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mesh.material_override = mat
	body.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius * 1.04
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		body.add_child(shape)
	return mesh

func _static_sphere(parent: Node3D, pos: Vector3, scale: Vector3, color: Color, segments := 10) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = segments
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.position = pos
	mesh.scale = scale
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material_override = mat
	world_root.add_child(mesh)
	return mesh

func _build_office() -> void:
	get_viewport().use_occlusion_culling = true
	OfficeMap.build(world_root,not dedicated_pvp)

func _build_desert() -> void:
	get_viewport().use_occlusion_culling = false
	DesertMap.build(world_root,not dedicated_pvp)

func _spawn_player(id: int, local: bool, npc := false, position := Vector3.ZERO) -> GamePlayer:
	var player: GamePlayer = _new_player()
	player.game = self
	player.peer_id = id
	player.is_local = local
	player.is_npc = npc
	if local and not npc:
		var preferred := str(profile.get("equipped","ak"))
		if preferred in profile.owned and GameWeapons.ITEMS.has(preferred): player.weapon_id = preferred
		player.loadout=profile.get("loadout",profile.owned).duplicate()
		player.grenades_enabled=bool(profile.get("grenades",true))
		player.grenades=2 if player.grenades_enabled else 0
		if player.weapon_id not in player.active_weapons() and not player.active_weapons().is_empty(): player.weapon_id=player.active_weapons()[0]
		initial_loadout_pending = online

	player.name = "Player_%s" % id
	# world_root is the direct parent, so set the local position before adding
	# the CharacterBody3D to the tree; querying global_position here logs errors.
	player.position = position
	player.collision_layer = 4
	player.collision_mask = 5
	var capsule_shape := CollisionShape3D.new()
	capsule_shape.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	capsule_shape.shape = capsule
	capsule_shape.position.y = 0.87
	player.add_child(capsule_shape)
	world_root.add_child(player)
	player.shot_requested.connect(_on_shot_requested)
	player.player_died.connect(_on_player_died)
	players[id] = player
	if not npc and (not online or multiplayer.is_server()): _register_match_stat(player)
	if local:
		local_player = player
	if local:
		if not get_meta("battle_royale",false) and not player.get_meta("default_shared_uniform",false):player.body_root.get_node("Torso").material_override = player._material(Color(str(profile.skin)))
		player.owned = profile.owned.duplicate()
		update_hud()
	return player

func _new_player() -> GamePlayer:
	return PlayerScript.new()

func _infantry_posture_allowed(actor: GamePlayer) -> bool:
	return is_instance_valid(actor) and actor.hp>0 and actor.vehicle_id.is_empty() and not actor.in_water()

func request_infantry_posture(actor: GamePlayer,value: int) -> void:
	if not _infantry_posture_allowed(actor):return
	var generation:=int(actor.get_meta("br_generation",0))
	if online and not multiplayer.is_server():rpc_id(1,"server_infantry_posture",actor.life_id,generation,value)
	elif online:_broadcast("remote_infantry_posture",[actor.peer_id,actor.life_id,generation,value])

@rpc("any_peer","call_remote","reliable")
func server_infantry_posture(life: int,generation: int,value: int) -> void:
	if not multiplayer.is_server():return
	var id:=multiplayer.get_remote_sender_id();var actor:=players.get(id) as GamePlayer
	if value not in [0,1,2] or not network_guard.allow(id,"infantry_posture",10,4) or not _infantry_posture_allowed(actor):return
	if life!=actor.life_id or generation!=int(actor.get_meta("br_generation",0)):return
	actor.set_posture(value)
	_broadcast("remote_infantry_posture",[id,life,generation,2 if actor.prone else (1 if actor.crouched else 0)])

@rpc("authority","call_remote","reliable")
func remote_infantry_posture(id: int,life: int,generation: int,value: int) -> void:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or actor.hp<=0 or actor.life_id!=life or generation!=int(actor.get_meta("br_generation",0)):return
	actor.set_posture(value,false,true)

func _network_capacity() -> int:
	return MAX_PLAYERS if dedicated_pvp else MAX_PLAYERS-1

func _health_file() -> String:
	return "pvp-status.json"

func _health_status() -> Dictionary:
	return {"connections":players.size(),"updated":pvp_health_at}

func _spawn_npc(index: int, armed := false) -> void:
	var npc_position := Vector3(float(index % 3 - 1) * 4.0, 0, -12.0 - float(index / 3) * 7.0)
	if map_kind == "desert":
		npc_position = Vector3(float(index % 3 - 1) * 16.0, 0, -26.0 - float(index / 3) * 12.0)
	if offline_director != null:
		var candidate: Variant = offline_director.spawn_position()
		if candidate == null: return
		npc_position = candidate
	var npc_id := -100
	while players.has(npc_id): npc_id -= 1
	var npc := _spawn_player(npc_id, false, true, npc_position)
	npc.weapon_id = "broom"
	npc._refresh_weapon()
	npc.weapon_root.visible = false
	npc.body_root.get_node("Torso").material_override = npc._material([Color("#d86a55"), Color("#d2b83d"), Color("#3477bd"), Color("#49a878")][index % 4])
	npc.camera.current = false
	npcs.append(npc)

func find_spawn(id: int) -> Vector3:
	# Fixed safe pads avoid office walls, furniture and the desert outpost.
	var pads: Array[Vector3]
	if map_kind == "office":
		pads.assign(OfficeMap.SPAWN_PADS)
	else:
		pads = []
		for index in DesertMap.SPAWN_PADS.size(): pads.append(DesertMap.spawn_pad(index))
	var zone:=str(players[id].get_meta("spawn_zone","auto")) if players.has(id) else "auto"
	if map_kind=="desert" and zone in ["west","east"]:
		var filtered: Array[Vector3]=[]
		for pad in pads:
			if (pad.x<0)==(zone=="west"): filtered.append(pad)
		if not filtered.is_empty(): pads=filtered
	var start := posmod(id, pads.size())
	var best := pads[start]
	var best_score := -INF
	var best_exposure:=2147483647
	for offset in range(pads.size()):
		var candidate := pads[(start + offset) % pads.size()]
		if not _spawn_capsule_clear(candidate): continue
		var nearest := INF
		var exposed:=0
		for value in players.values():
			var other := value as GamePlayer
			if not other or not is_instance_valid(other) or other.peer_id == id or other.hp <= 0.0:
				continue
			nearest = minf(nearest, candidate.distance_squared_to(other.global_position))
			if is_instance_valid(world_root):
				var sight:=world_root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*1.2,other.global_position+Vector3.UP*1.2,1))
				if sight.is_empty():exposed+=1
		if nearest == INF:
			nearest = float(offset)
		var score:=nearest
		if exposed<best_exposure or (exposed==best_exposure and score>best_score):
			best_exposure=exposed
			best_score = score
			best = candidate
	return best

func _spawn_capsule_clear(point: Vector3) -> bool:
	var shape:=CapsuleShape3D.new();shape.radius=.33;shape.height=1.75
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.875)
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func recover_terrain_position(actor: GamePlayer) -> bool:
	if map_kind!="desert" or get_meta("war_mode",false) or actor.hp<=0: return false
	var point:=actor.global_position
	if point.y>=DesertTerrain.height_at(point.x,point.z)-.12: return false
	var destination:=DesertMap.safe_ground_point(point)
	if not _spawn_capsule_clear(destination): destination=find_spawn(actor.peer_id)
	actor.global_position=destination;actor.velocity=Vector3.ZERO
	actor.network_target=destination;actor.previous_position=destination
	return true

func npc_line_clear(from: Vector3, to: Vector3, width := 0.0) -> bool:
	var side := (to-from).cross(Vector3.UP).normalized() * width
	for offset in [Vector3.ZERO,side,-side] if width > 0.0 else [Vector3.ZERO]:
		var query := PhysicsRayQueryParameters3D.create(from+Vector3.UP*0.85+offset,to+Vector3.UP*0.85+offset,1)
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	return true

func npc_separation(actor: GamePlayer) -> Vector3:
	var result := Vector3.ZERO
	for other in npcs:
		if not is_instance_valid(other) or other == actor: continue
		var offset := actor.global_position-other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 1.2 and distance > 0.001: result += offset/distance*(1.2-distance)
	return result.limit_length(1.0)

func finish_respawn(_player: GamePlayer) -> void:
	if is_instance_valid(death_view): death_view.stop()
	update_hud()

@rpc("any_peer","call_remote", "reliable")
func server_respawn_request() -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"respawn",2,2): return
	var player: GamePlayer = players.get(id)
	if not player or player.hp > 0.0: return
	_remote_spawn_ready(player)

func _reset_server_player(player: GamePlayer) -> void:
	network_guard.motion.erase(player.peer_id)
	player.set_meta("awaiting_deployment",false)
	player.life_id += 1
	player.infantry_protection.deploy(player)
	player.stance.reset(player);player.locomotion.reset(player)
	player._set_crouched(false)
	player.aiming = false
	player.iron_sights = false
	player.recoil = 0.0
	player.fire_cooldown=0;player.trigger_held=false;player.reload_sync_wait=0
	player.limbs = CombatRules.fresh_limbs()
	player.detached_region = ""
	player.cancel_melee()
	player.cancel_reload()
	player.grenades=2 if player.grenades_enabled else 0
	player.grenade_throw_left=0;player.grenade_held_id="";player.grenade_selected=false;player.grenade_prime_pending=false;player.grenade_fuse_left=0;player.grenade_aiming=false
	player.ammo = GameWeapons.fresh_ammo()
	player.reserves = CombatRules.fresh_reserves()
	GameLoadouts.trim_inventory(player)
	player.hp = 100.0
	player.velocity = Vector3.ZERO
	player.respawn_left = 0.0
	player.body_root.visible = true
	player._set_hitboxes_enabled(true)
	if player.body_collision: player.body_collision.disabled = false
	player.global_position = find_spawn(player.peer_id)
	player.yaw = 0.0
	player.pitch = 0.0
	player.rotation = Vector3.ZERO
	player.weapon_root.visible = true
	player._update_view() if player.is_local else null
	if player.is_local: damage_feedback(100.0)
	_broadcast("remote_player_respawn",[player.peer_id,player.global_position,player.life_id])
	_protection_changed(player)
	sync_inventory(player)

@rpc("authority","call_remote", "reliable")
func remote_player_respawn(id: int, pos: Vector3, life: int) -> void:
	var player: GamePlayer = players.get(id)
	if not is_instance_valid(player) or life < player.life_id: return
	if life>player.life_id: player.authoritative_reload_revision=-1
	player.set_meta("awaiting_deployment",false)
	player.life_id = life
	player.stance.reset(player);player.locomotion.reset(player)
	player.grenade_held_id="";player.grenade_selected=false;player.grenade_prime_pending=false;player.grenade_fuse_left=0;player.grenade_aiming=false;player.grenade_throw_left=0
	player.cancel_melee()
	player._set_crouched(false)
	player.aiming = false
	player.iron_sights = false
	player.recoil = 0.0
	player.fire_cooldown=0;player.trigger_held=false;player.reload_sync_wait=0
	player.limbs = CombatRules.fresh_limbs()
	player.detached_region = ""
	player.pending_shots.clear()
	player.cancel_reload()
	player.weapon_root.visible = true
	player.hp = 100.0
	player.velocity = Vector3.ZERO
	player.respawn_left = 0.0
	player.body_root.visible = true
	player._set_hitboxes_enabled(true)
	if player.body_collision: player.body_collision.disabled = false
	player.global_position = pos
	player.has_network_state = false
	player.network_target = pos
	player.yaw = 0.0
	player.pitch = 0.0
	player.rotation = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	if player.is_local:
		if is_instance_valid(death_view): death_view.stop()
		# A vehicle camera may have been selected while the death/seat RPCs
		# crossed channels. A new life always starts with its own camera.
		player.camera.make_current()
		damage_feedback(100.0)
	player._update_view()
	update_hud()

func _on_shot_requested(shooter: GamePlayer, _origin: Vector3, direction: Vector3, weapon_id: String, _is_melee: bool) -> void:
	if online and not multiplayer.is_server():
		rpc_id(1,"server_shot_request",shooter.shot_sequence,shooter.life_id,shooter.last_camera_origin,direction,weapon_id,2 if shooter.iron_sights else (1 if shooter.aiming else 0),shooter.zeroing_distance(weapon_id))
	else:
		_server_accept_shot(shooter.peer_id,shooter.shot_sequence,shooter.life_id,shooter.last_camera_origin,direction,weapon_id,2 if shooter.iron_sights else (1 if shooter.aiming else 0),shooter.zeroing_distance(weapon_id))

@rpc("any_peer","call_remote","reliable")
func server_shot_request(sequence: int, life: int, camera_origin: Vector3, direction: Vector3, weapon: String, aim_level := 0,zero_range := 0) -> void:
	if multiplayer.is_server() and network_guard.allow(multiplayer.get_remote_sender_id(),"shot",25,8): _server_accept_shot(multiplayer.get_remote_sender_id(),sequence,life,camera_origin,direction,weapon,aim_level,zero_range)

func _server_accept_shot(id: int, sequence: int, life: int, camera_origin: Vector3, direction: Vector3, weapon: String, aim_level := -1,zero_range := 0) -> void:
	if (dedicated_pvp and players.size()<2) or (is_instance_valid(domination) and domination.blocked()):
		# A rejected predicted shot must still be acknowledged. Otherwise an
		# empty predicted magazine can remain empty after the room resumes.
		if players.has(id):
			if players[id].life_id==life and sequence>int(shot_sequences.get(id,0)): shot_sequences[id]=sequence
			sync_inventory(players[id])
		return
	var shooter: GamePlayer = players.get(id)
	if not is_instance_valid(shooter): return
	if sequence <= int(shot_sequences.get(id,0)):
		sync_inventory(shooter)
		return
	shot_sequences[id] = sequence
	if not GameWeapons.ITEMS.has(weapon) or weapon not in shooter.active_weapons() or shooter.weapon_id != weapon or shooter.hp <= 0.0 or shooter.life_id != life or shooter.reload_left > 0.0 or shooter.grenade_throw_left>0 or not shooter.grenade_held_id.is_empty() or shooter.grenade_selected:
		sync_inventory(shooter)
		return
	if player_in_vehicle and shooter.is_local: return
	if not CombatRules.finite_vector(camera_origin) or not CombatRules.finite_vector(direction) or direction.length() < 0.99 or direction.length() > 1.01: return
	var eye := shooter.camera_pivot.global_position
	if not shooter.shot_camera_valid(camera_origin,direction):
		sync_inventory(shooter)
		return
	var expected := shooter.global_basis * (Basis(Vector3.RIGHT,shooter.pitch) * Vector3.FORWARD)
	if expected.dot(direction) < 0.88:
		sync_inventory(shooter)
		return
	var item := shooter.weapon_spec(weapon)
	var accepted_zero:=WEAPON_ZEROING.sanitize(int(zero_range),item) if aim_level==2 else 0
	if aim_level==2 and WEAPON_ZEROING.supported(item):shooter.zeroing_ranges[weapon]=accepted_zero
	if item.kind == "melee" and CombatRules.limb_disability_enabled(self) and float(shooter.limbs.armL) <= 0.0 and float(shooter.limbs.armR) <= 0.0: return
	var now := Time.get_ticks_msec() * 0.001
	var scheduled:=float(shot_clocks.get(id,-100.0))+float(item.cooldown)
	# Absorb bounded packet jitter, while keeping the long-term cadence.
	# Storing the scheduled time prevents repeated early packets gaining rate.
	if now+minf(.045,float(item.cooldown)*.4)<scheduled:
		sync_inventory(shooter)
		return
	if item.kind == "firearm":
		if int(shooter.ammo.get(weapon,0)) <= 0 or (CombatRules.limb_disability_enabled(self) and (float(shooter.limbs.armR) <= 0.0 or (weapon in ["ak","fal","sniper","g3"] and float(shooter.limbs.armL) <= 0.0))):
			sync_inventory(shooter)
			return
		shooter.ammo[weapon] = maxi(0,int(shooter.ammo[weapon]) - 1)
	shot_clocks[id] = maxf(now,scheduled)
	if aim_level >= 0:
		shooter.aiming = aim_level > 0
		shooter.iron_sights = aim_level == 2
	shooter._update_weapon_pose()
	var origin := shooter.weapon_root.global_position if item.kind == "melee" else shooter.get_muzzle_position()
	var query := PhysicsRayQueryParameters3D.create(camera_origin,camera_origin + direction * float(item.range),CombatRules.SHOT_MASK,_collision_excludes(id,false))
	query.collide_with_areas = true
	var aim_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = aim_hit.position if not aim_hit.is_empty() else camera_origin + direction * float(item.range)
	var shot_direction := (point - origin).normalized()
	if shot_direction.dot(direction) < 0.1: shot_direction = direction
	if accepted_zero>0:shot_direction=WEAPON_ZEROING.compensate(shot_direction,item,accepted_zero)
	# The eye-to-muzzle sweep prevents a protruding barrel from bypassing a wall.
	var block_query := PhysicsRayQueryParameters3D.create(eye,origin,1,_collision_excludes(id,false))
	block_query.hit_from_inside = true
	var obstruction := get_world_3d().direct_space_state.intersect_ray(block_query)
	var shot_id := "%d:%d:%d" % [id,life,sequence]
	var spread := float(item.spread) * (1.0 + Vector2(shooter.velocity.x,shooter.velocity.z).length() * 0.3) * (0.6 if shooter.crouched else 1.0)
	var random := RandomNumberGenerator.new()
	random.seed = hash(shot_id)
	shot_direction = shot_direction.rotated(Vector3.UP,random.randf_range(-spread,spread))
	var side := shot_direction.cross(Vector3.UP).normalized()
	if side.length_squared() > 0.01: shot_direction = shot_direction.rotated(side,random.randf_range(-spread,spread)).normalized()
	var packet := {"shot_id":shot_id,"owner":id,"sequence":sequence,"life":life,"weapon":weapon,"origin":origin,"direction":shot_direction,"blocked":not obstruction.is_empty(),"simulation":item.simulation,"zero_range":accepted_zero}
	if item.kind=="melee": packet["melee_offset"]=_melee_network_delay(id)
	_present_shot(packet)
	if online: _broadcast("remote_shot_packet",[packet])
	if item.simulation == "melee":
		_resolve_melee(id,origin,shot_direction,item,shot_id)
	elif not obstruction.is_empty():
		_confirm_impact(id,obstruction,item,shot_id,shot_direction)
	elif item.simulation == "hitscan":
		_resolve_hitscan(id,origin,shot_direction,item,shot_id)
	else:
		_spawn_projectile(id,origin,shot_direction,weapon,false,true,shot_id)
	sync_inventory(shooter)

@rpc("authority","call_remote","reliable")
func remote_shot_packet(packet: Dictionary) -> void:
	if not _present_shot(packet): return
	if not packet.blocked and packet.simulation == "projectile":
		_spawn_projectile(int(packet.owner),packet.origin,packet.direction,str(packet.weapon),false,false,str(packet.shot_id))

func _present_shot(packet: Dictionary) -> bool:
	var key := str(packet.shot_id)
	if seen_shots.has(key): return false
	seen_shots[key] = true
	if seen_shots.size() > 512: seen_shots.erase(seen_shots.keys()[0])
	var actor: GamePlayer = players.get(int(packet.owner))
	if is_instance_valid(actor):
		if not actor.is_local or not online or multiplayer.is_server(): actor.present_fire()
		if actor.melee_rig and (not actor.is_local or multiplayer.is_server()):
			var offset:=float(packet.get("melee_offset",0))
			if online and not multiplayer.is_server(): offset+=_melee_network_delay(1)
			if offset>0: actor.melee_rig.advance(minf(offset,.18));actor._update_weapon_pose()
		if CombatRules.weapon(str(packet.weapon)).kind == "firearm": _muzzle_flash(packet.origin)
		if not (actor.is_local and online and not multiplayer.is_server() and int(packet.sequence)<=int(actor.get_meta("predicted_audio_sequence",0))):
			play_weapon_sound(str(packet.weapon),packet.origin,int(packet.owner),0.0 if not online or multiplayer.is_server() else _melee_network_delay(1))
	return true

func _protection_changed(actor: GamePlayer,broken: String="") -> void:
	if online and multiplayer.is_server() and actor.infantry_protection.enabled:
		_broadcast("remote_protection_state",[actor.peer_id,actor.life_id,actor.infantry_protection.snapshot(),broken])

@rpc("authority","call_remote","reliable")
func remote_protection_state(id: int,life: int,data: Dictionary,broken: String="") -> void:
	var actor:=players.get(id) as GamePlayer
	if is_instance_valid(actor):actor.infantry_protection.receive(actor,life,data,broken)

func sync_inventory(player: GamePlayer) -> void:
	if online and multiplayer.is_server() and _network_peer_ready(player.peer_id): rpc_id(player.peer_id,"remote_equipment",player.peer_id,player.loadout,player.grenades_enabled,player.grenades)
	if online and multiplayer.is_server():
		_broadcast("remote_inventory",_inventory_packet(player))

func _inventory_packet(player: GamePlayer) -> Array:
	return [player.peer_id,player.ammo,player.reserves,int(shot_sequences.get(player.peer_id,0)),player.reload_weapon,player.reload_left,player.reload_total,player.paused_reloads,player.life_id,player.reload_revision]

@rpc("authority","call_remote","reliable")
func remote_inventory(id: int, magazines: Dictionary, reserve: Dictionary, ack: int, reload_id: String, reload_seconds: float,total_seconds: float=0.0,paused: Dictionary={},inventory_life: int=0,revision: int=-1) -> void:
	var actor: GamePlayer = players.get(id)
	if not is_instance_valid(actor) or (inventory_life>0 and inventory_life!=actor.life_id) or (revision>=0 and revision<actor.authoritative_reload_revision): return
	actor.ammo = magazines.duplicate()
	actor.reserves = reserve.duplicate()
	for seq in actor.pending_shots.keys():
		if int(seq) <= ack: actor.pending_shots.erase(seq)
	for weapon in actor.pending_shots.values():
		actor.ammo[weapon] = maxi(0,int(actor.ammo.get(weapon,0)) - 1)
	actor.apply_reload_state(reload_id,reload_seconds,total_seconds,paused,revision)
	if actor.is_local: update_hud()

func request_equip(player: GamePlayer, weapon: String) -> void:
	if online and not multiplayer.is_server(): rpc_id(1,"server_equip",weapon)
	else: _equip_server(player,weapon)

@rpc("any_peer","call_remote","reliable")
func server_equip(weapon: String) -> void:
	if not multiplayer.is_server(): return
	if not network_guard.allow(multiplayer.get_remote_sender_id(),"equip",8,6): return
	var actor: GamePlayer = players.get(multiplayer.get_remote_sender_id())
	if is_instance_valid(actor): _equip_server(actor,weapon)

func _equip_server(actor: GamePlayer, weapon: String) -> void:
	if not GameWeapons.ITEMS.has(weapon) or weapon not in actor.active_weapons() or actor.hp <= 0.0 or not actor.grenade_held_id.is_empty(): return
	if actor.weapon_id!=weapon or actor.grenade_selected: actor.pause_reload()
	actor.grenade_selected=false
	if online: _broadcast("remote_grenade_selection",[actor.peer_id,false])
	actor.weapon_id = weapon
	actor._refresh_weapon()
	actor._update_weapon_pose()
	if online: _broadcast("remote_equipped",[actor.peer_id,weapon])
	if not _resume_reload(actor): sync_inventory(actor)

@rpc("authority","call_remote","reliable")
func remote_equipped(id: int, weapon: String) -> void:
	var actor: GamePlayer = players.get(id)
	if not is_instance_valid(actor) or not GameWeapons.ITEMS.has(weapon): return
	if actor.weapon_id != weapon:
		actor.pause_reload()
	actor.weapon_id = weapon
	# Reliable equip events are the source of truth. Rebuild even when the ID
	# matches: a stale visual rig must never leave a sniper model on the AK.
	actor._refresh_weapon()
	if actor.is_local: actor._update_view()

func request_reload(player: GamePlayer, weapon: String, _duration: float) -> void:
	if online and not multiplayer.is_server(): rpc_id(1,"server_reload_request",weapon)
	else: _server_reload(player.peer_id,weapon)

func request_inventory_sync(actor: GamePlayer) -> void:
	if online and not multiplayer.is_server() and actor.is_local: rpc_id(1,"server_inventory_sync",actor.life_id)

@rpc("any_peer","call_remote","reliable")
func server_inventory_sync(life: int) -> void:
	if not multiplayer.is_server(): return
	var id:=multiplayer.get_remote_sender_id();var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or actor.life_id!=life or not network_guard.allow(id,"inventory_sync",1,2): return
	sync_inventory(actor)

@rpc("any_peer","call_remote","reliable")
func server_reload_request(weapon: String) -> void:
	if multiplayer.is_server() and network_guard.allow(multiplayer.get_remote_sender_id(),"reload",4,3): _server_reload(multiplayer.get_remote_sender_id(),weapon)

func _server_reload(id: int, weapon: String) -> void:
	var actor: GamePlayer = players.get(id)
	if not is_instance_valid(actor) or actor.hp <= 0.0: return
	if actor.reload_left > 0.0 or actor.weapon_id != weapon or not actor.ammo.has(weapon) or actor._grenade_active():
		# A rejected request still acknowledges the real inventory/reload. It
		# must not leave a client waiting on an obsolete local reload forever.
		if online and actor.weapon_id!=weapon and _network_peer_ready(id): rpc_id(id,"remote_equipped",id,actor.weapon_id)
		sync_inventory(actor);return
	if get_meta("war_mode",false) and (not str(actor.get("vehicle_id")).is_empty() or bool(actor.get("gadget_equipped")) or (has_method("water_restricted") and call("water_restricted",actor))): return
	var item := actor.weapon_spec(weapon)
	if int(actor.ammo[weapon]) >= int(item.mag) or int(actor.reserves.get(weapon,0)) <= 0:
		sync_inventory(actor);return
	if _resume_reload(actor): return
	actor.begin_reload(weapon,float(item.reload))
	if online: _broadcast("remote_reload_started",[id,weapon,float(item.reload),actor.reload_left,actor.life_id,actor.reload_revision])
	sync_inventory(actor)

func _resume_reload(actor: GamePlayer) -> bool:
	if get_meta("war_mode",false) and has_method("water_restricted") and call("water_restricted",actor): return false
	if not is_instance_valid(actor) or (online and not multiplayer.is_server()) or not actor.resume_reload(actor.weapon_id): return false
	if online: _broadcast("remote_reload_started",[actor.peer_id,actor.reload_weapon,actor.reload_total,actor.reload_left,actor.life_id,actor.reload_revision])
	sync_inventory(actor)
	return true

@rpc("authority","call_remote","reliable")
func remote_reload_started(id: int, weapon: String, duration: float,remaining: float=-1.0,life: int=0,revision: int=-1) -> void:
	var actor: GamePlayer = players.get(id)
	if not is_instance_valid(actor) or actor.hp<=0 or (life>0 and life!=actor.life_id) or (revision>=0 and revision<actor.authoritative_reload_revision): return
	actor.play_remote_reload(weapon,duration,remaining)
	if revision>=0: actor.authoritative_reload_revision=revision

func _spawn_projectile(owner_id: int, origin: Vector3, direction: Vector3, id: String, melee: bool, authoritative: bool, shot_id := "") -> void:
	var item := CombatRules.weapon(id)
	if melee:
		if authoritative: _resolve_melee(owner_id,origin,direction,item,shot_id)
		return
	if projectiles.size() >= 256: return
	var visible_trace:=GameTracerStyle.visible_for(id,shot_id)
	var visual: Dictionary=combat_visuals.acquire(id) if visible_trace and is_instance_valid(combat_visuals) else {}
	if not visual.is_empty(): visual.node.global_position=origin;visual.node.scale=Vector3.ONE*.025
	var query:=PhysicsRayQueryParameters3D.create(origin,origin,CombatRules.SHOT_MASK,_collision_excludes(owner_id,false))
	query.collide_with_areas=true;query.collide_with_bodies=true
	projectiles.append({"node":visual.get("node"),"trace":visual.get("trace"),"visual":visual,"query":query,"color":GameTracerStyle.color_for(id),"pos":origin,"vel":direction.normalized()*float(item.speed),"gravity":float(item.gravity),"life":float(item.range)/float(item.speed)*1.4+.1,"drag":float(item.get("drag",0)),"distance":0.0,"range":float(item.range),"owner":owner_id,"weapon":id,"damage":float(item.damage),"server":authoritative,"last":origin,"shot_id":shot_id})

func _resolve_melee(owner_id: int, origin: Vector3, direction: Vector3, item: Dictionary, shot_id := "") -> void:
	var actor: GamePlayer = players.get(owner_id)
	if not is_instance_valid(actor) or not is_instance_valid(actor.melee_rig): return
	if not actor.melee_rig.running: actor.play_fire_animation(str(item.id))
	melee_attacks[owner_id] = {"life":actor.life_id,"weapon":str(item.id),"shot_id":shot_id,"hit":{}}

func _melee_network_delay(id: int) -> float:
	if not online or id==multiplayer.get_unique_id(): return 0.0
	var transport:=multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var peer:=GameNetworkPeers.connected(transport,id)
	return clampf(float(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))*.0005,0,.12) if peer else 0.0

func melee_sweep(actor: GamePlayer, previous: PackedVector3Array, current: PackedVector3Array) -> void:
	if online and not multiplayer.is_server(): return
	var record: Dictionary = melee_attacks.get(actor.peer_id,{})
	if record.is_empty() or record.life != actor.life_id or record.weapon != actor.weapon_id or actor.hp <= 0.0: return
	var item := CombatRules.weapon(actor.weapon_id)
	var space := get_world_3d().direct_space_state
	for index in range(current.size()):
		var radius:=actor.melee_rig.contact_radius(index)
		var a := previous[index]
		var b := current[index]
		var motion := b-a
		var shape := actor.melee_rig.sweep_shape
		shape.radius = radius
		shape.height = motion.length()+radius*2.0
		var query := actor.melee_rig.sweep_query
		query.shape = shape
		var basis := Basis(Quaternion(Vector3.UP,motion.normalized())) if motion.length_squared() > 0.000001 else Basis.IDENTITY
		query.transform = Transform3D(basis,(a+b)*0.5)
		query.collision_mask = 2
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = _collision_excludes(actor.peer_id,false)
		for result in space.intersect_shape(query,24):
			var area := result.collider as Area3D
			if not is_instance_valid(area) or not area.has_meta("hit_region"): continue
			var target: Node = area
			while target != null and not target is GamePlayer: target = target.get_parent()
			if not target is GamePlayer or target == actor or target.hp <= 0.0 or record.hit.has(target.peer_id): continue
			var point := Geometry3D.get_closest_point_to_segment(area.global_position,a,b)
			if actor.melee_rig.grip_right.global_position.distance_to(point)>actor.melee_rig.contact_reach()+radius: continue
			# Walls block the tool's swept motion and the connection to its hands.
			var blocked := false
			for segment in [[a,b],[actor.melee_rig.grip_right.global_position,area.global_position],[actor.camera_pivot.global_position,area.global_position]]:
				var ray := PhysicsRayQueryParameters3D.create(segment[0],segment[1],1)
				ray.hit_from_inside = true
				if not space.intersect_ray(ray).is_empty():
					blocked = true
					break
			if blocked: continue
			record.hit[target.peer_id] = true
			var key := str(record.shot_id)+":"+str(target.peer_id)
			var impact := {"collider":area,"position":point,"normal":-motion.normalized() if motion.length_squared()>0.000001 else Vector3.UP}
			_confirm_impact(actor.peer_id,impact,item,key,(target.global_position-actor.global_position).normalized())
			if is_instance_valid(target) and target.hp > 0.0:
				target.velocity += (target.global_position-actor.global_position).normalized()*float(item.power)*0.07

func _resolve_hitscan(owner_id: int, origin: Vector3, direction: Vector3, item: Dictionary, shot_id: String) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin,origin + direction * float(item.range),CombatRules.SHOT_MASK,_collision_excludes(owner_id,false))
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): _confirm_impact(owner_id,hit,item,shot_id,direction)

func _confirm_impact(owner_id: int, hit: Dictionary, item: Dictionary, shot_id: String, direction: Vector3) -> void:
	_apply_hit(owner_id,hit,float(item.damage),"chest",str(item.get("id","")),direction)
	var collider: Object = hit.get("collider")
	var blood := is_instance_valid(collider) and collider.has_meta("hit_region")
	_present_impact(shot_id,hit.position,hit.get("normal",Vector3.UP),blood)
	if not blood:
		var surface:=GameImpactSurface.detect(hit,"war" if get_meta("war_mode",false) else map_kind)
		remote_surface_impact(shot_id,hit.position,surface,hit.get("normal",Vector3.UP))
		if online: _broadcast("remote_surface_impact",[shot_id,hit.position,surface,hit.get("normal",Vector3.UP)])
	if online: _broadcast("remote_impact",[shot_id,hit.position,hit.get("normal",Vector3.UP),blood])

@rpc("authority","call_remote","reliable")
func remote_surface_impact(shot_id: String,point: Vector3,surface: String,normal:=Vector3.UP) -> void:
	if is_instance_valid(combat_feedback): combat_feedback.impact(shot_id,point,surface)
	if surface in ["metal","vehicle"] and is_instance_valid(metal_sparks): metal_sparks.burst(point,normal,shot_id)

@rpc("authority","call_remote","reliable")
func remote_impact(shot_id: String, point: Vector3, normal: Vector3, blood: bool) -> void:
	for p in projectiles:
		if str(p.get("shot_id","")) == shot_id: p.life = 0.0
	_present_impact(shot_id,point,normal,blood)

func _present_impact(shot_id: String, point: Vector3, _normal: Vector3, blood: bool) -> void:
	if seen_impacts.has(shot_id): return
	seen_impacts[shot_id] = true
	if seen_impacts.size() > 512: seen_impacts.erase(seen_impacts.keys()[0])
	if not is_instance_valid(world_root): return
	if is_instance_valid(combat_visuals): combat_visuals.impact(point,blood)

func _process(delta: float) -> void:
	if is_instance_valid(loading_screen) and loading_screen.visible: loading_screen.detail.text = status_label.text
	if not is_instance_valid(music_player) or music_player.stream == null: return
	if is_instance_valid(naval_mode): return
	var audible := mode == "menu" and not dedicated_pvp and not is_instance_valid(naval_mode)
	if audible and not music_player.playing: music_player.play()
	music_player.volume_db = move_toward(music_player.volume_db,menu_music_db if audible else -60.0,delta*65.0)
	if not audible and music_player.volume_db <= -59.9: music_player.stop()

func _physics_process(delta: float) -> void:
	if is_instance_valid(war_mode) or offline_frozen: return
	if online: network_diagnostics.tick(multiplayer,"war" if get_meta("war_mode",false) else "infantry",delta)
	if dedicated_pvp:
		if Time.get_unix_time_from_system()-pvp_health_at>2.0:
			pvp_health_at = Time.get_unix_time_from_system()
			var status_error:=status_writer.submit(NavalStorage.folder().path_join(_health_file()),_health_status())
			if status_error!=OK:GameDiagnostics.record("server_status_error",{"error":status_error})
		for id in pvp_challenges.keys():
			if Time.get_ticks_msec()>int(pvp_challenges[id].expires):
				GameDiagnostics.record("handshake_timeout",{"peer":id,"mode":mode})
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(int(id))
				pvp_challenges.erase(id)
	if is_instance_valid(naval_mode): return
	if not get_meta("war_mode",false) and mode!="menu" and is_instance_valid(world_root):
		environment_seconds+=delta
		if is_instance_valid(day_night): day_night.apply_time(environment_seconds)
		if online and multiplayer.is_server():
			environment_sync_clock+=delta
			if NetworkCadence.due(environment_sync_clock,2.):
				environment_sync_clock=NetworkCadence.consume(environment_sync_clock,2.);_broadcast("remote_environment_time",[environment_seconds])
	_step_match_stats(delta)
	_step_projectiles(delta)
	if is_instance_valid(grenades_system) and online and multiplayer.is_server():
		grenade_snapshot_clock+=delta
		if NetworkCadence.due(grenade_snapshot_clock,.1):
			grenade_snapshot_clock=NetworkCadence.consume(grenade_snapshot_clock,.1)
			var states:=grenades_system.snapshots()
			for start in range(0,states.size(),8): _broadcast("remote_grenade_states",[states.slice(start,start+8)])
	if not online and (mode == "training" or mode == "desert"):
		offline_elapsed += delta
		npc_spawn_clock += delta
		var desired := mini(16 if mode == "training" else 24,(8 if mode == "training" else 12)+int(offline_elapsed/18.0))
		if npc_spawn_clock > 0.45 and npcs.size() < desired and is_instance_valid(local_player) and local_player.hp > 0.0:
			npc_spawn_clock = 0.0
			_spawn_npc(randi() % 4)
	if mode == "naval": _update_naval(delta)
	if online and mode == "naval" and ship_root:
		last_net_state += delta
		if not multiplayer.is_server() and NetworkCadence.due(last_net_state,.05):
			last_net_state = NetworkCadence.consume(last_net_state,.05)
			rpc_id(1, "server_naval_state", ship_root.global_position, ship_yaw, ship_speed, ship_aim_yaw, ship_aim_pitch, ship_weapon, ship_type)
		elif multiplayer.is_server():
			last_server_broadcast += delta
			if NetworkCadence.due(last_server_broadcast,.05):
				last_server_broadcast = NetworkCadence.consume(last_server_broadcast,.05)
				_broadcast("remote_naval_state",[1, ship_root.global_position, ship_yaw, ship_speed, ship_aim_yaw, ship_aim_pitch, ship_weapon, ship_type, float(naval_hp.get(1, 240.0))])
				for peer_id in naval_remote_ships:
					var remote_boat: Node3D = naval_remote_ships[peer_id]
					_broadcast("remote_naval_state",[int(peer_id), remote_boat.global_position, float(remote_boat.get_meta("yaw", 0.0)), float(remote_boat.get_meta("speed", 0.0)), float(remote_boat.get_meta("aim_yaw", 0.0)), float(remote_boat.get_meta("aim_pitch", 0.0)), str(remote_boat.get_meta("weapon", "lightMG")), str(remote_boat.get_meta("ship_type", "heavy")), float(naval_hp.get(peer_id, 240.0))])
	if online and mode != "naval" and multiplayer.multiplayer_peer and not multiplayer.is_server():
		last_net_state += delta
		if NetworkCadence.due(last_net_state,.05) and local_player and (get_meta("war_mode",false) or pvp_spawn_confirmed):
			last_net_state = NetworkCadence.consume(last_net_state,.05)
			movement_sequence+=1
			rpc_id(1, "server_player_state", local_player.global_position, local_player.yaw,local_player.clamp_aim_pitch(local_player.pitch+local_player.recoil),local_player.weapon_id,local_player.crouched,2 if local_player.iron_sights else (1 if local_player.aiming else 0),local_player.life_id,movement_sequence,local_player.lean)
	if multiplayer.is_server() and online:
		last_server_broadcast += delta
		if NetworkCadence.due(last_server_broadcast,.05):
			last_server_broadcast = NetworkCadence.consume(last_server_broadcast,.05)
			if local_player:
				_broadcast("remote_player_state",[1, local_player.global_position, local_player.yaw,local_player.clamp_aim_pitch(local_player.pitch+local_player.recoil),local_player.weapon_id,local_player.hp,local_player.crouched,local_player.life_id,local_player.kills,local_player.deaths,2 if local_player.iron_sights else (1 if local_player.aiming else 0),local_player.lean])
			for player_id in players:
				if int(player_id) == 1: continue
				if get_meta("war_mode",false): continue # War relays each validated pose immediately.
				var remote: GamePlayer = players[player_id]
				if not is_instance_valid(remote): continue
				_broadcast("remote_player_state",[int(player_id), remote.global_position, remote.yaw, remote.pitch, remote.weapon_id, remote.hp,remote.crouched,remote.life_id,remote.kills,remote.deaths,2 if remote.iron_sights else (1 if remote.aiming else 0),remote.lean])
		_update_lobby_text()

func _step_projectiles(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		if float(p.life)<=0:
			_release_projectile_visual(p);projectiles.remove_at(i);continue
		var step_time := minf(delta,float(p.life))
		var old: Vector3 = p.pos
		var weights:=GameBulletPhysics.coefficients(float(p.get("drag",0)),step_time)
		var acceleration:=Vector3.DOWN*float(p.gravity)
		var next: Vector3=old+p.vel*weights.y+acceleration*weights.z
		p.vel=p.vel*weights.x+acceleration*weights.y
		if p.has("range"):
			var remaining := maxf(0.0,float(p.range) - float(p.get("distance",0.0)))
			if old.distance_to(next) > remaining: next = old + (next-old).normalized() * remaining
		var query: PhysicsRayQueryParameters3D=p.query
		query.from=old;query.to=next
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var elapsed := step_time
		if not hit.is_empty():
			next = hit.position
			if p.server:
				if p.get("naval", false):
					var hit_node: Node = hit.get("collider")
					while hit_node and not hit_node.has_meta("naval_ship_id"):
						hit_node = hit_node.get_parent()
					if hit_node and int(hit_node.get_meta("naval_ship_id")) != int(p.owner):
						var target_id := int(hit_node.get_meta("naval_ship_id"))
						var start_hp := float(naval_hp.get(target_id, 160.0))
						var hp := maxf(0.0, start_hp - float(p.damage))
						naval_hp[target_id] = hp
						if target_id == 0: hit_node.set_meta("hp", hp)
						var health_mesh := hit_node.find_child("HealthBar", true, false) as MeshInstance3D
						var max_hp := float(hit_node.get_meta("max_hp", 160.0 if target_id == 0 else 240.0))
						if health_mesh: health_mesh.scale.x = clampf(hp / max_hp, 0.0, 1.0)
						if online: _broadcast("remote_naval_damage",[target_id, hp])
				else:
					_confirm_impact(int(p.owner),hit,CombatRules.weapon(str(p.weapon)),str(p.get("shot_id","")),p.vel.normalized())
			p.life = 0.0
		if not p.get("near_played",false) and is_instance_valid(combat_feedback) and is_instance_valid(local_player):
			if combat_feedback.near_miss(old,next,local_player,int(p.owner),p.vel,str(p.weapon)): p.near_played=true
		if is_instance_valid(combat_visuals): combat_visuals.draw(p.visual,old,next,camera)
		p.distance = float(p.get("distance",0.0)) + old.distance_to(next)
		if p.has("range") and float(p.distance) >= float(p.range): p.life = 0.0
		p.pos = next
		p.life = float(p.life) - elapsed
		projectiles[i] = p
		if float(p.life)<=0:
			_release_projectile_visual(p);projectiles.remove_at(i)

func _release_projectile_visual(shot: Dictionary) -> void:
	if is_instance_valid(combat_visuals): combat_visuals.release(shot.get("visual",{}))

func _apply_hit(owner_id: int, hit: Dictionary, damage: float, fallback_region := "chest", weapon := "ak", direction := Vector3.ZERO) -> void:
	var collider: Object = hit.get("collider")
	if not is_instance_valid(collider): return
	var region := str(collider.get_meta("hit_region", fallback_region)) if collider.has_meta("hit_region") else fallback_region
	var target: GamePlayer = null
	var candidate: Node = collider
	while is_instance_valid(candidate) and not candidate is GamePlayer:
		candidate = candidate.get_parent()
	if is_instance_valid(candidate) and candidate is GamePlayer: target = candidate
	if not is_instance_valid(target) or (target.peer_id == owner_id and weapon!="grenade" and not GameWeapons.is_launcher(weapon)) or target.hp <= 0.0: return
	if is_instance_valid(domination) and domination.blocked(): return
	if not collider.has_meta("hit_region"): return
	target.last_impact_direction = direction
	target.last_impact_weapon = weapon
	var was_alive := target.hp > 0.0
	if not online or multiplayer.is_server():
		var hp_before: float=target.hp
		var point: Vector3=target.global_position+Vector3.UP*2.1
		target.take_damage(damage, region, owner_id)
		var attacker:=players.get(owner_id) as GamePlayer
		var friendly:=_friendly_hit(attacker,target)
		if is_instance_valid(attacker) and not attacker.is_npc and attacker!=target and not friendly:
			_register_match_stat(attacker)
			match_stats.hit(owner_id,target.peer_id,target.life_id,hp_before-target.hp,target.hp<=0,region=="head" and CombatRules.weapon(weapon).kind!="melee",attacker.global_position.distance_to(target.global_position),Time.get_ticks_msec()*.001)
			if target.hp<=0 and _defending_objective(attacker,target): match_stats.award(owner_id,75,"defend:%d:%d"%[target.peer_id,target.life_id],"objective")
		if target.peer_id!=owner_id: _damage_confirmed(owner_id,point,hp_before-target.hp,region=="head")
		if was_alive and target.hp <= 0.0:
			var killer: GamePlayer = players.get(owner_id)
			if killer and killer!=target and not friendly:
				killer.kills += 1
				if killer.is_local:
					_award_kill()
				elif dedicated_pvp:
					_pvp_reward.call_deferred(str(killer.get_meta("account_id","")),str(target.get_meta("account_id","")),str(target.peer_id)+":"+str(target.life_id),killer.peer_id)
				elif online:
					killer.set_meta("coins",int(killer.get_meta("coins",0)) + 30)
					rpc_id(killer.peer_id,"remote_wallet",int(killer.get_meta("coins")),killer.owned)
		if online:
			var killer: GamePlayer = players.get(owner_id)
			_broadcast("remote_damage",[target.peer_id,{"hp":target.hp,"limbs":target.limbs,"region":region,"killer":owner_id,"kills":killer.kills if is_instance_valid(killer) else 0,"dead":target.hp <= 0.0,"life":target.life_id,"direction":direction,"weapon":weapon,"detached":target.detached_region,"death_sound":target.death_sound,"velocity":target.get_meta("death_velocity",target.velocity)}])

func _friendly_hit(_attacker: GamePlayer,_target: GamePlayer) -> bool:
	return false # Team modes override; FFA and the original offline keep their rules.

@rpc("authority","call_remote","reliable")
func remote_damage(victim_id: int, state: Dictionary) -> void:
	var victim: GamePlayer = players.get(victim_id)
	if not is_instance_valid(victim) or int(state.life) != victim.life_id: return
	victim.hp = float(state.hp)
	victim.limbs = state.limbs.duplicate()
	victim.last_hit_region = str(state.region)
	victim.last_impact_direction = state.direction
	victim.last_impact_weapon = str(state.weapon)
	victim.set_meta("death_velocity",state.get("velocity",victim.velocity))
	victim.detached_region = str(state.detached)
	victim.death_sound = int(state.get("death_sound",0))
	victim.reaction = 0.45
	if state.dead: victim.clear_aim()
	if state.dead and victim.death_presented != victim.life_id:
		victim.cancel_melee()
		victim.cancel_reload()
		victim._hide_dead_presentations()
		victim.respawn_left = 4.0
		victim.body_root.visible = false
		victim.weapon_root.visible = false
		victim.velocity = Vector3.ZERO
		victim._set_hitboxes_enabled(false)
		if victim.body_collision: victim.body_collision.set_deferred("disabled",true)
		victim.deaths += 1
		spawn_ragdoll(victim.global_position,int(state.killer),victim)
		if victim.is_local:
			profile.deaths = int(profile.deaths) + 1
			_save_profile()
	var killer: GamePlayer = players.get(int(state.killer))
	if is_instance_valid(killer): killer.kills = int(state.kills)
	if victim.is_local: damage_feedback(victim.hp)
	update_hud()

func _on_player_died(victim: GamePlayer, killer_id: int) -> void:
	if not victim.is_npc: victim.set_meta("deploy_ready_at",Time.get_ticks_msec()*.001+(4.0 if online else 2.0))
	_stats_death(victim)
	_record_match_death(victim)
	if is_instance_valid(grenades_system): grenades_system.drop_owner(victim.peer_id)
	victim.death_sound = randi_range(0,5)
	spawn_ragdoll(victim.global_position, killer_id, victim)
	if online and multiplayer.is_server():
		if not victim.is_npc:
			_schedule_remote_respawn(victim.peer_id)
	if victim.is_local:
		profile.deaths += 1
		_save_profile()
	if victim.is_npc:
		npcs.erase(victim)
		players.erase(victim.peer_id)

func _award_kill() -> void:
	profile.kills = int(profile.kills) + 1
	profile.coins = int(profile.coins) + 30
	_save_profile()
	hud_message("ABATE · +30 MOEDAS · NÍVEL %d" % (1 + int(profile.kills) / 5))

@rpc("authority","call_remote", "reliable")
func remote_ragdoll(peer_id: int, pos: Vector3, killer_id: int, hit_region: String) -> void:
	var victim: GamePlayer = players.get(peer_id)
	if victim:
		victim.last_hit_region = hit_region
		spawn_ragdoll(pos, killer_id, victim)

func _schedule_remote_respawn(id: int) -> void:
	var generation := match_generation
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree() or generation != match_generation or not online or not multiplayer.is_server(): return
	var player: GamePlayer = players.get(id)
	if not player or player.hp > 0.0: return
	_remote_spawn_ready(player)

func _collision_excludes(owner_id: int, naval: bool) -> Array[RID]:
	var excluded: Array[RID] = []
	if naval:
		var owner_boat: Node3D = ship_root if owner_id == multiplayer.get_unique_id() or not online else naval_remote_ships.get(owner_id)
		if owner_boat:
			var hull := owner_boat.get_node_or_null("HullCollider") as StaticBody3D
			if hull: excluded.append(hull.get_rid())
	else:
		var shooter: GamePlayer = players.get(owner_id)
		if is_instance_valid(shooter):
			excluded.append(shooter.get_rid())
			for area in shooter.hit_regions.values():
				if is_instance_valid(area): excluded.append(area.get_rid())
	return excluded

func spawn_ragdoll(pos: Vector3, _killer_id: int, source: GamePlayer = null) -> void:
	if not is_instance_valid(source) or not is_instance_valid(world_root) or source.death_presented == source.life_id: return
	source.death_presented = source.life_id
	_play_death_sound(source.death_sound,pos)
	var old := get_tree().get_nodes_in_group("death_ragdolls")
	if old.size() >= 10: old[0].queue_free()
	var body := DeathRagdoll.create(world_root,source,pos)
	if source.is_local and is_instance_valid(death_view): death_view.follow(body,pos,-source.global_basis.z)

func _ragdoll_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	return material

@rpc("any_peer","call_remote", "unreliable")
func server_player_state(pos: Vector3, new_yaw: float, new_pitch: float, _weapon: String, is_crouched: bool, aim_level := 0, state_life:=1,state_sequence:=0,state_lean:=0.0) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"motion",40,8): return
	var actor: GamePlayer = players.get(id)
	if not is_instance_valid(actor) or actor.hp <= 0.0 or actor.life_id!=state_life or not CombatRules.finite_vector(pos) or not is_finite(new_yaw) or not is_finite(new_pitch) or not is_finite(state_lean) or absf(state_lean)>1.: return
	network_diagnostics.observe_input(id,state_life,state_sequence)
	var bounded:=network_guard.movement(id,actor.life_id,state_sequence,actor.global_position,pos,12.0*actor.infantry_protection.multiplier())
	if not bounded.accepted: return
	if not Vector3(bounded.position).is_equal_approx(pos):
		pos=bounded.position
		rpc_id(id,"remote_position_correction",pos)
	var terrain_y := DesertTerrain.height_at(pos.x,pos.z) if map_kind=="desert" else 0.0
	if map_kind=="desert" and pos.y<terrain_y-.06:
		pos=DesertMap.safe_ground_point(pos)
		rpc_id(id,"remote_position_correction",pos)
	if absf(pos.x)>150.0 or absf(pos.z)>150.0 or pos.y<terrain_y-4.0 or pos.y>terrain_y+12.0: return
	var obstacle:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.9,pos+Vector3.UP*.9,1,[actor.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(obstacle).is_empty():
		rpc_id(id,"remote_position_correction",actor.global_position)
		return
	if actor.crouched != is_crouched: actor._set_crouched(is_crouched)
	actor.aiming = aim_level > 0
	actor.iron_sights = aim_level == 2
	actor.receive_network_state(pos,wrapf(new_yaw,-PI,PI),clampf(new_pitch,-1.30,1.25))
	actor.network_lean=GameInfantryPose.limit_lean(actor,state_lean);actor.lean=actor.network_lean
	actor.camera_pivot.position.x=actor.lean*GameInfantryPose.LEAN_DISTANCE
	actor._animate_walk()

@rpc("authority","call_remote", "unreliable")
func remote_player_state(id: int, pos: Vector3, new_yaw: float, new_pitch: float, weapon: String, hp_value: float, is_crouched: bool, life := 1, kill_count := 0, death_count := 0, aim_level := 0,state_lean:=0.0,state_sequence:=0) -> void:
	if id == multiplayer.get_unique_id(): return
	var actor: GamePlayer = players.get(id)
	# Only the reliable join event may create an avatar. Unreliable snapshots
	# can arrive after a reliable leave, or before the initial join; discard
	# those instead of resurrecting a disconnected peer.
	if not is_instance_valid(actor): return
	if int(life) != actor.life_id: return
	if not network_diagnostics.accept_pose(id,int(life),state_sequence): return
	actor.receive_network_state(pos,new_yaw,new_pitch)
	actor.network_lean=clampf(state_lean,-1,1) if is_finite(state_lean) else 0.
	actor.hp = minf(actor.hp,hp_value)
	actor.kills = kill_count
	actor.deaths = death_count
	actor.aiming = aim_level > 0
	actor.iron_sights = aim_level == 2
	if actor.crouched != is_crouched: actor._set_crouched(is_crouched)
	# Equipment changes arrive through the reliable remote_equipped RPC. Do
	# not let an older, reordered movement snapshot roll a rifle model back.

func scoreboard_context() -> Dictionary:
	var result: Dictionary={"mode":"DESERTO · TODOS CONTRA TODOS" if online else "OFFLINE · TREINO","map":"POSTO MILITAR" if map_kind=="desert" else "ESCRITÓRIO","seconds":offline_elapsed,"time_label":"DECORRIDO","network":online,"teams":false,"objectives":""}
	if is_instance_valid(domination) and online:
		result.seconds=domination.remaining;result.time_label="RESTANTE"
		result.objectives=domination.detail()
		if domination.phase=="finished": result.objectives="EMPATE" if domination.winner_id==0 else "VITÓRIA · "+domination.winner_name
	return result

func _register_match_stat(actor: GamePlayer) -> void:
	var label:=str(profile.nickname) if actor.is_local else str(actor.name)
	var team:=int(actor.get("war_team")) if get_meta("war_mode",false) else -1
	match_stats.register(actor.peer_id,label,team)

func _stats_death(actor: GamePlayer) -> void:
	if actor.is_npc or (online and not multiplayer.is_server()): return
	_register_match_stat(actor)
	match_stats.death(actor.peer_id,actor.life_id)

func _defending_objective(attacker: GamePlayer,victim: GamePlayer) -> bool:
	return is_instance_valid(domination) and domination.owner_id==attacker.peer_id and DesertDomination.inside(attacker.global_position) and DesertDomination.inside(victim.global_position)

func _step_match_stats(delta: float) -> void:
	if mode=="menu" or (online and not multiplayer.is_server()): return
	score_clock+=delta
	if not NetworkCadence.due(score_clock,.5): return
	score_clock=NetworkCadence.consume(score_clock,.5)
	for actor: GamePlayer in players.values():
		if actor.is_npc: continue
		_register_match_stat(actor)
		var ping:=-1
		if online and actor.peer_id!=1 and actor.peer_id in multiplayer.get_peers() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			var peer:=GameNetworkPeers.connected(multiplayer.multiplayer_peer as ENetMultiplayerPeer,actor.peer_id)
			if peer and peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)>0: ping=maxi(1,roundi(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))
		if int(match_stats.rows[actor.peer_id].ping)!=ping: match_stats.rows[actor.peer_id].ping=ping;match_stats.revision+=1
	if online and score_sent_revision!=match_stats.revision:
		score_sent_revision=match_stats.revision
		_broadcast("remote_match_stats",[match_stats.snapshot()])

@rpc("authority","call_remote","reliable")
func remote_match_stats(rows: Array) -> void:
	match_stats.receive(rows)

func _update_lobby_text() -> void:
	if not is_instance_valid(lobby_panel): return
	var label: Label = lobby_panel.get_node("LobbyText")
	var count := 1 + naval_remote_ships.size() if mode == "naval" else players.size()
	label.text = "SALA ONLINE · %d/%d jogadores\n%s" % [count, MAX_PLAYERS, "Partida em andamento" if count >= 2 else "Aguardando mais 1 jogador"]

func _spawn_remote_ship(id: int, pos: Vector3, kind := "heavy") -> Node3D:
	if naval_remote_ships.has(id) and is_instance_valid(naval_remote_ships[id]):
		return naval_remote_ships[id]
	var boat := Node3D.new()
	boat.name = "Ship_%d" % id
	boat.position = pos
	boat.set_meta("naval_ship_id", id)
	boat.set_meta("ship_type", kind if GameWeapons.NAVAL.has(kind) else "heavy")
	var boat_spec: Dictionary = GameWeapons.NAVAL.get(str(boat.get_meta("ship_type")), GameWeapons.NAVAL.heavy)
	boat.set_meta("max_hp", float(boat_spec.hp))
	boat.set_meta("yaw", 0.0)
	boat.set_meta("speed", 0.0)
	boat.set_meta("aim_yaw", 0.0)
	boat.set_meta("aim_pitch", 0.08)
	boat.set_meta("weapon", "lightMG")
	world_root.add_child(boat)
	var spec: Dictionary = boat_spec
	_build_ship_mesh(boat, "#7c8584", float(spec.length), float(spec.width), str(boat.get_meta("ship_type", "heavy")))
	_add_ship_health_bar(boat)
	naval_remote_ships[id] = boat
	naval_hp[id] = float(spec.hp)
	return boat

@rpc("authority","call_remote", "reliable")
func remote_naval_damage(id: int, hp_value: float) -> void:
	naval_hp[id] = hp_value
	var boat: Node3D = ship_root if id == multiplayer.get_unique_id() else naval_remote_ships.get(id)
	if id == 0: boat = world_root.get_node_or_null("TargetShip")
	if boat:
		var health_mesh := boat.find_child("HealthBar", true, false) as MeshInstance3D
		var max_hp := float(boat.get_meta("max_hp", 160.0 if id == 0 else 240.0))
		if health_mesh: health_mesh.scale.x = clampf(hp_value / max_hp, 0.0, 1.0)

@rpc("any_peer","call_remote", "unreliable")
func server_naval_state(pos: Vector3, new_yaw: float, speed: float, aim_yaw: float, aim_pitch: float, weapon: String, kind: String) -> void:
	if not multiplayer.is_server() or mode!="naval" or dedicated_pvp or get_meta("war_mode",false): return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id) or not network_guard.allow(id,"legacy_naval",35,8) or not CombatRules.finite_vector(pos): return
	if not is_finite(new_yaw) or not is_finite(speed) or not is_finite(aim_yaw) or not is_finite(aim_pitch): return
	var valid_kind := kind if GameWeapons.NAVAL.has(kind) else "heavy"
	var boat: Node3D = naval_remote_ships.get(id)
	if not boat: boat = _spawn_remote_ship(id, pos, valid_kind)
	else: valid_kind = str(boat.get_meta("ship_type", "heavy"))
	boat.global_position = pos
	boat.rotation.y = new_yaw
	boat.set_meta("yaw", new_yaw)
	boat.set_meta("speed", clampf(speed, -4.0, float(GameWeapons.NAVAL[valid_kind].speed)))
	boat.set_meta("aim_yaw", aim_yaw)
	boat.set_meta("aim_pitch", clampf(aim_pitch, -0.18, 0.60))
	var allowed: Array = GameWeapons.NAVAL[valid_kind].allowed
	boat.set_meta("weapon", weapon if weapon in allowed else str(allowed[0]))
	boat.set_meta("ship_type", valid_kind)
	boat.set_meta("max_hp", float(GameWeapons.NAVAL[valid_kind].hp))

@rpc("authority","call_remote", "unreliable")
func remote_naval_state(id: int, pos: Vector3, new_yaw: float, speed: float, aim_yaw: float, aim_pitch: float, weapon: String, kind: String, hp_value: float) -> void:
	if id == multiplayer.get_unique_id(): return
	var boat: Node3D = naval_remote_ships.get(id)
	if not boat: boat = _spawn_remote_ship(id, pos, kind)
	boat.global_position = boat.global_position.lerp(pos, 0.55)
	boat.rotation.y = new_yaw
	boat.set_meta("yaw", new_yaw)
	boat.set_meta("speed", speed)
	boat.set_meta("aim_yaw", aim_yaw)
	boat.set_meta("aim_pitch", aim_pitch)
	var valid_kind := kind if GameWeapons.NAVAL.has(kind) else "heavy"
	var allowed: Array = GameWeapons.NAVAL[valid_kind].allowed
	boat.set_meta("weapon", weapon if weapon in allowed else str(allowed[0]))
	boat.set_meta("ship_type", valid_kind)
	boat.set_meta("max_hp", float(GameWeapons.NAVAL[valid_kind].hp))
	naval_hp[id] = hp_value
	var health_mesh := boat.find_child("HealthBar", true, false) as MeshInstance3D
	if health_mesh: health_mesh.scale.x = clampf(hp_value / float(GameWeapons.NAVAL[valid_kind].hp), 0.0, 1.0)

func host_game(kind: String) -> void:
	if _central_pvp() and not dedicated_pvp and kind == "pvp":
		join_game(kind)
		return
	if kind == "naval":
		open_naval()
		return
	if online: return
	_read_profile_ui()
	var peer := ENetMultiplayerPeer.new()
	# Keep max_channels=0 on the 4.7.2 host: the native server path passes a
	# nonzero channel cap into ENet's bandwidth argument, starving datagrams.
	# Clients still negotiate four channels for BR; zero permits those channels.
	var error := peer.create_server(_network_port(), _network_capacity())
	if error==OK: error=GameSecureTransport.server(peer)
	if error != OK:
		status_label.text = "Não foi possível abrir a porta %d: %s" % [BASE_PORT, error_string(error)]
		return
	multiplayer.multiplayer_peer = peer
	online = true
	mode = "pvp" if kind == "pvp" else "naval"
	map_kind = _network_map_kind(kind)
	ship_type = str(profile.ship)
	team_choice = int(profile.team)
	if not multiplayer.peer_connected.is_connected(_peer_connected): multiplayer.peer_connected.connect(_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_peer_disconnected): multiplayer.peer_disconnected.connect(_peer_disconnected)
	_enter_match_world()
	if mode == "naval":
		_build_naval_world()
		_build_naval_camera()
	else:
		if not dedicated_pvp:
			_stage_infantry(_spawn_player(1,true,false,find_spawn(1)));open_infantry_deployment()
		else: pvp_match_id = NavalCatalog.uid()
	lobby_panel.visible = true
	status_label.text = "Hospedando na porta UDP %d. Amigos usam seu IP local." % BASE_PORT
	_update_lobby_text()

func _central_pvp() -> bool:
	return not bool(get_meta("test_mode",false))

func _network_map_kind(kind: String) -> String:
	return "desert" if kind=="pvp" else "naval"

func join_game(kind: String) -> void:
	if kind == "naval":
		open_naval()
		return
	if online or (loading_screen and loading_screen.is_visible_in_tree()): return
	_read_profile_ui()
	pvp_connection_generation += 1
	var connection_attempt := pvp_connection_generation
	if loading_screen: ui_focus.open(loading_screen)
	if _central_pvp():
		if main_accounts.token.is_empty(): main_accounts.load_session()
		if main_accounts.token.is_empty():
			ui_focus.close_all()
			pvp_account_pending = true
			open_naval()
			naval_mode.account_connected.connect(_pvp_logged_in,CONNECT_ONE_SHOT)
			return
		status_label.text = "Carregando sua conta..."
		var response := await main_accounts.call_api("profile")
		if connection_attempt!=pvp_connection_generation: return
		if not response.get("ok",false):
			status_label.text = str(response.get("error","Entre novamente."))
			ui_focus.close_all()
			return
		pvp_ticket = main_accounts.ticket
		profile.nickname = str(main_accounts.profile.username)
		nickname_input.text = profile.nickname
		profile.coins = int(main_accounts.profile.coins)
		profile.kills = int(main_accounts.profile.get("kills",0))
		address_input.text = NavalCatalog.SERVER
		pvp_join_nonce = ""
		pvp_join_sent = false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address_input.text.strip_edges(), _network_port(),int(get_meta("transport_channels",0)))
	if error==OK: error=GameSecureTransport.client(peer,address_input.text.strip_edges())
	if error != OK:
		status_label.text = "Não foi possível conectar: " + error_string(error)
		ui_focus.close_all()
		return
	multiplayer.multiplayer_peer = peer
	online = true
	mode = "pvp" if kind == "pvp" else "naval"
	map_kind = _network_map_kind(kind)
	ship_type = str(profile.ship)
	team_choice = int(profile.team)
	if not multiplayer.peer_disconnected.is_connected(_peer_disconnected): multiplayer.peer_disconnected.connect(_peer_disconnected)
	if not multiplayer.server_disconnected.is_connected(_server_disconnected): multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_connection_failed): multiplayer.connection_failed.connect(_connection_failed)
	status_label.text = "Conectando ao anfitrião..."

func _connected_to_server() -> void:
	if not online or mode not in ["pvp","naval"]: return
	GameDiagnostics.record("client_connected",{"peer":multiplayer.get_unique_id(),"mode":mode,"port":_network_port()})
	_enter_match_world()
	if mode == "naval":
		_build_naval_world()
		_build_naval_camera()
	else:
		_stage_infantry(_spawn_player(multiplayer.get_unique_id(),true,false,find_spawn(multiplayer.get_unique_id())))
	lobby_panel.visible = true
	status_label.text = "Conectado ao servidor principal." if _central_pvp() else "Conectado. A sala é uma sessão própria hospedada pelo anfitrião."
	if _central_pvp(): _send_pvp_join()
	else: rpc_id(1, "server_join_request", str(profile.nickname), _appearance_payload())

@rpc("any_peer","call_remote", "reliable")
func server_join_request(nickname: String, appearance: Dictionary, ticket: Dictionary = {}, public_pem := "", proof := PackedByteArray()) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"join",.25,2): return
	if players.has(id): return
	if not get_meta("war_mode",false) and not load("res://scripts/maps/definition.gd").compatible(map_kind,appearance.get("map_content")):
		GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"map_content","mode":mode});return
	var central: Dictionary = {}
	if dedicated_pvp:
		# Map colliders must match on both sides; an old flat-map client must
		# update before entering the new terrain, not fight against other walls.
		if int(appearance.get("map_revision",0))!=DesertMap.REVISION or int(appearance.get("deployment_protocol",0))!=GameLoadouts.PROTOCOL:
			GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"protocol_or_map_revision","mode":mode})
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
			return
		if var_to_bytes(appearance).size()>4096 or var_to_bytes(ticket).size()>18000:
			GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"packet_size","mode":mode});return
		var challenge: Dictionary = pvp_challenges.get(id,{})
		central = NavalAccounts.verify_ticket(ticket,public_pem.sha256_text())
		var key := CryptoKey.new()
		if central.is_empty():GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"invalid_or_expired_ticket","mode":mode});return
		if challenge.is_empty() or Time.get_ticks_msec()>int(challenge.expires):GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"challenge_timeout","mode":mode});return
		if public_pem.length()>6000 or proof.size()>1024 or key.load_from_string(public_pem,true)!=OK:GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"invalid_key","mode":mode});return
		if not Crypto.new().verify(HashingContext.HASH_SHA256,(str(challenge.nonce)+str(ticket.get("payload",""))).sha256_buffer(),proof,key):
			GameDiagnostics.record("admission_rejected",{"peer":id,"reason":"invalid_device_proof","mode":mode});return
		for other: GamePlayer in players.values().duplicate():
			if other.get_meta("account_id","")==central.id:
				# A new signed session can replace an old one even if its final
				# disconnect packet was lost. Never leave a valid login waiting.
				var old_id:=other.peer_id
				if old_id in multiplayer.get_peers(): (multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(old_id)
				_peer_disconnected(old_id)
		pvp_challenges.erase(id)
		nickname = str(central.username)
	var skin :=  str(appearance.get("skin", "#3477bd"))
	if mode == "naval":
		var selected_ship := str(appearance.get("ship", "heavy"))
		var remote_boat := _spawn_remote_ship(id, find_spawn(id), selected_ship)
		remote_boat.name = nickname.left(20)
		remote_boat.set_meta("skin", Color(skin).to_html(false))
		rpc_id(id, "remote_add_player", 1, str(profile.nickname), _appearance_payload(), ship_root.global_position)
		for existing_id in naval_remote_ships:
			if int(existing_id) == id: continue
			var existing_boat: Node3D = naval_remote_ships[existing_id]
			rpc_id(id, "remote_add_player", int(existing_id), existing_boat.name, {"skin":str(existing_boat.get_meta("skin", "#7d8585"))}, existing_boat.global_position)
		_broadcast("remote_add_player",[id, nickname.left(20), appearance, remote_boat.global_position])
		_update_lobby_text()
		return
	var player := _spawn_player(id, false, false, find_spawn(id))
	player.name = nickname.left(20)
	var clean_skin := Color(skin).to_html(false)
	if not get_meta("battle_royale",false) and not player.get_meta("default_shared_uniform",false):player.body_root.get_node("Torso").material_override = player._material(Color(clean_skin))
	player.set_meta("appearance", appearance)
	player.set_meta("coins",int(central.get("coins",0)))
	if dedicated_pvp: player.set_meta("account_id",central.id)
	GameDiagnostics.record("player_admitted",{"peer":id,"mode":mode,"port":_network_port(),"account":str(central.get("id","")).sha256_text().left(16)})
	player.apply_body_proportions({})
	player.apply_body_colors(appearance.get("colors",{}))
	_stage_infantry(player)
	appearance=appearance.duplicate(true);appearance["deployed"]=false
	player.set_meta("appearance",appearance)
	rpc_id(id,"remote_wallet",int(player.get_meta("coins",0)),player.owned)
	sync_inventory(player)
	if is_instance_valid(local_player):
		rpc_id(id, "remote_add_player", 1, str(profile.nickname), _appearance_payload(), local_player.global_position)
		_send_player_baseline(id,local_player)
	for existing_id in players:
		if int(existing_id) == 1 or int(existing_id) == id: continue
		var existing: GamePlayer = players[existing_id]
		var existing_appearance: Dictionary = existing.get_meta("appearance", {"skin":existing.body_root.get_node("Torso").material_override.albedo_color.to_html(false),"proportions":{}})
		existing_appearance=existing_appearance.duplicate(true);existing_appearance["deployed"]=existing.hp>0 and not existing.get_meta("awaiting_deployment",false)
		rpc_id(id, "remote_add_player", int(existing_id), existing.name, existing_appearance, existing.global_position)
		_send_player_baseline(id,existing)
	_broadcast("remote_add_player",[id, nickname.left(20), appearance, player.global_position])
	_broadcast("remote_infantry_staging",[id,player.life_id,0.0])
	# A scoreboard is a room baseline, not one baseline per actor. Repeating
	# the complete board for every bot floods the joining client's UDP queue.
	rpc_id(id,"remote_match_stats",match_stats.snapshot())
	if is_instance_valid(grenades_system): grenades_system.send_smoke_initial(id)

func _send_player_baseline(recipient: int, actor: GamePlayer) -> void:
	if not get_meta("war_mode",false) and actor.get_meta("awaiting_deployment",false):
		rpc_id(recipient,"remote_infantry_staging",actor.peer_id,actor.life_id,maxf(0,float(actor.get_meta("deploy_ready_at",0))-Time.get_ticks_msec()*.001));return
	# A late joiner starts with life 1. Without this reliable baseline it
	# discards every snapshot of a player who has already respawned.
	rpc_id(recipient,"remote_player_respawn",actor.peer_id,actor.global_position,actor.life_id)
	if actor.infantry_protection.enabled:rpc_id(recipient,"remote_protection_state",actor.peer_id,actor.life_id,actor.infantry_protection.snapshot(),"")
	rpc_id(recipient,"remote_equipped",actor.peer_id,actor.weapon_id)
	rpc_id(recipient,"remote_weapon_optics",actor.peer_id,actor.get_meta("weapon_optics",{}),actor.life_id)
	callv("rpc_id",[recipient,"remote_inventory"]+_inventory_packet(actor))
	rpc_id(recipient,"remote_grenade_kind",actor.peer_id,str(actor.get_meta("grenade_kind","grenade")))
	if not get_meta("war_mode",false):
		rpc_id(recipient,"remote_environment_time",environment_seconds)
		# Respawn clears equipment presentation: apply selection afterwards.
		rpc_id(recipient,"remote_grenade_selection",actor.peer_id,actor.grenade_selected and actor.hp>0)
	if actor.get_meta("awaiting_deployment",false): rpc_id(recipient,"remote_infantry_staging",actor.peer_id,actor.life_id,maxf(0,float(actor.get_meta("deploy_ready_at",0))-Time.get_ticks_msec()*.001))
	elif actor.hp<=0.0:
		rpc_id(recipient,"remote_damage",actor.peer_id,{"hp":actor.hp,"limbs":actor.limbs,"region":actor.last_hit_region,"killer":0,"kills":0,"dead":true,"life":actor.life_id,"direction":actor.last_impact_direction,"weapon":actor.last_impact_weapon,"detached":actor.detached_region,"death_sound":actor.death_sound,"velocity":actor.get_meta("death_velocity",Vector3.ZERO)})

@rpc("authority","call_remote", "reliable")
func remote_add_player(id: int, nickname: String, appearance: Dictionary, pos: Vector3) -> void:
	if id == multiplayer.get_unique_id():
		if mode=="pvp" and is_instance_valid(local_player) and not pvp_spawn_confirmed:
			local_player.global_position = pos
			local_player.velocity = Vector3.ZERO
			pvp_spawn_confirmed = true
		return
	var skin := str(appearance.get("skin", "#3477bd"))
	if mode == "naval":
		var remote_boat := _spawn_remote_ship(id, pos, str(appearance.get("ship", "heavy")))
		remote_boat.name = nickname
		remote_boat.set_meta("skin", skin)
		_update_lobby_text()
		return
	var player: GamePlayer = players.get(id)
	if not player: player = _spawn_player(id, false, false, pos)
	player.name = nickname
	if player.body_root and player.body_root.get_node_or_null("Torso") and not get_meta("battle_royale",false) and not player.get_meta("default_shared_uniform",false):
		player.body_root.get_node("Torso").material_override = player._material(Color(skin))
	player.set_meta("appearance", appearance)
	player.apply_body_proportions({})
	player.apply_body_colors(appearance.get("colors",{}))
	if not get_meta("war_mode",false) and appearance.has("deployed") and not bool(appearance.deployed): _stage_infantry(player)
	_update_lobby_text()

func _appearance_payload() -> Dictionary:
	return {"skin":Color(str(profile.skin)).to_html(false), "proportions":{"head":1.,"torso":1.,"arms":1.,"legs":1.},"colors":GameCharacterColors.normalize(profile.get("colors",{})), "ship":str(profile.ship),"map_content":load("res://scripts/maps/definition.gd").identity(map_kind),"map_revision":DesertMap.REVISION,"deployment_protocol":GameLoadouts.PROTOCOL,"loadout":profile.get("loadout",profile.owned).duplicate(),"grenades":bool(profile.get("grenades",true))}

func _peer_connected(id: int) -> void:
	GameDiagnostics.record("peer_connected",{"peer":id,"mode":mode})
	if dedicated_pvp:
		var nonce := NavalCatalog.uid()
		pvp_challenges[id] = {"nonce":nonce,"expires":Time.get_ticks_msec()+15000}
		rpc_id(id,"remote_join_challenge",nonce)
	if mode == "naval": return
	# Joining client creates its own local avatar after connection; the host advertises it on join RPC.
	hud_message("JOGADOR CONECTADO · " + str(id))

func _peer_disconnected(id: int) -> void:
	GameDiagnostics.record("peer_disconnected",{"peer":id,"mode":mode})
	network_guard.forget(id)
	network_diagnostics.forget(id)
	match_stats.remove(id)
	pvp_challenges.erase(id)
	if is_instance_valid(grenades_system): grenades_system.drop_owner(id)
	if online: _broadcast("remote_player_left",[id])
	shot_sequences.erase(id)
	shot_clocks.erase(id)
	state_clocks.erase(id)
	if naval_remote_ships.has(id):
		naval_remote_ships[id].queue_free()
		naval_remote_ships.erase(id)
		naval_hp.erase(id)
	var player: GamePlayer = players.get(id)
	if player:
		players.erase(id)
		_retire_avatar(player)
	if online and multiplayer.is_server():
		for remaining: GamePlayer in players.values():
			remaining.trigger_held=false
			sync_inventory(remaining)
	_update_lobby_text()

func _retire_avatar(actor: Node) -> void:
	if not is_instance_valid(retirement_queue):
		retirement_queue = load("res://scripts/deferred_disposal.gd").new()
		add_child(retirement_queue)
	retirement_queue.retire(actor)

func send_player_state(player: GamePlayer) -> void:
	if multiplayer.multiplayer_peer and player.is_local and not multiplayer.is_server() and (get_meta("war_mode",false) or pvp_spawn_confirmed):
		movement_sequence+=1
		rpc_id(1, "server_player_state", player.global_position, player.yaw, player.pitch, player.weapon_id, player.crouched,0,player.life_id,movement_sequence)

func update_hud() -> void:
	if not local_player: return
	var item: Dictionary = GameWeapons.ITEMS.get(local_player.weapon_id, GameWeapons.ITEMS.ak)
	var ammo_count := str(local_player.ammo.get(local_player.weapon_id, item.mag)) if item.kind == "firearm" else "∞"
	ammo_label.text = "%s\n%s / %s%s" % [item.name.to_upper(), ammo_count, str(local_player.reserves.get(local_player.weapon_id,0)) if item.kind == "firearm" else "∞", " · RECARGA %.1f s" % local_player.reload_left if local_player.reload_left > 0.0 else ""]
	hp_label.text = "VIDA\n%d" % int(local_player.hp)
	health_bar.value = local_player.hp
	var shop_button := hud_layer.find_child("ShopButton",true,false) as Button
	if shop_button: shop_button.text = "ARSENAL · %d 🪙" % int(profile.coins)
	var rows: Array[String] = []
	for id in players:
		var p: GamePlayer = players[id]
		if is_instance_valid(p) and not p.is_npc:
			rows.append("%s  %d / %d" % [str(profile.nickname if p.is_local else p.name).left(15),p.kills,p.deaths])
	if is_instance_valid(domination) and online:
		rows.clear()
		var ranked: Array=players.values().filter(func(actor):return is_instance_valid(actor) and not actor.is_npc)
		ranked.sort_custom(func(a,b):return int(domination.scores.get(a.peer_id,0))>int(domination.scores.get(b.peer_id,0)))
		for actor: GamePlayer in ranked:
			rows.append("%s  %d / %d / %d"%[str(profile.nickname if actor.is_local else actor.name).left(14),int(domination.scores.get(actor.peer_id,0)),actor.kills,actor.deaths])
		rank_label.text="JOGADOR · DOM / ABATES / MORTES\n"+"\n".join(rows)
	else: rank_label.text = "JOGADOR · ABATES / MORTES\n" + "\n".join(rows)
	lobby_panel.visible = online
	if infantry_hud: infantry_hud.refresh()

func hud_message(text: String) -> void:
	if not message_label: return
	message_label.text = text
	var timer := get_tree().create_timer(2.4)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(message_label):
			message_label.text = ""
	)

func damage_feedback(current_hp: float) -> void:
	var lost:=maxf(0,feedback_hp-current_hp)
	if lost>0:
		if is_instance_valid(combat_feedback) and is_instance_valid(local_player): combat_feedback.play("hurt",local_player.camera_pivot.global_position)
		if is_instance_valid(infantry_hud): infantry_hud.pulse_damage(lost,current_hp)
	elif current_hp>=100 and is_instance_valid(infantry_hud): infantry_hud.reset_damage()
	feedback_hp=current_hp
	update_hud()

func play_weapon_sound(id: String, at: Vector3, emitter := 0,elapsed:=0.0) -> void:
	if not is_instance_valid(world_root): return
	if not is_instance_valid(weapon_audio):
		weapon_audio=GameWeaponAudio.new()
		world_root.add_child(weapon_audio)
		# Keep these public references for diagnostics and existing tools.
		sound_pools=weapon_audio.pools
		sound_streams=weapon_audio.streams
	weapon_audio.play(emitter,id,at,elapsed)
	sound_voice_count=weapon_audio.voices.size()

func play_reload_sound(id: String, at: Vector3, actor: Node3D = null,offset: float=0.0) -> AudioStreamPlayer3D:
	if id not in ["sniper","ak","fal","glock","g3"]: return null
	var path := "res://audio/sound_032.wav" if id == "sniper" else ("res://audio/rifle_reload_generated.wav" if id in ["ak","fal","g3"] else "res://audio/glock_reload_generated.wav")
	var stream := load(path) as AudioStream
	if not stream or not world_root or offset>=stream.get_length(): return null
	var player := AudioStreamPlayer3D.new()
	player.bus="Armas"
	player.add_to_group("spatial_sfx")
	player.stream = stream
	player.volume_db = -5.0
	player.max_distance = 35.0
	if is_instance_valid(actor):
		actor.add_child(player)
	else:
		player.position = at
		world_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play(maxf(0,offset))
	return player

func _muzzle_flash(at: Vector3) -> void:
	if is_instance_valid(combat_visuals): combat_visuals.flash(at)

func _expire_visual(reference: WeakRef) -> void:
	var node:=reference.get_ref() as Node
	if is_instance_valid(node): node.queue_free()

func _build_naval_world() -> void:
	naval_remote_ships.clear()
	naval_hp.clear()
	world_root.name = "NavalWorld"
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	water.mesh = plane
	water.position.y = -0.55
	var water_mat := ShaderMaterial.new()
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 ocean_color : source_color = vec4(0.055, 0.25, 0.32, 1.0);
void vertex() {
    VERTEX.y += sin(VERTEX.x * 0.018 + TIME * 1.15) * 0.08;
    VERTEX.y += cos(VERTEX.z * 0.023 + TIME * 0.82) * 0.06;
}
void fragment() {
    float glint = sin(UV.x * 115.0 + TIME * 0.8) * cos(UV.y * 83.0 - TIME * 0.5);
    ALBEDO = ocean_color.rgb + vec3(max(glint, 0.0) * 0.035);
    METALLIC = 0.20;
    ROUGHNESS = 0.24;
}
"""
	water_mat.shader = water_shader
	water.material_override = water_mat
	world_root.add_child(water)
	ship_root = Node3D.new()
	ship_root.name = "PlayerShip"
	ship_root.position = Vector3.ZERO
	ship_root.set_meta("naval_ship_id", multiplayer.get_unique_id() if online else 1)
	ship_root.set_meta("ship_type", ship_type)
	var local_spec: Dictionary = GameWeapons.NAVAL.get(ship_type, GameWeapons.NAVAL.heavy)
	ship_root.set_meta("max_hp", float(local_spec.hp))
	ship_root.set_meta("yaw", 0.0)
	ship_root.set_meta("speed", 0.0)
	ship_root.set_meta("weapon", ship_weapon)
	naval_hp[ship_root.get_meta("naval_ship_id")] = float(local_spec.hp)
	world_root.add_child(ship_root)
	_build_ship_mesh(ship_root, "#596267", float(local_spec.length), float(local_spec.width), ship_type)
	ship_camera = Camera3D.new()
	ship_camera.position = Vector3(0, 9.5, 18.0)
	ship_camera.fov = 58.0
	ship_camera.current = true
	ship_root.add_child(ship_camera)
	var target := Vector3.ZERO
	ship_camera.look_at(target, Vector3.UP)
	if not online:
		var enemy := Node3D.new()
		enemy.name = "TargetShip"
		enemy.position = Vector3(0, 0, -220)
		enemy.set_meta("naval_ship_id", 0)
		enemy.set_meta("hp", 160.0)
		enemy.set_meta("max_hp", 160.0)
		world_root.add_child(enemy)
		_build_ship_mesh(enemy, "#879091", 15.0, 4.6, "combat")
		_add_ship_health_bar(enemy)
	_build_naval_guide()
	lobby_panel.visible = online

func _build_ship_mesh(parent: Node3D, color: String, length: float, width: float, kind := "heavy") -> void:
	var hull_body := StaticBody3D.new()
	hull_body.name = "HullCollider"
	parent.add_child(hull_body)
	var hull_shape := CollisionShape3D.new()
	var hull_box := BoxShape3D.new()
	hull_box.size = Vector3(width, 2.4, length)
	hull_shape.shape = hull_box
	hull_shape.position.y = 0.1
	hull_body.add_child(hull_shape)
	var hull := MeshInstance3D.new()
	if kind == "submarine":
		var submarine_mesh := SphereMesh.new()
		submarine_mesh.radius = 1.0
		submarine_mesh.height = 2.0
		hull.mesh = submarine_mesh
		hull.scale = Vector3(width * 0.5, 0.46, length * 0.5)
		hull.position.y = -0.24
	else:
		var box := BoxMesh.new()
		box.size = Vector3(width, 1.2, length)
		hull.mesh = box
		hull.position.y = -0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.55
	hull.material_override = mat
	parent.add_child(hull)
	var deck := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = Vector3(width * (0.78 if kind == "assault" else 0.68), 0.45 if kind == "assault" else 1.0, length * (0.66 if kind in ["assault", "submarine"] else 0.35))
	deck.mesh = deck_box
	deck.position = Vector3(0, 0.46 if kind == "assault" else 0.76, -1.0)
	deck.material_override = mat
	parent.add_child(deck)
	var aim_pivot := Node3D.new()
	aim_pivot.name = "AimPivot"
	aim_pivot.position = Vector3(0, 1.52, -2.0)
	parent.add_child(aim_pivot)
	var turret := MeshInstance3D.new()
	turret.name = "Turret"
	var gun := CylinderMesh.new()
	gun.top_radius = 0.45
	gun.bottom_radius = 0.55
	gun.height = 0.65
	turret.mesh = gun
	turret.material_override = mat
	aim_pivot.add_child(turret)
	var barrel := MeshInstance3D.new()
	var barrel_box := BoxMesh.new()
	barrel_box.size = Vector3(0.18, 0.18, 2.3)
	barrel.mesh = barrel_box
	barrel.name = "Barrel"
	barrel.position = Vector3(0, 0.13, -1.25)
	barrel.material_override = mat
	aim_pivot.add_child(barrel)
	var bridge := MeshInstance3D.new()
	var bridge_box := BoxMesh.new()
	bridge_box.size = Vector3(width * 0.48, 1.45 if kind == "heavy" else 1.0, length * 0.16)
	bridge.mesh = bridge_box
	bridge.position = Vector3(0, 1.40, length * 0.16)
	bridge.material_override = mat
	parent.add_child(bridge)
	if kind in ["heavy", "assault", "combat"]:
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.045
		mast_mesh.bottom_radius = 0.075
		mast_mesh.height = 2.4
		mast.mesh = mast_mesh
		mast.position = Vector3(0, 3.0, length * 0.16)
		mast.material_override = mat
		parent.add_child(mast)

func _add_ship_health_bar(parent: Node3D) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "HealthBar"
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 0.18)
	bar.mesh = quad
	bar.position = Vector3(0, 4.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#84ed55")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar.material_override = mat
	parent.add_child(bar)
	bar.set_meta("health_bar", true)

func _build_naval_guide() -> void:
	ship_guides.clear()
	for i in range(32):
		var dot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.34, 0.34, 0.34)
		dot.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#ffda81")
		mat.emission_enabled = true
		mat.emission = Color("#ffb847")
		mat.emission_energy_multiplier = 1.0
		dot.material_override = mat
		world_root.add_child(dot)
		ship_guides.append(dot)

func _build_naval_camera() -> void:
	if not ship_camera: return
	ship_camera.current = true

func _update_naval(delta: float) -> void:
	if not ship_root: return
	var controls := gameplay_input_allowed()
	ship_fire_wait = maxf(0.0, ship_fire_wait - delta)
	var was_reloading := ship_reload > 0.0
	ship_reload = maxf(0.0, ship_reload - delta)
	if was_reloading and ship_reload <= 0.0 and not ship_reload_weapon.is_empty():
		ship_ammo[ship_reload_weapon] = GameWeapons.NAVAL_WEAPONS[ship_reload_weapon].ammo
		ship_reload_weapon = ""
	var ship_spec: Dictionary = GameWeapons.NAVAL.get(ship_type, GameWeapons.NAVAL.heavy)
	if controls and Input.is_action_pressed("move_forward"): ship_speed = move_toward(ship_speed, float(ship_spec.speed), 5.0 * delta)
	elif controls and Input.is_action_pressed("move_back"): ship_speed = move_toward(ship_speed, -4.0, 6.0 * delta)
	else: ship_speed = move_toward(ship_speed, 0.0, 1.4 * delta)
	var steer := (float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))) if controls else 0.0
	ship_yaw += steer * float(ship_spec.turn) * delta
	ship_root.rotation.y = ship_yaw
	ship_root.position.y = -0.05 + sin(Time.get_ticks_msec() * 0.0014) * 0.12
	ship_root.set_meta("yaw", ship_yaw)
	ship_root.set_meta("speed", ship_speed)
	ship_root.set_meta("aim_yaw", ship_aim_yaw)
	ship_root.set_meta("aim_pitch", ship_aim_pitch)
	ship_root.set_meta("weapon", ship_weapon)
	ship_root.position += -ship_root.global_transform.basis.z * ship_speed * delta
	_rotate_naval_turret(ship_root, ship_aim_yaw, ship_aim_pitch)
	for peer_id in naval_remote_ships:
		var remote_boat: Node3D = naval_remote_ships[peer_id]
		_rotate_naval_turret(remote_boat, float(remote_boat.get_meta("aim_yaw", 0.0)), float(remote_boat.get_meta("aim_pitch", 0.08)))
	if ship_camera:
		ship_camera.look_at(ship_root.position + _naval_aim_direction() * 80.0, Vector3.UP)
	if controls and naval_trigger_held:
		_fire_naval()
	if ammo_label:
		ammo_label.text = "%s\n%d / %d%s" % [GameWeapons.NAVAL_WEAPONS[ship_weapon].name.to_upper(), int(ship_ammo[ship_weapon]), int(GameWeapons.NAVAL_WEAPONS[ship_weapon].ammo), " · RECARGA %.1f s" % ship_reload if ship_reload > 0.0 else ""]
	if hp_label: hp_label.text = "VIDA DO NAVIO\n%d / %d" % [int(naval_hp.get(multiplayer.get_unique_id() if online else 1, ship_spec.hp)), int(ship_spec.hp)]
	_update_naval_guide()

func _input(event: InputEvent) -> void:
	if is_instance_valid(naval_mode) or is_instance_valid(war_mode): return
	if mode in ["training","desert","pvp"] and is_instance_valid(local_player) and event is InputEventMouseMotion and gameplay_input_allowed():
		local_player.apply_look(event.relative)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(naval_mode) or is_instance_valid(war_mode): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if ui_focus.blocked():
			if ui_focus.stack.back()==loading_screen: show_menu()
			elif ui_focus.stack.back()==deployment_panel and mode!="menu" and (not is_instance_valid(local_player) or local_player.hp<=0): ui_focus.open(pause_panel)
			else: ui_focus.back()
		elif mode != "menu": ui_focus.open(pause_panel)
		get_viewport().set_input_as_handled()
		return
	if ui_focus.blocked() or mode == "menu": return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if is_instance_valid(local_player): local_player.mouse_captured = true
		get_viewport().set_input_as_handled()
		return
	if mode == "naval": _naval_input(event)

func _naval_input(event: InputEvent) -> void:
	if mode != "naval": return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: naval_trigger_held = event.pressed
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := 0.0016 * (0.5 if naval_zoom else 1.0)
		ship_aim_yaw += event.relative.x * sensitivity
		ship_aim_pitch = clampf(ship_aim_pitch - event.relative.y * sensitivity, -0.18, 0.60)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		naval_zoom = not naval_zoom
		if ship_camera: ship_camera.fov = 11.6 if naval_zoom else 58.0
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
		var ship_spec: Dictionary = GameWeapons.NAVAL.get(ship_type, GameWeapons.NAVAL.heavy)
		var weapon_ids: Array = ship_spec.allowed
		var current_index := weapon_ids.find(ship_weapon)
		var step := -1 if event.keycode == KEY_Q else 1
		ship_weapon = weapon_ids[posmod(current_index + step, weapon_ids.size())]
		hud_message(GameWeapons.NAVAL_WEAPONS[ship_weapon].name.to_upper())

func _limit_ship_weapon() -> void:
	if not GameWeapons.NAVAL.has(ship_type): ship_type = "heavy"
	var allowed: Array = GameWeapons.NAVAL[ship_type].allowed
	if ship_weapon not in allowed:
		ship_weapon = str(allowed[0])
	if not ship_ammo.has(ship_weapon):
		for weapon_id in GameWeapons.NAVAL_WEAPONS:
			if not ship_ammo.has(weapon_id): ship_ammo[weapon_id] = int(GameWeapons.NAVAL_WEAPONS[weapon_id].ammo)

func _naval_aim_direction() -> Vector3:
	return _naval_direction_for(ship_root, ship_aim_yaw, ship_aim_pitch)

func _naval_direction_for(boat: Node3D, aim_yaw: float, aim_pitch: float) -> Vector3:
	var local_dir := Vector3(sin(aim_yaw) * cos(aim_pitch), sin(aim_pitch), -cos(aim_yaw) * cos(aim_pitch))
	return (boat.global_transform.basis * local_dir).normalized()

func _rotate_naval_turret(boat: Node3D, aim_yaw: float, aim_pitch: float) -> void:
	var pivot := boat.get_node_or_null("AimPivot") as Node3D
	if pivot:
		pivot.rotation.y = aim_yaw
		pivot.rotation.x = -aim_pitch

func _update_naval_guide() -> void:
	if not ship_root: return
	var item: Dictionary = GameWeapons.NAVAL_WEAPONS.get(ship_weapon, GameWeapons.NAVAL_WEAPONS.lightMG)
	var dir := _naval_aim_direction()
	var mount := _naval_muzzle(ship_root)
	var speed := float(item.speed)
	var gravity := float(item.gravity)
	var step := 0.18
	for i in range(ship_guides.size()):
		var t := float(i + 1) * step
		var inherited_velocity := -ship_root.global_transform.basis.z * ship_speed
		var point := mount + (dir * speed + inherited_velocity) * t + Vector3(0, -0.5 * gravity * t * t, 0)
		ship_guides[i].global_position = point

func _fire_naval() -> void:
	if ship_fire_wait > 0.0 or ship_reload > 0.0: return
	var item: Dictionary = GameWeapons.NAVAL_WEAPONS[ship_weapon]
	if int(ship_ammo[ship_weapon]) <= 0:
		ship_reload = float(item.reload)
		ship_reload_weapon = ship_weapon
		return
	ship_fire_wait = float(item.cadence)
	ship_ammo[ship_weapon] -= 1
	var mount := _naval_muzzle(ship_root)
	var dir := _naval_aim_direction()
	var velocity := dir * float(item.speed) - ship_root.global_transform.basis.z * ship_speed
	if online and not multiplayer.is_server():
		rpc_id(1, "server_naval_fire", ship_weapon)
		_spawn_naval_projectile(mount, velocity, float(item.gravity), ship_weapon, float(item.damage), false, multiplayer.get_unique_id())
	else:
		_accept_naval_fire(multiplayer.get_unique_id() if online else 1, mount, velocity, ship_weapon)
	play_weapon_sound(ship_weapon, mount)

func _naval_muzzle(boat: Node3D) -> Vector3:
	var barrel := boat.get_node_or_null("AimPivot/Barrel") as Node3D
	if not barrel: return boat.global_position + boat.global_transform.basis * Vector3(0, 1.65, -3.25)
	return barrel.to_global(Vector3(0, 0, -1.2))

@rpc("any_peer","call_remote", "reliable")
func server_naval_fire(weapon: String) -> void:
	if not multiplayer.is_server() or mode!="naval" or dedicated_pvp or get_meta("war_mode",false) or not GameWeapons.NAVAL_WEAPONS.has(weapon): return
	var owner_id := multiplayer.get_remote_sender_id()
	var boat: Node3D = naval_remote_ships.get(owner_id)
	if not boat: return
	var kind := str(boat.get_meta("ship_type", "heavy"))
	var allowed: Array = GameWeapons.NAVAL[kind].allowed
	if weapon not in allowed: return
	var aim_yaw := float(boat.get_meta("aim_yaw", 0.0))
	var aim_pitch := float(boat.get_meta("aim_pitch", 0.08))
	_rotate_naval_turret(boat, aim_yaw, aim_pitch)
	var mount := _naval_muzzle(boat)
	var item: Dictionary = GameWeapons.NAVAL_WEAPONS[weapon]
	var velocity := _naval_direction_for(boat, aim_yaw, aim_pitch) * float(item.speed) - boat.global_transform.basis.z * float(boat.get_meta("speed", 0.0))
	_accept_naval_fire(owner_id, mount, velocity, weapon)

func _accept_naval_fire(owner_id: int, pos: Vector3, vel: Vector3, weapon: String) -> void:
	var item: Dictionary = GameWeapons.NAVAL_WEAPONS[weapon]
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(naval_shot_clocks.get(owner_id, -100.0)) < float(item.cadence) * 0.75: return
	naval_shot_clocks[owner_id] = now
	_spawn_naval_projectile(pos, vel, float(item.gravity), weapon, float(item.damage), true, owner_id)
	if online: _broadcast("remote_naval_shot",[owner_id, pos, vel, weapon])

@rpc("authority","call_remote", "unreliable")
func remote_naval_shot(owner_id: int, pos: Vector3, vel: Vector3, weapon: String) -> void:
	if owner_id == multiplayer.get_unique_id(): return
	var item: Dictionary = GameWeapons.NAVAL_WEAPONS.get(weapon, GameWeapons.NAVAL_WEAPONS.lightMG)
	_spawn_naval_projectile(pos, vel, float(item.gravity), weapon, float(item.damage), false, owner_id)
	play_weapon_sound(weapon, pos)

func _spawn_naval_projectile(pos: Vector3, vel: Vector3, gravity: float, weapon: String, damage: float, authoritative := true, owner_id := 1) -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.20 if weapon in ["missile", "torpedo"] else 0.09
	mesh.height = mesh.radius * 2.0
	ball.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameWeapons.NAVAL_WEAPONS[weapon].color
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.2
	ball.material_override = mat
	ball.position = pos
	world_root.add_child(ball)
	projectiles.append({"node":ball,"trace":null,"pos":pos,"vel":vel,"gravity":gravity,"life":25.0,"owner":owner_id,"weapon":weapon,"damage":damage,"server":authoritative,"last":pos,"naval":true})

func gameplay_input_allowed() -> bool:
	if waiting_for_pvp(): return false
	if is_instance_valid(domination) and domination.blocked(): return false
	if online and mode=="pvp" and not multiplayer.is_server() and not pvp_spawn_confirmed and not get_meta("war_mode",false): return false
	if is_instance_valid(naval_mode): return false
	if mode == "menu" or (ui_focus and ui_focus.blocked()) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	var focus := get_viewport().gui_get_focus_owner()
	return not (focus is LineEdit or focus is TextEdit)

func _focus_changed() -> void:
	naval_trigger_held = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	offline_frozen=not online and mode!="menu" and ui_focus.blocked()
	if get_meta("war_mode",false): offline_frozen=offline_frozen and is_instance_valid(local_player) and local_player.hp>0 and bool(local_player.get("deployed"))
	if is_instance_valid(world_root): world_root.process_mode=Node.PROCESS_MODE_DISABLED if offline_frozen else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(local_player):
		local_player.trigger_held = false
		local_player.mouse_captured = false
		local_player.grenade_aiming=false

func _build_modal_ui() -> void:
	ui_focus = GameUIFocus.new()
	add_child(ui_focus)
	ui_focus.changed.connect(_focus_changed)
	ui_focus.shield.theme = GameUI.THEME
	for panel in [appearance_panel,shop_panel]:
		panel.add_theme_stylebox_override("panel",FieldTheme.box())
		var content: Control = panel.get_child(0)
		panel.remove_child(content)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		scroll.add_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aim_settings_panel=GameAimSettingsPanel.new();ui_focus.add_child(aim_settings_panel)
	var shared_settings:=GameSettingsPanel.new();shared_settings.game=self;shared_settings.focus=ui_focus;ui_focus.add_child(shared_settings);settings_panel=shared_settings
	var pause:=GamePauseMenu.new();pause.game=self;pause.focus=ui_focus;pause.settings=shared_settings;ui_focus.add_child(pause);pause_panel=pause
	deployment_panel=GameInfantryDeployment.new();deployment_panel.game=self;ui_focus.add_child(deployment_panel)
	purchase_panel = _modal_card("CONFIRMAR COMPRA")
	var purchase := purchase_panel.find_child("Content",true,false) as VBoxContainer
	purchase_label = Label.new()
	purchase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purchase.add_child(purchase_label)
	var confirm := _add_menu_button(purchase,"CONFIRMAR",func(): _buy_weapon(purchase_target,0))
	confirm.name = "ConfirmPurchase"
	_add_menu_button(purchase,"CANCELAR",func():
		if purchase_pending.is_empty(): ui_focus.close_top()
	)
	_make_hud_passthrough(hud_layer)
	_build_scope()
	loading_screen = GameLoadingScreen.new()
	loading_screen.set_meta("fullscreen",true)
	ui_focus.add_child(loading_screen)
	loading_screen.hide()
	GameUI.button(loading_screen.detail.get_parent(),"CANCELAR",show_menu)


func _make_hud_passthrough(parent: Node) -> void:
	for child in parent.get_children():
		if child == shop_panel: continue
		if child is Control and not child is BaseButton: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_hud_passthrough(child)

func _modal_card(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",FieldTheme.box())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation",16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(_title_label(title))
	ui_focus.add_child(panel)
	panel.hide()
	return panel

func _build_scope() -> void:
	var scope := ColorRect.new()
	scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.z_index = -1
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/scope_reticle.gdshader")
	GameScopeReticle.configure(material,get_viewport().get_visible_rect().size,14.0)
	scope.material = material
	get_viewport().size_changed.connect(_resize_scope_reticle)
	hud_layer.add_child(scope)
	scope_overlay = scope
	scope_overlay.hide()

func _resize_scope_reticle() -> void:
	if not is_instance_valid(scope_overlay) or not scope_overlay.material is ShaderMaterial: return
	var fov:=local_player.camera.fov if is_instance_valid(local_player) else 14.0
	GameScopeReticle.configure(scope_overlay.material,get_viewport().get_visible_rect().size,fov)

func _confirm_purchase(id: String, cost: int) -> void:
	if not purchase_pending.is_empty() or profile.owned.has(id): return
	purchase_target = id
	purchase_label.text = "%s · %d moedas\nSaldo atual: %d" % [GameWeapons.ITEMS[id].name,cost,int(profile.coins)]
	ui_focus.open(purchase_panel)

@rpc("any_peer","call_remote","reliable")
func server_purchase(operation: String, weapon: String) -> void:
	if multiplayer.is_server() and network_guard.allow(multiplayer.get_remote_sender_id(),"purchase",3,3): _server_purchase(multiplayer.get_remote_sender_id(),operation,weapon)

func _server_purchase(id: int, operation: String, weapon: String) -> void:
	var actor: GamePlayer = players.get(id)
	if not is_instance_valid(actor) or operation.length() > 96: return
	var key := str(id) + ":" + operation
	var result: Dictionary
	if purchase_results.has(key): result = purchase_results[key]
	else:
		var costs := {"broom":0,"squeegee":70,"axe":160,"glock":260,"ak":420,"fal":520,"sniper":700}
		var levels := {"broom":0,"squeegee":1,"axe":2,"glock":3,"ak":4,"fal":5,"sniper":6}
		var balance := int(profile.coins) if actor.is_local else int(actor.get_meta("coins",0))
		var accepted := costs.has(weapon) and not actor.owned.has(weapon) and balance >= int(costs.get(weapon,0)) and 1 + actor.kills / 5 >= int(levels.get(weapon,0))
		if accepted:
			balance -= int(costs[weapon])
			actor.owned.append(weapon)
			actor.set_meta("coins",balance)
		result = {"ok":accepted,"coins":balance,"owned":actor.owned.duplicate()}
		purchase_results[key] = result
		if purchase_results.size() > 256: purchase_results.erase(purchase_results.keys()[0])
	if actor.is_local: remote_purchase_result(operation,result)
	elif online: rpc_id(id,"remote_purchase_result",operation,result)

@rpc("authority","call_remote","reliable")
func remote_purchase_result(operation: String, result: Dictionary) -> void:
	if operation != purchase_pending: return
	purchase_pending = ""
	var confirm := purchase_panel.find_child("ConfirmPurchase",true,false) as Button
	if confirm:
		confirm.disabled = false
		confirm.text = "CONFIRMAR"
	profile.coins = int(result.coins)
	profile.owned = result.owned.duplicate()
	if is_instance_valid(local_player): local_player.owned = result.owned.duplicate()
	_save_profile()
	if ui_focus.blocked() and ui_focus.stack.back() == purchase_panel: ui_focus.close_top()
	_refresh_shop()
	update_hud()
	hud_message("COMPRA CONFIRMADA" if result.ok else "COMPRA RECUSADA · VERIFIQUE NÍVEL E SALDO")

@rpc("authority","call_remote","unreliable")
func remote_position_correction(position_value: Vector3) -> void:
	if is_instance_valid(local_player):
		if get_meta("war_mode",false):
			var pacing: Variant=get("frame_pacing")
			if pacing!=null:pacing.correction(local_player.global_position.distance_to(position_value))
		local_player.global_position=position_value;local_player.velocity=Vector3.ZERO
		local_player.previous_position=position_value;local_player._update_camera_collision(0)

func _network_port() -> int:
	return BASE_PORT

func _server_disconnected() -> void:
	if not online: return
	GameDiagnostics.record("server_disconnected",{"mode":mode})
	show_menu()
	status_label.text = "Conexão encerrada pelo servidor. Você pode entrar novamente."

func _connection_failed() -> void:
	GameDiagnostics.record("connection_failed",{"mode":mode,"port":_network_port()})
	show_menu()
	status_label.text = "Servidor indisponível. Verifique a conexão com a rede/VPN e tente novamente."

func _play_death_sound(index: int, at: Vector3) -> void:
	if not is_instance_valid(world_root): return
	GameAudioSettings.ensure()
	var stream := load("res://audio/death_%d.wav" % posmod(index,6)) as AudioStream
	if not stream: return
	var player := AudioStreamPlayer3D.new()
	player.add_to_group("spatial_sfx")
	player.stream = stream
	player.bus = "Efeitos"
	player.position = at + Vector3.UP
	GameCombatAudioCatalog.apply_player_voice_profile(player)
	world_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _network_peer_ready(id: int) -> bool:
	return GameNetworkPeers.connected(multiplayer.multiplayer_peer as ENetMultiplayerPeer,id)!=null

func _broadcast(method: String, arguments: Array) -> void:
	if not online or not multiplayer.is_server(): return
	if method=="remote_player_state":
		arguments=arguments.duplicate()
		arguments.append(network_diagnostics.next_pose_sequence(int(arguments[0]),int(arguments[7])))
	if network_diagnostics.enabled: network_diagnostics.observe_broadcast(method,arguments,multiplayer.get_peers().size())
	GameNetworkBroadcast.send(self,method,arguments)

func _stop_world_audio() -> void:
	if not is_inside_tree(): return
	for scheduler in get_tree().get_nodes_in_group("acoustic_schedulers"):
		if is_ancestor_of(scheduler): scheduler.cancel()
	for player in get_tree().get_nodes_in_group("spatial_sfx"):
		if is_instance_valid(player): player.stop()

func _exit_tree() -> void:
	status_writer.close()
	_stop_world_audio()
	if is_instance_valid(music_player): music_player.stop()

func _profile_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--naval-data="): return NavalStorage.folder().path_join("infantry-profile.cfg")
	var directory := ProjectSettings.globalize_path("user://")
	if directory.is_empty() or directory.begins_with("user:"):
		directory = ProjectSettings.globalize_path("res://user_data")
		DirAccess.make_dir_recursive_absolute(directory)
		return directory.path_join("profile.cfg")
	return "user://profile.cfg"

@rpc("authority","call_remote","reliable")
func remote_wallet(balance: int, owned_weapons: Array) -> void:
	profile.coins = maxi(0,balance)
	profile.owned = owned_weapons.duplicate()
	if is_instance_valid(local_player): local_player.owned = owned_weapons.duplicate()
	if initial_loadout_pending and is_instance_valid(local_player):
		initial_loadout_pending = false
		var preferred := str(profile.get("equipped","ak"))
		if preferred in local_player.active_weapons(): request_equip(local_player,preferred)
	_save_profile()
	update_hud()

@rpc("authority","call_remote","reliable")
func remote_player_left(id: int) -> void:
	_peer_disconnected(id)

func _pvp_logged_in() -> void:
	if not pvp_account_pending: return
	pvp_account_pending = false
	naval_mode._close_mode()
	join_game.call_deferred("pvp")

@rpc("authority","call_remote","reliable")
func remote_join_challenge(nonce: String) -> void:
	pvp_join_nonce = nonce
	_send_pvp_join()

func _send_pvp_join() -> void:
	if pvp_join_sent or pvp_join_nonce.is_empty() or not is_instance_valid(local_player): return
	var key := NavalStorage.client_key()
	var proof := Crypto.new().sign(HashingContext.HASH_SHA256,(pvp_join_nonce+str(pvp_ticket.get("payload",""))).sha256_buffer(),key)
	pvp_join_sent = true
	rpc_id(1,"server_join_request",str(profile.nickname),_appearance_payload(),pvp_ticket,key.save_to_string(true),proof)

func _record_match_death(victim: GamePlayer) -> void:
	if not dedicated_pvp or not online or not multiplayer.is_server() or victim.is_npc or not _central_pvp(): return
	if not is_instance_valid(main_accounts) or not main_accounts.service_auth or pvp_match_id.is_empty(): return
	var account:=str(victim.get_meta("account_id",""))
	if account.length()!=32: return
	var event:=pvp_match_id+":"+str(victim.peer_id)+":"+str(victim.life_id)
	if submitted_deaths.has(event): return
	submitted_deaths[event]=true
	if submitted_deaths.size()>2048: submitted_deaths.erase(submitted_deaths.keys()[0])
	var ids: Array=[account]
	for actor: GamePlayer in players.values():
		var other:=str(actor.get_meta("account_id",""))
		if other.length()==32 and other not in ids and ids.size()<_network_capacity(): ids.append(other)
	_persist_match_death.call_deferred(pvp_match_id,event,account,ids,"war" if bool(get_meta("war_mode",false)) else "infantry")

func _persist_match_death(match_id: String,event: String,account: String,ids: Array,kind: String) -> void:
	# A death and its possible kill reward share the same life event key.
	# The API deduplicates either arrival order, without awarding self-kills.
	for attempt in 3:
		if not is_inside_tree() or not is_instance_valid(main_accounts): return
		var registered:=await main_accounts.call_api("match_register",{"match":match_id,"players":ids,"mode":kind})
		if registered.get("ok",false):
			var result:=await main_accounts.call_api("match_death",{"match":match_id,"event":event,"victim":account})
			if result.get("ok",false): return
		if attempt<2 and is_inside_tree(): await get_tree().create_timer(.5*(attempt+1)).timeout
	push_warning("Não foi possível persistir uma morte online após três tentativas.")

func _pvp_reward(killer: String,victim: String,event: String,peer: int) -> void:
	var ids: Array = []
	for actor: GamePlayer in players.values(): ids.append(str(actor.get_meta("account_id","")))
	var registered := await main_accounts.call_api("match_register",{"match":pvp_match_id,"players":ids,"mode":"infantry"})
	if not registered.get("ok",false): return
	var result := await main_accounts.call_api("reward",{"match":pvp_match_id,"event":pvp_match_id+":"+event,"killer":killer,"victim":victim})
	if not result.get("ok",false): return
	var wallet := await main_accounts.call_api("match_wallet",{"match":pvp_match_id,"account":killer})
	var actor: GamePlayer = players.get(peer)
	if wallet.get("ok",false) and is_instance_valid(actor):
		actor.set_meta("coins",int(wallet.account.coins))
		if peer in multiplayer.get_peers():
			var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
			var remote := GameNetworkPeers.connected(transport,peer)
			if remote and remote.get_state()==ENetPacketPeer.STATE_CONNECTED and remote.get_channels()>0:
				rpc_id(peer,"remote_wallet",int(wallet.account.coins),actor.owned)

func _boot_login() -> void:
	boot_login_pending = true
	open_naval()

func _boot_authenticated() -> void:
	boot_login_pending = false
	_apply_account_profile()
	naval_mode._close_mode()
	var veil := ColorRect.new()
	veil.color = Color("071013")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(veil)
	var fade := create_tween()
	fade.tween_property(veil,"modulate:a",0.0,0.22)
	fade.tween_callback(veil.queue_free)

func _apply_account_profile() -> void:
	if not is_instance_valid(main_accounts) or main_accounts.profile.is_empty(): return
	var loaded := main_accounts.profile
	profile.nickname = str(loaded.username)
	profile.coins = int(loaded.coins)
	profile.kills = int(loaded.get("kills",0))
	profile.deaths = int(loaded.get("deaths",0))
	profile.ship = str(loaded.selected)
	profile.owned_ships = loaded.owned.duplicate()
	var appearance: Dictionary=loaded.get("appearance",{})
	var previous_account: String=str(profile.get("appearance_account",""))
	var changed_account: bool=not previous_account.is_empty() and previous_account!=str(loaded.id)
	if changed_account:
		character_dirty=false
		character_save_serial+=1
		profile.skin="3477bd"
		profile.proportions={"head":1.0,"torso":1.0,"arms":1.0,"legs":1.0}
		profile.colors=GameCharacterColors.DEFAULTS.duplicate()
	profile.appearance_account=str(loaded.id)
	if appearance.has("skin") and appearance.has("proportions") and not character_dirty:
		profile.skin=str(appearance.skin)
		profile.proportions={"head":1.,"torso":1.,"arms":1.,"legs":1.}
		profile.colors=GameCharacterColors.normalize(appearance.get("colors",{}))
	else:
		# First upgrade: migrate the character already saved on this PC once.
		queue_character_save()
	_save_profile()
	nickname_input.text = profile.nickname
	main_menu.refresh()

func _main_logout() -> void:
	if boot_login_pending: return
	boot_login_pending = true
	for control in menu_layer.find_children("*","BaseButton",true,false): control.disabled = true
	status_label.text = "Encerrando sessão..."
	while character_save_busy: await get_tree().process_frame
	if character_dirty: await queue_character_save()
	await main_accounts.logout()
	for control in menu_layer.find_children("*","BaseButton",true,false): control.disabled = false
	status_label.text = ""
	account_summary.text = ""
	_boot_login()

func open_naval_page(id: String) -> void:
	open_naval(id)


func _impact_character(collider: Object) -> GamePlayer:
	var node:=collider as Node
	while is_instance_valid(node) and not node is GamePlayer: node=node.get_parent()
	return node as GamePlayer

func _configure_loadout(actor: GamePlayer,choices: Variant,with_grenades: bool) -> void:
	var clean: Array=[]
	if choices is Array and choices.size()<=6:
		for id in choices:
			if id is String and id in actor.owned and not clean.has(id): clean.append(id)
	if clean.is_empty(): clean=actor.owned.duplicate()
	actor.loadout=clean;actor.grenades_enabled=with_grenades;actor.grenades=2 if with_grenades else 0
	if actor.weapon_id not in clean: actor.weapon_id=clean[0];actor._refresh_weapon()

@rpc("authority","call_remote","reliable")
func remote_equipment(id: int,choices: Array,enabled: bool,count: int) -> void:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor): return
	actor.loadout=choices.duplicate();actor.grenades_enabled=enabled;actor.grenades=clampi(count,0,2)
	update_hud()

@rpc("authority","call_remote","reliable")
func remote_weapon_optics(id: int,selection: Dictionary,life: int) -> void:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or life!=actor.life_id: return
	var clean: Dictionary={}
	for weapon in ["fal","ak","g3","sniper"]:
		var optic:=str(selection.get(weapon,""))
		if not optic.is_empty() and GameOpticCatalog.compatible(optic,weapon):clean[weapon]=optic
	if not get_meta("battle_royale",false):
		var configurations: Dictionary={}
		for weapon in clean:configurations[weapon]=GameAttachmentState.from_legacy(str(weapon),str(clean[weapon]))
		actor.set_meta("weapon_attachments",configurations)
	actor.set_meta("weapon_optics",clean);actor.refresh_weapon_optics()
	if actor.is_local: actor._update_view()

@rpc("authority","call_remote","reliable")
func remote_weapon_attachment_state(id: int,configurations: Dictionary,life: int,generation: int=0) -> void:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or life!=actor.life_id or configurations.size()>8 or var_to_bytes(configurations).size()>12000:return
	if get_meta("battle_royale",false) and generation!=int(get("br_generation")):return
	var clean: Dictionary={};var optics: Dictionary={}
	for weapon in configurations:
		if not weapon is String or not GameWeapons.ITEMS.has(weapon):return
		var checked:=GameAttachmentState.validate(str(weapon),configurations[weapon])
		if not checked.get("ok",false):return
		clean[weapon]=checked.state
		var optic:=GameAttachmentState.legacy_optic(weapon,checked.state)
		if not optic.is_empty():optics[weapon]=optic
	actor.set_meta("weapon_attachments",clean);actor.set_meta("weapon_optics",optics);actor.refresh_weapon_optics()
	if actor.is_local:actor._update_view()

func grenade_allowed(actor: GamePlayer) -> bool:
	return is_instance_valid(actor) and actor.hp>0 and not waiting_for_pvp() and not (is_instance_valid(domination) and domination.blocked())

func request_grenade_kind_choice(actor: GamePlayer,kind: String) -> void:
	# BR has an in-match backpack instead of the loadout picker; use Y.
	if not get_meta("battle_royale",false) or kind not in ["grenade","smoke"] or not is_instance_valid(actor): return
	if actor.hp<=0 or actor.grenades<=0 or not actor.grenades_enabled or not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending: return
	if online and not multiplayer.is_server():
		rpc_id(1,"server_grenade_kind_choice",kind)
		# Local preview is corrected by the authoritative reliable broadcast.
		actor.set_meta("grenade_kind",kind);actor.set_meta("grenade_display_kind",kind)
	else:
		_apply_grenade_kind_choice(actor,kind)

@rpc("any_peer","call_remote","reliable")
func server_grenade_kind_choice(kind: String) -> void:
	if not multiplayer.is_server() or not get_meta("battle_royale",false) or not network_guard.allow(multiplayer.get_remote_sender_id(),"grenade_kind_choice",4,3): return
	var actor:=players.get(multiplayer.get_remote_sender_id()) as GamePlayer
	_apply_grenade_kind_choice(actor,kind)

func _apply_grenade_kind_choice(actor: GamePlayer,kind: String) -> void:
	if kind not in ["grenade","smoke"] or not is_instance_valid(actor) or actor.hp<=0 or actor.grenades<=0 or not actor.grenades_enabled: return
	if not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending: return
	actor.set_meta("grenade_kind",kind);actor.set_meta("grenade_display_kind",kind)
	actor._update_grenade_pose()
	if online: _broadcast("remote_grenade_kind",[actor.peer_id,kind])

func request_grenade(actor: GamePlayer) -> void:
	if not gameplay_input_allowed() or not is_instance_valid(grenades_system) or (actor.grenades<=0 and actor.grenade_held_id.is_empty() and not actor.grenade_prime_pending) or actor.grenade_throw_left>0: return
	if actor.grenade_held_id.is_empty() and not actor.grenade_prime_pending: actor.grenade_sequence+=1
	if online and not multiplayer.is_server(): rpc_id(1,"server_grenade_request",actor.life_id,actor.grenade_sequence,actor.camera_pivot.global_position,-actor.camera.global_basis.z.normalized())
	else: grenades_system.accept(actor,actor.life_id,actor.grenade_sequence,actor.camera_pivot.global_position,-actor.camera.global_basis.z.normalized())

@rpc("any_peer","call_remote","reliable")
func server_grenade_request(life: int,sequence: int,origin: Vector3,direction: Vector3) -> void:
	if not multiplayer.is_server() or not is_instance_valid(grenades_system): return
	if not network_guard.allow(multiplayer.get_remote_sender_id(),"grenade_throw",4,3): return
	var actor:=players.get(multiplayer.get_remote_sender_id()) as GamePlayer
	if is_instance_valid(actor):
		grenades_system.accept(actor,life,sequence,origin,direction)
		sync_inventory(actor)

@rpc("authority","call_remote","reliable")
func remote_grenade_spawn(packet: Dictionary) -> void:
	if is_instance_valid(grenades_system): grenades_system.spawn(packet)

@rpc("authority","call_remote","unreliable_ordered")
func remote_grenade_states(states: Array) -> void:
	if is_instance_valid(grenades_system): grenades_system.receive_snapshots(states)

@rpc("authority","call_remote","reliable")
func remote_grenade_explosion(id: String,point: Vector3,kind: String="grenade") -> void:
	if is_instance_valid(grenades_system): grenades_system.present_explosion(id,point,kind)

@rpc("authority","call_remote","reliable")
func remote_grenade_smoke(id: String,point: Vector3,elapsed: float) -> void:
	if is_instance_valid(grenades_system): grenades_system.receive_smoke_initial(id,point,elapsed)

@rpc("authority","call_remote","reliable")
func remote_grenade_kind(id: int,kind: String) -> void:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or kind not in ["grenade","smoke"]: return
	actor.set_meta("grenade_kind",kind)
	actor.set_meta("grenade_display_kind",kind)
	if actor.is_local: actor._update_grenade_pose()

@rpc("authority","call_remote","reliable")
func remote_earth_impact(_id: String,point: Vector3) -> void:
	if is_instance_valid(combat_feedback): combat_feedback.play("earth",point)

func _damage_confirmed(owner_id: int,point: Vector3,amount: float,critical: bool) -> void:
	if amount<=0: return
	operation_sequence+=1
	var event_id:="damage:%d:%d"%[match_generation,operation_sequence]
	if online and owner_id!=multiplayer.get_unique_id():
		if owner_id in multiplayer.get_peers(): rpc_id(owner_id,"remote_damage_number",event_id,point,amount,critical)
	elif is_instance_valid(local_player) and local_player.peer_id==owner_id: remote_damage_number(event_id,point,amount,critical)

@rpc("authority","call_remote","reliable")
func remote_damage_number(id: String,point: Vector3,amount: float,critical: bool) -> void:
	if is_instance_valid(damage_numbers): damage_numbers.show_damage(id,point,amount,critical)

func waiting_for_pvp() -> bool:
	return online and mode=="pvp" and not get_meta("war_mode",false) and players.size()<2

@rpc("authority","call_remote","reliable")
func remote_environment_time(seconds: float) -> void:
	if not online or mode!="pvp" or not is_finite(seconds) or seconds<0: return
	environment_seconds=seconds
	environment_received=true
	if is_instance_valid(day_night): day_night.apply_time(environment_seconds,true)

func prime_grenade(actor: GamePlayer) -> void:
	if not gameplay_input_allowed() or not is_instance_valid(grenades_system) or actor.grenades<=0 or not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending: return
	actor.grenade_sequence+=1;actor.grenade_prime_pending=true;actor.grenade_aiming=true;actor.grenade_fuse_left=GameGrenades.fuse_for(actor);actor.clear_weapon_aim()
	if online and not multiplayer.is_server(): rpc_id(1,"server_prime_grenade",actor.life_id,actor.grenade_sequence)
	elif not grenades_system.prime(actor,actor.life_id,actor.grenade_sequence): remote_grenade_rejected(actor.grenade_sequence)

@rpc("any_peer","call_remote","reliable")
func server_prime_grenade(life: int,sequence: int) -> void:
	if not multiplayer.is_server() or not is_instance_valid(grenades_system): return
	if not network_guard.allow(multiplayer.get_remote_sender_id(),"grenade_prime",4,3): return
	var actor:=players.get(multiplayer.get_remote_sender_id()) as GamePlayer
	if is_instance_valid(actor) and not grenades_system.prime(actor,life,sequence):
		rpc_id(actor.peer_id,"remote_grenade_rejected",sequence);sync_inventory(actor)

@rpc("authority","call_remote","reliable")
func remote_grenade_rejected(sequence: int) -> void:
	if is_instance_valid(local_player) and local_player.grenade_sequence==sequence and local_player.grenade_held_id.is_empty():
		local_player.grenade_prime_pending=false;local_player.grenade_aiming=false;local_player.grenade_fuse_left=0

func request_grenade_selection(actor: GamePlayer,enabled: bool) -> void:
	if online and not multiplayer.is_server(): rpc_id(1,"server_grenade_selection",enabled)
	else:
		actor.grenade_selected=enabled
		if enabled: actor.pause_reload()
		if online: _broadcast("remote_grenade_selection",[actor.peer_id,enabled])
		if not enabled: _resume_reload(actor)

@rpc("any_peer","call_remote","reliable")
func server_grenade_selection(enabled: bool) -> void:
	if not multiplayer.is_server(): return
	if not network_guard.allow(multiplayer.get_remote_sender_id(),"grenade_selection",8,6): return
	var actor:=players.get(multiplayer.get_remote_sender_id()) as GamePlayer
	if not is_instance_valid(actor) or actor.hp<=0: return
	if not actor.grenade_held_id.is_empty(): return
	actor.grenade_selected=enabled and actor.grenades_enabled and actor.grenades>0
	if actor.grenade_selected: actor.pause_reload()
	actor.clear_weapon_aim()
	_broadcast("remote_grenade_selection",[actor.peer_id,actor.grenade_selected])
	if not _resume_reload(actor): sync_inventory(actor)

@rpc("authority","call_remote","reliable")
func remote_grenade_selection(id: int,enabled: bool) -> void:
	var actor:=players.get(id) as GamePlayer
	if is_instance_valid(actor):
		actor.grenade_selected=enabled
		if not enabled and actor.grenade_held_id.is_empty() and not actor.grenade_prime_pending: actor.grenade_aiming=false
		if enabled: actor.pause_reload()
		actor._update_grenade_pose()

func request_supplies(actor: GamePlayer) -> void:
	if not gameplay_input_allowed() or not is_instance_valid(domination): return
	if online and not multiplayer.is_server(): rpc_id(1,"server_supply_request",actor.life_id)
	else: hud_message(domination.replenish(actor,actor.life_id))

@rpc("any_peer","call_remote","reliable")
func server_supply_request(life: int) -> void:
	if not multiplayer.is_server() or not is_instance_valid(domination): return
	if not network_guard.allow(multiplayer.get_remote_sender_id(),"supply",2,2): return
	var actor:=players.get(multiplayer.get_remote_sender_id()) as GamePlayer
	var response:=domination.replenish(actor,life)
	if is_instance_valid(actor) and not response.is_empty(): rpc_id(actor.peer_id,"remote_supply_feedback",response)

@rpc("authority","call_remote","reliable")
func remote_supply_feedback(message: String) -> void:
	hud_message(message)

@rpc("authority","call_remote","reliable")
func remote_domination_state(state: Dictionary) -> void:
	if is_instance_valid(domination): domination.receive(state)

func aim_settings_context() -> String:
	if is_instance_valid(local_player): return "weapon:"+("grenade" if local_player.grenade_selected else GameWeapons.canonical(local_player.weapon_id))
	return "weapon:ak"


func open_infantry_deployment() -> void:
	if is_instance_valid(deployment_panel): deployment_panel.present(mode if mode!="menu" else "training")

func infantry_deployment_wait() -> float:
	return maxf(0,deployment_wait_until-Time.get_ticks_msec()*.001)

func _stage_infantry(actor: GamePlayer) -> void:
	actor.set_meta("awaiting_deployment",true);actor.hp=0;actor.respawn_left=0;actor.trigger_held=false;actor.velocity=Vector3.ZERO
	actor.loadout=[];actor.ammo.clear();actor.reserves.clear();actor.grenades_enabled=false;actor.grenades=0;actor.remove_meta("quick_slots")
	actor.cancel_reload();actor.cancel_melee();actor.clear_aim();actor._set_hitboxes_enabled(false)
	actor.body_collision.set_deferred("disabled",true);actor.body_root.hide();actor.weapon_root.hide();actor._hide_dead_presentations()

func _remote_spawn_ready(actor: GamePlayer) -> void:
	if get_meta("war_mode",false) or not is_instance_valid(actor) or actor.hp>0: return
	_stage_infantry(actor)
	if online: _broadcast("remote_infantry_staging",[actor.peer_id,actor.life_id,0.0])
	elif actor.is_local:
		deployment_wait_until=float(actor.get_meta("deploy_ready_at",0));open_infantry_deployment()

func defer_respawn_selection(actor: GamePlayer) -> bool:
	if get_meta("war_mode",false) or actor.is_npc or not actor.is_local: return false
	_remote_spawn_ready(actor);return true

func confirm_infantry_deployment(slots: Dictionary,spawn_zone: String,kind: String) -> void:
	if mode=="menu": _begin_offline(kind,slots,spawn_zone);return
	if online and not multiplayer.is_server(): rpc_id(1,"server_infantry_deploy",slots,spawn_zone,local_player.life_id)
	else: _accept_infantry_deploy(local_player.peer_id,slots,spawn_zone,local_player.life_id)

@rpc("any_peer","call_remote","reliable")
func server_infantry_deploy(slots: Dictionary,spawn_zone: String,life: int) -> void:
	if multiplayer.is_server() and not get_meta("war_mode",false) and network_guard.allow(multiplayer.get_remote_sender_id(),"deploy",4,3) and var_to_bytes(slots).size()<=4096: _accept_infantry_deploy(multiplayer.get_remote_sender_id(),slots,spawn_zone,life)

func _accept_infantry_deploy(id: int,slots: Dictionary,spawn_zone: String,life: int) -> bool:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or actor.life_id!=life or actor.hp>0 or get_meta("war_mode",false): return false
	if Time.get_ticks_msec()*.001<float(actor.get_meta("deploy_ready_at",0)): _spawn_notice(id,"Aguarde para reaparecer.");return false
	if spawn_zone not in ["auto","west","east"] or (map_kind=="office" and spawn_zone!="auto"): _spawn_notice(id,"Ponto indisponível.");return false
	var approved:=GameLoadouts.validate(slots,"desert" if online else "offline_"+mode,actor.owned)
	if not approved.ok: _spawn_notice(id,str(approved.error));return false
	GameLoadouts.apply(actor,approved);actor.set_meta("spawn_zone",spawn_zone)
	if online: _broadcast("remote_grenade_kind",[id,str(actor.get_meta("grenade_kind","grenade"))])
	_reset_server_player(actor);actor._refresh_weapon();actor._update_view()
	_broadcast("remote_weapon_optics",[id,actor.get_meta("weapon_optics",{}),actor.life_id])
	_broadcast("remote_equipped",[id,actor.weapon_id])
	if online and id in multiplayer.get_peers(): rpc_id(id,"remote_infantry_spawn_result",true,actor.life_id,"")
	elif actor.is_local: remote_infantry_spawn_result(true,actor.life_id,"")
	return true

func _spawn_notice(id: int,text: String) -> void:
	if online and id in multiplayer.get_peers(): rpc_id(id,"remote_infantry_spawn_result",false,players[id].life_id,text)
	elif is_instance_valid(local_player) and id==local_player.peer_id: remote_infantry_spawn_result(false,local_player.life_id,text)

@rpc("authority","call_remote","reliable")
func remote_infantry_staging(id: int,life: int,seconds: float) -> void:
	var actor:=players.get(id) as GamePlayer
	if not is_instance_valid(actor) or life<actor.life_id or get_meta("war_mode",false): return
	actor.life_id=life
	_stage_infantry(actor)
	if actor.is_local:
		pvp_spawn_confirmed=false;deployment_wait_until=Time.get_ticks_msec()*.001+maxf(0,seconds)
		open_infantry_deployment()

@rpc("authority","call_remote","reliable")
func remote_infantry_spawn_result(ok: bool,life: int,message: String) -> void:
	if not is_instance_valid(local_player) or local_player.life_id!=life: return
	deployment_panel.pending=false
	if not ok: deployment_panel.notice(message);return
	local_player.set_meta("awaiting_deployment",false);pvp_spawn_confirmed=true;deployment_wait_until=0
	if is_instance_valid(death_view): death_view.stop()
	ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;local_player.mouse_captured=true;local_player.camera.make_current();update_hud()

func multi_kill_count(owner: int) -> int:
	return int(match_stats.rows.get(owner,{}).get("kills",0)) if match_stats else 0

func notify_multi_kill(owner: int,before: int,event: String) -> void:
	var count:=multi_kill_count(owner)-before
	if count<2 or multi_kill_events.has(event): return
	multi_kill_events[event]=true
	if multi_kill_events.size()>256: multi_kill_events.erase(multi_kill_events.keys()[0])
	var message:="%s · %d"%["DUPLA ELIMINAÇÃO" if count==2 else ("TRIPLA ELIMINAÇÃO" if count==3 else "MÚLTIPLAS ELIMINAÇÕES"),count]
	if has_method("_combat_notice"): call("_combat_notice",owner,message)
	elif is_instance_valid(local_player) and local_player.peer_id==owner: remote_multi_kill(message)
	elif owner in multiplayer.get_peers(): rpc_id(owner,"remote_multi_kill",message)

@rpc("authority","call_remote","reliable")
func remote_multi_kill(message: String) -> void: hud_message(message)
