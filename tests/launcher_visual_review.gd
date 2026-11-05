extends SceneTree

# Captures actual Godot 4.7.2 game presentations. Only writes reserved work/ PNGs.
const OUT := "res://work/launcher-visual/"
var game: WarGame
var actor: WarPlayer
var results: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func _capture(label: String) -> void:
	await create_timer(.25).timeout
	RenderingServer.force_draw(false)
	var img:=root.get_texture().get_image()
	var code:=img.save_png(OUT+label+".png")
	print("CAPTURE ",label," ",img.get_size()," status ",code)
	results.append(label+":"+str(code))

func _click_right() -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT
	event.pressed=true
	Input.parse_input_event(event)
	var release:=event.duplicate()
	release.pressed=false
	Input.parse_input_event(release)

func run() -> void:
	Engine.max_fps=60
	DisplayServer.window_set_size(Vector2i(1280,720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game=load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	actor=game.local_player as WarPlayer
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	actor.camera.make_current()
	actor.rotation.y=.35
	actor.yaw=.35
	actor.pitch=.05
	for id in ["rpg","stinger"]:
		var team:=1 if id=="rpg" else 0
		actor.apply_identity(team,"antitank")
		game.members[1].team=team
		game.members[2].team=1-team
		game.players[2].apply_identity(1-team,"soldier")
		game.third_person=true
		actor.clear_aim()
		actor.set_gadget(true,id)
		actor._update_weapon_pose()
		actor._animate_walk()
		actor._update_view()
		print("POSE ",id," details ",actor.launcher_model.get_meta("model_details"))
		await _capture(id+"-tpp")
		game.third_person=false
		actor._update_view()
		actor._animate_walk()
		await _capture(id+"-fpp")
		_click_right()
		await process_frame
		await process_frame
		actor._update_grenade_pose()
		print("ADS ",id," fov ",actor.camera.fov," scope level ",actor.scope_level," visible ",game.scope_overlay.visible)
		await _capture(id+"-ads")
		_click_right()
		await process_frame
		actor._update_view()
		var muzzle:=actor.launcher_muzzle.global_position
		var direction: Vector3=-actor.weapon_root.global_basis.z.normalized()
		# Hide the launcher and avatar so the moving projectile is independently visible.
		actor.weapon_root.hide()
		actor.body_root.hide()
		if is_instance_valid(actor.view_root): actor.view_root.hide()
		game.hud_layer.hide()
		var data: Dictionary=WarRules.SPECIAL[id].duplicate()
		var step:=.014 if id=="rpg" else .010
		var expected:=muzzle+direction*float(data.get("speed",100.0))*step
		var shot_camera:=Camera3D.new()
		game.world_root.add_child(shot_camera)
		shot_camera.global_position=expected+Vector3(1.48,.48,1.85)
		shot_camera.look_at(expected,Vector3.UP)
		shot_camera.fov=33.0
		shot_camera.make_current()
		var shot_id: String="visual_"+id
		var spawned: bool=game.war_fx.spawn(1,muzzle,direction,id,true,shot_id,data)
		if spawned:
			game.war_fx._physics_process(step)
		print("PROJECTILE ",id," spawn ",spawned," muzzle ",muzzle," shot ",game.war_fx.find_round(shot_id).get("position",Vector3.ZERO))
		await _capture(id+"-projectile")
		game.war_fx.cancel_shot(shot_id)
		game.war_fx._physics_process(.16)
		shot_camera.queue_free()
		game.hud_layer.show()
		actor.camera.make_current()
		actor._update_view()
	actor.set_gadget(false,"stinger")
	print("VISUAL_REVIEW ",results)
	game.queue_free()
	await process_frame
	quit(0)
