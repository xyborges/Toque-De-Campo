extends SceneTree
var game: WarGame
var actor: WarPlayer
var checks:=0
var failures: Array[String]=[]
var modes_seen: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func wait_for(predicate: Callable,seconds:=90.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func orphan_presentations() -> void:
	if is_instance_valid(actor.view_root):
		var parent:=actor.view_root.get_parent()
		if parent:parent.remove_child(actor.view_root)
	var manager: GameAttachmentManager=actor.weapon_optics.mounting
	if is_instance_valid(manager.markers):
		var parent:=manager.markers.get_parent()
		if parent:parent.remove_child(manager.markers)
func render_capture() -> void:
	if DisplayServer.get_name()=="headless":return
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game.third_person=false;actor._update_view();game.ui_focus.close_all();game.war_ui.deployment.hide()
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/war-team1-spawn-scope-regression.png")
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.offline_participants=2;game.set_meta("test_mode",true);game.set_meta("war_test",true);root.add_child(game)
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player)):
		push_error("Full War offline load timed out");quit(1);return
	game.set_physics_process(false);game.set_process(false)
	if is_instance_valid(game.bot_director):
		var director:=game.bot_director;director.get_parent().remove_child(director);director.free();game.bot_director=null
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values():vehicle.set_physics_process(false)
	actor=game.local_player as WarPlayer;actor.set_physics_process(false);actor.set_process(false)
	for team in [0,1]:
		var rifle: String=WarRules.TEAM_RIFLES[team]
		for cycle in 10:
			if actor.hp>0 and actor.deployed:
				game.members[1].shield=0.;actor.last_impact_weapon=rifle;actor.take_damage(1000.,"legL",0)
				check(actor.hp==0. and not actor.deployed,"real War death schedules next deployment")
			game.war_clock=maxf(game.war_clock,float(game.members[1].ready_at))+.1
			var slots:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",team);slots.primary=rifle
			if cycle%3!=2:slots.optic="scope4x"
			var deployed:=game._deploy(1,team,"soldier",rifle,WarRules.launcher_for_team(team),"base",slots)
			check(deployed and actor.hp==100. and actor.deployed and actor.war_team==team and actor.weapon_id==rifle,"team%d deployment%d has real rifle/life"%[team,cycle])
			await process_frame
			for other: WarPlayer in game.players.values():other.set_physics_process(false);other.set_process(false)
			game.ui_focus.close_all();game.war_ui.deployment.hide()
			for optic in ["prism4x","pso4x",""]:
				actor.set_meta("weapon_attachments",{rifle:GameAttachmentState.from_legacy(rifle,optic)})
				actor.set_meta("weapon_optics",{rifle:optic} if not optic.is_empty() else {})
				actor.refresh_weapon_optics();orphan_presentations();actor._refresh_weapon()
				check(actor.view_root.get_parent()==actor.camera and actor.view_root.get_meta("weapon","")==rifle,"orphan FPP rebuild safe team%d %s"%[team,optic])
				check(actor.weapon_optics.enabled(actor)==not optic.is_empty(),"orphan socket rebuild preserves selected optic")
				for tpp in [true,false]:
					game.third_person=tpp;actor.aiming=not tpp;actor.iron_sights=not tpp;actor._update_view();actor._animate_walk();actor.weapon_optics.update(actor)
					check(actor.get_muzzle_position().is_finite() and actor.camera.global_transform.is_finite(),"valid view/muzzle after spawn and FPP/TPP")
				await process_frame
				if team==0 and cycle==0 and optic=="prism4x":await render_capture()
			# Use the existing physical launcher presentation, including a
			# detached old FPP copy, then return to the deployed rifle.
			actor.apply_identity(team,"antitank")
			var launcher:=WarRules.launcher_for_team(team)
			actor.set_gadget(true,launcher);orphan_presentations();actor._refresh_weapon()
			check(actor.weapon_id==launcher and is_instance_valid(actor.launcher_model) and actor.view_root.get_parent()==actor.camera,"team launcher presentation safely rebuilds orphan old view")
			actor.set_gadget(false,launcher);actor.apply_identity(team,"soldier");actor.weapon_id=rifle;actor._refresh_weapon()
			check(actor.weapon_root.get_node_or_null("Imported_"+rifle)!=null,"return from launcher reconstructs same rifle")
			await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"full_map":true,"cycles_per_team":10,"display":DisplayServer.get_name(),"scope":"Production WarGame offline map, team1FAL and team2AK, real death/deployment, prism/PSO/iron, FPP/TPP and Javelin presentation with deliberately detached FPP/socket roots. Confirms exercised native teardown paths only; does not prove all crashes absent. No FPS benchmark."}
	NavalStorage.write_json("res://work/war-spawn-attachment-crash-regression.json",report);print("WAR_SPAWN_ATTACHMENT_CRASH_REGRESSION ",JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
