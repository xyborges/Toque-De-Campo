extends SceneTree
const FIXTURE=preload("res://tests/br_completion_fixture.gd")
var checks:=0
var failures: Array[String]=[]
var game: BattleRoyaleGame
var actor: BRPlayer
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func run() -> void:
	Engine.max_fps=60;game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	game.flat_world();game.match_started=true;game.phase="active";game.br_generation=1
	actor=game._spawn_player(1,true,false,Vector3(0,.1,0));game.br_inventory.add_player(1)
	game.br_round.begin([1,2,3],game._now());game.br_zone.configure(42,[Vector3.ZERO]);game.br_zone.begin(game._now())
	game.footsteps=WarSoundscape.new();game.footsteps.game=game;game.footsteps.footsteps_only=true;game.world_root.add_child(game.footsteps)
	game.br_inventory.add_loot({"kind":"weapon","weapon":"ak","magazine":30,"position":Vector3(.5,.05,0)})
	game._br_action(1,"ground_use",{"id":game.br_inventory.next_loot_id-1},actor.life_id,1)
	# Do not depend on test inventory ids to select the locomotion model.
	actor.loadout=["ak"];actor.owned=["fists","ak"];actor.weapon_id="ak";actor._refresh_weapon();actor._update_view()
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await create_timer(.3).timeout
	get_root().gui_release_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(game.gameplay_input_allowed(),"real controller is not blocked by a hidden menu focus")
	key(KEY_CTRL,true);await physics_frame;key(KEY_CTRL,false);await create_timer(.2).timeout
	check(actor.crouched,"one Ctrl tap remains crouched after release")
	key(KEY_CTRL,true);await physics_frame;key(KEY_CTRL,false);await create_timer(.2).timeout
	check(not actor.crouched and not actor.prone,"second Ctrl tap stands")
	var capture:=AudioEffectCapture.new();var bus:=AudioServer.get_bus_index("Passos")
	if DisplayServer.get_name()!="headless":AudioServer.add_bus_effect(bus,capture)
	var before:=actor.global_position;var step_before:=actor.locomotion.step_sequence
	var peak:=0.;var sway:=0.;var rms:=0.
	Input.action_press("move_forward");key(KEY_SHIFT,true)
	var until:=Time.get_ticks_msec()+2400
	while Time.get_ticks_msec()<until:
		await physics_frame
		peak=maxf(peak,actor.locomotion.sprint);sway=maxf(sway,actor.view_root.position.distance_to(actor._weapon_offset()))
		if capture.get_frames_available()>0:
			for sample in capture.get_buffer(capture.get_frames_available()):rms=maxf(rms,sample.length())
	Input.action_release("move_forward");key(KEY_SHIFT,false)
	check(actor.global_position.distance_to(before)>8. and peak>.8 and sway>.07,"BR uses shared sprint distance and weapon sway")
	check(actor.locomotion.step_sequence-step_before>=3,"real floor movement emits foot contacts")
	if DisplayServer.get_name()!="headless":
		check(game.footsteps.footstep_count>=3 and rms>.0001,"step samples reach the actual Passos audio bus")
		AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	actor.hp=40.;game.br_inventory.members[1].medkits=2
	game.br_hud.refresh(game._state_for(1),game.br_inventory.snapshot(1),[])
	game.ui_focus.open(game.br_hud.inventory_panel)
	game.request_br_heal();game.br_hud._close_inventory()
	var heal_position:=actor.global_position;Input.action_press("move_forward")
	var heal_until:=Time.get_ticks_msec()+3800
	while Time.get_ticks_msec()<heal_until:
		await physics_frame;game._step_br_authority(1./60.)
	Input.action_release("move_forward")
	var held_position:=actor.global_position
	var completion_until:=Time.get_ticks_msec()+600
	while Time.get_ticks_msec()<completion_until:
		await physics_frame;game._step_br_authority(1./60.)
	check(not game.ui_focus.blocked() and not game.br_hud.inventory_panel.visible,"backpack stays closed while using medkit")
	check(held_position.distance_to(heal_position)<.2,"application holds position without requiring Tab")
	check(actor.hp>40. and actor.hp<50. and game.heal_restore.has(1),"closed-backpack application completes and begins gradual healing")
	var report:={"checks":checks,"failures":failures,"ok":failures.is_empty(),"sprint":peak,"weapon_offset":sway,"footsteps":game.footsteps.footstep_count,"audio_peak":rms,"scope":"Real BR local controller, collision floor, keyboard taps, sprint, weapon presentation and backpack close during timed medkit. Graphical run captures the Passos bus; no microphone recording or performance claim."}
	NavalStorage.write_json("res://work/revision-1102-controls-audio.json",report);print("BR_CONTROLS_AUDIO ",JSON.stringify(report))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
