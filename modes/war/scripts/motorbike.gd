extends WarVehicle

const MODEL=preload("res://modes/war/equipment/motorbike.tscn")
var model: Node3D
var handlebar: Node3D
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
	if DisplayServer.get_name()!="headless":
		model=MODEL.instantiate();add_child(model);handlebar=model.get_node("Steering")
		wheels.append(model.get_node("RearWheel"));wheels.append(handlebar.get_node("FrontWheel"))
		for wheel in wheels: wheel.set_meta("wheel_radius",.32)
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false): mesh.visibility_range_end=350
	else:
		handlebar=Node3D.new();handlebar.position=Vector3(0,.41,-.74);add_child(handlebar)
		for side in [-1.,1.]:
			var grip:=Marker3D.new();grip.name="GripLeft" if side<0 else "GripRight";grip.position=Vector3(side*.30,.73,.14);handlebar.add_child(grip)

func aim(_delta: float,_point: Vector3,_immediate:=false) -> void:
	# Looking around never steers the motorcycle or creates a gun aim.
	pass

func capacity() -> int: return 0
func start_reload() -> bool: return false
func start_secondary_reload() -> bool: return false

func animate_running_gear(delta: float) -> void:
	for wheel in wheels: wheel.rotate_x(-speed*delta/.32)
	if is_instance_valid(handlebar): handlebar.rotation.y=lerpf(handlebar.rotation.y,steering*.35,1.-exp(-delta*12.))

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

func pose_rider(actor: GamePlayer) -> void:
	actor.body_root.show();actor.weapon_root.hide()
	actor.rotation.y=heading
	for label in ["head","torso","arm_l","arm_r","leg_l","leg_r"]: actor.avatar_parts[label].show()
	var pelvis:=actor.body_root.get_node_or_null("Pelvis") as Node3D
	if is_instance_valid(pelvis): pelvis.show()
	actor.avatar_parts.torso.rotation.x=-.12
	for side in ["L","R"]:
		var leg: Node3D=actor.avatar_parts["leg_"+side.to_lower()]
		leg.rotation.x=1.0
		var knee:=leg.get_node_or_null("Knee"+side) as Node3D
		if knee:
			knee.rotation.x=-1.35
			var shoe:=knee.get_node_or_null("Shoe"+side) as Node3D
			if shoe: shoe.rotation.x=.35
		if is_instance_valid(handlebar):
			var grip:=handlebar.get_node("GripLeft" if side=="L" else "GripRight") as Marker3D
			WarHumanRig.pose(actor,actor.avatar_parts["arm_"+side.to_lower()],grip.global_position,"arm"+side,grip)
