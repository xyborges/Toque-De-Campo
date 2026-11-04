extends WarVehicle

const MODEL=preload("res://modes/war/equipment/motorbike.tscn")
const WHEEL_RADIUS := .32
const MAX_BANK := deg_to_rad(19.)
const MAX_PITCH := deg_to_rad(5.)

var model: Node3D
var handlebar: Node3D
var driver_seat: Marker3D
var pillion_seat: Marker3D
var driver_grips: Array[Marker3D]
var pillion_grips: Array[Marker3D]
var driver_pegs: Array[Marker3D]
var pillion_pegs: Array[Marker3D]
var bank := 0.
var pitch := 0.
var last_speed := 0.
var travel_phase := 0.
var abandoned_left:=WarRules.TRANSPORT_ABANDON_SECONDS

func _ready() -> void:
	spec=WarRules.VEHICLES[kind];sensor=WarRules.VEHICLE_SENSORS[kind]
	team=int(spec.team);hp=float(spec.hp);name=vehicle_id
	set_meta("war_vehicle",vehicle_id);set_meta("surface","vehicle")
	collision_layer=1|16;collision_mask=1|4|16;floor_snap_length=.65;floor_max_angle=deg_to_rad(35)
	var shape:=BoxShape3D.new();shape.size=Vector3(.52,.68,1.65)
	turret_shape=CollisionShape3D.new();turret_shape.name="BikeContact";turret_shape.shape=shape;turret_shape.position.y=.43;add_child(turret_shape)
	# Existing snapshot/seat helpers retain their stable schema. These anchors
	# have no weapons or rotating gun collision; authority rejects firing.
	turret=Node3D.new();turret.name="TransportAnchor";add_child(turret)
	elevation=Node3D.new();turret.add_child(elevation)
	muzzle=Marker3D.new();elevation.add_child(muzzle)
	secondary_muzzle=Marker3D.new();elevation.add_child(secondary_muzzle)
	optic=Marker3D.new();optic.position=Vector3(0,1.25,0);add_child(optic)
	ammo=0;reserve=0;secondary_ammo=0;secondary_reserve=0
	spawn_position=global_position;destination=global_position;aim_target=global_position-global_basis.z*50
	if DisplayServer.get_name()=="headless":
		model = _headless_model()
	else:
		model = MODEL.instantiate()
	add_child(model)
	handlebar = model.get_node("Steering")
	driver_seat = model.get_node("DriverSeat")
	pillion_seat = model.get_node("PillionSeatAnchor")
	for side in ["Left","Right"]:
		driver_grips.append(handlebar.get_node("Grip"+side))
		driver_pegs.append(model.get_node("DriverPeg"+side))
		pillion_grips.append(model.get_node("PillionGrip"+side))
		pillion_pegs.append(model.get_node("PillionPeg"+side))
	wheels.append(model.get_node("RearWheel"))
	wheels.append(handlebar.get_node("FrontWheel"))
	if DisplayServer.get_name()!="headless":
		_batch_model()

func _headless_model() -> Node3D:
	# Exposed rider hit regions use the same anchors without decorative meshes.
	var scene := MODEL.get_state()
	var pivots := Node3D.new()
	for index in range(1, scene.get_node_count()):
		var type := scene.get_node_type(index)
		if type not in [&"Node3D", &"Marker3D"]: continue
		var node := Marker3D.new() if type==&"Marker3D" else Node3D.new()
		node.name = scene.get_node_name(index)
		var parent_path := scene.get_node_path(index, true)
		pivots.get_node(parent_path).add_child(node)
		for property in scene.get_node_property_count(index):
			var key := scene.get_node_property_name(index, property)
			node.set(key, scene.get_node_property_value(index, property))
	return pivots

func _batch_model() -> void:
	# Keep wheel spin and steering independent while sharing the rigid meshes.
	for path in [".","Steering","RearWheel","Steering/FrontWheel"]:
		var pivot := model.get_node(path) as Node3D
		var meshes: Array[Node] = []
		for child in pivot.get_children():
			if child is MeshInstance3D: meshes.append(child)
		WarRenderBatch.merge(pivot, "motorbike-v2:"+path, meshes)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end = 350.

func aim(_delta: float,_point: Vector3,_immediate:=false) -> void:
	# Looking around never steers the motorcycle or creates a gun aim.
	pass

func capacity() -> int: return 0
func start_reload() -> bool: return false
func start_secondary_reload() -> bool: return false

func animate_running_gear(delta: float) -> void:
	for wheel in wheels:
		wheel.rotate_x(-speed*delta/WHEEL_RADIUS)
	# A positive steer reduces heading around Y. Forward is local -Z.
	handlebar.rotation.y = lerpf(handlebar.rotation.y, -steering*.42, 1.-exp(-delta*12.))
	var pace := clampf((speed-1.)/11., 0., 1.)
	bank = lerpf(bank, -steering*MAX_BANK*pace, 1.-exp(-delta*6.))
	var acceleration := (speed-last_speed)/maxf(delta,.001)
	last_speed = speed
	pitch = lerpf(pitch, clampf(acceleration*.008,-MAX_PITCH,MAX_PITCH), 1.-exp(-delta*6.))
	travel_phase = fposmod(travel_phase+delta*absf(speed)*2.2, TAU)
	model.rotation = Vector3(pitch,0.,bank)
	model.position.y = sin(travel_phase)*.006*pace

func reset_abandonment() -> void:
	abandoned_left=WarRules.TRANSPORT_ABANDON_SECONDS

func snapshot() -> Dictionary:
	var state:=super.snapshot();state.steering=steering
	return state

func receive(state: Dictionary) -> void:
	if int(state.get("seats_revision",0))<seats_revision or int(state.get("spawn_generation",0))<spawn_generation: return
	if received_state_sequence>0 and int(state.get("sequence",0))<=received_state_sequence: return
	super.receive(state);steering=clampf(float(state.get("steering",0.)),-1.,1.)

func abandoned_return_due(delta: float) -> bool:
	# A parked spawn is already where it belongs. Empty displaced bikes return
	# after 180 seconds; occupied bikes never count down or steal a rider's seat.
	if destroyed or not occupant_ids().is_empty() or global_position.distance_squared_to(spawn_position)<9.:
		reset_abandonment();return false
	abandoned_left=maxf(0.,abandoned_left-delta)
	return abandoned_left<=0.

static func reset_rider_pose(actor: GamePlayer) -> void:
	actor.body_root.position = Vector3.ZERO
	actor.body_root.rotation = Vector3.ZERO
	GameInfantryPose.reset(actor)
	for side in actor.stance.leg_parts:
		var leg: Dictionary = actor.stance.leg_parts[side]
		leg.joint.rotation = Vector3.ZERO
		leg.knee.rotation = Vector3.ZERO
		leg.shoe.rotation = Vector3.ZERO
	actor.stance.pose(actor,false)

func pose_rider(actor: GamePlayer) -> void:
	var passenger := seat_of(actor.peer_id)>0
	var saddle := pillion_seat if passenger else driver_seat
	var grips := pillion_grips if passenger else driver_grips
	var pegs := pillion_pegs if passenger else driver_pegs
	actor.body_root.show()
	actor.weapon_root.hide()
	actor._hide_dead_presentations()
	actor.rotation.y = rotation.y
	for part: Node3D in actor.avatar_parts.values(): part.show()
	var pelvis := actor.body_root.get_node("Pelvis") as Node3D
	pelvis.show()
	# The hips rotate around the saddle contact. The hands and boots follow
	# the same bike frame through slopes, banking and steering.
	var posture := Basis(Vector3.RIGHT, -.16 if passenger else -.30)
	var body_basis := saddle.global_basis*posture
	var pelvis_contact := pelvis.position + Vector3.DOWN*.10
	actor.body_root.global_transform = Transform3D(body_basis, saddle.global_position-body_basis*pelvis_contact)
	actor.avatar_parts.torso.rotation = Vector3(-pitch*.45,0.,-bank*.12)
	actor.avatar_parts.head.rotation = Vector3(.11-pitch*.4,handlebar.rotation.y*.30,-bank*.28)
	for index in 2:
		var side := "L" if index==0 else "R"
		var grip := grips[index]
		WarHumanRig.pose(actor,actor.avatar_parts["arm_"+side.to_lower()],grip.global_position,"arm"+side,grip)
		_plant_boot(actor, side, pegs[index])

func _plant_boot(actor: GamePlayer, side: String, peg: Marker3D) -> void:
	var leg: Dictionary = actor.stance.leg_parts[side]
	var thigh: Node3D = leg.joint
	var knee: Node3D = leg.knee
	var boot: Node3D = leg.shoe
	var body := actor.body_root
	var foot_basis := body.global_basis.inverse()*peg.global_basis
	var sole := Vector3(0,float(leg.sole_y),0)
	var target := body.to_local(peg.global_position)-foot_basis*sole-thigh.position
	var along := target.normalized()
	var upper_length := knee.position.length()
	var lower_length := boot.position.length()
	var reach := clampf(target.length(), absf(upper_length-lower_length)+.001, upper_length+lower_length-.001)
	var pole := Vector3(-.24 if side=="L" else .24,0.,-1.)
	var bend := (pole-along*pole.dot(along)).normalized()
	var projection := (upper_length*upper_length+reach*reach-lower_length*lower_length)/(2.*reach)
	var knee_offset := along*projection+bend*sqrt(maxf(0.,upper_length*upper_length-projection*projection))
	thigh.basis = Basis(Quaternion(Vector3.DOWN,knee_offset.normalized()))
	var lower := thigh.basis.inverse()*(along*reach-knee_offset)
	knee.basis = Basis(Quaternion(boot.position.normalized(),lower.normalized()))
	boot.basis = (thigh.basis*knee.basis).inverse()*foot_basis
