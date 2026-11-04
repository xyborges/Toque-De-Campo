extends SceneTree

var game: WarGame
var actor: WarPlayer
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func key(code: int) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	var release:=event.duplicate();release.pressed=false;Input.parse_input_event(release)
func click(button: int) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=true;Input.parse_input_event(event)
	var release:=event.duplicate();release.pressed=false;Input.parse_input_event(release)
func settle() -> void:
	await process_frame;await process_frame
func capture(label: String) -> void:
	await create_timer(.14).timeout;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/war-optics-"+label+".png")
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game)
	await settle();actor=game.local_player
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor.camera.make_current()
	check(game.gameplay_input_allowed(),"focused War fixture accepts normal physical keys/mouse input")
	check(GameWeapons.INFANTRY_IDS.size()==6 and "rpg" not in GameWeapons.INFANTRY_IDS,"class launchers do not leak into the ordinary account arsenal")
	check(not GameInventorySlots.resolve(actor).values().has("rpg") and GameInventorySlots.resolve(actor).get(8)=="stinger","team 1 AT inventory exposes its Stinger category, never the other launcher")
	for previous_view in [false,true]:
		game.third_person=previous_view;actor.weapon_id="sniper";actor._refresh_weapon();actor.clear_aim();actor._update_view()
		var base_yaw:=actor.yaw;actor.apply_look(Vector2(20,0));var normal_delta:=absf(actor.yaw-base_yaw)
		click(MOUSE_BUTTON_RIGHT);await settle()
		check(actor.scope_level==1 and actor.uses_telescopic_sight() and is_equal_approx(actor.camera.fov,14.),"first right click opens sniper scope from "+("TPP" if previous_view else "FPP"))
		check(game.scope_overlay.visible and not actor.view_root.visible,"telescopic sight hides FPP clone and displays the shared reticle")
		base_yaw=actor.yaw;actor.apply_look(Vector2(20,0));var first_delta:=absf(actor.yaw-base_yaw)
		check(absf(first_delta/normal_delta-.25)<.001,"first sniper magnification has one quarter normal sensitivity")
		await create_timer(.42).timeout # Must work outside the old double-click window.
		click(MOUSE_BUTTON_RIGHT);await settle()
		check(actor.scope_level==2 and is_equal_approx(actor.camera.fov,7.),"second isolated click increases magnification independently of timing")
		base_yaw=actor.yaw;actor.apply_look(Vector2(20,0));var deep_delta:=absf(actor.yaw-base_yaw)
		check(absf(deep_delta/normal_delta-.12)<.001,"deep sniper magnification has .12 normal sensitivity")
		var dot_pixels:=GameScopeReticle.pixels_per_mrad(root.get_visible_rect().size.y,actor.camera.fov)
		check(dot_pixels>5. and dot_pixels<12.,"mildot spacing follows a real one-milliradian angle at deep zoom")
		measurements["scope_"+str(previous_view)]={"normal_delta":normal_delta,"first_ratio":first_delta/normal_delta,"deep_ratio":deep_delta/normal_delta,"pixels_per_mrad":dot_pixels}
		if previous_view:
			await capture("sniper-deep")
			var image:=root.get_texture().get_image()
			var center:=Vector2i(image.get_width()/2,image.get_height()/2)
			var dot_color:=image.get_pixel(center.x+roundi(dot_pixels),center.y+1)
			var gap_color:=image.get_pixel(center.x+roundi(dot_pixels*.5),center.y+1)
			var contrast:=gap_color.get_luminance()-dot_color.get_luminance()
			measurements.dot_contrast=contrast
			check(contrast>.12,"rendered one-mrad dots have visible contrast beside the thin crosshair")
		click(MOUSE_BUTTON_RIGHT);await settle()
		check(not actor.aiming and not actor.iron_sights and actor.scope_level==0 and is_equal_approx(actor.camera.fov,70.),"third click exits the sniper scope")
		check(game.third_person==previous_view and actor.camera.get_parent()==(actor.shoulder_arm if previous_view else actor.camera_pivot),"scope exit restores the preexisting perspective without toggling V")
	# Test both launchers through the actual quickslot input and existing
	# authoritative WarVehicles path; no replacement physics or shot RPC.
	actor.yaw=.63;actor.rotation.y=actor.yaw;actor.pitch=.17
	for id in ["rpg","stinger"]:
		var team:=1 if id=="rpg" else 0
		actor.apply_identity(team,"antitank");game.members[1].team=team
		game.members[2].team=1-team;game.players[2].apply_identity(1-team,"soldier")
		actor.launcher_recoil=0;actor.recoil=0
		game.third_person=true;actor.clear_aim();actor._update_view()
		key(KEY_7 if id=="rpg" else KEY_8);await settle();actor._animate_walk()
		check(actor.weapon_id==id and actor.gadget_equipped and GameWeapons.ITEMS[id].kind=="launcher","quickslot equips a real "+id+" weapon, not a hidden FAL")
		check(actor.launcher_model.get_meta("weapon")==id and int(actor.launcher_model.get_meta("model_details").parts)>35,"recognizable detailed "+id+" model is the selected world rig")
		var right: Vector3=actor.launcher_model.get_node("GripRight").global_position
		var left: Vector3=actor.launcher_model.get_node("GripLeft").global_position
		var error_right:=right.distance_to(actor.avatar_parts.arm_r.get_node("HandR").global_position)
		var error_left:=left.distance_to(actor.avatar_parts.arm_l.get_node("HandL").global_position)
		check(error_right<.14 and error_left<.14,"both third-person hands meet their own "+id+" grip markers")
		check(actor.weapon_root.visible and not actor.view_root.visible,"third person displays the launcher attached to the avatar")
		await capture(id+"-tpp")
		game.third_person=false;actor._update_view();await settle()
		check(actor.view_root.visible and actor.view_root.has_node("LauncherHandRight") and actor.view_root.has_node("LauncherHandLeft"),"first person uses matching launcher grip hands and forearms")
		var clone:=actor.view_root.get_node("WarLauncher") as Node3D
		check(clone.get_meta("weapon")==id and clone.get_node("GripRight").position==actor.launcher_model.get_node("GripRight").position,"FPP and TPP share identical model and grip coordinates")
		await capture(id+"-fpp")
		click(MOUSE_BUTTON_RIGHT);await settle();actor._update_grenade_pose()
		check(actor.uses_telescopic_sight() and is_equal_approx(actor.camera.fov,float(GameWeapons.ITEMS[id].optic_fovs[0])) and not actor.view_root.visible,"right click opens the "+id+" sight without a clone leaking over the scope")
		var level:=actor.scope_level;actor.set_gadget(true,id)
		check(actor.scope_level==level and actor.iron_sights,"reliable equip acknowledgement preserves an already open launcher sight")
		click(MOUSE_BUTTON_RIGHT);await settle()
		game.war_clock+=10;game.members[1].last_gadget=-100.;actor.fire_cooldown=0
		var charges:=int(game.members[1].charges);var rounds: int=game.war_fx.active_slots.size()
		if id=="stinger":
			game.vehicle_system.locks.erase(1);click(MOUSE_BUTTON_LEFT);await settle()
			check(game.war_fx.active_slots.size()==rounds and int(game.members[1].charges)==charges,"Stinger cannot consume a charge or launch without an authority lock")
			var drone:=WarDrone.new();drone.drone_id="qa_enemy_drone";drone.team=1
			game.world_root.add_child(drone);drone.set_physics_process(false)
			drone.global_position=actor.camera_pivot.global_position-actor.weapon_root.global_basis.z*60
			game.vehicle_system.drones[drone.drone_id]=drone
			game.vehicle_system._update_gadgets(.02);game.vehicle_system._update_gadgets(1.3)
			check(float(game.vehicle_system.locks.get(1,{}).get("progress",0))>=1.,"authority acquires and completes a lock on a real opposing drone")
			game.war_clock+=1;actor.fire_cooldown=0
		var muzzle:=actor.launcher_muzzle.global_position
		var direction: Vector3=-actor.weapon_root.global_basis.z.normalized()
		click(MOUSE_BUTTON_LEFT);await settle()
		check(game.war_fx.active_slots.size()==rounds+1 and int(game.members[1].charges)==charges-1,"normal left click spawns one server-authoritative "+id+" and consumes one shared charge")
		if game.war_fx.active_slots.size()>rounds:
			var shot: Dictionary=game.war_fx.rounds[game.war_fx.active_slots[-1]]
			check(Vector3(shot.position).distance_to(muzzle)<.001 and Vector3(shot.velocity).normalized().dot(direction)>.99999,"authoritative "+id+" starts at the actual barrel and follows its full yaw/pitch")
		var before: int=game.war_fx.counter
		game._server_accept_shot(1,100,actor.life_id,actor.camera_pivot.global_position,direction,id,2)
		check(game.war_fx.counter==before,"launcher selection cannot bypass its authority via the generic firearm packet")
		measurements[id]={"right_hand_error":error_right,"left_hand_error":error_left,"muzzle":var_to_str(muzzle),"direction":var_to_str(direction)}
		key(KEY_2);await settle()
		check(actor.weapon_id=="fal" and not actor.gadget_equipped and actor.active_weapons().has("fal"),"normal primary slot stows "+id+" and restores the rifle")
	var before_stowed: int=game.war_fx.counter
	game.war_clock+=10;game.members[1].last_gadget=-100.;game.vehicle_system.use_gadget(1)
	check(game.war_fx.counter==before_stowed,"authority rejects a launcher request while the rifle is equipped")
	actor.apply_identity(0,"soldier")
	check(not actor.active_weapons().has("rpg") and not GameInventorySlots.resolve(actor).values().has("stinger"),"changing class invalidates quickslots and removes AT-only weapons")
	actor.weapon_id="sniper";actor._refresh_weapon();actor.clear_aim();click(MOUSE_BUTTON_RIGHT);await settle();actor.hp=0;actor._update_view()
	check(not game.scope_overlay.visible and actor.scope_level==0,"death clears sniper zoom and reticle state")
	var report: Dictionary={"checks":checks,"failures":failures,"measurements":measurements}
	var file:=FileAccess.open("res://tests/war-optics-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WAR_OPTICS ",checks," checks; failures=",failures.size())
	game.queue_free();await process_frame;await create_timer(.4).timeout;quit(0 if failures.is_empty() else 1)
