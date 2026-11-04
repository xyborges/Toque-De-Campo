extends CharacterBody3D
class_name GamePlayer

signal shot_requested(shooter: GamePlayer, origin: Vector3, direction: Vector3, weapon_id: String, is_melee: bool)
signal player_died(victim: GamePlayer, killer_id: int)

var game: Node
var peer_id := 1
var is_local := true
var is_npc := false
var hp := 100.0
var last_hit_region := "torso"
var kills := 0
var deaths := 0
var yaw := 0.0
var pitch := 0.0
var weapon_id := "ak"
var ammo := GameWeapons.fresh_ammo()
var owned := ["broom", "squeegee", "axe", "glock", "ak", "fal", "sniper"]
var loadout: Array=[]
var grenades:=2
var grenades_enabled:=true
var grenade_throw_left:=0.0
var grenade_aiming:=false
var grenade_sequence:=0
var grenade_selected:=false
var grenade_held_id:=""
var grenade_fuse_left:=0.0
var grenade_prime_pending:=false
var grenade_view: Node3D
var grenade_view_mesh: MeshInstance3D
var grenade_prop: MeshInstance3D
var reload_left := 0.0
var reload_weapon := ""
var paused_reloads: Dictionary = {}
var _reload_pose_weapon:=""
var _reload_pose_left:=-1.
var _reload_pose_total:=-1.
var _reload_pose_state: Dictionary={}
var reload_revision := 0
var authoritative_reload_revision := -1
var fire_cooldown := 0.0
var respawn_left := 0.0
var mouse_captured := false
var aiming := false
var iron_sights := false
var scope_level := 0
var recoil := 0.0
var hit_regions: Dictionary = {}
var avatar_parts: Dictionary = {}
var body_root: Node3D
var camera_pivot: Node3D
var audio_listener: AudioListener3D
var audio_listener_check_clock:=0.0
var camera: Camera3D
var weapon_root: Node3D
var weapon_mount: Node3D
var muzzle_marker: Node3D
var melee_rig: MeleeRig
var npc_attack_clock := -1.0
var npc_attack_landed := false
var npc_avoid_timer := 0.0
var npc_avoid_direction := Vector3.ZERO
var hit_flash: MeshInstance3D
var move_speed := 6.2
var reload_sync_wait:=0.0
var previous_position := Vector3.ZERO
var npc_attack_wait := 0.0
var attack_anim := 0.0
var reload_total := 0.0
var reload_audio: AudioStreamPlayer3D
var crouched := false
var prone:=false
var swimming:=false
var deployed:=true
var vehicle_id:=""
var gadget_equipped:=false
var stance:=WarStance.new()
var locomotion:=WarLocomotion.new()
var next_pose_usec:=0
var body_collision: CollisionShape3D
var reserves := CombatRules.fresh_reserves()
var limbs := CombatRules.fresh_limbs()
var detached_region := ""
var last_impact_direction := Vector3.ZERO
var last_impact_weapon := ""
var reaction := 0.0
var shot_sequence := 0
var pending_shots: Dictionary = {}
var life_id := 1
var death_presented := 0
var death_sound := 0
var trigger_held := false
var aim_click_time := -1.0
var network_target := Vector3.ZERO
var network_yaw := 0.0
var network_pitch := 0.0
var lean:=0.0
var network_lean:=0.0
var has_network_state := false
var last_snapshot_time := 0.0
var last_snapshot_position := Vector3.ZERO
var body_proportions: Dictionary = {}
var view_root: Node3D
var aim_point := Vector3.ZERO
var last_camera_origin := Vector3.ZERO
var last_view_direction := Vector3.FORWARD
var camera_distance := -1.0
var camera_close := false
var weapon_optics:=preload("res://scripts/weapon_optics.gd").new()
var infantry_protection:=preload("res://scripts/infantry_protection.gd").new()

func _ready() -> void:
	floor_snap_length = .45
	body_collision = get_node_or_null("BodyCollision") as CollisionShape3D
	body_root = Node3D.new()
	body_root.name = "Avatar"
	add_child(body_root)
	_build_avatar()
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.68, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.fov = 76.0
	camera.position = Vector3(0.50, 0.32, 3.05)
	camera.current = is_local
	camera_pivot.add_child(camera)
	if is_local:
		# Hearing stays at the head when the shoulder camera retracts, zooms
		# or switches perspective. Remote actors never replace the listener.
		audio_listener=AudioListener3D.new()
		audio_listener.name="PlayerEars"
		camera_pivot.add_child(audio_listener)
		audio_listener.make_current()
	_build_weapon()
	previous_position = global_position
	if not is_local:
		camera.current = false
		camera.position = Vector3.ZERO
	else:
		_update_view()

func _build_avatar() -> void:
	var skin := Color(GameCharacterColors.normalize(get_meta("body_colors",{})).skin)
	var shirt := Color(str(game.profile.skin)) if game and is_local else Color("#3477bd")
	var pants := Color("#26313b")
	# Common region anchors; the shared War human mesh/rig replaces these shells.
	var head := _part("Head", Vector3(0, 1.73, 0), Vector3(0.52, 0.52, 0.48), skin)
	_face_detail(head)
	var torso := _part("Torso", Vector3(0, 1.10, 0), Vector3(0.72, 0.92, 0.42), shirt)
	_part("Pelvis", Vector3(0, 0.57, 0), Vector3(0.62, 0.24, 0.38), pants)
	var arm_l := _limb("ArmL", Vector3(-0.47, 1.42, 0), Vector3(0.25, 0.76, 0.30), skin, "armL")
	var arm_r := _limb("ArmR", Vector3(0.47, 1.42, 0), Vector3(0.25, 0.76, 0.30), skin, "armR")
	var leg_l := _limb("LegL", Vector3(-0.19, 0.78, 0), Vector3(0.30, 0.78, 0.34), pants, "legL")
	var leg_r := _limb("LegR", Vector3(0.19, 0.78, 0), Vector3(0.30, 0.78, 0.34), pants, "legR")
	_limb_detail(arm_l, "HandL", Vector3(0.15, 0.17, 0.18), Vector3(0, -0.78, 0), skin)
	_limb_detail(arm_r, "HandR", Vector3(0.15, 0.17, 0.18), Vector3(0, -0.78, 0), skin)
	_limb_detail(leg_l, "ShoeL", Vector3(0.32, 0.16, 0.46), Vector3(0, -0.78, -0.055), Color("#171c20"))
	_limb_detail(leg_r, "ShoeR", Vector3(0.32, 0.16, 0.46), Vector3(0, -0.78, -0.055), Color("#171c20"))
	_add_hit_region("head", head, Vector3(0.52, 0.52, 0.48))
	_add_hit_region("chest", torso, Vector3(0.72, 0.48, 0.42), Vector3(0, 0.22, 0))
	_add_hit_region("abdomen", torso, Vector3(0.72, 0.44, 0.42), Vector3(0, -0.24, 0))
	_add_hit_region("abdomenPelvis", body_root.get_node("Pelvis"), Vector3(0.62, 0.24, 0.38))
	avatar_parts = {"head":head, "torso":torso, "arm_l":arm_l, "arm_r":arm_r, "leg_l":leg_l, "leg_r":leg_r}
	if game and is_local:
		apply_body_proportions(game.profile.get("proportions", {}))
	WarBodyMesh.apply(self)
	stance.build_legs(self)
	apply_body_colors(game.profile.get("colors",{}) if game and is_local else {})
	if game and not game.get_meta("battle_royale",false) and not self is WarPlayer:
		WarUniform.apply(self,0,"soldier");set_meta("default_shared_uniform",true)

func _limb(part_name: String, shoulder: Vector3, size: Vector3, color: Color, region: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = shoulder
	body_root.add_child(pivot)
	var mesh := MeshInstance3D.new()
	mesh.name = part_name + "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position.y = -size.y * 0.5
	mesh.material_override = _material(color)
	pivot.add_child(mesh)
	if region.begins_with("arm"):
		_add_hit_region(region, mesh, Vector3(size.x, size.y * 0.5, size.z), Vector3(0, size.y * 0.25, 0))
		_add_hit_region("forearm" + region.right(1), mesh, Vector3(size.x, size.y * 0.5, size.z), Vector3(0, -size.y * 0.25, 0))
	else:
		_add_hit_region(region, mesh, size)
	return pivot

func _limb_detail(parent: Node3D, part_name: String, size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	var side := "L" if part_name.ends_with("L") else "R"
	_add_hit_region(("hand" if part_name.begins_with("Hand") else "foot") + side, mesh, size)

func apply_body_proportions(_values: Dictionary) -> void:
	# Legacy account payloads cannot deform the shared model or its hitboxes.
	body_proportions = {"head":1.,"torso":1.,"arms":1.,"legs":1.}
	for part in avatar_parts.values(): part.scale=Vector3.ONE

func apply_body_colors(value: Variant) -> void:
	GameCharacterColors.apply(self,value)

func _face_detail(head: MeshInstance3D) -> void:
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.045
		eye_mesh.height = 0.09
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.12, 0.045, -0.235)
		eye.material_override = _material(Color("#14191a"), 0.35)
		head.add_child(eye)
	var nose := MeshInstance3D.new()
	nose.name="Nose"
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.055
	nose_mesh.height = 0.10
	nose.mesh = nose_mesh
	nose.position = Vector3(0, -0.04, -0.245)
	nose.scale = Vector3(0.8, 1.0, 0.65)
	nose.material_override = _material(Color("#d3a080"))
	head.add_child(nose)

func _part(part_name: String, pos: Vector3, size: Vector3, color: Color, rounded := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	if rounded:
		var capsule := CapsuleMesh.new()
		capsule.radius = minf(size.x, size.z) * 0.48
		capsule.height = maxf(size.y, capsule.radius * 2.0)
		mesh.mesh = capsule
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color)
	body_root.add_child(mesh)
	return mesh

func _material(color: Color, roughness := 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_hit_region(region: String, mesh: MeshInstance3D, size: Vector3, offset := Vector3.ZERO) -> void:
	var area := Area3D.new()
	area.name = "Hit_" + region
	area.position = offset
	area.set_meta("hit_region", "abdomen" if region == "abdomenPelvis" else region)
	area.collision_layer = 2
	area.collision_mask = 0
	# Shot/melee queries detect these regions directly. They never consume
	# overlap signals/lists, so do not maintain a monitor for every body part.
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	mesh.add_child(area)
	hit_regions[region] = area

func _build_weapon() -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "HeldWeapon"
	add_child(weapon_root)
	weapon_mount = weapon_root
	_refresh_weapon()
	_update_weapon_pose()

func _refresh_weapon() -> void:
	_build_weapon_geometry()
	refresh_weapon_optics()
	# Reliable equip and local authority changes use this same rebuild path.
	# Invalidate-and-wait left the old FPP weapon/fists until the next aim or
	# camera toggle; rebuild its presentation as part of the equip itself.
	if is_local and is_instance_valid(camera):_update_view()

func refresh_weapon_optics() -> void:
	weapon_optics.refresh(self)

func _build_weapon_geometry() -> void:
	# Deployment can change the weapon ID before rebuilding the world mesh.
	# Any existing FPP copy must follow the rebuilt geometry, even at the
	# same ID after respawn or a reliable equipment acknowledgement.
	if is_instance_valid(view_root): view_root.set_meta("weapon","")
	for child in weapon_root.get_children():
		weapon_root.remove_child(child)
		child.queue_free()
	muzzle_marker = null
	melee_rig = null
	if is_npc: return
	var item: Dictionary = GameWeapons.ITEMS.get(weapon_id, GameWeapons.ITEMS.ak)
	if item.kind == "melee":
		melee_rig = MeleeRig.new()
		weapon_root.add_child(melee_rig)
		melee_rig.build(weapon_id)
	elif GameWeapons.canonical(weapon_id) == "fal":
		var model:=FALModel.create()
		weapon_root.add_child(model)
		muzzle_marker=model.get_node("Muzzle")
		return
	elif GameWeapons.canonical(weapon_id) == "g3":
		var model:=G3Model.create()
		weapon_root.add_child(model)
		muzzle_marker=model.get_node("Muzzle")
		return
	elif GameWeapons.canonical(weapon_id) == "glock":
		var model:=GlockModel.create();weapon_root.add_child(model)
		muzzle_marker=model.get_node("Muzzle")
		return
	else:
		if _load_gltf_weapon("sniper" if GameWeapons.canonical(weapon_id) == "sniper" else "ak"):
			return
		var sniper := GameWeapons.canonical(weapon_id) == "sniper"
		var dark := Color("#171b1b")
		var metal := Color("#303737")
		var stock_color := Color("#514437") if GameWeapons.canonical(weapon_id) == "ak" else Color("#242a28")
		_weapon_box("Receiver", Vector3(0.15, 0.17, 0.48), Vector3(0, 0, -0.20), item.color)
		_weapon_box("UpperReceiver", Vector3(0.13, 0.055, 0.46), Vector3(0, 0.105, -0.22), metal)
		_weapon_box("Handguard", Vector3(0.135, 0.14, 0.35 if not sniper else 0.55), Vector3(0, 0.005, -0.55 if not sniper else -0.66), Color("#31372f"))
		_weapon_box("Barrel", Vector3(0.045, 0.045, 0.48 if not sniper else 0.74), Vector3(0, 0.015, -0.91 if not sniper else -1.03), dark)
		_weapon_box("MuzzleBrake", Vector3(0.075, 0.07, 0.12), Vector3(0, 0.015, -1.17 if sniper else -1.15), metal)
		_weapon_box("Stock", Vector3(0.12, 0.15, 0.33), Vector3(0, -0.02, 0.20), stock_color)
		_weapon_box("ButtPad", Vector3(0.13, 0.17, 0.045), Vector3(0, -0.02, 0.37), dark)
		_weapon_box("Magazine", Vector3(0.105, 0.26, 0.14), Vector3(0, -0.20, -0.22), Color("#242a28"))
		_weapon_box("PistolGrip", Vector3(0.09, 0.20, 0.105), Vector3(0, -0.17, 0.015), Color("#242a28"))
		_weapon_box("TriggerGuard", Vector3(0.10, 0.015, 0.14), Vector3(0, -0.115, -0.09), metal)
		_weapon_box("Trigger", Vector3(0.018, 0.07, 0.025), Vector3(0, -0.095, -0.15), Color("#a5a79e"))
		_weapon_box("FrontSight", Vector3(0.035, 0.075, 0.035), Vector3(0, 0.15, -0.83), dark)
		_weapon_box("RearSight", Vector3(0.055, 0.055, 0.045), Vector3(0, 0.15, -0.12), dark)
		_weapon_box("TopRail", Vector3(0.075, 0.025, 0.65 if not sniper else 0.82), Vector3(0, 0.145, -0.48), dark)
		for slot in range(4):
			_weapon_box("RailSlot", Vector3(0.012, 0.045, 0.035), Vector3(0.073, 0.015, -0.40 - slot * 0.085), metal)
		if GameWeapons.canonical(weapon_id) == "ak":
			_weapon_box("GasBlock", Vector3(0.09, 0.09, 0.11), Vector3(0, 0.02, -0.91), metal)
			_weapon_box("ChargingHandle", Vector3(0.10, 0.028, 0.045), Vector3(0.09, 0.09, -0.22), dark)
		if sniper:
			# Iron sights instead of a permanent telescopic model.
			_weapon_box("SniperRearIron", Vector3(0.07, 0.08, 0.05), Vector3(0, 0.18, -0.13), dark)
			_weapon_box("SniperFrontIron", Vector3(0.025, 0.08, 0.025), Vector3(0, 0.18, -1.10), dark)
			_weapon_box("BipodL", Vector3(0.025, 0.22, 0.035), Vector3(-0.045, -0.18, -0.68), dark)
			_weapon_box("BipodR", Vector3(0.025, 0.22, 0.035), Vector3(0.045, -0.18, -0.68), dark)
		muzzle_marker = _muzzle_at(Vector3(0, 0.015, -1.42 if sniper else -1.21))

func _muzzle_at(pos: Vector3) -> Node3D:
	var point := Node3D.new()
	point.name = "Muzzle"
	point.position = pos
	weapon_root.add_child(point)
	return point

func _load_gltf_weapon(id: String) -> bool:
	var packed := load("res://assets/weapons/%s.glb" % ("ak_animated" if id=="ak" else ("sniper_iron" if id=="sniper" else id))) as PackedScene
	if not packed: return false
	var model := packed.instantiate() as Node3D
	if not model: return false
	model.name = "Imported_" + id
	var sizes := {"glock":0.34,"ak":1.1,"sniper":1.25}
	var grip := {"glock":Vector3(0.25,-0.14,0),"ak":Vector3(-0.15,-0.06,0),"sniper":Vector3(-0.16,-0.06,0)}
	var tips := {"glock":Vector3(-0.502,0.3108,0),"ak":Vector3(0.502,0.084,0),"sniper":Vector3(0.502,0.0348,0)}
	model.rotation.y = (-PI if id == "glock" else PI) * 0.5
	model.scale = Vector3.ONE * float(sizes[id])
	model.position = -(model.basis * grip[id])
	model.set_meta("rest_position",model.position)
	model.set_meta("rest_basis",model.basis)
	weapon_root.add_child(model)
	if id=="ak":GameAKReload.prepare(model)
	if id=="sniper":GameSniperIrons.install(model)
	# The physical outlet follows the imported gun during recoil/reload too.
	# Keeping this marker on the actor's weapon root left it behind the mesh.
	muzzle_marker=Marker3D.new();muzzle_marker.name="Muzzle";muzzle_marker.position=tips[id];model.add_child(muzzle_marker)
	var sight := Marker3D.new()
	sight.name = "RearSight"
	sight.position = Vector3(0, (model.transform*tips[id]).y + 0.025, 0.13)
	weapon_root.add_child(sight)
	return true

func _weapon_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color, 0.35)
	weapon_root.add_child(mesh)

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or is_npc or not game or hp <= 0.0: return
	if event is InputEventKey and event.keycode == KEY_ESCAPE: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		trigger_held = false
		if grenade_selected and grenade_aiming and (not grenade_held_id.is_empty() or grenade_prime_pending):
			grenade_aiming=false;game.request_grenade(self);return
	if event is InputEventKey and event.keycode==KEY_G and not event.pressed:
		return
	if not game.gameplay_input_allowed(): return
	if event.is_action_pressed("crouch") and not event.is_echo() and vehicle_id.is_empty():
		set_posture(0 if crouched else 1,true);get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_Z and vehicle_id.is_empty():
			set_posture(0 if prone else 2,true)
		elif event.keycode == KEY_V:
			game.third_person = not game.third_person
			_update_view()
		elif event.keycode == KEY_R: start_reload()
		elif event.keycode == KEY_F and game.has_method("request_supplies"): game.request_supplies(self)
		elif event.keycode == KEY_G and game.has_method("request_grenade") and not game.get_meta("war_mode",false):
			equip_grenade()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9: equip_quick_slot(event.keycode - KEY_1+1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if grenade_selected:
				if grenade_held_id.is_empty() and not grenade_prime_pending: game.prime_grenade(self)
				return
			trigger_held = true
			fire()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not _grenade_active() and GameWeapons.ITEMS[weapon_id].kind in ["firearm","launcher"]:
			cycle_weapon_aim()
	get_viewport().set_input_as_handled()

func apply_look(relative: Vector2) -> void:
	if not is_local or is_npc or not game or not game.gameplay_input_allowed():
		return
	var sensitivity := 0.0023 * aim_sensitivity_scale() * GameAimSensitivity.factor("weapon:"+("grenade" if grenade_selected else GameWeapons.canonical(weapon_id)),aiming or iron_sights)
	yaw -= relative.x * sensitivity
	pitch = clamp_aim_pitch(pitch - relative.y * sensitivity)
	rotation.y = yaw
	camera_pivot.rotation.x = clamp_aim_pitch(pitch + recoil)
	_update_camera_collision(0.0)

func optic_fovs() -> Array:
	return GameWeapons.ITEMS.get(weapon_id,{}).get("optic_fovs",[])

func uses_telescopic_sight() -> bool:
	return iron_sights and not optic_fovs().is_empty()

func cycle_weapon_aim() -> void:
	if hp<=0 or reload_left>0 or not vehicle_id.is_empty():return
	if weapon_optics.enabled(self):
		aiming=not aiming;iron_sights=aiming;scope_level=1 if aiming else 0
		_update_view();return
	var levels:=optic_fovs()
	if not levels.is_empty():
		scope_level=(scope_level+1)%(levels.size()+1)
		aiming=scope_level>0;iron_sights=aiming
	else:
		var now:=Time.get_ticks_msec()*.001
		if aiming and now-aim_click_time<.32: iron_sights=true
		else: aiming=not aiming;iron_sights=false
		aim_click_time=now
	_update_view()

func aim_sensitivity_scale() -> float:
	if iron_sights and weapon_optics.enabled(self): return clampf(1.0 / maxf(1.0, GameOpticCatalog.magnification(weapon_optics.selected_optic,weapon_id)),.08,.5)
	if uses_telescopic_sight(): return .12 if scope_level>=2 else .25
	return .5 if aiming else 1.0

func clamp_aim_pitch(value: float) -> float:
	return clampf(value,-.38 if prone else -1.30,1.25)

func aim_fov(normal:=76.0,soft:=64.0) -> float:
	var offset:=GameOptions.number("fov",normal)-normal
	normal=clampf(normal+offset,60,100);soft=clampf(soft+offset,45,90)
	if weapon_optics.enabled(self) and (iron_sights or weapon_optics.presented()):
		return lerpf(normal,52.0,weapon_optics.blend())
	var levels:=optic_fovs()
	if iron_sights and not levels.is_empty(): return float(levels[clampi(scope_level-1,0,levels.size()-1)])
	return 52.0 if iron_sights else (soft if aiming else normal)

func update_scope_reticle() -> void:
	if not game or not is_local or not is_instance_valid(game.scope_overlay): return
	game.scope_overlay.visible=hp>0 and uses_telescopic_sight() and not _grenade_active()
	if game.scope_overlay.material is ShaderMaterial:
		GameScopeReticle.configure(game.scope_overlay.material,get_viewport().get_visible_rect().size,camera.fov)

func _capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_mouse() -> void:
	mouse_captured = false
	aiming = false
	iron_sights = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_view()

func _update_view() -> void:
	if not camera or not game or game.mode == "naval": return
	if hp<=0:
		aiming=false;iron_sights=false
	if not aiming and not iron_sights: scope_level=0
	var first_person: bool = is_local and (not game.third_person or iron_sights or weapon_optics.presented())
	camera.fov = aim_fov()
	camera.near = 0.035
	camera.position = Vector3.ZERO if first_person else Vector3(0.52, 0.22, 2.0)
	camera_distance = -1.0
	if is_local:
		if not is_instance_valid(view_root) or str(view_root.get_meta("weapon","")) != weapon_id: _refresh_view_weapon()
		view_root.visible = first_person and hp > 0.0 and not uses_telescopic_sight() and not _grenade_active()
	body_root.visible = hp > 0.0
	for part_name in ["Head","Torso","Pelvis","LegL","LegR"]:
		var part := body_root.get_node_or_null(part_name) as Node3D
		if part: part.visible = not first_person
	avatar_parts.arm_l.visible = not first_person
	avatar_parts.arm_r.visible = not first_person
	if weapon_root: weapon_root.visible = not is_npc and hp > 0.0 and not first_person and not _grenade_active()
	if game.aim_dot and is_local: game.aim_dot.visible = not iron_sights
	update_scope_reticle()
	if is_inside_tree() and is_local: _update_camera_collision(0.0)

func _update_camera_collision(delta: float) -> void:
	if not is_local or is_npc or not is_instance_valid(camera) or not game or hp<=0: return
	var first_person: bool = not game.third_person or iron_sights or weapon_optics.presented()
	var offset := Vector3.ZERO if first_person else Vector3(.52,.22,2.0)
	var anchor := camera_pivot.global_position
	var goal := camera_pivot.to_global(offset)
	var safe := CameraObstruction.resolve(get_world_3d(),anchor,goal,[get_rid()])
	var available := anchor.distance_to(safe.position)
	if first_person:
		camera.global_position = safe.position
		camera_distance = 0.0
	else:
		# Immediate inward correction; smooth only when expanding back out.
		if camera_distance<0 or available<camera_distance: camera_distance = available
		else: camera_distance = lerpf(camera_distance,available,1.0-exp(-maxf(delta,0.0)*8.0))
		var direction: Vector3 = (safe.position-anchor).normalized()
		camera.global_position = anchor+direction*camera_distance
	camera_close = not first_person and camera_distance<.42
	# When pressed tightly against a wall, use the existing first-person
	# presentation instead of showing the inside of the avatar's torso.
	# This is local rendering only; the selected view and world muzzle stay intact.
	body_root.visible = hp>0 and not camera_close
	if is_instance_valid(view_root): view_root.visible = (first_person or camera_close) and hp>0 and not uses_telescopic_sight() and not _grenade_active()
	if is_instance_valid(weapon_root): weapon_root.visible = hp>0 and not first_person and not camera_close and not _grenade_active()
	var head := body_root.get_node_or_null("Head") as Node3D
	if head: head.visible = not first_person and not camera_close

func equip_quick_slot(number: int) -> void:
	if hp<=0: return
	var id:=str(GameInventorySlots.resolve(self).get(number,""))
	if id=="grenade": equip_grenade()
	elif not id.is_empty(): equip_slot(["broom","squeegee","axe","ak","glock","sniper","fal","g3"].find(id))

func _process(_delta: float) -> void:
	weapon_optics.update(self)
	if is_local and is_instance_valid(audio_listener):
		var current:=get_viewport().get_camera_3d()
		if is_instance_valid(current): audio_listener.global_basis=current.global_basis.orthonormalized()

func equip_slot(slot: int) -> void:
	if hp<=0: return
	if game and game.get_meta("war_mode",false) and (not bool(get("deployed")) or not str(get("vehicle_id")).is_empty()): return
	var ids := ["broom", "squeegee", "axe", "ak", "glock", "sniper", "fal", "g3"]
	if slot < 0 or slot >= ids.size() or ids[slot] not in active_weapons(): return
	if not grenade_held_id.is_empty() or grenade_prime_pending or grenade_throw_left>0: return
	if grenade_selected:
		grenade_selected=false
		if game.has_method("request_grenade_selection"): game.request_grenade_selection(self,false)
	grenade_aiming=false
	if weapon_id == ids[slot]: _update_view();return
	pause_reload()
	trigger_held = false
	weapon_id = ids[slot]
	aiming = false
	iron_sights = false
	_refresh_weapon()
	_update_weapon_pose()
	_update_view()
	if game:
		game.request_equip(self, weapon_id)
		if game.online and not game.multiplayer.is_server(): resume_reload(weapon_id)
		game.update_hud()

func _physics_process(delta: float) -> void:
	weapon_optics.advance(self,delta)
	if is_local and not is_npc and hp>0 and vehicle_id.is_empty() and is_instance_valid(audio_listener):
		audio_listener_check_clock+=delta
		if audio_listener_check_clock>=.5:
			audio_listener_check_clock=0.
			if get_viewport().get_audio_listener_3d()!=audio_listener:
				audio_listener.make_current()
				if is_instance_valid(game):GameDiagnostics.record("player_audio_listener_recovered",{"mode":str(game.mode),"life":life_id})
	else:
		audio_listener_check_clock=0.
	if shared_human_motion():
		stance.advance(self,delta);locomotion.advance(self,delta)
	GameInfantryPose.advance(self,delta)
	grenade_throw_left=maxf(0,grenade_throw_left-delta)
	if grenade_prime_pending and grenade_held_id.is_empty(): grenade_fuse_left=maxf(0,grenade_fuse_left-delta)
	fire_cooldown = maxf(-delta, fire_cooldown - delta)
	recoil = move_toward(recoil, 0.0, delta * 0.15)
	reaction = move_toward(reaction, 0.0, delta * 4.0)
	attack_anim = move_toward(attack_anim, 0.0, delta * 3.8)
	if reload_left > 0.0:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left == 0.0 and not reload_weapon.is_empty() and (not game.online or game.multiplayer.is_server()):
			complete_reload()
	if game and game.online and not game.multiplayer.is_server() and is_local and hp>0 and not reload_weapon.is_empty() and reload_left<=0:
		reload_sync_wait+=delta
		if reload_sync_wait>.5:
			reload_sync_wait=-.5;game.request_inventory_sync(self)
	else: reload_sync_wait=0
	if not paused_reloads.is_empty() and reload_weapon.is_empty() and game and (not game.online or game.multiplayer.is_server()) and can_resume_reload(weapon_id):
		game._resume_reload(self)
	if hp <= 0.0:
		trigger_held = false
		if is_local and respawn_left > 0.0:
			respawn_left = maxf(0.0, respawn_left - delta)
			if respawn_left == 0.0 and not game.online: respawn()
		return
	_advance_melee(delta)
	if is_npc:
		_npc_step(delta)
		_animate_walk()
		return
	if not is_local:
		if has_network_state and not game.multiplayer.is_server():
			global_position = global_position.lerp(network_target, 1.0 - exp(-delta * 18.0))
			yaw = lerp_angle(yaw, network_yaw, 1.0 - exp(-delta * 18.0))
			pitch = lerpf(pitch, network_pitch, 1.0 - exp(-delta * 18.0))
			rotation.y = yaw
		_animate_walk()
		_update_grenade_pose()
		return
	var controls: bool = game.gameplay_input_allowed() and not game.player_in_vehicle
	if not controls: trigger_held = false;grenade_aiming=false
	elif grenade_selected and grenade_held_id.is_empty() and not grenade_prime_pending: grenade_aiming=true
	elif not grenade_selected and grenade_held_id.is_empty() and not grenade_prime_pending: grenade_aiming=false
	var wish := Input.get_vector("move_left","move_right","move_forward","move_back") if controls and not movement_input_locked() else Vector2.ZERO
	var direction := (transform.basis * Vector3(wish.x,0,wish.y)).normalized()
	var leg_factor := ((0.55 if float(limbs.legL) <= 0.0 else 1.0) * (0.55 if float(limbs.legR) <= 0.0 else 1.0)) if CombatRules.limb_disability_enabled(game) else 1.0
	var sprinting := controls and not movement_input_locked() and Input.is_physical_key_pressed(KEY_SHIFT) and not aiming and not crouched and leg_factor == 1.0
	var speed := move_speed * movement_stance_factor(sprinting) * leg_factor * infantry_protection.multiplier()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 9.81 * delta
	elif controls and not movement_input_locked() and Input.is_action_just_pressed("jump") and leg_factor > 0.5 and can_jump(): velocity.y = 4.4
	GameStepMotion.move(self,delta)
	if game.map_kind=="desert" and not game.get_meta("war_mode",false): game.recover_terrain_position(self)
	if global_position.y < -20.0 and not game.get_meta("war_mode",false):
		global_position = game.find_spawn(peer_id)
		velocity = Vector3.ZERO
	if game.map_kind == "desert" and not game.get_meta("war_mode",false):
		global_position.x = clampf(global_position.x, -149, 149)
		global_position.z = clampf(global_position.z, -149, 149)
	if controls and trigger_held and weapon_spec(weapon_id).mode == "auto": fire()
	camera_pivot.rotation.x = clamp_aim_pitch(pitch + recoil)
	_animate_walk()
	_update_camera_collision(delta)
	_update_grenade_pose()

func _animate_walk() -> void:
	if not is_instance_valid(body_root): return
	var speed := Vector2(velocity.x, velocity.z).length()
	var side_reaction := -1.0 if last_hit_region.ends_with("L") else 1.0
	body_root.rotation.z = reaction * 0.1 * side_reaction
	var gait := sin(Time.get_ticks_msec() * 0.012) * minf(speed / 6.0, 1.0) * 0.32
	var armed: bool = not is_npc
	avatar_parts.leg_l.rotation.x = -gait * (0.2 if float(limbs.legL) <= 0.0 else 1.0)
	avatar_parts.leg_r.rotation.x = gait * (0.2 if float(limbs.legR) <= 0.0 else 1.0)
	avatar_parts.torso.rotation=Vector3.ZERO
	if armed and is_instance_valid(melee_rig) and melee_rig.running:
		body_root.rotation.y = sin(melee_rig.elapsed / float(MeleeRig.SPECS[weapon_id].duration) * TAU) * (0.16 if weapon_id == "broom" else 0.07)
		avatar_parts.torso.rotation.x = -sin(melee_rig.elapsed / float(MeleeRig.SPECS[weapon_id].duration) * PI) * 0.12
	else: body_root.rotation.y=0.
	if not is_npc: locomotion_torso_pose()
	if not is_npc and _grenade_active():
		avatar_parts.torso.rotation.x=-sin((1-grenade_throw_left/.75)*PI)*.06 if grenade_throw_left>0 else 0.
	GameInfantryPose.apply(self)
	_finish_body_pose()
	if armed:
		_update_weapon_pose()
		_pose_weapon_arms()
	else:
		var punch := sin(clampf(npc_attack_clock / 0.65,0.0,1.0) * PI) if npc_attack_clock >= 0.0 else 0.0
		avatar_parts.arm_l.rotation = Vector3(gait * 0.7 - punch * 0.9, 0, 0)
		avatar_parts.arm_r.rotation = Vector3(-gait * 0.7 - punch * 1.8, 0, 0)
		if float(limbs.armL) <= 0.0: avatar_parts.arm_l.rotation = Vector3(0.10,0,0.12)
		if float(limbs.armR) <= 0.0: avatar_parts.arm_r.rotation = Vector3(0.10,0,-0.12)
		avatar_parts.torso.rotation.x = punch * -0.10
	if not is_npc and (grenade_selected or not grenade_held_id.is_empty() or grenade_prime_pending or grenade_throw_left>0):
		var progress:=1-grenade_throw_left/.75
		var local_grip:=Vector3(.32,-.26,-.48)
		if grenade_throw_left>0: local_grip+=Vector3(-.10,.12,-.35)*sin(progress*PI)
		var aimed_grip: Vector3=camera_pivot.global_position+global_basis*Basis(Vector3.RIGHT,pitch)*local_grip
		_pose_arm(avatar_parts.arm_r,aimed_grip,"armR")
		_pose_arm(avatar_parts.arm_l,camera_pivot.global_position+global_basis*Vector3(-.26,-.40,-.18),"armL")
	if shared_human_motion():
		locomotion.pose_body(self);stance.pose(self)

func _finish_body_pose() -> void:
	pass # Modes finalize their body before solving the real weapon and grips.

func weapon_hand_target(support: bool) -> Vector3:
	if is_instance_valid(melee_rig):
		return (melee_rig.grip_left if support else melee_rig.grip_right).global_position
	var id:=GameWeapons.canonical(weapon_id)
	if id=="ak":return _ak_hand_target(support)
	if id=="sniper":return _sniper_hand_target(support)
	var model:=weapon_root.get_node_or_null("Imported_"+id) as Node3D
	if model and id in ["fal","glock","g3"]:
		if support:
			var pose:=reload_pose_state(id,reload_left if GameWeapons.canonical(reload_weapon)==id else 0.,reload_total)
			return model.to_global(pose.hand)
		return model.get_node("GripRight").global_position
	var marker:=weapon_root.find_child("GripLeft" if support else "GripRight",true,false) as Node3D
	if marker:return marker.global_position
	return weapon_root.to_global(Vector3(0,-.015,-.16) if support else Vector3.ZERO)

func _pose_weapon_arms() -> void:
	if not is_instance_valid(weapon_root):return
	_pose_arm(avatar_parts.arm_r,weapon_hand_target(false),"armR")
	_pose_arm(avatar_parts.arm_l,weapon_hand_target(true),"armL")

func shared_human_motion() -> bool:
	# WarPlayer already advances and applies this same controller itself.
	return not self is WarPlayer

func in_water() -> bool:
	return false

func emit_step_sound(sequence: int,point: Vector3,running: bool) -> void:
	if is_instance_valid(game.footsteps):game.footsteps.play_step(peer_id,life_id,sequence,point,running,crouched)

func locomotion_torso_pose() -> void:
	locomotion.pose_torso(self)

func grenade_hand_position() -> Vector3:
	return avatar_parts.arm_r.get_node("HandR").global_position+global_basis*Basis(Vector3.RIGHT,pitch)*Vector3(0,.06,-.10)

func _weapon_offset() -> Vector3:
	if (iron_sights or weapon_optics.presented()) and weapon_optics.enabled(self):
		return Vector3(.24,-.24,-.62).lerp(weapon_optics.aimed_offset(weapon_id),weapon_optics.blend())
	if iron_sights and is_instance_valid(muzzle_marker):
		if GameWeapons.canonical(weapon_id)=="g3":return Vector3(0,-G3Model.SIGHT_Y,-.48)
		if GameWeapons.canonical(weapon_id)=="glock": return Vector3(0,-GlockModel.SIGHT_Y,-.48)
		if GameWeapons.canonical(weapon_id)=="sniper":
			var rear:=weapon_root.find_child("RearIron",true,false) as Node3D
			if rear:
				var sight:=weapon_root.to_local(rear.global_position)
				return Vector3(-sight.x,-sight.y,-.62)
			return Vector3(0,-.18,-.62)
		var height:=muzzle_marker.position.y
		if muzzle_marker.get_parent()!=weapon_root: height=(muzzle_marker.get_parent().transform*muzzle_marker.position).y
		return Vector3(0,-FALModel.SIGHT_Y,-0.48) if GameWeapons.canonical(weapon_id)=="fal" else Vector3(0,-height - (0.10 if GameWeapons.canonical(weapon_id) == "ak" else 0.040),-0.62)
	return Vector3(0.24,-0.24,-0.46 if GameWeapons.canonical(weapon_id) == "glock" else -0.62)

func active_weapons() -> Array:
	if get_meta("awaiting_deployment",false): return []
	if loadout.is_empty(): return owned
	return owned.filter(func(id): return id in loadout)

func clear_weapon_aim() -> void:
	aiming=false;iron_sights=false;trigger_held=false;aim_click_time=-1
	_update_view()

func clear_aim() -> void:
	aiming=false;iron_sights=false;trigger_held=false;aim_click_time=-1;grenade_aiming=false
	_update_view()

func _update_weapon_pose() -> void:
	if not weapon_root or is_npc: return
	var aim_pitch := clamp_aim_pitch(pitch + (recoil if is_local else 0.0))
	var basis_pitch := Basis(Vector3.RIGHT, aim_pitch)
	weapon_root.position = camera_pivot.position + basis_pitch * _weapon_offset()
	weapon_root.rotation = Vector3(aim_pitch,0,0)
	weapon_root.scale = Vector3.ONE
	if GameWeapons.ITEMS[weapon_id].kind in ["firearm","launcher"]:
		var offset:=Vector3(.15,-.045,-.38) if GameWeapons.canonical(weapon_id) in ["fal","g3"] else (Vector3(.20,-.035,-.48) if GameWeapons.canonical(weapon_id)=="glock" else Vector3(.23,-.06,-.53))
		weapon_root.transform=GameInfantryPose.weapon_pose(self,offset)
		if (iron_sights or weapon_optics.presented()) and weapon_optics.enabled(self):
			# One deterministic pose for the real weapon, its FPP copy and the
			# server's muzzle. Do not keep the combat weapon at the hip while
			# drawing a second copy centred under the optic.
			var optical_basis:=basis_pitch*Basis(Vector3.BACK,-lean*GameInfantryPose.LEAN_ROLL)
			var aimed:=Transform3D(optical_basis,camera_pivot.position+optical_basis*weapon_optics.aimed_offset(weapon_id))
			weapon_root.transform=weapon_root.transform.interpolate_with(aimed,weapon_optics.blend())
	if is_instance_valid(melee_rig):
		weapon_root.position = camera_pivot.position + Basis(Vector3.RIGHT,clampf(pitch,-0.65,0.65)) * Vector3(0.20,-0.48,-0.38)
		weapon_root.rotation.x = clampf(pitch,-0.65,0.65)
	if is_instance_valid(view_root):
		view_root.position = Vector3(0.42,-0.60,-0.90) if is_instance_valid(melee_rig) else _weapon_offset()
		view_root.rotation = Vector3.ZERO
		if is_instance_valid(melee_rig):
			var copy := view_root.get_node_or_null("MeleeView") as Node3D
			if copy:
				copy.transform = melee_rig.swing.transform
				for side in ["R","L"]:
					var arm := view_root.get_node_or_null("MeleeForearm"+side) as Node3D
					if not arm: continue
					var marker := melee_rig.grip_right if side == "R" else melee_rig.grip_left
					var hand := copy.transform * marker.position
					var anchor := Vector3(0.22,-0.30,0.65) if side == "R" else Vector3(-0.50,-0.35,0.62)
					var delta := hand-anchor
					arm.position = (hand+anchor)*0.5
					arm.basis = Basis(Quaternion(Vector3.UP,delta.normalized()))
					arm.scale.y = delta.length()
	var model := weapon_root.get_node_or_null("Imported_" + GameWeapons.canonical(weapon_id)) as Node3D
	if model:
		var progress := reload_left / maxf(reload_total,0.001)
		model.rotation.z = sin(progress * PI) * -0.65
		var rest: Vector3 = model.get_meta("rest_position",Vector3.ZERO)
		model.position = rest + Vector3(sin(progress * PI) * -0.06,0,attack_anim * 0.08)
		var reload_pose: Dictionary={}
		if GameWeapons.canonical(weapon_id) in ["fal","glock","g3"]:
			reload_pose=reload_pose_state(weapon_id,reload_left if reload_weapon==weapon_id else 0.,reload_total)
			model.rotation=reload_pose.angles;model.position=rest+Vector3(reload_pose.offset)+Vector3(0,0,attack_anim*.08)
			GameReloadPose.apply(model,weapon_id,reload_pose)
		elif GameWeapons.canonical(weapon_id) in ["sniper","ak"]:
			reload_pose=reload_pose_state(weapon_id,reload_left if reload_weapon==weapon_id else 0.,reload_total)
			model.basis=Basis.from_euler(reload_pose.angles)*Basis(model.get_meta("rest_basis"))
			model.position=rest+Vector3(reload_pose.offset)+Vector3(0,0,attack_anim*.08)
			if GameWeapons.canonical(weapon_id)=="ak":GameReloadPose.apply(model,weapon_id,reload_pose)
		if is_instance_valid(view_root):
			var copy := view_root.get_node_or_null(NodePath(model.name)) as Node3D
			if copy:
				copy.transform = model.transform
				if not reload_pose.is_empty(): GameReloadPose.apply(copy,weapon_id,reload_pose)
	if GameWeapons.canonical(weapon_id)=="sniper": _update_sniper_view_hands()
	elif GameWeapons.canonical(weapon_id)=="ak":_update_ak_view_hands()
	else:_update_first_person_hands()
	if shared_human_motion():
		locomotion.pose_weapon(self)

func reload_pose_state(id: String,left: float,total: float) -> Dictionary:
	# The weapon, support hand and FPP hands read the same reload state.
	# Cache exact arguments, so every reload tick still changes immediately.
	if id!=_reload_pose_weapon or left!=_reload_pose_left or total!=_reload_pose_total:
		_reload_pose_weapon=id;_reload_pose_left=left;_reload_pose_total=total
		_reload_pose_state=GameReloadPose.state(id,left,total)
	return _reload_pose_state

func _ak_hand_target(support: bool) -> Vector3:
	var model:=weapon_root.get_node_or_null("Imported_ak") as Node3D
	if not model:return weapon_root.global_position
	var pose:=reload_pose_state("ak",reload_left if GameWeapons.canonical(reload_weapon)=="ak" else 0.,reload_total)
	return GameAKReload.hand(model,pose,support)

func _update_ak_view_hands() -> void:
	if not is_local or not is_instance_valid(view_root):return
	var model:=view_root.get_node_or_null("Imported_ak") as Node3D
	if not model:return
	var pose:=reload_pose_state("ak",reload_left if GameWeapons.canonical(reload_weapon)=="ak" else 0.,reload_total)
	var gun_basis:=view_root.global_basis.inverse()*GameAKReload.hand_basis(model)
	for side in ["Right","Left"]:
		var support: bool=side=="Left"
		var hand:=view_root.get_node_or_null("SupportHand" if support else "GripHand") as MeshInstance3D
		var forearm:=view_root.get_node_or_null(side+"Forearm") as MeshInstance3D
		if not hand or not forearm:continue
		var grip:=GameAKReload.hand(model,pose,support);hand.position=view_root.to_local(grip);hand.basis=gun_basis
		var grasp: bool=support and bool(pose.hand_grabbing)
		hand.mesh=WarHumanRig.grip_glove(support,grasp);hand.material_override=presentation_material(support,true)
		var wrist:=hand.position+gun_basis*(Vector3(-.035,-.029,.075) if support and not grasp else Vector3(.023,-.025,.085))
		var anchor:=Vector3(-.31,-.22,.20) if support else Vector3(.15,-.24,.43)
		forearm.position=(anchor+wrist)*.5
		var length:=wrist.distance_to(anchor)
		var base:=forearm.mesh.get_aabb().size.y
		forearm.basis=Basis(Quaternion(Vector3.DOWN,(wrist-anchor).normalized()))*Basis.from_scale(Vector3(1,length/maxf(.01,base),1))

func _sniper_hand_target(support: bool) -> Vector3:
	var model:=weapon_root.get_node_or_null("Imported_sniper") as Node3D
	if not model: return weapon_root.global_position
	var pose:=reload_pose_state("sniper",reload_left if GameWeapons.canonical(reload_weapon)=="sniper" else 0.,reload_total)
	return weapon_root.to_global(GameReloadPose.sniper_hand(model,pose.hand if support else pose.right_hand))

func _update_sniper_view_hands() -> void:
	if not is_local or not is_instance_valid(view_root): return
	var model:=view_root.get_node_or_null("Imported_sniper") as Node3D
	if not model: return
	var pose:=reload_pose_state("sniper",reload_left if GameWeapons.canonical(reload_weapon)=="sniper" else 0.,reload_total)
	for side in ["Right","Left"]:
		var support: bool=side=="Left"
		var hand:=view_root.get_node_or_null("SupportHand" if support else "GripHand") as MeshInstance3D
		var forearm:=view_root.get_node_or_null(side+"Forearm") as MeshInstance3D
		if not hand or not forearm: continue
		hand.position=GameReloadPose.sniper_hand(model,pose.hand if support else pose.right_hand)
		var anchor:=Vector3(-.31,-.22,.20) if support else Vector3(.15,-.24,.43)
		var grasp: bool=support and bool(pose.hand_grabbing)
		var wrist:=hand.position+(Vector3(-.035,-.029,.075) if support and not grasp else Vector3(.023,-.025,.085))
		forearm.position=(anchor+wrist)*.5
		var length:=maxf(.001,wrist.distance_to(anchor))
		hand.mesh=WarHumanRig.grip_glove(support,grasp);hand.material_override=presentation_material(support,true)
		var original: float=forearm.mesh.get_aabb().size.y
		forearm.basis=Basis(Quaternion(Vector3.DOWN,(wrist-anchor).normalized()))*Basis.from_scale(Vector3(1,length/original,1))

func presentation_material(support: bool,hand: bool) -> Material:
	var arm:=avatar_parts.get("arm_l" if support else "arm_r") as Node3D
	var part:=arm.get_node_or_null(("Hand" if hand else "Forearm")+("L" if support else "R")+("" if hand else "Mesh")) as MeshInstance3D if arm else null
	return part.material_override if part else GameCharacterColors.material(GameCharacterColors.normalize(get_meta("body_colors",{})).skin)

func _update_first_person_hands() -> void:
	var id:=GameWeapons.canonical(weapon_id)
	if not is_local or not is_instance_valid(view_root):return
	var firearm: bool=id in ["fal","glock","g3"]
	if not firearm and not GameWeapons.is_launcher(id) and id!="binoculars":return
	var model:=view_root.get_node_or_null("Imported_"+id) as Node3D
	if firearm and not model:return
	var pose:=reload_pose_state(id,reload_left if GameWeapons.canonical(reload_weapon)==id else 0.,reload_total) if firearm else {}
	var gun_basis:=view_root.global_basis.inverse()*model.global_basis if model else Basis.IDENTITY
	for support in [false,true]:
		var hand:=view_root.get_node_or_null("SupportHand" if support else "GripHand") as MeshInstance3D
		var forearm:=view_root.get_node_or_null("LeftForearm" if support else "RightForearm") as MeshInstance3D
		if not hand or not forearm:continue
		if firearm:
			var point: Vector3=pose.hand if support else (GlockModel.GRIP if id=="glock" else (G3Model.GRIP if id=="g3" else FALModel.GRIP))
			hand.position=view_root.to_local(model.to_global(point))
		else:
			var marker:=view_root.find_child("GripLeft" if support else "GripRight",true,false) as Node3D
			if not marker:continue
			hand.position=view_root.to_local(marker.global_position)
		hand.basis=gun_basis
		var grasp: bool=firearm and (id=="glock" or support and bool(pose.hand_grabbing))
		hand.mesh=WarHumanRig.grip_glove(support,grasp) if firearm else WarHumanRig.glove(-1 if support else 1)
		hand.material_override=presentation_material(support,true)
		var cuff:=Vector3(-.035,-.029,.075) if support and not grasp else Vector3(.023,-.025,.085)
		var wrist:=hand.position+gun_basis*(cuff if firearm else Vector3(0,.067,0))
		var anchor:=Vector3(-.31,-.22,.20) if support else Vector3(.15,-.24,.43)
		forearm.position=(wrist+anchor)*.5
		forearm.basis=Basis(Quaternion(Vector3.DOWN,(wrist-anchor).normalized()))*Basis.from_scale(Vector3(1,wrist.distance_to(anchor)/maxf(.01,forearm.mesh.get_aabb().size.y),1))

func _pose_arm(arm: Node3D, hand_position: Vector3, group: String) -> void:
	if CombatRules.limb_disability_enabled(game) and float(limbs.get(group,100.0)) <= 0.0:
		arm.rotation = Vector3(0.10,0,0.12 if group == "armL" else -0.12)
		return
	if get_meta("articulated_arms",false):
		WarHumanRig.pose(self,arm,hand_position,group);return
	var local_target := body_root.to_local(hand_position)
	var direction := local_target - arm.position
	if direction.length_squared() < 0.001: return
	arm.basis = Basis(Quaternion(Vector3.DOWN,direction.normalized()))
	var proportion := float(body_proportions.get("arms",1.0))
	arm.scale = Vector3(proportion, clampf(direction.length() / 0.78,0.6,1.5),proportion)

func _set_crouched(value: bool) -> void:
	if prone and (not is_local or not value):return
	set_posture(1 if value else 0,is_local)

func set_posture(value: int,notify:=false,validated:=false) -> bool:
	if value not in [0,1,2]:return false
	if value==(2 if prone else (1 if crouched else 0)):return true
	if not stance.apply_collision(self,value,not validated):return false
	pitch=clamp_aim_pitch(pitch);network_pitch=clamp_aim_pitch(network_pitch)
	if is_instance_valid(camera_pivot):camera_pivot.rotation.x=clamp_aim_pitch(pitch+recoil)
	if notify and is_instance_valid(game) and game.has_method("request_infantry_posture"):game.request_infantry_posture(self,value)
	return true

func movement_input_locked() -> bool:return false

func movement_stance_factor(sprinting: bool) -> float:
	return .24 if prone else (.53 if crouched else (1.4 if sprinting else 1.))

func can_jump() -> bool:
	return not prone

func play_fire_animation(id: String) -> void:
	if GameWeapons.ITEMS[id].kind == "melee":
		if is_instance_valid(melee_rig) and melee_rig.id == id: melee_rig.start()
		_update_weapon_pose()
		return
	attack_anim = 0.78 if GameWeapons.ITEMS[id].kind == "melee" else 0.16
	if weapon_root:
		weapon_root.rotation.x = 0.22 if GameWeapons.ITEMS[id].kind == "melee" else -0.08
	if game and game.third_person:
		_animate_walk()

func play_remote_reload(id: String, duration: float,remaining: float=-1.0) -> void:
	if hp<=0 or weapon_id != id: return
	begin_reload(id,duration,remaining)

func _npc_step(delta: float) -> void:
	if not game or not is_instance_valid(game.local_player) or hp <= 0.0:
		velocity = Vector3.ZERO
		return
	var target: GamePlayer = game.local_player
	if target.hp <= 0.0:
		velocity = Vector3.ZERO
		return
	var to_target := target.global_position - global_position
	to_target.y = 0
	npc_attack_wait = maxf(0.0, npc_attack_wait - delta)
	if npc_attack_clock >= 0.0:
		npc_attack_clock += delta
		if npc_attack_clock >= 0.31 and not npc_attack_landed:
			npc_attack_landed = true
			if to_target.length() <= 1.85 and (float(limbs.armL)>0.0 or float(limbs.armR)>0.0) and game.npc_line_clear(global_position,target.global_position):
				target.last_impact_weapon = "broom"
				target.last_impact_direction = to_target.normalized()
				target.take_damage(8.0,"chest",peer_id)
		if npc_attack_clock >= 0.65: npc_attack_clock = -1.0
	if to_target.length() > 1.55:
		var d := to_target.normalized()
		npc_avoid_timer -= delta
		if npc_avoid_timer <= 0.0:
			npc_avoid_timer = 0.22 + posmod(peer_id,5)*0.023
			npc_avoid_direction = _npc_path_direction(d, target)
		var move_dir := npc_avoid_direction if game.offline_director != null or npc_avoid_direction.length_squared() > 0.1 else d
		var speed := 1.9 + minf(float(game.offline_elapsed) / 180.0,1.0) * 0.7
		var leg_factor := ((0.55 if float(limbs.legL) <= 0.0 else 1.0) * (0.55 if float(limbs.legR) <= 0.0 else 1.0)) if CombatRules.limb_disability_enabled(game) else 1.0
		move_dir = (move_dir + game.npc_separation(self) * 0.7).normalized()
		velocity.x = move_dir.x * speed * leg_factor * (0.6 if reaction > 0.0 else 1.0)
		velocity.z = move_dir.z * speed * leg_factor * (0.6 if reaction > 0.0 else 1.0)
		yaw = atan2(-move_dir.x, -move_dir.z)
		rotation.y = yaw
	else:
		velocity.x = 0
		velocity.z = 0
		if npc_attack_wait <= 0.0:
			npc_attack_wait = 1.1 - minf(float(game.offline_elapsed) / 240.0,1.0)*0.25
			npc_attack_clock = 0.0
			npc_attack_landed = false
		yaw = atan2(-to_target.x,-to_target.z)
		rotation.y = yaw
	if not is_on_floor(): velocity.y -= 9.81 * delta
	GameStepMotion.move(self,delta)

func _npc_path_direction(desired: Vector3, target: GamePlayer) -> Vector3:
	if game.offline_director != null:
		return game.offline_director.direction_for(self,target)
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.9
	var excluded: Array[RID] = [get_rid()]
	for candidate in game.players.values():
		if is_instance_valid(candidate) and candidate is GamePlayer:
			excluded.append(candidate.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + desired * 1.7, 1, excluded)
	if space.intersect_ray(query).is_empty():
		return desired
	var best := Vector3.ZERO
	var best_score := -INF
	for degrees in [-100.0, -70.0, 70.0, 100.0, 145.0, -145.0]:
		var candidate_dir := desired.rotated(Vector3.UP, deg_to_rad(degrees)).normalized()
		var side_query := PhysicsRayQueryParameters3D.create(origin, origin + candidate_dir * 1.65, 1, excluded)
		if space.intersect_ray(side_query).is_empty():
			var score := candidate_dir.dot(desired)
			if score > best_score:
				best_score = score
				best = candidate_dir
	return best if best != Vector3.ZERO else -desired

func fire() -> void:
	if grenade_selected or grenade_throw_left>0 or grenade_aiming or not grenade_held_id.is_empty() or grenade_prime_pending: return
	if fire_cooldown > 0.0 or not reload_weapon.is_empty() or hp <= 0.0 or not game or game.player_in_vehicle: return
	if is_local and not game.gameplay_input_allowed(): return
	var item := weapon_spec(weapon_id)
	var melee: bool = item.kind == "melee"
	if melee and CombatRules.limb_disability_enabled(game) and float(limbs.armR) <= 0.0 and float(limbs.armL) <= 0.0: return
	if not melee and int(ammo.get(weapon_id,0)) <= 0:
		fire_cooldown=.20
		if is_local and is_instance_valid(game.combat_feedback): game.combat_feedback.play("empty",get_muzzle_position())
		return
	if CombatRules.limb_disability_enabled(game):
		if float(limbs.armR) <= 0.0 and not melee: return
		if GameWeapons.canonical(weapon_id) in ["ak","fal","sniper","g3"] and float(limbs.armL) <= 0.0: return
	fire_cooldown = float(item.cooldown)+minf(0.0,fire_cooldown) if item.mode=="auto" and trigger_held else float(item.cooldown)
	_update_weapon_pose()
	shot_sequence += 1
	last_camera_origin = camera.global_position
	last_view_direction = -camera.global_basis.z.normalized()
	var from := camera_pivot.global_position if melee else get_muzzle_position()
	if game.online and not game.multiplayer.is_server():
		if not melee:
			ammo[weapon_id] = maxi(0,int(ammo[weapon_id]) - 1)
			pending_shots[shot_sequence] = weapon_id
		present_fire()
		game.play_weapon_sound(weapon_id,from,peer_id)
		set_meta("predicted_audio_sequence",shot_sequence)
	shot_requested.emit(self, from, last_view_direction, weapon_id, melee)
	game.update_hud()

func get_muzzle_position() -> Vector3:
	_update_weapon_pose()
	return muzzle_marker.global_position if is_instance_valid(muzzle_marker) else weapon_root.global_position

func shot_camera_valid(origin: Vector3,_direction: Vector3) -> bool:
	return origin.distance_to(camera_pivot.global_position)<=3.8

func present_fire() -> void:
	play_fire_animation(weapon_id)
	if is_local:
		recoil = minf(0.18,recoil + float(weapon_spec(weapon_id).recoil))
		camera_pivot.rotation.x = clamp_aim_pitch(pitch + recoil)
		# The FPP copy inherits this camera rotation immediately. Move the real
		# held weapon in the same event instead of leaving its muzzle behind
		# until the next physics tick (visible during live scoped firefights).
		_update_weapon_pose()

func start_reload() -> void:
	if hp<=0 or _grenade_active(): return
	if reload_left>0 or not ammo.has(weapon_id):
		if game and game.online and not game.multiplayer.is_server() and is_local: game.request_inventory_sync(self)
		return
	if game and game.get_meta("war_mode",false) and (not str(get("vehicle_id")).is_empty() or bool(get("gadget_equipped"))): return
	if int(ammo[weapon_id]) >= int(weapon_spec(weapon_id).mag) or int(reserves.get(weapon_id,0)) <= 0: return
	if game: game.request_reload(self,weapon_id,float(weapon_spec(weapon_id).reload))

func weapon_spec(id: String) -> Dictionary:
	return GameAttachmentState.effective(CombatRules.weapon(id),id,GameAttachmentManager.actor_configuration(self,id))

func begin_reload(id: String,duration: float,remaining: float=-1.0) -> void:
	if hp<=0 or not ammo.has(id) or not is_finite(duration) or duration<=0: return
	_stop_reload_presentation()
	if id=="sniper" and id==weapon_id and is_local and iron_sights:
		scope_level=0;clear_weapon_aim()
	paused_reloads.erase(id)
	reload_weapon = id
	reload_total = duration
	reload_left = duration if remaining<0 else clampf(remaining,.001,duration)
	reload_revision+=1
	trigger_held = false
	if game: reload_audio = game.play_reload_sound(id,global_position,self,maxf(0,reload_total-reload_left))

func pause_reload() -> void:
	if reload_weapon.is_empty(): return
	if hp>0 and reload_left>0:
		paused_reloads[reload_weapon]={"left":reload_left,"total":reload_total,"life":life_id}
	_stop_reload_presentation()
	reload_revision+=1

func can_resume_reload(id: String) -> bool:
	if hp<=0 or weapon_id!=id or _grenade_active() or not reload_weapon.is_empty() or not paused_reloads.has(id) or not ammo.has(id): return false
	if game and game.get_meta("war_mode",false) and (not str(get("vehicle_id")).is_empty() or bool(get("gadget_equipped"))): return false
	var state: Dictionary=paused_reloads[id]
	return int(state.get("life",-1))==life_id and float(state.get("left",0))>0 and int(ammo[id])<int(weapon_spec(id).mag) and int(reserves.get(id,0))>0

func resume_reload(id: String) -> bool:
	if not can_resume_reload(id): return false
	var state: Dictionary=paused_reloads[id].duplicate()
	begin_reload(id,float(state.total),float(state.left))
	return true

func apply_reload_state(id: String,remaining: float,total: float,paused: Dictionary,revision: int) -> void:
	if revision>=0 and revision<authoritative_reload_revision: return
	if hp<=0:
		_stop_reload_presentation();paused_reloads.clear()
		if revision>=0: authoritative_reload_revision=revision
		return
	var clean: Dictionary={}
	for key in paused:
		if not ammo.has(str(key)) or not paused[key] is Dictionary: continue
		var record: Dictionary=paused[key]
		var left:=float(record.get("left",0));var length:=float(record.get("total",0))
		if int(record.get("life",-1))!=life_id or not is_finite(left) or not is_finite(length) or left<=0 or length<=0: continue
		clean[str(key)]={"left":minf(left,length),"total":length,"life":life_id}
	paused_reloads=clean
	var active:=not id.is_empty() and ammo.has(id) and is_finite(remaining) and remaining>=0 and hp>0
	if not active:
		# Ammo acknowledgements arrive after every shot. An idle reload state
		# must not release the physical trigger of an automatic weapon.
		if not reload_weapon.is_empty() or reload_left>0 or is_instance_valid(reload_audio): _stop_reload_presentation()
	else:
		var length:=total if total>0 else float(weapon_spec(id).reload)
		var changed:=reload_weapon!=id or not is_equal_approx(reload_total,length)
		if changed:
			begin_reload(id,length,maxf(.001,remaining))
		else: reload_left=clampf(remaining,0,length)
		paused_reloads.erase(id)
	if revision>=0: authoritative_reload_revision=revision

func complete_reload() -> void:
	var id := reload_weapon
	if id.is_empty() or (game and game.online and not game.multiplayer.is_server()): return
	if hp > 0.0 and weapon_id == id and ammo.has(id):
		var result := CombatRules.transfer_ammo(int(ammo[id]),int(reserves.get(id,0)),int(weapon_spec(id).mag))
		ammo[id] = result.x
		reserves[id] = result.y
	paused_reloads.erase(id)
	_stop_reload_presentation()
	reload_revision+=1
	if game:
		game.sync_inventory(self)
		game.update_hud()

func cancel_reload() -> void:
	_stop_reload_presentation()
	paused_reloads.clear()
	reload_revision+=1

func _stop_reload_presentation() -> void:
	if is_instance_valid(reload_audio):
		reload_audio.stop()
		reload_audio.queue_free()
	reload_audio = null
	reload_left = 0.0
	reload_weapon = ""
	reload_total = 0.0
	trigger_held = false

func take_damage(amount: float, region := "chest", killer_id := 0) -> void:
	if hp <= 0.0 or amount <= 0.0 or (game and game.online and not game.multiplayer.is_server()): return
	last_hit_region = region
	var group := CombatRules.region_group(region)
	var actual := health_damage(amount,region)
	var limb_damage:=minf(amount,actual/maxf(.01,float(CombatRules.DAMAGE.get(region,1.)))) if infantry_protection.enabled else amount
	limbs[group] = maxf(0.0,float(limbs.get(group,100.0)) - limb_damage)
	reaction = 0.45
	hp = maxf(0.0,hp - actual)
	var mode_rules: Dictionary = CombatRules.MODES.get(game.mode if game else "training",CombatRules.MODES.pvp)
	if float(limbs[group]) <= 0.0 and mode_rules.dismemberment and bool(CombatRules.weapon(last_impact_weapon).sever):
		detached_region = group
	if game and is_local: game.damage_feedback(hp)
	if hp <= 0.0:
		clear_aim()
		cancel_melee()
		cancel_reload()
		_hide_dead_presentations()
		deaths += 1
		set_meta("death_velocity",velocity)
		velocity = Vector3.ZERO
		body_root.visible = false
		weapon_root.visible = false
		_set_hitboxes_enabled(false)
		if body_collision: body_collision.set_deferred("disabled",true)
		respawn_left = 4.0 if game and game.online else 2.0
		player_died.emit(self,killer_id)
		if is_npc: queue_free()

func health_damage(amount: float,region: String) -> float:
	if region=="head" and GameWeapons.ITEMS.has(last_impact_weapon) and GameWeapons.ITEMS[last_impact_weapon].kind=="melee":return amount*float(CombatRules.DAMAGE.head)
	return infantry_protection.damage(self,amount,region,CombatRules.health_damage(amount,region,game.mode if game else "training"))

func _hide_dead_presentations() -> void:
	# These are world meshes parented to the personal camera, so hiding the
	# third-person weapon alone does not hide them from a cinematic camera.
	for visual in [view_root,grenade_view,grenade_prop]:
		if is_instance_valid(visual): visual.hide()

func respawn() -> void:
	GameInfantryPose.reset(self)
	if game and game.has_method("defer_respawn_selection") and game.defer_respawn_selection(self): return
	cancel_melee()
	grenades=2 if grenades_enabled else 0;grenade_throw_left=0;grenade_aiming=false;grenade_held_id="";grenade_selected=false;grenade_prime_pending=false;grenade_fuse_left=0
	hp = 100.0
	life_id += 1
	infantry_protection.deploy(self)
	stance.reset(self);locomotion.reset(self)
	fire_cooldown=0;trigger_held=false;reload_sync_wait=0
	limbs = CombatRules.fresh_limbs()
	detached_region = ""
	reserves = CombatRules.fresh_reserves()
	pending_shots.clear()
	cancel_reload()
	last_hit_region = "chest"
	ammo = GameWeapons.fresh_ammo()
	velocity = Vector3.ZERO
	recoil = 0.0
	reload_left = 0.0
	reload_weapon = ""
	aiming = false
	iron_sights = false
	crouched = false
	body_root.visible = true
	_set_hitboxes_enabled(true)
	if body_collision: body_collision.disabled = false
	if game:
		if body_collision and body_collision.shape is CapsuleShape3D:
			body_collision.shape.height = 1.75
			body_collision.position.y = 0.87
		body_root.scale = Vector3.ONE
		camera_pivot.position.y = 1.68
		_update_view()
		global_position = game.find_spawn(peer_id)
		yaw = 0.0
		pitch = 0.0
		rotation = Vector3.ZERO
		camera_pivot.rotation = Vector3.ZERO
		previous_position = global_position
		game.damage_feedback(100.0)
		game.update_hud()
		game.finish_respawn(self)

func get_region_at(point: Vector3) -> String:
	var closest := "torso"
	var best := INF
	for key in hit_regions:
		var area: Area3D = hit_regions[key]
		if not is_instance_valid(area) or not area.is_inside_tree():
			continue
		var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not shape_node or not shape_node.shape is BoxShape3D:
			continue
		var half := (shape_node.shape as BoxShape3D).size * 0.5
		var local_point := area.to_local(point) - shape_node.position
		var normalized := Vector3(absf(local_point.x) / maxf(half.x, 0.001), absf(local_point.y) / maxf(half.y, 0.001), absf(local_point.z) / maxf(half.z, 0.001))
		var outside_distance := Vector3(maxf(0.0, normalized.x - 1.0), maxf(0.0, normalized.y - 1.0), maxf(0.0, normalized.z - 1.0)).length()
		var score := outside_distance * 10.0 + normalized.length() * 0.01
		if score < best:
			best = score
			closest = str(key)
	return closest

func _set_hitboxes_enabled(enabled: bool) -> void:
	for value in hit_regions.values():
		if not is_instance_valid(value):
			continue
		var area := value as Area3D
		if is_instance_valid(area): area.collision_layer = 2 if enabled else 0
		if not area:
			continue
		# Some articulated regions are reparented/rebuilt and Godot assigns an
		# auto-generated node name (for example @CollisionShape3D@1017). Do not
		# rely on the literal node name when toggling physical hit regions.
		var shape := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not is_instance_valid(shape):
			for child in area.get_children():
				if child is CollisionShape3D:
					shape=child as CollisionShape3D
					break
		if is_instance_valid(shape):
			shape.set_deferred("disabled", not enabled)

func receive_network_state(pos: Vector3, new_yaw: float, new_pitch: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if last_snapshot_time > 0.0:
		velocity = (pos - last_snapshot_position) / maxf(0.02,now - last_snapshot_time)
	last_snapshot_position = pos
	last_snapshot_time = now
	network_target = pos
	network_yaw = new_yaw
	network_pitch = new_pitch
	has_network_state = true
	if game.multiplayer.is_server():
		global_position = pos
		yaw = new_yaw
		pitch = new_pitch
		rotation.y = yaw
	_update_weapon_pose()

func _refresh_view_weapon() -> void:
	if not is_local: return
	if is_instance_valid(view_root):
		var previous_parent:=view_root.get_parent()
		if is_instance_valid(previous_parent):previous_parent.remove_child(view_root)
		view_root.queue_free()
	view_root = Node3D.new()
	view_root.name = "FirstPersonPresentation"
	view_root.set_meta("weapon",weapon_id)
	camera.add_child(view_root)
	for child in weapon_root.get_children():
		if child == melee_rig:
			var copy := melee_rig.swing.duplicate() as Node3D
			copy.name = "MeleeView"
			view_root.add_child(copy)
			for marker in [melee_rig.grip_right,melee_rig.grip_left]:
				var hand := MeshInstance3D.new()
				var shape := BoxMesh.new()
				shape.size = Vector3(0.115,0.14,0.13)
				hand.mesh = shape
				hand.position = marker.position
				hand.material_override = GameCharacterColors.material(GameCharacterColors.normalize(get_meta("body_colors",{})).skin)
				copy.add_child(hand)
			continue
		if child == muzzle_marker or child.name == "RearSight": continue
		# Instantiating an inherited accessory scene again discards its runtime
		# lens material and merged housing. Copy the live subtree in this case.
		view_root.add_child(child.duplicate(7 if child.find_child("Scope4x",true,false)!=null or child.get_node_or_null("MagazineAssembly")!=null else 15))
	if is_instance_valid(melee_rig):
		for side in ["R","L"]:
			var arm := MeshInstance3D.new()
			arm.name = "MeleeForearm"+side
			var box := BoxMesh.new()
			box.size = Vector3(0.105,1.0,0.12)
			arm.mesh = box
			arm.material_override = GameCharacterColors.material(GameCharacterColors.normalize(get_meta("body_colors",{})).skin)
			view_root.add_child(arm)
		_update_weapon_pose()
		return
	var definitions := [
		["GripHand",Vector3(0,-0.035,0.03),Vector3(0.10,0.12,0.15)],
		["RightForearm",Vector3(0.055,-0.14,0.22),Vector3(0.13,0.16,0.30)],
		["SupportHand",FALModel.SUPPORT if GameWeapons.canonical(weapon_id)=="fal" else Vector3(-0.025,-0.045,-0.15 if GameWeapons.canonical(weapon_id) != "glock" else 0.035),Vector3(0.11,0.10,0.14)],
		["LeftForearm",Vector3(-0.14,-0.14,0.04 if GameWeapons.canonical(weapon_id) != "glock" else 0.20),Vector3(0.13,0.14,0.28)]]
	for definition in definitions:
		var mesh := MeshInstance3D.new()
		mesh.name = definition[0]
		mesh.position = definition[1]
		var support: bool=str(definition[0]).begins_with("Left") or definition[0]=="SupportHand"
		var hand: bool=str(definition[0]).ends_with("Hand")
		if hand:mesh.mesh=WarHumanRig.grip_glove(support,GameWeapons.canonical(weapon_id)=="glock")
		else:
			var arm: Node3D=avatar_parts["arm_l" if support else "arm_r"]
			mesh.mesh=(arm.get_node("Forearm"+("L" if support else "R")+"Mesh") as MeshInstance3D).mesh
		mesh.material_override=presentation_material(support,hand)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view_root.add_child(mesh)
	view_root.position = _weapon_offset()
	weapon_optics.prepare_copy(self)
	_update_weapon_pose()

func _advance_melee(delta: float) -> void:
	if not is_instance_valid(melee_rig) or not melee_rig.running: return
	if CombatRules.limb_disability_enabled(game) and float(limbs.armR) <= 0.0 and float(limbs.armL) <= 0.0:
		cancel_melee()
		return
	var left := minf(delta,0.25)
	while left > 0.000001 and melee_rig.running and hp > 0.0:
		var step := melee_rig.step_size(left)
		_update_weapon_pose()
		var before := melee_rig.elapsed
		var previous := melee_rig.samples()
		melee_rig.advance(step)
		_update_weapon_pose()
		if melee_rig.active_between(before,melee_rig.elapsed):
			game.melee_sweep(self,previous,melee_rig.samples())
		left -= step
	if not melee_rig.running: game.melee_attacks.erase(peer_id)

func cancel_melee() -> void:
	if game: game.melee_attacks.erase(peer_id)
	if is_instance_valid(melee_rig):
		melee_rig.running = false
		melee_rig.elapsed = 0.0
		melee_rig.animator.play("attack")
		melee_rig.animator.advance(0.0)
		melee_rig.animator.pause()

func _uses_first_person_presentation() -> bool:
	return is_local and (not game.third_person or iron_sights or weapon_optics.presented() or camera_close)

func _update_grenade_pose() -> void:
	var holding: bool=not grenade_held_id.is_empty() or grenade_prime_pending
	var active: bool=hp>0 and _grenade_active()
	if grenade_selected and not is_instance_valid(grenade_prop):
		grenade_prop=GameGrenades.make_prop();body_root.add_child(grenade_prop)
	if is_instance_valid(grenade_prop):
		grenade_prop.visible=hp>0 and grenade_selected and not holding and not _uses_first_person_presentation()
		grenade_prop.global_position=grenade_hand_position()
	if active:
		weapon_root.hide()
		if is_instance_valid(view_root): view_root.hide()
	elif hp>0:
		var first_person: bool=_uses_first_person_presentation()
		weapon_root.visible=not is_npc and not first_person
		if is_instance_valid(view_root): view_root.visible=first_person and not uses_telescopic_sight() and not _grenade_active()
	if not is_local: return
	var in_first: bool=_uses_first_person_presentation()
	if active and in_first and not is_instance_valid(grenade_view):
		grenade_view=Node3D.new();grenade_view.name="GrenadePresentation";camera.add_child(grenade_view)
		var arm:=MeshInstance3D.new();var capsule:=CapsuleMesh.new();capsule.radius=.055;capsule.height=.40;capsule.radial_segments=8;capsule.rings=3
		arm.mesh=capsule;arm.rotation.x=-.65;arm.position=Vector3(.015,-.20,.10);arm.material_override=GameCharacterColors.material(GameCharacterColors.normalize(get_meta("body_colors",{})).skin);arm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;grenade_view.add_child(arm)
		var hand:=MeshInstance3D.new();var block:=BoxMesh.new();block.size=Vector3(.105,.12,.13);hand.mesh=block;hand.position=Vector3(0,-.015,.03);hand.material_override=arm.material_override;hand.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;grenade_view.add_child(hand)
		grenade_view_mesh=GameGrenades.make_prop();grenade_view.add_child(grenade_view_mesh)
	if is_instance_valid(grenade_view):
		grenade_view.visible=active and in_first
		grenade_view_mesh.visible=holding or (grenade_selected and grenades>0)
		var progress:=1-grenade_throw_left/.75
		# The FPP mesh occupies exactly the world hand's location. Changing
		# cameras no longer substitutes a different grenade position.
		grenade_view.global_position=grenade_hand_position()
		grenade_view.rotation.x=-sin(progress*PI)*.8 if grenade_throw_left>0 else -.15

func _grenade_active() -> bool:
	return grenade_selected or not grenade_held_id.is_empty() or grenade_prime_pending or grenade_throw_left>0

func equip_grenade() -> void:
	if hp<=0 or is_npc or not grenades_enabled or grenades<=0 or not grenade_held_id.is_empty() or grenade_prime_pending or grenade_throw_left>0: return
	if game and game.get_meta("war_mode",false) and (not bool(get("deployed")) or not str(get("vehicle_id")).is_empty()): return
	grenade_selected=true;trigger_held=false;pause_reload();clear_weapon_aim()
	grenade_aiming=true
	if game and game.has_method("request_grenade_selection"): game.request_grenade_selection(self,true)
	_update_grenade_pose()
