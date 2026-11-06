extends CharacterBody3D
class_name WarVehicle
var kind := "guarani"
var wreck_visible:=false
var wreck_age:=0.0
static var wreck_material: StandardMaterial3D
var vehicle_id := ""
var team := 0
var driver := 0
var seats: Dictionary = {}
var seat_order: Dictionary = {}
var boarding_serial := 0
var seats_revision := 0
var control_epoch := 0
var received_state_sequence:=0
var received_state_usec:=0
var hp := 650.0
var ammo := 400
var reserve := 0
var reloading := false
var secondary_ammo := 0
var secondary_reserve:=0
var secondary_reload_left:=0.0
var secondary_fire_wait:=0.0
var selected := "primary"
var reload_left := 0.0
var fire_wait := 0.0
var speed := 0.0
var heading := 0.0
var aim_target := Vector3.ZERO
var turret: Node3D
var elevation: Node3D
var muzzle: Marker3D
var secondary_muzzle: Marker3D
var turret_shape: CollisionShape3D
var wheels: Array[Node3D] = []
var destination := Vector3.ZERO
var destination_rotation := Vector3.ZERO
var turret_yaw := 0.0
var gun_pitch := 0.0
var steering := 0.0
var respawn_left := 0.0
var spawn_position := Vector3.ZERO
var spawn_generation := 0
var shot_sequence := 0
var destroyed := false
var spec: Dictionary
var sensor: Dictionary
var optic: Marker3D
var gun_blocked:=false
var barrel_recoil: Node3D
var barrel_recoil_age:=1.0
var ground_support:=WarVehicleGround.new()
var step_motion:=preload("res://modes/war/scripts/vehicle_step.gd").new()
const PERFORMANCE_PROBE:=preload("res://scripts/performance_probe.gd")
var resting:=false
var rest_quiet:=0.0
var rest_check_left:=0.0
var rest_pose:=Transform3D.IDENTITY
var rest_support: WeakRef
var rest_support_pose:=Transform3D.IDENTITY
var rest_shape_node: WeakRef
var rest_shape_pose:=Transform3D.IDENTITY
var rest_shape: Shape3D
var rest_contact:=KinematicCollision3D.new()
var rest_hp:=0.0
var rest_selected:=""
var rest_turret_yaw:=0.0
var rest_gun_pitch:=0.0
var rest_aim_target:=Vector3.ZERO
static var material_cache: Dictionary = {}
static var paint_texture: ImageTexture

func _ready() -> void:
	spec = WarRules.VEHICLES[kind]
	sensor=WarRules.VEHICLE_SENSORS[kind]
	team = int(spec.team)
	hp = float(spec.hp)
	secondary_ammo=int(WarRules.SECONDARY[kind].capacity);secondary_reserve=int(WarRules.SECONDARY[kind].reserve)
	ammo = mini(int(spec.ammo),capacity())
	reserve = int(spec.ammo)-ammo
	name = vehicle_id
	set_meta("war_vehicle",vehicle_id)
	collision_layer = 1|16
	collision_mask = 1|4|16
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(38)
	var shape := BoxShape3D.new()
	# The lower contact box follows the running gear. The full-length hull
	# is higher; making its overhang the floor contact lifted the tracks.
	shape.size = Vector3(spec.size.x*.82,1.6,spec.size.z*.70)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = .89
	add_child(collider)
	var armor:=CollisionShape3D.new();var armor_shape:=BoxShape3D.new()
	armor_shape.size=Vector3(spec.size.x,.6,spec.size.z);armor.shape=armor_shape;armor.position.y=1.65;add_child(armor)
	turret_shape = CollisionShape3D.new()
	var top := BoxShape3D.new()
	top.size = Vector3(2.5,.8,2.5) if kind in ["abrams","t90"] else Vector3(1.1,.65,1.2)
	turret_shape.shape = top
	turret_shape.position.y = float(spec.size.y)-.35
	add_child(turret_shape)
	turret = Node3D.new()
	turret.name = "TurretYaw"
	turret.position = Vector3(0,float(spec.size.y)-.65,-.1 if kind!="bmp2" else -.7)
	add_child(turret)
	elevation = Node3D.new()
	elevation.name = "GunElevation"
	elevation.position = Vector3(0,.3,-.6 if kind not in ["abrams","t90"] else -1.25)
	turret.add_child(elevation)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position.z = -3.8 if kind in ["abrams","t90"] else -2.2
	elevation.add_child(muzzle)
	secondary_muzzle = Marker3D.new()
	secondary_muzzle.position = Vector3(.83,.56,-1.15) if kind in ["guarani","bmp2"] else Vector3(.42,.33,-.7)
	elevation.add_child(secondary_muzzle)
	optic=Marker3D.new();optic.name="GunnerOptic";optic.position=sensor.optic;elevation.add_child(optic)
	if DisplayServer.get_name()!="headless":
		build_model()
		if kind in ["abrams","t90"]:
			barrel_recoil=Node3D.new();barrel_recoil.name="CannonRecoil";elevation.add_child(barrel_recoil)
			for part in elevation.get_children():
				if part is MeshInstance3D and part.get_meta("thermal_region","")=="gun": part.reparent(barrel_recoil,true)
			muzzle.reparent(barrel_recoil,true)
	aim_target = global_position-global_basis.z*500
	spawn_position = global_position
	destination = global_position

static func material(id: String) -> StandardMaterial3D:
	if not material_cache.has(id):
		if not paint_texture:
			var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
			var noise:=FastNoiseLite.new();noise.seed=261023;noise.frequency=.065
			for y in 128:
				for x in 128:
					var grain:=.90+noise.get_noise_2d(x,y)*.09
					if (x*719+y*269)%131==0: grain=.69
					image.set_pixel(x,y,Color(grain,grain,grain))
			image.generate_mipmaps();paint_texture=ImageTexture.create_from_image(image)
		var value := StandardMaterial3D.new()
		value.albedo_color = Color(id)
		value.albedo_texture=paint_texture
		value.uv1_triplanar=true;value.uv1_world_triplanar=false;value.uv1_scale=Vector3.ONE*1.2
		value.roughness = .87
		value.metallic = .06
		if id in ["252b28","232825","353d36"]: value.roughness=.97;value.metallic=0
		elif id=="213d40": value.roughness=.20;value.metallic=.35;value.albedo_texture=null
		elif id in ["384039","727963"]: value.roughness=.65;value.metallic=.55
		value.metallic_specular=.25
		value.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material_cache[id] = value
	return material_cache[id]

func part(parent: Node3D,label: String,pos: Vector3,size: Vector3,color := "56604a",angles := Vector3.ZERO) -> MeshInstance3D:
	var result := WarUniform.box(parent,label,pos,size,material(color))
	result.rotation = angles
	result.visibility_range_end = 950
	return result

func cylinder(parent: Node3D,label: String,pos: Vector3,radius: float,length: float,color: String,angles := Vector3.ZERO,top := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius*top
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 14
	node.mesh = shape
	node.material_override = material(color)
	node.position = pos
	node.rotation = angles
	node.name = label
	node.visibility_range_end = 950
	parent.add_child(node)
	return node

func wedge(parent: Node3D,label: String,size: Vector3,pos: Vector3,color: String) -> void:
	var x := size.x*.5
	var z := size.z*.5
	var points := PackedVector3Array([Vector3(-x,0,-z),Vector3(x,0,-z),Vector3(x,0,z),Vector3(-x,0,z),Vector3(-x*.91,size.y,-z*.70),Vector3(x*.91,size.y,-z*.70),Vector3(x*.91,size.y,z*.93),Vector3(-x*.91,size.y,z*.93)])
	var indices := PackedInt32Array([0,1,4,1,5,4,1,2,5,2,6,5,2,3,6,3,7,6,3,0,7,0,4,7,4,5,7,5,6,7,3,2,0,2,1,0])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices: surface.add_vertex(points[index])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name=label;node.mesh=surface.commit();node.position=pos;node.material_override=material(color)
	node.visibility_range_end = 950
	parent.add_child(node)

func build_model() -> void:
	WarVehicleModels.build(self)

func aim(delta: float,point: Vector3,immediate := false) -> void:
	var delta_world := point-turret.global_position
	var local := global_basis.inverse()*delta_world
	var desired_yaw := atan2(-local.x,-local.z)
	var desired_pitch := clampf(atan2(local.y-elevation.position.y,maxf(.01,Vector2(local.x,local.z).length()+elevation.position.z)),float(spec.pitch_min),float(spec.pitch_max))
	turret_yaw = desired_yaw if immediate else rotate_toward(turret_yaw,desired_yaw,delta*float(sensor.yaw_rate))
	gun_pitch = desired_pitch if immediate else move_toward(gun_pitch,desired_pitch,delta*float(sensor.pitch_rate))
	if turret.rotation.y!=turret_yaw: turret.rotation.y = turret_yaw
	if elevation.rotation.x!=gun_pitch: elevation.rotation.x = gun_pitch
	if turret_shape.rotation.y!=turret_yaw: turret_shape.rotation.y = turret_yaw
	aim_target = point

func simulate(delta: float,control: Dictionary) -> void:
	if destroyed: return
	if not bool(control.get("fire",false)): gun_blocked=false
	if reloading:
		reload_left = maxf(0,reload_left-delta)
		if reload_left==0:
			var amount := mini(capacity()-ammo,reserve)
			ammo+=amount;reserve-=amount;reloading=false
	fire_wait = maxf(0,fire_wait-delta)
	secondary_fire_wait=maxf(0,secondary_fire_wait-delta)
	if secondary_reload_left>0:
		secondary_reload_left=maxf(0,secondary_reload_left-delta)
		if secondary_reload_left==0:
			var transfer:=mini(int(WarRules.SECONDARY[kind].capacity)-secondary_ammo,secondary_reserve)
			secondary_ammo+=transfer;secondary_reserve-=transfer
	# Turret/reload remain responsive while a parked occupied hull rests.
	aim(delta,control.get("aim",aim_target))
	if _skip_resting_motion(delta,control): return
	var throttle := float(control.get("throttle",0))
	var safety_brake:=bool(control.get("brake",false))
	if safety_brake:throttle=0.
	steering = float(control.get("steer",0))
	var target_speed := throttle*(float(spec.speed) if throttle>=0 else float(spec.reverse))
	var braking:=3.5 if safety_brake or speed*throttle<-.05 else (1.0 if absf(throttle)>.01 else 1.7)
	speed = move_toward(speed,target_speed,delta*float(spec.acceleration)*braking)
	var turning := float(spec.turn)*(1.0 if spec.tracked else clampf(absf(speed)/6,0,1))
	heading -= steering*turning*delta*(1.0 if speed>=0 or spec.tracked else -1.0)
	var hull_basis:=Basis(Vector3.UP,heading)*ground_support.tilt
	if basis!=hull_basis: basis=hull_basis
	var forward := Basis(Vector3.UP,heading)*Vector3.FORWARD
	velocity.x = forward.x*speed
	velocity.z = forward.z*speed
	velocity.y -= 15.0*delta
	var motion_start:=global_position
	var impact_speed:=absf(speed)
	var impact_direction:=forward*signf(speed)
	step_motion.move(self,delta)
	if impact_speed>=3.0 and get_parent().has_method("resolve_runover"):
		get_parent().resolve_runover(self,impact_speed,impact_direction)
	if is_on_floor() or Engine.get_physics_frames()-step_motion.last_step_frame<=2:
		# A slope projects horizontal motion upward; it must not become a
		# stored launch velocity after passing a small stone.
		velocity.y=minf(velocity.y,0.0)
	if step_motion.blocked_motion:
		var actual_speed: float=(global_position-motion_start).dot(forward)/maxf(delta,.001)
		if absf(actual_speed)<absf(speed)*.5: speed=actual_speed
		if get_parent().has_method("ram_light_obstacles"): get_parent().ram_light_obstacles(self,impact_speed,impact_direction)
	# A quay/bridge above deep terrain is still dry ground. Flood only once
	# the actual vehicle floor reaches the water, not a probe two metres ahead.
	if WarRules.CURRENT_OPERATION==WarOperation.UKRAINE and WarTerrain.height_at(global_position.x,global_position.z)<-.6 and global_position.y<WarCoast.wave(global_position,float(get_parent().game.war_clock))+.15:
		get_parent().flood_vehicle(self);return
	var bounded:=global_position
	bounded.x=clampf(bounded.x,-WarTerrain.HALF+20,WarTerrain.HALF-20)
	bounded.z=clampf(bounded.z,-WarTerrain.HALF+20,WarTerrain.HALF-20)
	if global_position!=bounded: global_position=bounded
	var ground_started:=PERFORMANCE_PROBE.begin(&"vehicle.ground_align")
	ground_support.align(self,delta)
	if ground_started: PERFORMANCE_PROBE.end(&"vehicle.ground_align",ground_started)
	animate_running_gear(delta)
	_observe_ground_rest(delta,control)

func _wake_ground_rest() -> void:
	resting=false;rest_quiet=0;ground_support.timer=0
	if is_instance_valid(rest_shape) and rest_shape.changed.is_connected(_wake_ground_rest): rest_shape.changed.disconnect(_wake_ground_rest)
	rest_shape=null;rest_shape_node=null;rest_support=null

func _motion_requested(control: Dictionary) -> bool:
	return absf(float(control.get("throttle",0)))>.001 or absf(float(control.get("steer",0)))>.001 or absf(speed)>.005

func _skip_resting_motion(delta: float,control: Dictionary) -> bool:
	if spec.has("naval"): return false
	if _motion_requested(control):
		if resting or rest_quiet>0: _wake_ground_rest()
		return false
	if not resting: return false
	if hp!=rest_hp or selected!=rest_selected or turret_yaw!=rest_turret_yaw or gun_pitch!=rest_gun_pitch or aim_target!=rest_aim_target:
		_wake_ground_rest();return false
	var support: StaticBody3D=rest_support.get_ref() if rest_support else null
	var contact_shape: CollisionShape3D=rest_shape_node.get_ref() if rest_shape_node else null
	if not global_transform.is_equal_approx(rest_pose) or not is_instance_valid(support) or not is_instance_valid(contact_shape):
		_wake_ground_rest();return false
	if not support.global_transform.is_equal_approx(rest_support_pose) or not contact_shape.global_transform.is_equal_approx(rest_shape_pose) or (support.collision_layer&collision_mask)==0 or contact_shape.disabled or contact_shape.shape!=rest_shape:
		_wake_ground_rest();return false
	rest_check_left-=delta
	if rest_check_left>0: return true
	# Revalidate physics, water and all support rays periodically. An edited
	# neighbouring shape can affect the footprint without replacing this one.
	resting=false;ground_support.timer=0
	return false

func _observe_ground_rest(delta: float,control: Dictionary) -> void:
	if spec.has("naval"): return
	if _motion_requested(control) or velocity.y>.1:
		if resting or rest_quiet>0: _wake_ground_rest()
		return
	if global_position.distance_squared_to(rest_pose.origin)>.000004 or not global_basis.is_equal_approx(rest_pose.basis): rest_quiet=0
	else: rest_quiet+=delta
	rest_pose=global_transform
	if rest_quiet<.5: return
	# Suspension has 2.5 cm clearance and need not report is_on_floor.
	if not test_move(global_transform,Vector3.DOWN*.12,rest_contact,.001) or rest_contact.get_normal().y<cos(floor_max_angle):
		_wake_ground_rest();return
	var support:=rest_contact.get_collider() as StaticBody3D
	if not is_instance_valid(support): _wake_ground_rest();return
	var owner_id:=support.shape_find_owner(rest_contact.get_collider_shape_index())
	var contact_shape:=support.shape_owner_get_owner(owner_id) as CollisionShape3D
	if not is_instance_valid(contact_shape): _wake_ground_rest();return
	if rest_shape!=contact_shape.shape:
		if is_instance_valid(rest_shape) and rest_shape.changed.is_connected(_wake_ground_rest): rest_shape.changed.disconnect(_wake_ground_rest)
		rest_shape=contact_shape.shape
		rest_shape.changed.connect(_wake_ground_rest)
	rest_support=weakref(support);rest_support_pose=support.global_transform;rest_shape_node=weakref(contact_shape);rest_shape_pose=contact_shape.global_transform
	rest_hp=hp;rest_selected=selected;rest_turret_yaw=turret_yaw;rest_gun_pitch=gun_pitch;rest_aim_target=aim_target
	resting=true;rest_check_left=.15

func snapshot() -> Dictionary:
	return {"id":vehicle_id,"kind":kind,"team":team,"position":global_position,"rotation":rotation,"driver":driver,"seats":seats.duplicate(),"seats_revision":seats_revision,"control_epoch":control_epoch,"spawn_generation":spawn_generation,"hp":hp,"ammo":ammo,"reserve":reserve,"secondary_ammo":secondary_ammo,"secondary_reserve":secondary_reserve,"secondary_reload":secondary_reload_left,"secondary_wait":secondary_fire_wait,"selected":selected,"reload":reload_left,"wait":fire_wait,"speed":speed,"turret":turret_yaw,"pitch":gun_pitch,"destroyed":destroyed,"respawn":int(ceilf(respawn_left)),"gun_blocked":gun_blocked}

func receive(state: Dictionary) -> void:
	# Reliable occupancy and unreliable motion travel independently. Reject
	# the whole old generation, including its health, destruction and pose.
	if int(state.get("seats_revision",0))<seats_revision: return
	if int(state.get("spawn_generation",0))<spawn_generation: return
	var state_sequence:=int(state.get("sequence",0))
	if received_state_sequence>0 and state_sequence<=received_state_sequence: return
	if state_sequence>0: received_state_sequence=state_sequence
	received_state_usec=Time.get_ticks_usec()
	var was_destroyed:=destroyed
	var prior_spawn_generation:=spawn_generation
	spawn_generation=int(state.get("spawn_generation",spawn_generation))
	destination=state.position;destination_rotation=state.rotation;hp=float(state.hp);ammo=int(state.ammo);secondary_ammo=int(state.secondary_ammo);selected=str(state.selected);reload_left=float(state.reload);fire_wait=float(state.wait);speed=float(state.speed);turret_yaw=float(state.turret);gun_pitch=float(state.pitch);destroyed=bool(state.destroyed)
	receive_seats(state.get("seats",{0:int(state.driver)} if int(state.driver)>0 else {}),int(state.get("seats_revision",0)),int(state.get("control_epoch",0)))
	reserve=int(state.get("reserve",0))
	secondary_reserve=int(state.get("secondary_reserve",0));secondary_reload_left=float(state.get("secondary_reload",0));secondary_fire_wait=float(state.get("secondary_wait",0))
	gun_blocked=bool(state.get("gun_blocked",false))
	respawn_left=clampf(float(state.get("respawn",0)),0,WarRules.SHIP_RESPAWN_SECONDS if spec.has("naval") else WarRules.VEHICLE_RESPAWN_SECONDS)
	if not destroyed and (was_destroyed or spawn_generation!=prior_spawn_generation):
		global_position=destination;rotation=destination_rotation
		turret.rotation.y=turret_yaw;elevation.rotation.x=gun_pitch
	visible=true
	collision_layer=0 if destroyed else 1|16
	update_wreck(0)

func render(delta: float) -> void:
	global_position = global_position.lerp(destination,1.0-exp(-delta*14))
	for axis in 3: rotation[axis] = lerp_angle(rotation[axis],destination_rotation[axis],1.0-exp(-delta*14))
	turret.rotation.y = lerp_angle(turret.rotation.y,turret_yaw,1.0-exp(-delta*20))
	elevation.rotation.x = lerpf(elevation.rotation.x,gun_pitch,1.0-exp(-delta*20))
	animate_running_gear(delta)
	update_wreck(delta)

func update_wreck(delta: float) -> void:
	if DisplayServer.get_name()=="headless": return
	if wreck_visible!=destroyed:
		wreck_visible=destroyed;wreck_age=0
		if wreck_material==null:
			wreck_material=StandardMaterial3D.new();wreck_material.albedo_color=Color("252a27");wreck_material.metallic=.45;wreck_material.roughness=.94
		for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
			if destroyed:
				mesh.set_meta("wreck_source",{"material":DeathRagdoll.original_material(mesh)})
				mesh.material_override=wreck_material
			else:
				if mesh.has_meta("wreck_source"): mesh.material_override=mesh.get_meta("wreck_source").get("material");mesh.remove_meta("wreck_source")
		visible=true
	if destroyed:
		wreck_age+=delta
		# A short physical-looking jolt settles into a disabled, burned vehicle.
		# No new rigid fragments or per-frame particles are created.
		if not self is WarShip:
			elevation.rotation.x=gun_pitch+sin(wreck_age*12)*.08*exp(-wreck_age*3)+.10*(1-exp(-wreck_age*2))

func animate_running_gear(delta: float) -> void:
	for wheel in wheels: wheel.rotate_x(-speed*delta/float(wheel.get_meta("wheel_radius",.43)))

func seat_capacity() -> int:
	return WarRules.VEHICLE_SEATS[kind].size()

func seat_of(peer: int) -> int:
	for seat in seats:
		if int(seats[seat])==peer: return int(seat)
	return -1

func first_available_seat() -> int:
	for seat in seat_capacity():
		if not seats.has(seat): return seat
	return -1

func occupant_ids() -> Array[int]:
	var result: Array[int]=[]
	for seat in seat_capacity():
		if seats.has(seat): result.append(int(seats[seat]))
	return result

func seat_position(seat: int) -> Vector3:
	return WarRules.VEHICLE_SEATS[kind][clampi(seat,0,seat_capacity()-1)]

func allocate_seat(peer: int) -> int:
	if destroyed or peer<=0 or seat_of(peer)>=0: return -1
	var seat:=first_available_seat()
	if seat<0: return -1
	boarding_serial+=1;seats[seat]=peer;seat_order[peer]=boarding_serial;seats_revision+=1
	if seat==0: driver=peer;control_epoch+=1
	return seat

# Authoritative human takeover: swap only the bot occupying seat zero
# into an empty passenger seat. The caller validates both player identities.
# A single revision/epoch keeps remote occupancy and driver controls atomic.
func hand_over_driver(peer: int,expected_bot_driver: int) -> bool:
	# Reject a stale command if the operator changed after validation.
	if destroyed or driver<=0 or driver!=expected_bot_driver or peer<=0 or peer==driver or seat_of(peer)>=0: return false
	var passenger_seat:=-1
	for slot in range(1,seat_capacity()):
		if not seats.has(slot):
			passenger_seat=slot
			break
	if passenger_seat<0: return false
	var old_driver:=driver
	seats[0]=peer
	seats[passenger_seat]=old_driver
	boarding_serial+=1
	seat_order[peer]=boarding_serial
	driver=peer
	seats_revision+=1
	control_epoch+=1
	return true

func vacate_seat(peer: int,promote:=true) -> int:
	var seat:=seat_of(peer)
	if seat<0: return 0
	seats.erase(seat);seat_order.erase(peer);seats_revision+=1
	if seat!=0: return 0
	driver=0;control_epoch+=1
	if not promote or destroyed: return 0
	var oldest:=0;var order:=9223372036854775807
	for occupant: int in occupant_ids():
		var candidate:=int(seat_order.get(occupant,occupant))
		if candidate<order: oldest=occupant;order=candidate
	if oldest>0:
		seats.erase(seat_of(oldest));seats[0]=oldest;driver=oldest
	return oldest

func clear_seats() -> Array[int]:
	var previous:=occupant_ids()
	seats.clear();seat_order.clear();boarding_serial=0;driver=0
	seats_revision+=1;control_epoch+=1
	return previous

func receive_seats(values: Dictionary,revision: int,epoch: int) -> void:
	# Reliable seat changes and unreliable movement snapshots use different
	# channels. A late movement packet must never undo a promotion or exit.
	if revision<seats_revision: return
	var accepted: Dictionary={};var used: Dictionary={}
	for key in values:
		var seat:=int(key);var peer:=int(values[key])
		if seat<0 or seat>=seat_capacity() or peer<=0 or used.has(peer): continue
		accepted[seat]=peer;used[peer]=true
	seats=accepted;driver=int(seats.get(0,0));seats_revision=revision;control_epoch=epoch

func capacity() -> int:
	return 1 if kind in ["abrams","t90"] else 30

func start_secondary_reload() -> bool:
	var data: Dictionary=WarRules.SECONDARY[kind]
	if destroyed or secondary_reload_left>0 or secondary_reserve<=0 or secondary_ammo>=int(data.capacity): return false
	secondary_reload_left=float(data.reload);return true

func start_reload() -> bool:
	if selected=="secondary": return start_secondary_reload()
	if destroyed or ammo>=capacity() or reserve<=0: return false
	if reloading and reload_left>0: return false
	reloading=true;reload_left=float(spec.reload)
	return true

func present_cannon_recoil() -> void:
	barrel_recoil_age=0.0

func animate_cannon_recoil(delta: float) -> void:
	if not is_instance_valid(barrel_recoil): return
	barrel_recoil_age=minf(1.,barrel_recoil_age+delta)
	var displacement:=.34*sin(minf(1.,barrel_recoil_age/.065)*PI*.5) if barrel_recoil_age<.065 else .34*pow(maxf(0.,1.-(barrel_recoil_age-.065)/.65),2)
	barrel_recoil.position.z=displacement
