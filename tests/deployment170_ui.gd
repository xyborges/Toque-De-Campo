extends SceneTree
var game: Node3D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func frames(count:=3) -> void:
	for tick in count: await process_frame
func capture(label: String) -> void:
	await create_timer(.35).timeout;await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/deployment170-"+label+".png")
func button(parent: Node,text: String) -> Button:
	for candidate: Button in parent.find_children("*","Button",true,false):
		if candidate.text==text: return candidate
	return null
func run() -> void:
	game=load("res://scripts/main.gd").new();game.set_meta("test_mode",true);root.add_child(game);await frames()
	game.start_offline("training");await frames()
	check(game.mode=="menu" and game.world_root==null and game.players.is_empty(),"offline selection opens deployment before creating a player or map")
	var panel:=game.deployment_panel as GameInfantryDeployment
	check(panel.visible and game.ui_focus.blocked() and panel.editor.slots.has("primary"),"initial deployment shows restored loadout")
	await capture("offline-loadout")
	panel.editor.slots={"primary":"sniper"};panel.editor._rebuild();panel.editor._changed();panel.confirm.pressed.emit();await frames()
	var actor:=game.local_player as GamePlayer
	for npc in game.npcs:
		if is_instance_valid(npc): npc.set_physics_process(false)
	check(game.mode=="training" and actor.hp==100 and actor.weapon_id=="sniper","confirm deploy creates the player with the selected primary")
	check(actor.active_weapons()==["sniper"] and actor.ammo.keys()==["sniper"] and actor.reserves.keys()==["sniper"],"disabled weapons do not exist in this life's ammunition or loadout")
	check(not actor.grenades_enabled and actor.grenades==0 and GameInventorySlots.resolve(actor)=={2:"sniper"},"disabled grenade has no inventory or reserved quick slot")
	game.infantry_hud.refresh();check(not game.infantry_hud.slot_views[1].button.visible and not game.infantry_hud.slot_views[3].button.visible and not game.infantry_hud.slot_views[4].button.visible,"HUD omits disabled slots instead of drawing placeholders")
	game.open_infantry_deployment();await frames();panel.editor.slots={"sidearm":"glock"};panel.editor._rebuild();panel.editor._changed();panel.confirm.pressed.emit();await frames()
	check(actor.weapon_id=="sniper" and actor.active_weapons()==["sniper"],"editing next-life loadout cannot replace a living player's weapon")
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	actor.take_damage(1000,"chest",0);await create_timer(2.3).timeout
	check(actor.hp==0 and panel.visible and game.offline_frozen,"offline death returns to deployment and pauses the simulation")
	check(panel.editor.slots=={"sidearm":"glock"},"next deployment restores the saved selection")
	panel.confirm.pressed.emit();await frames()
	check(actor.hp==100 and actor.weapon_id=="glock" and actor.active_weapons()==["glock"] and not game.offline_frozen,"respawn grants only the new life's approved gear and resumes")
	var camera_id:=actor.camera.get_instance_id();var actor_id:=actor.get_instance_id()
	game.ui_focus.open(game.pause_panel);await frames()
	check(game.offline_frozen and actor.get_instance_id()==actor_id,"offline pause freezes the world without rebuilding player")
	game.settings_panel.present();await frames()
	var settings:=game.settings_panel as GameSettingsPanel
	check(settings.tabs.get_tab_count()==5 and settings.visible,"in-game settings expose five functional categories")
	await capture("settings")
	var count:=AudioServer.bus_count;GameAudioSettings.ensure();check(AudioServer.bus_count==count,"opening common settings does not duplicate audio buses")
	var music_gain:=GameAudioSettings.get_volume("Music");GameAudioSettings.flush();GameAudioSettings.loaded_path="";GameAudioSettings.ensure()
	check(absf(music_gain-GameAudioSettings.get_volume("Music"))<.001 and absf(linear_to_db(music_gain)-(-11.))<.05,"previous menu music loudness survives migration and a second settings load")
	var original_size:=DisplayServer.window_get_size();settings.window_mode.select(0);settings.resolution.select(0);settings._apply_video()
	check(settings.video_pending and settings.video_left==10 and settings.confirmation.visible,"display change requires a ten-second confirmation")
	settings.video_left=.01;await frames(5)
	check(not settings.video_pending and DisplayServer.window_get_size()==original_size,"unconfirmed video change automatically restores the real window")
	settings.window_mode.select(1);settings._apply_video();await frames(3)
	check(settings.video_pending and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"full-screen preview uses the actual desktop mode")
	settings._revert_video();await frames(3)
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size()==original_size,"rejecting full-screen restores window mode, position and size")
	settings.window_mode.select(0);settings.resolution.select(1);settings._apply_video();settings._confirm_video()
	check(not settings.video_pending and GameOptions.values.has("window_size"),"accepted display settings are persisted")
	for preset in GameOptions.PRESETS:
		for field in GameOptions.PRESETS[preset]: GameOptions.set_value(field,GameOptions.PRESETS[preset][field])
		settings._apply();await frames(2)
		check(root.msaa_3d==int(GameOptions.PRESETS[preset].aa) and is_equal_approx(root.scaling_3d_scale,float(GameOptions.PRESETS[preset].scale)),"quality preset changes the actual render viewport: "+str(preset))
	check(not GameOptions.bind("move_forward",KEY_S).is_empty() and not GameOptions.bind("move_forward",KEY_R).is_empty(),"remapping rejects existing movement and combat bindings")
	check(GameOptions.bind("move_forward",KEY_Z).is_empty() and GameOptions.key_name("move_forward")=="Z","movement remap updates the actual InputMap and persists")
	game.ui_focus.close_top();game.pause_panel.resume();await frames()
	check(not game.ui_focus.blocked() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and actor.camera.get_instance_id()==camera_id,"continue restores focus without recreating camera")
	game.ui_focus.open(game.pause_panel);button(game.pause_panel,"PLACAR").pressed.emit();await frames()
	check(game.scoreboard.visible and game.ui_focus.stack.back()==game.scoreboard,"pause opens the existing reusable scoreboard")
	game.ui_focus.close_top();button(game.pause_panel,"SAIR DA PARTIDA").pressed.emit();await frames()
	check(game.pause_panel.leave_confirmation.visible and game.mode=="training","leaving asks for confirmation without disposing the match")
	button(game.pause_panel.leave_confirmation,"CANCELAR").pressed.emit();check(game.mode=="training" and actor.hp==100,"cancel exit preserves the current life")
	button(game.pause_panel,"SAIR DA PARTIDA").pressed.emit();button(game.pause_panel.leave_confirmation,"SAIR").pressed.emit();await frames()
	check(game.mode=="menu" and game.players.is_empty() and game.world_root==null and not game.ui_focus.blocked(),"confirmed exit clears match state and all modal focus")
	var result:={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/deployment170-ui-results.json",result);print(JSON.stringify(result))
	game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
