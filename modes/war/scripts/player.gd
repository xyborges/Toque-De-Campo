extends GamePlayer
class_name WarPlayer
const BINOCULAR_MODEL=preload("res://modes/war/equipment/binoculars.tscn")
var swim_camera_height:=1.5
var war_team := -1
var war_class := "soldier"
var gadget := "rpg"
var launcher_model: Node3D
var launcher_muzzle: Marker3D
var stowed_weapon_id := "ak"
var shoulder_arm: SpringArm3D
var shoulder_distance:=3.25
var shoulder_side:=.72
var launcher_recoil:=0.0
var drone_controller: Node3D
var utility_mode:=""
var utility_zoom:=0
var utility_model: Node3D
var utility_view: Node3D
var utility_equip_weight:=0.0
var utility_raise_weight:=0.0
var binocular_overlay: ColorRect
var binocular_overlay_size:=Vector2.ZERO
var medic_keepalive:=0.0
var medic_pressed:=false
var launcher_events: Dictionary={}
var _water_tick: int=-1
var _water_position:=Vector3.ZERO
var _water_revision: int=-1
var _water_clock:=0.0
var _water_weather_seed: int=-1
var _water_value:=false
var p1a_authority_collision_pilot:=false

func _exit_tree() -> void:
	if is_instance_valid(binocular_overlay): binocular_overlay.queue_free()

func _ready() -> void:
	# Explicit QA-only pilot. Never increase host pose CPU by default.
	p1a_authority_collision_pilot="--true-fpp-p1a-authority" in OS.get_cmdline_user_args()
	deployed=false;move_speed=WarRules.WALK_SPEED
	super._ready()
	floor_constant_speed=true
	if is_local:
		var preferences:=NavalStorage.read_json(NavalStorage.settings_folder().path_join("war-camera.json"))
		shoulder_distance=clampf(float(preferences.get("distance",3.25)),2.0,4.0)
		shoulder_side=clampf(float(preferences.get("side",.72)),.4,1.05)
		shoulder_arm=SpringArm3D.new()
		shoulder_arm.name="ShoulderSpringArm"
		shoulder_arm.collision_mask=1
		shoulder_arm.margin=.08
		shoulder_arm.spring_length=shoulder_distance
		var volume:=SphereShape3D.new();volume.radius=.16
		shoulder_arm.shape=volume
		shoulder_arm.add_excluded_object(get_rid())
		camera_pivot.add_child(shoulder_arm)
		_update_view()

func _update_view() -> void:
	# The base presentation refresh assigns its own camera offset. Preserve
	# the child transform already solved by SpringArm before calling it.
	var preserve_shoulder:=is_instance_valid(shoulder_arm) and is_instance_valid(camera) and camera.get_parent()==shoulder_arm
	var solved_offset:=camera.position if preserve_shoulder else Vector3.ZERO
	super._update_view()
	if not is_local or not is_instance_valid(shoulder_arm): return
	var first_person: bool=not game.third_person or iron_sights or weapon_optics.presented() or (utility_mode=="binoculars" and utility_zoom>0)
	if first_person:
		if camera.get_parent()!=camera_pivot: camera.reparent(camera_pivot,false)
		camera.position=Vector3.ZERO
	elif preserve_shoulder:
		camera.position=solved_offset
	camera.rotation=Vector3.ZERO
	camera.fov=aim_fov(70.0,58.0)
	update_scope_reticle()
	_update_camera_collision(0)
	if not utility_mode.is_empty(): _utility_pose()
	if in_water():
		_swim_pose();weapon_root.hide()
		if is_instance_valid(view_root): view_root.hide()
		if is_instance_valid(grenade_view): grenade_view.hide()

func _update_camera_collision(delta: float) -> void:
	if not is_local or not is_instance_valid(shoulder_arm) or not is_instance_valid(camera) or hp<=0: return
	var first_person: bool=not game.third_person or iron_sights or weapon_optics.presented() or (utility_mode=="binoculars" and utility_zoom>0)
	if first_person:
		if camera.get_parent()!=camera_pivot: camera.reparent(camera_pivot,false)
		camera.position=Vector3.ZERO
		camera_close=false
		return
	var attaching:=camera.get_parent()!=shoulder_arm
	var lateral:=Vector3(shoulder_side,.12,0)
	var desired:=camera_pivot.to_global(lateral)
	var safe:=CameraObstruction.resolve(get_world_3d(),camera_pivot.global_position,desired,[get_rid()],.16)
	shoulder_arm.global_position=safe.position
	shoulder_arm.rotation=Vector3.ZERO
	var target_length:=shoulder_distance*(.68 if aiming else 1.0)
	var dt:=maxf(delta,1.0/60.0)
	shoulder_arm.spring_length=lerpf(shoulder_arm.spring_length,target_length,1.0-exp(-dt*10))
	if attaching:
		camera.reparent(shoulder_arm,false)
		# Seed a safe TPP pose immediately on entry, before the arm's next
		# physics tick. Later ticks exclusively own the child translation.
		var end:=shoulder_arm.to_global(Vector3(0,0,shoulder_arm.spring_length))
		var initial:=CameraObstruction.resolve(get_world_3d(),shoulder_arm.global_position,end,[get_rid()],.16)
		camera.global_position=initial.position
	camera.rotation=Vector3.ZERO
	# Do not zero camera.position here: mouse input can run between physics
	# ticks. It used to overwrite the arm's solved Z and expose world arms
	# at the shoulder for an entire rendered frame, even in open terrain.
	camera_close=camera.position.z<.42
	body_root.visible=hp>0 and not camera_close
	weapon_root.visible=hp>0 and not camera_close and not _grenade_active() and utility_mode.is_empty()
	if is_instance_valid(view_root): view_root.hide()
	avatar_parts.head.visible=not camera_close

func _build_avatar() -> void:
	super._build_avatar()
	if not get_meta("human_war_mesh",false):WarBodyMesh.apply(self)
	stance.build_legs(self)
	# Keep the proven animated pivot hierarchy and region hitboxes. Clothing
	# and equipment are children of those pivots, never world-space props.
	WarUniform.apply(self,maxi(0,war_team),war_class)

func apply_identity(team: int,role: String) -> void:
	var changed: bool=war_team!=team or war_class!=role or int(get_meta("war_team",-1))!=maxi(0,team) or str(get_meta("war_class",""))!=role
	war_team = team
	war_class = role
	if changed:
		remove_meta("quick_slots")
		if GameWeapons.is_launcher(weapon_id) and (war_class!="antitank" or not WarRules.launcher_allowed(war_team,weapon_id)): set_gadget(false,gadget)
	if changed: WarUniform.apply(self,maxi(0,team),role)
	else: WarUniform.refresh_materials(self,maxi(0,team))

func _physics_process(delta: float) -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.physics") if POSE_PROBE.enabled else null
	if _pose_scope:_pose_scope.section("war.stance_advance")
	stance.advance(self,delta)
	if _pose_scope:_pose_scope.section("war.state_advance")
	utility_equip_weight=move_toward(utility_equip_weight,1. if not utility_mode.is_empty() else 0.,delta*4.)
	utility_raise_weight=move_toward(utility_raise_weight,1. if utility_mode=="binoculars" and utility_zoom>0 else 0.,delta*5.)
	launcher_recoil=move_toward(launcher_recoil,0.0,delta*2.8)
	if _pose_scope:_pose_scope.section("war.locomotion_advance")
	locomotion.advance(self,delta)
	if _pose_scope:_pose_scope.section("war.state_gates")
	if hp<=0:
		if _pose_scope:_pose_scope.section("war.dead_state")
		weapon_optics.advance(self,delta)
		utility_zoom=0;_update_binocular_overlay()
		if is_instance_valid(utility_model): utility_model.hide()
		if is_instance_valid(utility_view): utility_view.hide()
		if is_instance_valid(drone_controller): drone_controller.hide()
		if _pose_scope:_pose_scope.section("war.dead_reset")
		GameInfantryPose.reset(self)
		if _pose_scope:_pose_scope.section("war.dead_hide")
		trigger_held=false;velocity=Vector3.ZERO
		body_root.hide();weapon_root.hide();_hide_dead_presentations()
		return
	if not deployed or not vehicle_id.is_empty():
		if _pose_scope:_pose_scope.section("war.inactive_state")
		weapon_optics.advance(self,delta)
		utility_zoom=0;_update_binocular_overlay()
		if is_instance_valid(utility_model): utility_model.hide()
		if is_instance_valid(utility_view): utility_view.hide()
		if _pose_scope:_pose_scope.section("war.inactive_reset")
		if not vehicle_id.begins_with("drone_"): GameInfantryPose.reset(self)
		if _pose_scope:_pose_scope.section("war.inactive_hide")
		trigger_held = false
		velocity = Vector3.ZERO
		if not vehicle_id.is_empty():
			body_root.visible = vehicle_id.begins_with("drone_")
			weapon_root.hide()
			if is_instance_valid(view_root): view_root.hide()
			if vehicle_id.begins_with("drone_"):
				for part in avatar_parts.values(): part.show()
				_drone_controller_pose()
			elif is_instance_valid(drone_controller): drone_controller.hide()
			if _pose_scope:_pose_scope.section("war.rider_pose")
			var transport: Node=game.vehicle_system.find_target(vehicle_id) if is_instance_valid(game.vehicle_system) else null
			if is_instance_valid(transport) and game.vehicle_system._transport(transport): transport.pose_rider(self)
		return
	if is_instance_valid(drone_controller): drone_controller.hide()
	if in_water():
		if not utility_mode.is_empty():
			if game.multiplayer.is_server(): game.vehicle_system._set_utility(peer_id,"")
			else: set_utility("")
		weapon_optics.advance(self,delta)
		GameInfantryPose.reset(self);_swim_physics(delta);return
	elif swimming:
		swimming=false;body_root.rotation.x=0;body_root.position.y=stance.visual_ground_offset(self);camera_pivot.position.y=swim_camera_height+stance.visual_ground_offset(self);camera_pivot.position.z=0;_update_view()
	if _pose_scope:_pose_scope.section("war.base_call")
	super._physics_process(delta)
	if _pose_scope:_pose_scope.section("war.utility_and_bounds")
	if not utility_mode.is_empty(): _utility_pose()
	elif is_instance_valid(utility_model): utility_model.hide()
	# Only the authority may recover a fallen actor. Spread expensive
	# procedural terrain checks across six ticks for bots, keeping movement,
	# collision, hitboxes and the real physics solver at 60 Hz.
	var physics_tick:=Engine.get_physics_frames()
	if game.multiplayer.is_server() and (not bool(get_meta("war_bot",false)) or posmod(physics_tick+peer_id,6)==0):
		if global_position.y<WarTerrain.height_at(global_position.x,global_position.z)-10:
			game.war_safe_reset(peer_id)
	var bounded:=global_position
	bounded.x=clampf(bounded.x,-WarTerrain.HALF+10,WarTerrain.HALF-10)
	bounded.z=clampf(bounded.z,-WarTerrain.HALF+10,WarTerrain.HALF-10)
	if global_position!=bounded: global_position=bounded

func _drone_controller_pose() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.drone") if POSE_PROBE.enabled else null
	if not is_instance_valid(drone_controller):
		drone_controller=Node3D.new();drone_controller.name="DroneController";body_root.add_child(drone_controller)
		WarUniform.box(drone_controller,"Controller",Vector3.ZERO,Vector3(.26,.10,.14),WarVehicle.material("252b28"))
		for side in [-1,1]:
			WarUniform.box(drone_controller,"Stick",Vector3(side*.07,.065,-.015),Vector3(.025,.035,.025),WarVehicle.material("727963"))
	if POSE_PROBE.setter_probe and POSE_PROBE.collecting:POSE_PROBE.record_setter(self,drone_controller,"position",avatar_parts.torso.position+Vector3(0,-.04,-.30),"_drone_controller_pose")
	drone_controller.position=avatar_parts.torso.position+Vector3(0,-.04,-.30)
	drone_controller.show()
	var centre:=drone_controller.global_position
	var _ik_before_1: Variant=POSE_PROBE.cache_before(avatar_parts.arm_l) if POSE_PROBE.enabled and POSE_PROBE.sampled(self) else null
	WarHumanRig.pose(self,avatar_parts.arm_l,centre+global_basis*Vector3(-.13,0,0),"armL")
	if _ik_before_1!=null:POSE_PROBE.cache_after(self,avatar_parts.arm_l,_ik_before_1)
	var _ik_before_2: Variant=POSE_PROBE.cache_before(avatar_parts.arm_r) if POSE_PROBE.enabled and POSE_PROBE.sampled(self) else null
	WarHumanRig.pose(self,avatar_parts.arm_r,centre+global_basis*Vector3(.13,0,0),"armR")
	if _ik_before_2!=null:POSE_PROBE.cache_after(self,avatar_parts.arm_r,_ik_before_2)

func _animate_walk() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.body") if POSE_PROBE.enabled else null
	# P1a opt-in host audit. Physical hit regions are still children of
	# visual pivots. The existing distance LOD can leave hitboxes stale on
	# listen servers. Full articulation at 60 Hz corrects that, but the 28
	# actor microbenchmark shows considerable CPU cost: keep the old LOD
	# until collision pivots can be solved independently from visual detail.
	# Dedicated servers without a local camera already update every tick.
	var force_authoritative_pose: bool=p1a_authority_collision_pilot and is_instance_valid(game) and game.multiplayer.is_server()
	if not force_authoritative_pose and not is_local and is_instance_valid(game) and is_instance_valid(game.local_player):
		var now:=Time.get_ticks_usec()
		if now<next_pose_usec: return
		var observer:=get_viewport().get_camera_3d()
		var distance:=global_position.distance_squared_to(observer.global_position if is_instance_valid(observer) else game.local_player.global_position)
		next_pose_usec=now+(33333 if distance<6400 else (66666 if distance<62500 else 125000))
	if in_water():
		_swim_pose();return
	# Network velocity is the last packet's derivative and can outlive motion.
	# Keep it for authority/ballistics, but do not feed it to the base gait
	# after interpolation has actually stopped at the replicated position.
	if not is_local and locomotion.initialized and locomotion.speed<=.18:
		var previous_velocity:=velocity
		velocity.x=0;velocity.z=0
		super._animate_walk()
		velocity=previous_velocity
	else: super._animate_walk()
	if gadget_equipped and is_instance_valid(launcher_model) and not _grenade_active():
		_pose_arm(avatar_parts.arm_r,launcher_model.get_node("GripRight").global_position,"armR")
		_pose_arm(avatar_parts.arm_l,launcher_model.get_node("GripLeft").global_position,"armL")

func _finish_body_pose() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.finish_body") if POSE_PROBE.enabled else null
	# Finalize the legs/stance before the inherited weapon and arm solve.
	# Previously stance changed the body height after both arms had already
	# been solved, then rebuilt the weapon and both arms a second time.
	if _pose_scope:_pose_scope.section("war.locomotion_pose_body")
	locomotion.pose_body(self)
	if _pose_scope:_pose_scope.section("war.stance_pose")
	stance.pose(self,false)

func _update_weapon_pose() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.weapon") if POSE_PROBE.enabled else null
	if in_water():
		weapon_root.hide()
		if is_instance_valid(view_root): view_root.hide()
		return
	super._update_weapon_pose()
	# weapon_pose already includes body_root's stance translation. Lower the
	# shoulder once so the actual muzzle and both grips follow the low torso.
	if GameWeapons.ITEMS[weapon_id].kind in ["firearm","launcher"] and not ((iron_sights or weapon_optics.presented()) and weapon_optics.enabled(self)):
		weapon_root.position.y-=.05*stance.crouch_weight+1.20*stance.prone_weight
		weapon_root.position.z-=.30*stance.prone_weight
		var head_clearance:=.19*clampf(float(body_proportions.get("head",1.)),.65,1.5)+.06
		weapon_root.position.x=lerpf(weapon_root.position.x,maxf(weapon_root.position.x,head_clearance),stance.prone_weight)
	elif GameWeapons.ITEMS[weapon_id].kind not in ["firearm","launcher"]: weapon_root.position.y+=.32*stance.prone_weight
	if _pose_scope:_pose_scope.section("war.locomotion_pose_weapon")
	locomotion.pose_weapon(self)
	if gadget_equipped and launcher_recoil>0:
		if POSE_PROBE.setter_probe and POSE_PROBE.collecting:POSE_PROBE.record_setter(self,weapon_root,"position",weapon_root.position+(weapon_root.basis*Vector3(0,.025,launcher_recoil*.22)),"_update_weapon_pose")
		weapon_root.position+=weapon_root.basis*Vector3(0,.025,launcher_recoil*.22)
		weapon_root.rotation.x+=launcher_recoil*.10
		if is_instance_valid(view_root):
			if POSE_PROBE.setter_probe and POSE_PROBE.collecting:POSE_PROBE.record_setter(self,view_root,"position",view_root.position+(Vector3(0,.025,launcher_recoil*.22)),"_update_weapon_pose")
			view_root.position+=Vector3(0,.025,launcher_recoil*.22)
			view_root.rotation.x+=launcher_recoil*.10

func restore_infantry_presentation_after_vehicle_exit() -> void:
	# Vehicle boarding hides both world and first-person weapon trees.  Merely
	# showing the body left an AK's copied rig in its vehicle pose until an
	# unrelated weapon swap rebuilt it.  Rebuild through the normal equip path
	# on both authority and local confirmation.
	if hp<=0 or not vehicle_id.is_empty(): return
	if is_instance_valid(body_root): body_root.show()
	if is_instance_valid(weapon_root): weapon_root.show()
	_refresh_weapon()
	_update_weapon_pose()
	_update_view()

func locomotion_torso_pose() -> void:
	locomotion.pose_torso(self)

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not game: return
	if utility_mode=="medic" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		medic_pressed=false;game.vehicle_system.request_command("med_hold",{"pressed":false});return
	if in_water() and not event is InputEventMouseMotion:
		if not event is InputEventKey or event.keycode not in [KEY_M,KEY_ESCAPE,KEY_TAB,KEY_V]: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_Z and game.gameplay_input_allowed() and vehicle_id.is_empty() and not in_water():
			set_posture(0 if prone else 2,true);get_viewport().set_input_as_handled();return
		if event.keycode==KEY_M:
			game.open_deployment()
			get_viewport().set_input_as_handled()
			return
		if game.gameplay_input_allowed():
			if event.keycode==KEY_F:
				game.request_interact()
				get_viewport().set_input_as_handled()
				return
			if event.keycode in [KEY_7,KEY_8] and war_class=="antitank" and vehicle_id.is_empty():
				game.select_gadget("rpg" if event.keycode==KEY_7 else "stinger")
				get_viewport().set_input_as_handled()
				return
			if event.keycode==KEY_G:
				game.request_gadget()
				get_viewport().set_input_as_handled()
				return
			if event.keycode==KEY_T:
				game.toggle_thermal()
				get_viewport().set_input_as_handled()
				return
	if not vehicle_id.is_empty(): return
	if not utility_mode.is_empty() and game.gameplay_input_allowed():
		if event is InputEventMouseButton:
			if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
				if utility_mode=="medic": medic_pressed=true;medic_keepalive=.5;game.vehicle_system.request_command("med_hold",{"pressed":true})
				get_viewport().set_input_as_handled();return
			if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
				if utility_mode=="binoculars":
					set_utility_zoom((utility_zoom+1)%3)
					game.vehicle_system.request_command("utility_zoom",{"level":utility_zoom,"life":life_id})
				get_viewport().set_input_as_handled();return
		if event is InputEventKey and event.pressed and event.keycode==KEY_R:
			get_viewport().set_input_as_handled();return
	super._unhandled_input(event)

func aim_fov(normal:=76.0,soft:=64.0) -> float:
	if utility_mode=="binoculars" and utility_zoom>0: return 20. if utility_zoom==1 else 10.
	return super.aim_fov(normal,soft)

func aim_sensitivity_scale() -> float:
	if utility_mode=="binoculars" and utility_zoom>0: return .25 if utility_zoom==1 else .12
	return super.aim_sensitivity_scale()

func set_utility(value: String) -> void:
	if value not in ["","binoculars","medic"]: return
	if value==utility_mode: return
	utility_mode=value;utility_zoom=0;utility_equip_weight=0.;utility_raise_weight=0.;trigger_held=false;medic_pressed=false;clear_aim()
	if not value.is_empty(): cancel_reload();cancel_melee()
	if is_instance_valid(utility_model): utility_model.hide();utility_model.queue_free();utility_model=null
	if is_instance_valid(utility_view): utility_view.hide();utility_view.queue_free();utility_view=null
	if is_local: _update_view()

func set_utility_zoom(value: int) -> void:
	value=clampi(value,0,2) if utility_mode=="binoculars" and hp>0 and deployed and vehicle_id.is_empty() else 0
	if utility_zoom==value: return
	utility_zoom=value;trigger_held=false
	if is_local: _update_view()

func update_scope_reticle() -> void:
	if not utility_mode.is_empty():
		if is_local and is_instance_valid(game.scope_overlay): game.scope_overlay.hide()
		if is_local and is_instance_valid(game.aim_dot): game.aim_dot.hide()
	else: super.update_scope_reticle()
	if is_local and game and is_instance_valid(game.scope_overlay):
		var material:=game.scope_overlay.material as ShaderMaterial
		if material: material.set_shader_parameter("launcher_mode",1 if weapon_id=="rpg" else (2 if weapon_id=="stinger" else 0))
	_update_binocular_overlay()

func _update_binocular_overlay() -> void:
	if not is_local or not is_instance_valid(game): return
	var active:=utility_mode=="binoculars" and utility_zoom>0 and hp>0 and deployed and vehicle_id.is_empty() and not swimming
	if active and not is_instance_valid(binocular_overlay) and DisplayServer.get_name()!="headless":
		binocular_overlay=ColorRect.new();binocular_overlay.name="BinocularView"
		binocular_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		binocular_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;binocular_overlay.z_index=-1
		var optical_material:=ShaderMaterial.new();optical_material.shader=preload("res://modes/war/shaders/binocular_view.gdshader")
		binocular_overlay.material=optical_material;game.hud_layer.add_child(binocular_overlay)
	if not is_instance_valid(binocular_overlay): return
	binocular_overlay.visible=active
	var size:=get_viewport().get_visible_rect().size
	if size!=binocular_overlay_size:
		binocular_overlay_size=size
		binocular_overlay.material.set_shader_parameter("aspect",size.x/maxf(1.,size.y))

func _process(delta: float) -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.process") if POSE_PROBE.enabled else null
	super._process(delta)
	_update_binocular_overlay()
	if not is_local or not medic_pressed: return
	if utility_mode!="medic" or hp<=0 or not deployed or not vehicle_id.is_empty() or not game.gameplay_input_allowed() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		medic_pressed=false;game.vehicle_system.request_command("med_hold",{"pressed":false});return
	medic_keepalive-=delta
	if medic_keepalive<=0:
		medic_keepalive=.5;game.vehicle_system.request_command("med_hold",{"pressed":true})

func _utility_pose() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.utility") if POSE_PROBE.enabled else null
	if utility_mode=="binoculars":
		_binocular_pose();return
	if not is_instance_valid(utility_model):
		utility_model=Node3D.new();utility_model.name="UtilityItem";body_root.add_child(utility_model)
		if utility_mode=="medic":
			WarUniform.box(utility_model,"MedicalKit",Vector3.ZERO,Vector3(.24,.16,.12),WarVehicle.material("596e58"))
			WarUniform.box(utility_model,"MedicalMark",Vector3(0,.083,0),Vector3(.10,.005,.025),WarVehicle.material("d3d8cc"))
		else:
			for side in [-1,1]: WarUniform.box(utility_model,"Optic",Vector3(float(side)*.065,0,0),Vector3(.10,.10,.20),WarVehicle.material("252b28"))
			WarUniform.box(utility_model,"Bridge",Vector3.ZERO,Vector3(.18,.05,.10),WarVehicle.material("353d36"))
	if POSE_PROBE.setter_probe and POSE_PROBE.collecting:POSE_PROBE.record_setter(self,utility_model,"position",(body_root.to_local(avatar_parts.head.global_position)+Vector3(0,-.02,-.23)) if utility_mode=="binoculars" else avatar_parts.torso.position+Vector3(0,-.05,-.3),"_utility_pose")
	utility_model.position=(body_root.to_local(avatar_parts.head.global_position)+Vector3(0,-.02,-.23)) if utility_mode=="binoculars" else avatar_parts.torso.position+Vector3(0,-.05,-.3)
	utility_model.show();weapon_root.hide()
	if is_instance_valid(view_root): view_root.hide()
	if is_local:
		if not is_instance_valid(utility_view):
			utility_view=Node3D.new();utility_view.name="UtilityView";camera.add_child(utility_view)
			if utility_mode=="medic":
				WarUniform.box(utility_view,"MedicalKit",Vector3.ZERO,Vector3(.25,.16,.12),WarVehicle.material("596e58"))
				WarUniform.box(utility_view,"MedicalMark",Vector3(0,.083,0),Vector3(.10,.005,.025),WarVehicle.material("d3d8cc"))
			else:
				for side in [-1,1]: WarUniform.box(utility_view,"Optic",Vector3(float(side)*.065,0,0),Vector3(.10,.10,.20),WarVehicle.material("252b28"))
			if POSE_PROBE.setter_probe and POSE_PROBE.collecting:POSE_PROBE.record_setter(self,utility_view,"position",Vector3(.26,-.22,-.45),"_utility_pose")
			utility_view.position=Vector3(.26,-.22,-.45)
		utility_view.visible=(not game.third_person or camera_close) and not (utility_mode=="binoculars" and utility_zoom>0)
	var centre:=utility_model.global_position
	var _ik_before_3: Variant=POSE_PROBE.cache_before(avatar_parts.arm_l) if POSE_PROBE.enabled and POSE_PROBE.sampled(self) else null
	WarHumanRig.pose(self,avatar_parts.arm_l,centre+global_basis*Vector3(-.12,0,0),"armL")
	if _ik_before_3!=null:POSE_PROBE.cache_after(self,avatar_parts.arm_l,_ik_before_3)
	var _ik_before_4: Variant=POSE_PROBE.cache_before(avatar_parts.arm_r) if POSE_PROBE.enabled and POSE_PROBE.sampled(self) else null
	WarHumanRig.pose(self,avatar_parts.arm_r,centre+global_basis*Vector3(.12,0,0),"armR")
	if _ik_before_4!=null:POSE_PROBE.cache_after(self,avatar_parts.arm_r,_ik_before_4)

func _binocular_pose() -> void:
	if not is_instance_valid(utility_model):
		utility_model=BINOCULAR_MODEL.instantiate();utility_model.name="Binoculars";body_root.add_child(utility_model)
		var rigid: Array[Node]=[]
		for child in utility_model.get_children():
			if child is MeshInstance3D: rigid.append(child)
		WarRenderBatch.merge(utility_model,"equipment:binoculars:1",rigid)
	var aim_basis: Basis=body_root.global_basis.inverse()*global_basis*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,-lean*GameInfantryPose.LEAN_ROLL)
	var eye:=body_root.to_local(camera_pivot.global_position)
	var lower:=eye+aim_basis*Vector3(.04,-.28,-.45)
	var eye_anchor: Vector3=utility_model.get_node("EyeAnchor").position
	var raised:=eye-aim_basis*(eye_anchor+Vector3(0,0,.035))
	if POSE_PROBE.setter_probe and POSE_PROBE.collecting:POSE_PROBE.record_setter(self,utility_model,"transform",Transform3D(aim_basis,lower.lerp(raised,utility_raise_weight)+aim_basis*Vector3(0,-.16*(1.-utility_equip_weight),.04*(1.-utility_equip_weight))),"_binocular_pose")
	utility_model.transform=Transform3D(aim_basis,lower.lerp(raised,utility_raise_weight)+aim_basis*Vector3(0,-.16*(1.-utility_equip_weight),.04*(1.-utility_equip_weight)))
	var optical:=is_local and utility_zoom>0
	utility_model.visible=utility_equip_weight>.01 and not optical and (not is_local or not camera_close)
	weapon_root.hide()
	if is_instance_valid(view_root): view_root.hide()
	if is_instance_valid(utility_view): utility_view.hide()
	if is_local:
		body_root.visible=not optical and not camera_close
		avatar_parts.arm_l.visible=not optical;avatar_parts.arm_r.visible=not optical
		if is_instance_valid(game.aim_dot): game.aim_dot.hide()
		_update_binocular_overlay()
	for side in ["L","R"]:
		var marker:=utility_model.get_node("GripLeft" if side=="L" else "GripRight") as Marker3D
		var arm: Node3D=avatar_parts["arm_"+side.to_lower()]
		var hand:=arm.get_node("Hand"+side) as Node3D
		var target:=hand.global_position.lerp(marker.global_position,utility_equip_weight)
		var _ik_before_5: Variant=POSE_PROBE.cache_before(arm) if POSE_PROBE.enabled and POSE_PROBE.sampled(self) else null
		WarHumanRig.pose(self,arm,target,"arm"+side,marker)
		if _ik_before_5!=null:POSE_PROBE.cache_after(self,arm,_ik_before_5)

func _set_crouched(value: bool) -> void:
	# The legacy movement packet only has a crouch bit. A delayed packet must
	# not overwrite the reliable server-approved prone posture.
	if prone and (not is_local or not value): return
	set_posture(1 if value else 0,is_local)

func set_posture(value: int,notify:=false,validated:=false) -> bool:
	if value not in [0,1,2]: return false
	if value==(2 if prone else (1 if crouched else 0)): return true
	if not stance.apply_collision(self,value,not validated): return false
	pitch=clamp_aim_pitch(pitch)
	network_pitch=clamp_aim_pitch(network_pitch)
	if is_instance_valid(camera_pivot): camera_pivot.rotation.x=clamp_aim_pitch(pitch+recoil)
	next_pose_usec=0
	if notify and is_instance_valid(game): game.request_posture(self,value)
	return true

func movement_stance_factor(sprinting: bool) -> float:
	return .24 if prone else (.53 if crouched else (1.4 if sprinting else 1.))

func clamp_aim_pitch(value: float) -> float:
	return clampf(value,-.38 if prone and not swimming else -1.30,1.25)

func can_jump() -> bool:
	return not prone

func equip_slot(index: int) -> void:
	if hp<=0 or not deployed or not vehicle_id.is_empty() or in_water(): return
	if not utility_mode.is_empty(): game.vehicle_system.request_command("utility",{"mode":""});set_utility("")
	if gadget_equipped:
		set_gadget(false,gadget)
		if game.offline_operation or (game.online and not game.multiplayer.is_server()): game.vehicle_system.request_command("select",{"gadget":gadget,"enabled":false})
	super.equip_slot(index)

func start_reload() -> void:
	if not utility_mode.is_empty(): return
	super.start_reload()

func can_resume_reload(id: String) -> bool:
	return utility_mode.is_empty() and super.can_resume_reload(id)

func fire() -> void:
	if hp<=0 or not deployed or not vehicle_id.is_empty() or in_water(): return
	if not utility_mode.is_empty(): return
	# The same battle gate must run before local ammo, recoil and predicted
	# sound. Otherwise a rejected waiting-room shot looks real but has no
	# authoritative projectile and leaves unacknowledged predicted rounds.
	if not game._battle_active(): return
	if gadget_equipped:
		if fire_cooldown<=0 and game.gameplay_input_allowed():
			fire_cooldown = .25
			game.request_gadget()
		return
	super.fire()

func shot_camera_valid(origin: Vector3,direction: Vector3) -> bool:
	# The configurable shoulder arm reaches 4 m plus its lateral offset.
	# Validate that authored envelope, rather than the shorter base FPP limit.
	var offset:=origin-camera_pivot.global_position
	var behind: float=-offset.dot(direction)
	if offset.length()>4.4 or behind<-.4 or behind>4.15 or (offset+direction*behind).length()>1.35: return false
	var query:=PhysicsRayQueryParameters3D.create(camera_pivot.global_position,origin,1,game._collision_excludes(peer_id,false))
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func set_gadget(enabled: bool,value := "rpg") -> void:
	if enabled and in_water(): return
	if value not in ["rpg","stinger"]: return
	if enabled and not get_meta("class_equipment",true): return
	if enabled and not WarRules.launcher_allowed(war_team,value): return
	enabled=enabled and war_class=="antitank"
	gadget=value
	# Reliable equip acknowledgements must not reset a locally opened sight.
	if enabled and weapon_id==value and is_instance_valid(launcher_model): return
	if not enabled and not GameWeapons.is_launcher(weapon_id):
		gadget_equipped=false
		return
	if enabled:
		if not GameWeapons.is_launcher(weapon_id):
			stowed_weapon_id=weapon_id
			pause_reload()
		weapon_id=value
	else:
		weapon_id=stowed_weapon_id if stowed_weapon_id in super.active_weapons() else str(WarRules.primary_for(war_class,war_team)[0])
	aiming=false;iron_sights=false;scope_level=0;trigger_held=false
	_refresh_weapon()
	if is_local: _refresh_view_weapon()
	_update_weapon_pose()
	_update_view()
	if not gadget_equipped and game:
		if game.online and not game.multiplayer.is_server():
			if is_local: resume_reload(weapon_id)
		else: game._resume_reload(self)

func _build_launcher() -> void:
	launcher_model=WarLauncherModels.build(weapon_id)
	weapon_root.add_child(launcher_model)
	launcher_muzzle=launcher_model.get_node("LauncherMuzzle")
	muzzle_marker=launcher_muzzle

func active_weapons() -> Array:
	var result:=super.active_weapons().duplicate()
	if war_class=="antitank" and war_team in [0,1] and get_meta("class_equipment",true): result.append(WarRules.launcher_for_team(war_team))
	return result

func equip_quick_slot(number: int) -> void:
	if in_water(): return
	if not utility_mode.is_empty() and number in [1,2,3,4,5,6]: game.vehicle_system.request_command("utility",{"mode":""});set_utility("")
	if number in [7,8]:
		if hp>0 and deployed and vehicle_id.is_empty() and war_class=="antitank": game.select_gadget("rpg" if number==7 else "stinger")
		return
	super.equip_quick_slot(number)

func _refresh_weapon() -> void:
	if is_instance_valid(view_root): view_root.set_meta("weapon","")
	launcher_model=null;launcher_muzzle=null
	gadget_equipped=GameWeapons.is_launcher(weapon_id)
	if not gadget_equipped:
		stowed_weapon_id=weapon_id
		super._refresh_weapon()
		return
	gadget=weapon_id
	for child in weapon_root.get_children():
		weapon_root.remove_child(child);child.queue_free()
	muzzle_marker=null;melee_rig=null
	_build_launcher()
	if is_local and is_instance_valid(camera):_update_view()

func _weapon_offset() -> Vector3:
	if weapon_id=="stinger": return Vector3(.43,-.38,-.55)
	if GameWeapons.is_launcher(weapon_id): return Vector3(.26,-.28,-.36)
	return super._weapon_offset()

func _refresh_view_weapon() -> void:
	if not GameWeapons.is_launcher(weapon_id):
		super._refresh_view_weapon()
		return
	if not is_local or not is_instance_valid(camera) or not is_instance_valid(launcher_model): return
	if is_instance_valid(view_root):
		var previous_parent:=view_root.get_parent()
		if is_instance_valid(previous_parent):previous_parent.remove_child(view_root)
		view_root.queue_free()
	view_root=Node3D.new();view_root.name="FirstPersonPresentation";view_root.set_meta("weapon",weapon_id)
	camera.add_child(view_root)
	view_root.add_child(launcher_model.duplicate())
	var glove:=EnvironmentKit.material("cloth:343d2c")
	var sleeve:=EnvironmentKit.material("cloth:596043")
	for side in ["Right","Left"]:
		var marker:=launcher_model.get_node("Grip"+side) as Marker3D
		var hand:=MeshInstance3D.new();hand.name="LauncherHand"+side
		var palm:=BoxMesh.new();palm.size=Vector3(.09,.105,.105)
		hand.mesh=palm;hand.position=marker.position;hand.material_override=glove;view_root.add_child(hand)
		var anchor:=Vector3(.12,-.20,.47) if side=="Right" else Vector3(-.40,-.22,.36)
		var direction:=marker.position-anchor
		var arm:=MeshInstance3D.new();arm.name="LauncherForearm"+side
		var shape:=CapsuleMesh.new();shape.radius=.054;shape.height=direction.length()
		arm.mesh=shape;arm.position=(marker.position+anchor)*.5
		arm.quaternion=Quaternion(Vector3.UP,direction.normalized());arm.material_override=sleeve
		view_root.add_child(arm)
	view_root.position=_weapon_offset()

func _pose_arm(arm: Node3D,hand_position: Vector3,group: String) -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.ik") if POSE_PROBE.enabled else null
	if get_meta("articulated_arms",false) and (float(limbs.get(group,100.))>0 or not CombatRules.limb_disability_enabled(game)):
		if weapon_id in ["fal","glock","g3"] and not _grenade_active():
			var model:=weapon_root.get_node_or_null("Imported_"+weapon_id) as Node3D
			if model:
				hand_position=model.get_node("GripRight" if group=="armR" else "SupportGrip").global_position
				if group=="armL" and reload_weapon==weapon_id and reload_left>0:
					var pose:=reload_pose_state(weapon_id,reload_left,reload_total)
					hand_position=model.to_global(pose.hand)
		var _ik_before_6: Variant=POSE_PROBE.cache_before(arm) if POSE_PROBE.enabled and POSE_PROBE.sampled(self) else null
		WarHumanRig.pose(self,arm,hand_position,group)
		if _ik_before_6!=null:POSE_PROBE.cache_after(self,arm,_ik_before_6)
	else: super._pose_arm(arm,hand_position,group)

func _update_first_person_hands() -> void:
	super._update_first_person_hands()

func _uses_first_person_presentation() -> bool:
	return is_local and utility_mode.is_empty() and vehicle_id.is_empty() and not in_water() and (not game.third_person or iron_sights or weapon_optics.presented())

func _update_grenade_pose() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.grenade") if POSE_PROBE.enabled else null
	super._update_grenade_pose()
	if not vehicle_id.is_empty():
		_hide_dead_presentations();weapon_root.hide();return
	if uses_telescopic_sight() and is_instance_valid(view_root): view_root.hide()
	if is_local and game.third_person and not iron_sights and not weapon_optics.presented():
		if is_instance_valid(view_root): view_root.hide()
		if is_instance_valid(grenade_view): grenade_view.hide()
		if camera_close: weapon_root.hide()

func accepted_launcher_shot(id: String,weapon: String) -> void:
	if launcher_events.has(id) or hp<=0: return
	launcher_events[id]=true
	if launcher_events.size()>64: launcher_events.erase(launcher_events.keys()[0])
	launcher_recoil=1.0
	if is_local:
		recoil=minf(.24,recoil+(.12 if weapon=="rpg" else .095))
		camera_pivot.rotation.x=clampf(pitch+recoil,-1.3,1.25)

func _apply_dead_camera_look(relative: Vector2) -> void:
	# The body stays frozen; only the camera orientation changes during the
	# respawn wait. Do not run movement or weapon input for this state.
	var sensitivity:=0.0023*aim_sensitivity_scale()*GameAimSensitivity.factor("weapon:"+weapon_id,false)
	yaw-=relative.x*sensitivity
	pitch=clampf(pitch-relative.y*sensitivity,-1.30,1.25)
	rotation.y=yaw
	camera_pivot.rotation.x=pitch
	_update_camera_collision(0.0)

func apply_look(relative: Vector2) -> void:
	if not is_local or not game or game.ui_focus.blocked(): return
	if hp<=0:
		_apply_dead_camera_look(relative)
	elif Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if not vehicle_id.is_empty(): game.vehicle_look(relative)
		else: super.apply_look(relative)

func in_water() -> bool:
	if hp<=0 or not deployed or not vehicle_id.is_empty(): return false
	# The Afghan valley has shallow inland streams but no sea at y≈0.
	# Ukraine's ocean/wave query is both invalid and expensive on Afghan
	# terrain. Infantry crosses the creek using ordinary ground physics.
	if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:return false
	var tick:=Engine.get_physics_frames()
	var point:=global_position
	var clock:=float(game.war_clock)
	# Pose/weapon/lean validation ask the same question several times per tick.
	# A snapshot, teleport, terrain edit or changed wave clock invalidates it
	# immediately, including changes that happen within the current tick.
	if _water_tick==tick and _water_position==point and _water_revision==WarTerrainEdits.revision and _water_clock==clock and _water_weather_seed==WarWeather.seed: return _water_value
	_water_value=WarTerrain.height_at(point.x,point.z)<-.6 and point.y<WarCoast.wave(point,clock)+.18
	_water_tick=tick;_water_position=point;_water_revision=WarTerrainEdits.revision;_water_clock=clock;_water_weather_seed=WarWeather.seed
	return _water_value

func _swim_physics(delta: float) -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.swim") if POSE_PROBE.enabled else null
	if not swimming:
		stance.reset(self);swim_camera_height=1.68;swimming=true
		clear_aim();cancel_reload();cancel_melee();trigger_held=false;grenade_selected=false;grenade_aiming=false
		if game.multiplayer.is_server() and game.grenades_system and game.grenades_system.rounds.has(grenade_held_id): game.grenades_system._drop(game.grenades_system.rounds[grenade_held_id])
		if game.multiplayer.is_server(): game.sync_inventory(self)
	if is_local or is_npc or get_meta("war_bot",false):
		var direction:=Vector3.ZERO
		if is_local and game.gameplay_input_allowed():
			var wish:=Input.get_vector("move_left","move_right","move_forward","move_back")
			direction=global_basis*Vector3(wish.x,0,wish.y)
		elif is_npc or get_meta("war_bot",false): direction=Vector3(-global_position.x,0,-global_position.z).normalized()
		velocity.x=direction.x*2.8;velocity.z=direction.z*2.8
		var surface:=WarCoast.wave(global_position,float(game.war_clock))
		velocity.y=clampf((surface-.85-global_position.y)*6,-3,3)
		move_and_slide()
	elif has_network_state and not game.multiplayer.is_server():
		global_position=global_position.lerp(network_target,1-exp(-delta*18));yaw=lerp_angle(yaw,network_yaw,1-exp(-delta*18));pitch=lerpf(pitch,network_pitch,1-exp(-delta*18));rotation.y=yaw
	camera_pivot.position.y=.98;camera_pivot.rotation.x=pitch
	_swim_pose();weapon_root.hide()
	if is_instance_valid(view_root): view_root.hide()
	if is_instance_valid(grenade_view): grenade_view.hide()
	if is_instance_valid(grenade_prop): grenade_prop.hide()
	if is_local:
		_update_camera_collision(delta);weapon_root.hide()
		camera.global_position.y=maxf(camera.global_position.y,WarCoast.wave(camera.global_position,float(game.war_clock))+.16)

func _swim_pose() -> void:
	var _pose_scope = POSE_PROBE.scope(self,"war.swim_pose") if POSE_PROBE.enabled else null
	var phase:=float(game.war_clock)*4.8
	body_root.rotation.x=-1.4;body_root.position.y=.8
	if is_local:
		body_root.show();camera_pivot.position.z=0 if game.third_person else -1.25
		for label in ["head","torso","leg_l","leg_r"]: avatar_parts[label].visible=game.third_person
		var pelvis:=body_root.get_node_or_null("Pelvis") as Node3D
		if pelvis: pelvis.visible=game.third_person
		avatar_parts.arm_l.show();avatar_parts.arm_r.show()
	for side in ["l","r"]:
		var sign_value:=1. if side=="l" else -1.
		var arm:=avatar_parts["arm_"+side] as Node3D
		arm.rotation=Vector3(sin(phase+(.0 if side=="l" else PI))*1.4,0,sign_value*.35)
		var leg:=avatar_parts["leg_"+side] as Node3D
		leg.rotation.x=sin(phase*1.8+(.0 if side=="l" else PI))*.35

func shared_human_motion() -> bool:
	return false

func emit_step_sound(sequence: int,point: Vector3,running: bool) -> void:
	if is_instance_valid(game.soundscape):game.soundscape.play_step(peer_id,life_id,sequence,point,running,crouched)

