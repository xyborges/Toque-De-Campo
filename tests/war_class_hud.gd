extends SceneTree
var game: WarGame
var human: WarPlayer
var hud: GameInfantryHUD
var checks:=0
var failures: Array[String]=[]
var captures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func member(id: int,local_player:=false) -> WarPlayer:
	var actor:=game._spawn_player(id,local_player,false,game.find_spawn(id)) as WarPlayer
	actor.set_physics_process(false)
	game.members[id]={"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	return actor
func refresh() -> void:
	game.war_ui._refresh_equipment(hud);hud.refresh()
func deploy(role: String,team:=0) -> void:
	human.hp=0;human.deployed=false;game.members[1].deployed=false;game.members[1].ready_at=0.
	game.war_clock+=10
	check(game._deploy(1,team,role,"sniper" if role=="marksman" else "fal",WarRules.launcher_for_team(team),"base"),"class deployment accepted: "+role)
	human.yaw=0;human.rotation.y=0;human.pitch=0;human.camera_pivot.rotation=Vector3.ZERO;human._update_weapon_pose()
	refresh()
func shot(label_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	var path:="res://work/war-class-hud-"+label_text+".png"
	root.get_texture().get_image().save_png(path);captures.append(path)
func bounds(label_text: String) -> void:
	var rectangle: Rect2=hud.ammo.get_parent().get_parent().get_global_rect()
	var viewport:=root.get_visible_rect().size
	check(rectangle.position.x>=0 and rectangle.position.y>=0 and rectangle.end.x<=viewport.x and rectangle.end.y<=viewport.y,"compact equipment stays inside viewport: "+label_text)
	check(hud.ammo.get_minimum_size().x<=hud.ammo.size.x+.1 and hud.equipment_state.get_minimum_size().x<=hud.equipment_state.size.x+.1,"equipped name/counter and resource line do not overflow: "+label_text)
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/war_hud_fixture.gd").new();game.offline_operation=true
	game.set_meta("war_test",true);game.set_meta("war_visual_preview",true);game.set_meta("test_mode",true);root.add_child(game)
	game.online=false;game.mode="pvp";game.map_kind="desert";game._enter_match_world()
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false);game.vehicle_system.set_process(false);game.war_fx.set_physics_process(false)
	human=member(1,true);var opponent:=member(2)
	check(game._deploy(2,1,"soldier","fal","rpg","base"),"opposing team supplies the existing battle eligibility")
	hud=game.infantry_hud;game.join_ready=true;game.war_clock=100
	game.ui_focus.close_all();game.war_ui.deployment.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	deploy("soldier")
	check(hud.equipment_title.text.begins_with("H · REABASTECER") and hud.equipment_state.text=="×3 CARGAS · PRONTO","soldier H resupply uses its three real class charges")
	check(hud.grenade_text.visible and hud.slot_views[3].amount.text=="×2","soldier grenades keep their separate real stock and existing slot")
	human.reserves.fal=0;game.vehicle_system.resupply(1);refresh()
	check(game.members[1].charges==2 and hud.equipment_state.text.contains("×2") and hud.equipment_state.text.contains("6,0 s"),"resupply consumption and six-second authoritative cooldown reach the HUD")
	game.war_clock+=6;refresh();check(hud.equipment_state.text.ends_with("PRONTO"),"cooldown expires using the operation clock")
	deploy("medic")
	check(hud.equipment_title.text.begins_with("G · KIT MÉDICO") and hud.equipment_state.text.begins_with("×4") and not hud.grenade_text.visible,"medic G kit replaces the soldier hint without inventing grenades")
	var ally:=member(3);game.members[3].team=0;game.members[3].deployed=true;ally.apply_identity(0,"soldier");ally.deployed=true;ally.hp=30;ally.position=Vector3(2,0,0)
	game.vehicle_system.use_gadget(1);refresh()
	check(game.members[1].charges==3 and hud.equipment_state.text.contains("1,0 s"),"successful real medical use consumes a charge and shows its actual one-second interval")
	deploy("marksman")
	check(hud.equipment_title.text=="G · OBSERVAÇÃO" and hud.equipment_state.text.begins_with("×4") and hud.ammo.text.begins_with("SNIPER"),"marksman observation and sniper inventory are represented separately")
	opponent.position=Vector3(0,0,-12);opponent._set_hitboxes_enabled(true)
	await physics_frame;await physics_frame;game.vehicle_system.use_gadget(1);refresh()
	check(game.members[1].charges==3 and hud.equipment_state.text.begins_with("×3"),"successful observation decrements the real class resource")
	deploy("antitank",1)
	human.ammo.fal=7;human.reserves.fal=73;human.set_gadget(true,"rpg");refresh()
	check(hud.ammo.text=="RPG-7\n×3 DISPONÍVEIS" and not hud.low_ammo.visible,"held RPG shows actual launcher charges rather than the preserved FAL magazine")
	check(hud.equipment_actions.visible and hud.equipment_buttons.rpg.get_meta("equipment_selected",false) and not hud.equipment_buttons.stinger.get_meta("equipment_selected",false),"existing 7/8 launchers have one selected contextual slot")
	check(hud.equipment_state.text=="×3 CARGAS · PRONTO" and not hud.slot_views[2].selected and hud.slot_views[2].amount.text=="7 / 73","shared launcher pool is explicit and the primary slot retains its own ammo")
	hud.equipment_buttons.stinger.pressed.emit();refresh()
	check(human.gadget=="rpg" and not hud.equipment_buttons.stinger.visible,"the hidden opposite-team Stinger action is rejected by the validated equipment path")
	hud.equipment_buttons.rpg.pressed.emit();refresh()
	check(not human.gadget_equipped,"clicking the selected team launcher stows it")
	hud.equipment_buttons.rpg.pressed.emit();refresh()
	check(human.gadget_equipped and human.gadget=="rpg" and hud.ammo.text.begins_with("RPG-7"),"RPG contextual slot invokes the existing validated equipment action")
	game.vehicle_system.use_gadget(1);refresh()
	check(game.members[1].charges==2 and hud.ammo.text=="RPG-7\n×2 DISPONÍVEIS" and hud.equipment_state.text.contains("5,5 s"),"a real RPG projectile consumes one shared charge and starts the real launcher cooldown")
	human.apply_identity(0,"antitank");game.members[1].team=0
	human.set_gadget(true,"stinger");refresh()
	check(hud.ammo.text=="STINGER\n×2 DISPONÍVEIS" and hud.equipment_state.text.contains("6,5 s"),"Stinger sees the same remaining stock and its own actual firing interval")
	game.war_clock+=7;refresh();check(hud.equipment_state.text.ends_with("SEM ALVO"),"Stinger readiness respects the existing target-lock state")
	game.vehicle_system.lock_target="fixture_drone";game.vehicle_system.lock_progress=.5;refresh();check(hud.equipment_state.text.ends_with("TRAVANDO ALVO"),"partial Stinger lock is not labelled ready")
	game.vehicle_system.lock_progress=1;refresh();check(hud.equipment_state.text.ends_with("ALVO TRAVADO"),"complete Stinger lock receives the existing ready feedback")
	await process_frame;await process_frame
	var nodes_before:=get_node_count();var buttons_before:=hud.equipment_buttons.duplicate();var signature:=hud.equipment_signature
	var draws:={"count":0};hud.ammo.draw.connect(func(): draws.count+=1)
	for i in 50: refresh()
	check(get_node_count()==nodes_before and hud.equipment_buttons==buttons_before and hud.equipment_signature==signature,"unchanged refreshes reuse all contextual widgets and their cached presentation")
	await process_frame;await process_frame
	check(int(draws.count)==0,"unchanged launcher refresh does not rewrite the ammo label through the stowed rifle")
	for dimensions in [Vector2i(1024,768),Vector2i(1920,1080)]:
		root.size=dimensions;await process_frame;await process_frame
		for third_person in [false,true]:
			game.third_person=third_person;human._update_view();refresh()
			var tag:="%dx%d-%s"%[dimensions.x,dimensions.y,"tpp" if third_person else "fpp"]
			await shot(tag);bounds(tag)
			check(not hud.ammo.text.strip_edges().is_empty() and hud.ammo.text.begins_with("STINGER"),"equipped header remains present: "+tag)
	human.equip_quick_slot(2);refresh()
	check(not human.gadget_equipped and hud.ammo.text=="FAL\n7 / 73" and hud.slot_views[2].selected,"returning to primary restores the existing FAL state without altering its rounds")
	check(hud.slot_views[1].button.visible and hud.slot_views[2].button.visible and not hud.slot_views[3].button.visible and hud.slot_views[4].button.visible,"antitank inventory keeps its selected weapons and omits the unavailable grenade slot")
	game.members[1].charges=0;refresh();check(hud.equipment_state.text.ends_with("SEM CARGAS") and hud.equipment_state.get_theme_color("font_color")==FieldTheme.BAD,"exhausted class resources use a truthful empty indicator")
	human.set_gadget(true,"stinger");refresh();check(hud.ammo.text=="STINGER\n×0 DISPONÍVEIS" and hud.ammo.get_theme_color("font_color")==FieldTheme.BAD and not hud.low_ammo.visible,"empty launcher shows zero charges without inventing a rifle reload instruction")
	game.members[2].team=-1;refresh();check(hud.equipment_state.text.ends_with("AGUARDANDO EQUIPES"),"waiting battle state does not promise a usable gadget")
	game.members[2].team=1
	human.vehicle_id="v_guarani";game.war_ui._process(.11);check(not hud.equipment_box.visible and not hud.ammo.get_parent().get_parent().visible,"boarding removes infantry gadget and ammo HUD")
	human.vehicle_id="";game.war_ui._process(.11);check(hud.equipment_box.visible and hud.ammo.get_parent().get_parent().visible,"leaving vehicle restores the real infantry resources")
	human.deployed=false;refresh();check(not hud.equipment_box.visible,"undeployed actors have no usable class equipment badge")
	human.deployed=true;human.hp=0;refresh();check(not hud.equipment_box.visible,"dead actors have no usable class equipment badge")
	deploy("antitank");check(game.members[1].charges==3 and hud.equipment_state.text.begins_with("×3"),"normal new-life deployment replenishes the class resource shown in the HUD")
	game.members[1].erase("charges");refresh();check(hud.equipment_state.text.begins_with("—") and not hud.equipment_state.text.contains("SINCRONIZANDO"),"unknown resource state shows a dash without inventing charges or exposing transport details")
	game.show_menu();game.queue_free();await process_frame;await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures,"native_render":DisplayServer.get_name()!="headless","fixture":"Real WarPlayer/WarVehicles actions and a small deterministic floor. No multiplayer transport; online resource replication requires its separate regression."}
	NavalStorage.write_json("res://tests/war-class-hud"+("-headless" if DisplayServer.get_name()=="headless" else "")+"-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
