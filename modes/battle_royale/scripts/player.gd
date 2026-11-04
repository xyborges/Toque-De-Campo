extends GamePlayer
class_name BRPlayer

var binocular_overlay: ColorRect
var br_bot:=false
var punch_clock:=0.0
var punch_side:=0
var punch_tested:=false
var bot_clock:=0.0
var bot_target:=Vector3.ZERO
var war_team:=-1

func _ready() -> void:
	weapon_id="fists";owned=["fists"];loadout=["fists"]
	ammo.clear();reserves.clear();grenades_enabled=true;grenades=0
	move_speed=4.3
	super._ready()
	floor_constant_speed=true

func _riding_motorbike() -> bool:
	return not vehicle_id.is_empty() and is_instance_valid(game.motorbikes) and game.motorbikes.occupied(self)

func _update_view() -> void:
	if is_local and hp>0 and _riding_motorbike():
		game.motorbikes.pose(self);return
	super._update_view()

func _update_camera_collision(delta: float) -> void:
	# Mouse input reaches this method between physics frames. The seated
	# camera must own those frames too, without showing the on-foot FPP copy
	# or sweeping the camera against its own motorcycle.
	if is_local and hp>0 and _riding_motorbike():
		game.motorbikes.pose(self);return
	super._update_camera_collision(delta)

func _uses_first_person_presentation() -> bool:
	return false if _riding_motorbike() else super._uses_first_person_presentation()

func _build_avatar() -> void:
	super._build_avatar()
	BRProtectionAppearance.apply(self,0,0)

func active_weapons() -> Array:
	return ["fists"]+loadout.filter(func(id): return id!="fists")+(["binoculars"] if "binoculars" in owned else [])

func _build_weapon_geometry() -> void:
	if weapon_id=="binoculars":
		for child in weapon_root.get_children():child.queue_free();weapon_root.remove_child(child)
		weapon_root.add_child(preload("res://modes/war/equipment/binoculars.tscn").instantiate());muzzle_marker=null;melee_rig=null
		if is_instance_valid(view_root):view_root.set_meta("weapon","")
		return
	if GameWeapons.is_launcher(weapon_id):
		for child in weapon_root.get_children():weapon_root.remove_child(child);child.queue_free()
		melee_rig=null
		var model:=WarLauncherModels.build(GameWeapons.canonical(weapon_id));weapon_root.add_child(model);muzzle_marker=model.get_node("LauncherMuzzle")
		if is_instance_valid(view_root):view_root.set_meta("weapon","")
		return
	if weapon_id!="fists": super._build_weapon_geometry();return
	for child in weapon_root.get_children(): weapon_root.remove_child(child);child.queue_free()
	muzzle_marker=null;melee_rig=null
	if is_instance_valid(view_root): view_root.set_meta("weapon","")

func _refresh_view_weapon() -> void:
	if weapon_id!="fists": super._refresh_view_weapon();return
	if not is_local:return
	if is_instance_valid(view_root):
		var previous_parent:=view_root.get_parent()
		if is_instance_valid(previous_parent):previous_parent.remove_child(view_root)
		view_root.queue_free()
	view_root=Node3D.new();view_root.name="FistsView";view_root.set_meta("weapon","fists");camera.add_child(view_root)
	for side in [-1,1]:
		var hand:=MeshInstance3D.new();hand.name="Left" if side<0 else "Right"
		hand.mesh=WarHumanRig.glove(side);hand.material_override=presentation_material(side<0,true)
		hand.position=Vector3(side*.22,-.2,-.43);hand.rotation.x=-PI*.5
		hand.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view_root.add_child(hand)
		var arm:=MeshInstance3D.new();arm.name="ForearmLeft" if side<0 else "ForearmRight"
		arm.mesh=WarBodyMesh.loft("br-fpp-forearm-v2",[[-.505,0,0,0],[-.5,.048,.05,0],[-.28,.06,.065,0],[.3,.08,.085,0],[.5,.075,.075,0],[.505,0,0,0]],14,.95)
		arm.material_override=presentation_material(side<0,false);arm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;view_root.add_child(arm)
	# Match other FPP hands. Optical copies use a private rendering layer so
	# the main camera sees the hands while the scope camera never sees itself.
	weapon_optics.prepare_copy(self)
	_pose_fists()

func _pose_arm(arm: Node3D,hand_position: Vector3,group: String) -> void:
	super._pose_arm(arm,hand_position,group)

func _update_weapon_pose() -> void:
	if weapon_id!="fists": super._update_weapon_pose()
	elif is_instance_valid(weapon_root): weapon_root.transform=Transform3D(Basis(Vector3.RIGHT,pitch),camera_pivot.position)

func _animate_walk() -> void:
	if not is_local and hp>0:
		var now:=Time.get_ticks_usec()
		if now<next_pose_usec:return
		var distance:=INF
		for observer: GamePlayer in game.players.values():
			if observer.get("br_bot")==true or observer.hp<=0:continue
			distance=minf(distance,global_position.distance_squared_to(observer.global_position))
		next_pose_usec=now+(33333 if distance<6400. else (66666 if distance<62500. else 125000))
	super._animate_walk()
	if weapon_id!="fists" or hp<=0: return
	_pose_fists()

func _pose_fists() -> void:
	if not is_instance_valid(camera_pivot) or not is_instance_valid(weapon_root):return
	var phase:=clampf(punch_clock/.38,0,1)
	var thrust:=sin(phase*PI)
	for side in [-1,1]:
		var reach:=thrust if (side<0)==(punch_side==0) else 0.
		var grip:=camera_pivot.global_position+global_basis*Basis(Vector3.RIGHT,pitch)*Vector3(side*.24,-.21,-.40-reach*.60)
		_pose_arm(avatar_parts.arm_l if side<0 else avatar_parts.arm_r,grip,"armL" if side<0 else "armR")
		if is_instance_valid(view_root) and view_root.get_node_or_null("Left" if side<0 else "Right"):
			view_root.position=Vector3.ZERO;view_root.rotation=Vector3.ZERO
			var hand: Node3D=view_root.get_node("Left" if side<0 else "Right")
			hand.position=Vector3(side*(.22-reach*.08),-.20+reach*.035,-.43-reach*.48)
			var forearm:=view_root.get_node_or_null("ForearmLeft" if side<0 else "ForearmRight") as MeshInstance3D
			if forearm:
				var wrist:=hand.position+Vector3(0,-.01,.07);var anchor:=Vector3(side*.34,-.38,.02)
				forearm.position=(anchor+wrist)*.5;forearm.basis=Basis(Quaternion(Vector3.UP,(wrist-anchor).normalized()))*Basis.from_scale(Vector3(1,wrist.distance_to(anchor),1))
			view_root.visible=_uses_first_person_presentation() and hp>0 and not _grenade_active()

func health_damage(amount: float,region: String) -> float:
	var actual:=maxf(0.,amount)*float(CombatRules.DAMAGE.get(region,1.))
	if last_impact_weapon in ["zone","fall","disconnect"]:return actual
	return game.br_inventory.protected_damage(peer_id,actual,region)

func weapon_spec(id: String) -> Dictionary:
	var spec:=CombatRules.weapon(id)
	# BR launchers use validated magazines, not War class charges or locks.
	if GameWeapons.is_launcher(id):spec.kind="firearm";spec.mag=1;spec.reload=4.5
	return GameAttachmentState.effective(spec,id,GameAttachmentManager.actor_configuration(self,id))

func play_fire_animation(id: String) -> void:
	if id!="fists": super.play_fire_animation(id);return
	punch_side=1-punch_side;punch_clock=.38;punch_tested=false

func _physics_process(delta: float) -> void:
	if hp>0 and not vehicle_id.is_empty() and is_instance_valid(game.motorbikes) and game.motorbikes.occupied(self):
		weapon_optics.advance(self,delta)
		trigger_held=false;game.motorbikes.pose(self);return
	if game.phase!="active":
		if aiming or iron_sights or weapon_optics.presented():
			weapon_optics.aim_weight=0.
			weapon_optics.stop()
			clear_aim()
		trigger_held=false;velocity=Vector3.ZERO;punch_clock=0
		if hp>0:_animate_walk()
		return
	var previous:=punch_clock
	punch_clock=maxf(0,punch_clock-delta)
	if hp<=0: respawn_left=0
	if previous>.21 and punch_clock<=.21 and not punch_tested and game.multiplayer.is_server():
		punch_tested=true;game.resolve_br_punch(self)
	super._physics_process(delta)
	if hp<=0: return
	if br_bot and game.multiplayer.is_server(): game.step_br_bot(self,delta)
	if is_local or br_bot:
		global_position.x=clampf(global_position.x,-990,990);global_position.z=clampf(global_position.z,-990,990)

func applying_heal() -> bool:
	if game.online and not game.multiplayer.is_server() and is_local:
		return float(game.snapshot.get("heal_remaining",0.))>0. or Time.get_ticks_msec()<int(get_meta("br_heal_requested_until",0))
	return game.heal_pending.has(peer_id)

func movement_input_locked() -> bool:return applying_heal()

func start_reload() -> void:
	if not applying_heal():super.start_reload()

func fire() -> void:
	if applying_heal():trigger_held=false;return
	if game.phase!="active" or not vehicle_id.is_empty() or weapon_id=="binoculars": return
	super.fire()

func _unhandled_input(event: InputEvent) -> void:
	if hp<=0 or game.phase!="active": return
	if event is InputEventKey and event.pressed and not event.echo and is_local and game.gameplay_input_allowed():
		if event.keycode==KEY_F: game.interact_nearest();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_4 and "binoculars" in owned:game.request_equip(self,"binoculars");get_viewport().set_input_as_handled();return
		if event.keycode==KEY_H: game.request_br_heal();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_BACKSPACE:game.request_br_drop(weapon_id);get_viewport().set_input_as_handled();return
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			var index:=int(event.keycode-KEY_1)
			if index==2:game.request_equip(self,"fists")
			elif index<loadout.size():game.request_equip(self,str(loadout[index]))
			get_viewport().set_input_as_handled();return
	if not vehicle_id.is_empty():return
	if weapon_id=="binoculars" and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		cycle_weapon_aim();get_viewport().set_input_as_handled();return
	super._unhandled_input(event)

func equip_quick_slot(_number: int) -> void: pass
func respawn() -> void: pass


func update_scope_reticle() -> void:
	if weapon_id!="binoculars":
		if is_instance_valid(binocular_overlay):binocular_overlay.hide()
		super.update_scope_reticle();return
	if not is_local:return
	if is_instance_valid(game.scope_overlay):game.scope_overlay.hide()
	if iron_sights and not is_instance_valid(binocular_overlay):
		binocular_overlay=ColorRect.new();binocular_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;binocular_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material:=ShaderMaterial.new();material.shader=preload("res://modes/war/shaders/binocular_view.gdshader");binocular_overlay.material=material;game.hud_layer.add_child(binocular_overlay)
	if is_instance_valid(binocular_overlay):
		binocular_overlay.visible=iron_sights and hp>0
		var size:=get_viewport().get_visible_rect().size;binocular_overlay.material.set_shader_parameter("aspect",size.x/maxf(1.,size.y))
	if iron_sights and is_instance_valid(view_root):view_root.hide()

func _exit_tree() -> void:
	if is_instance_valid(binocular_overlay):binocular_overlay.queue_free()
