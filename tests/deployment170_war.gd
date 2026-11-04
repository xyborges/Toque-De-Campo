extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable,seconds:=20.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if condition.call(): return true
	return false
func capture(name_text: String) -> void:
	await create_timer(.35).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/deployment170-war-"+name_text+".png")
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	if not await wait_for(func():return game.join_ready and game.war_ui.deployment.visible): quit(1);return
	var actor:=game.local_player as WarPlayer;var ui:=game.war_ui
	check(not actor.deployed and not actor.body_root.visible and actor.body_collision.disabled,"War starts in deployment with no active body or collision")
	ui.team_select.select(1);ui.class_select.select(2);ui._class_changed();ui.refresh_spawns()
	check(ui.loadout_editor.choices.equipment==["rpg"] and not ui.loadout_editor.choices.has("grenade"),"team and class define the available loadout slots")
	ui.loadout_editor.slots={"sidearm":"glock","primary":"fal","melee":"axe","equipment":"rpg"};ui.loadout_editor._rebuild();ui.loadout_editor._changed()
	await capture("loadout")
	ui.deploy_button.pressed.emit()
	check(await wait_for(func():return actor.deployed and game.players.size()==12),"real offline deployment populates eleven bots")
	check(actor.active_weapons()==["glock","fal","axe","rpg"] and not actor.grenades_enabled and not actor.get_meta("drone_enabled"),"War grants only selected weapons and one team launcher")
	check(actor.ammo.keys().size()==2 and actor.ammo.has("glock") and actor.ammo.has("fal") and not actor.ammo.has("sniper"),"unselected sniper ammunition is absent from this life")
	var drones: int=game.vehicle_system.drones.size();game.vehicle_system.launch_drone(1);check(game.vehicle_system.drones.size()==drones,"disabled drone cannot be launched through its old hotkey")
	var rejected:=game._deploy(1,1,"antitank","fal","rpg","base",{"primary":"sniper","equipment":"stinger"})
	check(not rejected and actor.war_class=="antitank" and actor.weapon_id=="fal","authority rejects wrong-class rifle and opposing launcher")
	var old_life:=actor.life_id;var inventory:=actor.active_weapons().duplicate()
	game.open_deployment();ui.class_select.select(0);ui._class_changed();ui.loadout_editor.slots={"sidearm":"glock","equipment":"medkit"};ui.loadout_editor._rebuild();ui.loadout_editor._changed();ui.deploy_button.pressed.emit()
	check(actor.life_id==old_life and actor.war_class=="antitank" and actor.active_weapons()==inventory,"living deployment menu stages a future life without changing current equipment")
	check(game.members[1].pending.loadout=={"sidearm":"glock","equipment":"medkit"},"queued deployment preserves the exact validated optional slots")
	game.close_deployment()
	var opponent:=0
	for id in game.members:
		if int(game.members[id].team)==0: opponent=int(id);break
	game.members[1].shield=0;game._apply_hit(opponent,{"collider":actor.hit_regions.chest},1000,"chest","fal")
	check(actor.hp==0 and not actor.deployed,"death removes the prior active life")
	check(await wait_for(func():return actor.hp==100 and actor.life_id>old_life,7),"offline respawn deadline continues through the deployment menu")
	check(actor.war_class=="medic" and actor.weapon_id=="glock" and actor.active_weapons()==["glock"] and actor.ammo.keys()==["glock"],"queued medic respawns with only its selected pistol and kit")
	check(not game.ui_focus.blocked() and actor.camera.current,"successful deployment returns control and the existing camera")
	var saved:=GameLoadouts.saved(game,"war","medic",1);check(saved.ok and saved.slots=={"sidearm":"glock","equipment":"medkit"},"class and optional slots persist for the same account and team")
	var last:=GameLoadouts.war_last(game);check(last.team==1 and last.role=="medic","last confirmed team and class are retained")
	var result:={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/deployment170-war-results.json",result);print(JSON.stringify(result));game.show_menu();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
