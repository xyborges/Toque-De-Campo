extends "res://tests/br_completion_fixture.gd"

var duel_reports: Dictionary={}
var duel_pose: Dictionary={}
var duel_clock:=0.

# Only the account/room bootstrap and physical input focus are bypassed.
# Guns, reloads, projectile collisions, damage, inventory RPCs and cameras are
# the actual BR implementation on three separate ENet/DTLS processes.
func gameplay_input_allowed() -> bool:return phase=="active" and not closing
func _focus_changed() -> void:pass
func _physics_process(delta: float) -> void:
	if closing or not is_instance_valid(world_root):return
	_step_projectiles(delta)
	_update_spectator(delta)
	duel_clock+=delta
	if duel_clock>.2:
		duel_clock=0.
		if multiplayer.is_server():_send_br_states()
		_refresh_br_ui()

func _duel_pose(actor: GamePlayer,target: GamePlayer,offset:=Vector2.ZERO) -> void:
	var direction: Vector3=target.hit_regions.chest.global_position-actor.camera_pivot.global_position
	actor.yaw=atan2(-direction.x,-direction.z)+offset.x
	actor.pitch=actor.clamp_aim_pitch(asin(clampf(direction.normalized().y,-1.,1.))+offset.y)
	actor.rotation.y=actor.yaw;actor.camera_pivot.rotation.x=actor.pitch+actor.recoil
	actor.aiming=true;actor.iron_sights=true;actor._update_view();actor._update_weapon_pose();actor.weapon_optics.update(actor)

@rpc("authority","call_remote","reliable")
func duel_stage(generation: int,ids: Array) -> void:
	br_generation=generation;phase="active";closing=false;pvp_spawn_confirmed=true
	br_inventory.clear();br_round.begin(ids,_now());_clear_br_round()
	for index in ids.size():
		var id:=int(ids[index]);var actor:=players.get(id) as BRPlayer
		if not actor:actor=_spawn_player(id,id==multiplayer.get_unique_id(),false,Vector3(0,0,10 if index==0 else -10)) as BRPlayer
		actor.life_id=100+generation;actor.hp=100.;actor.respawn_left=0.;actor.limbs=CombatRules.fresh_limbs();actor.recoil=0.;actor.fire_cooldown=0.;actor.cancel_reload()
		actor.velocity=Vector3.ZERO;actor.global_position=Vector3(0,0,10 if index==0 else -10);actor.has_network_state=false
		actor.set_meta("br_generation",generation);actor.set_meta("weapon_optics",{});actor.owned=["fists"];actor.loadout=[];actor.ammo.clear();actor.reserves.clear();actor.weapon_id="fists"
		actor.stance.reset(actor);actor.locomotion.reset(actor);actor._set_hitboxes_enabled(true);actor._refresh_weapon();actor._update_view();actor.set_physics_process(true);actor.set_process(true)
		actor.body_collision.set_deferred("disabled",false);br_inventory.add_player(id)
	if is_instance_valid(local_player):local_player.camera.make_current()
	ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

@rpc("authority","call_remote","reliable")
func duel_posture(value: int) -> void:
	Input.action_release("crouch")
	if value==1:Input.action_press("crouch")
	for actor: GamePlayer in players.values():
		actor.set_posture(value,false,true);actor.stance.advance(actor,1.);actor._animate_walk()

func _target() -> GamePlayer:
	for actor: GamePlayer in players.values():
		if actor!=local_player:return actor
	return null

func _metrics() -> Dictionary:
	var actor:=local_player as BRPlayer;var optic=actor.weapon_optics
	var camera:=get_viewport().get_camera_3d()
	var scopes:=actor.find_children("OpticalLens4x","SubViewport",true,false)
	var remote:=_target();var remote_viewports:=remote.find_children("OpticalLens4x","SubViewport",true,false).size() if remote else -1
	var delta:=INF
	if is_instance_valid(optic.camera):delta=optic.camera.global_transform.origin.distance_to(actor.camera.global_transform.origin)+optic.camera.global_basis.z.distance_to(actor.camera.global_basis.z)
	var lens_local:=Vector3.INF
	var barrel_error:=INF
	if is_instance_valid(optic.lens):lens_local=actor.camera.to_local(optic.lens.global_position)
	var copied_muzzle:=actor.view_root.get_node_or_null(actor.weapon_root.get_path_to(actor.muzzle_marker)) as Node3D if is_instance_valid(actor.muzzle_marker) else null
	if copied_muzzle:
		var tip: Vector3=copied_muzzle.global_position
		# get_muzzle_position() updates both poses. Compare the currently drawn
		# models before calling it, then compare their updated positions too.
		# Mixing the old FPP point with the new attack pose creates a false
		# 12.8 mm "error" immediately after every shot.
		barrel_error=actor.muzzle_marker.global_position.distance_to(tip)
	return {"hp":actor.hp,"weapon":actor.weapon_id,"optic":actor.get_meta("weapon_optics",{}).get(actor.weapon_id,""),"main_own":camera==actor.camera,"spectator_current":camera==spectator,"active":optic.active,"viewports":scopes.size(),"remote_viewports":remote_viewports,"camera_delta":delta if is_finite(delta) else -1.,"lens_local":[lens_local.x,lens_local.y,lens_local.z] if lens_local.is_finite() else [],"barrel_error":barrel_error if is_finite(barrel_error) else -1.,"ammo":int(actor.ammo.get(actor.weapon_id,0)),"reserve":int(actor.reserves.get(actor.weapon_id,0)),"reload":actor.reload_left,"sequence":actor.shot_sequence,"pending":actor.pending_shots.size(),"recoil":actor.recoil,"pose":[actor.yaw,actor.pitch],"viewport_mode":int(optic.view.render_target_update_mode) if is_instance_valid(optic.view) else -1}

@rpc("authority","call_remote","reliable")
func duel_command(label: String,action: String,data: Dictionary={}) -> void:
	var actor:=local_player as BRPlayer
	var report: Dictionary={}
	if action=="aim":
		actor.recoil=0.;_duel_pose(actor,_target());await get_tree().create_timer(.32).timeout;await RenderingServer.frame_post_draw
	elif action=="look":
		_duel_pose(actor,_target());await get_tree().process_frame;await RenderingServer.frame_post_draw
		var first:=actor.weapon_optics.view.get_texture().get_image().get_data()
		_duel_pose(actor,_target(),Vector2(.15,.08));await get_tree().process_frame;await get_tree().process_frame;await RenderingServer.frame_post_draw
		report.image_changed=first!=actor.weapon_optics.view.get_texture().get_image().get_data()
		report.look_camera_delta=actor.weapon_optics.camera.global_position.distance_to(actor.camera.global_position)
		_duel_pose(actor,_target());await get_tree().process_frame
	elif action=="fire":
		actor.recoil=0.;actor.fire_cooldown=0.;_duel_pose(actor,_target());actor.fire();await get_tree().process_frame;await RenderingServer.frame_post_draw
	elif action=="optic":
		request_br_optic(actor.weapon_id,str(data.get("optic","")))
		await get_tree().create_timer(.25).timeout
		_duel_pose(actor,_target());await get_tree().process_frame;await RenderingServer.frame_post_draw
	elif action=="reload":
		actor.start_reload();await get_tree().create_timer(.3).timeout
		var sequence:=actor.shot_sequence;actor.fire();report.reload_shot_blocked=actor.shot_sequence==sequence
	elif action=="probe":
		actor.weapon_optics.update(actor);await get_tree().process_frame;await RenderingServer.frame_post_draw
	elif action=="death":
		await get_tree().create_timer(1.1).timeout
		_update_spectator(.1);actor.weapon_optics.update(actor)
		var sequence:=actor.shot_sequence;actor.fire();report.dead_shot_blocked=actor.shot_sequence==sequence
		await get_tree().process_frame;await RenderingServer.frame_post_draw
	elif action=="spectator_fpp":
		spectator_tpp=false;_update_spectator(.1);await get_tree().process_frame;await RenderingServer.frame_post_draw
	elif action=="capture":
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/br-optic-duel-"+str(data.get("name",label))+"-"+str(multiplayer.get_unique_id())+".png")
	report.merge(_metrics());duel_report.rpc_id(1,label,report)

@rpc("any_peer","call_remote","reliable")
func duel_report(label: String,data: Dictionary) -> void:
	if multiplayer.is_server():duel_reports[str(multiplayer.get_remote_sender_id())+":"+label]=data

@rpc("authority","call_remote","reliable")
func duel_finish() -> void:
	leave_match();await get_tree().create_timer(2.2).timeout;get_tree().quit()
