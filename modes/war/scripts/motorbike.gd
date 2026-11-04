extends WarVehicle

const MODEL=preload("res://modes/war/equipment/motorbike.tscn")
var model: Node3D
var handlebar: Node3D
var visual_lean:=0.0
var visual_pitch:=0.0
var last_visual_speed:=0.0
var vibration_clock:=0.0
const MAX_LEAN:=deg_to_rad(19.0)
const MAX_PITCH:=deg_to_rad(5.0)
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
		# The scene keeps wheel/steering and grip pivots independent, while
		# its static detail is merged once per part. All bikes reuse the cache.
		for group in [[model,"body"],[handlebar,"steering"],[wheels[0],"rear_wheel"],[wheels[1],"front_wheel"]]:
			var parent: Node3D=group[0]
			var roots: Array[Node]=[]
			for child in parent.get_children():
				if child is MeshInstance3D: roots.append(child)
			WarRenderBatch.merge(parent,"motorbike-v2:"+str(group[1]),roots)
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
	# Physics is correct: positive steer decreases heading (turns right).
	# The old positive handlebar angle pointed the visible wheel LEFT.
	var blend:=1.-exp(-delta*10.)
	if is_instance_valid(handlebar):
		handlebar.rotation.y=lerpf(handlebar.rotation.y,-steering*.42,blend)
	var speed_weight:=clampf((absf(speed)-1.0)/11.,0.,1.)
	var target_lean:=-steering*MAX_LEAN*speed_weight if speed>0. else 0.
	visual_lean=lerpf(visual_lean,target_lean,1.-exp(-delta*5.5))
	var acceleration:=clampf((speed-last_visual_speed)/maxf(delta,.001),-15.,15.)
	last_visual_speed=speed
	visual_pitch=lerpf(visual_pitch,clampf(acceleration*.012,-MAX_PITCH,MAX_PITCH),1.-exp(-delta*4.5))
	vibration_clock+=delta*maxf(0.,absf(speed))*2.2
	if is_instance_valid(model):
		model.rotation=Vector3(visual_pitch,0.,visual_lean)
		model.position.y=sin(vibration_clock)*.004*clampf(absf(speed)/12.,0.,1.)

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

func reset_rider_pose(actor: GamePlayer) -> void:
	# Bike-only offsets must never leak into normal infantry locomotion.
	actor.body_root.position=Vector3.ZERO
	actor.body_root.rotation=Vector3.ZERO
	actor.rotation.x=0.;actor.rotation.z=0.
	actor.avatar_parts.torso.rotation=Vector3.ZERO
	actor.avatar_parts.head.rotation=Vector3.ZERO
	for side in ["L","R"]:
		var leg:=actor.avatar_parts["leg_"+side.to_lower()] as Node3D
		leg.rotation=Vector3.ZERO
		var knee:=leg.get_node_or_null("Knee"+side) as Node3D
		if is_instance_valid(knee):
			knee.rotation=Vector3.ZERO
			var shoe:=knee.get_node_or_null("Shoe"+side) as Node3D
			if is_instance_valid(shoe): shoe.rotation=Vector3.ZERO

func pose_rider(actor: GamePlayer) -> void:
	actor.body_root.show();actor.weapon_root.hide()
	# Base yaw/pitch/roll follows the PRESENTED motorcycle transform, not a
	# stale heading. Lean remains visual, leaving server hit/collision alone.
	actor.global_basis=global_basis
	actor.body_root.position=Vector3(0,.32,.22)
	actor.body_root.rotation=Vector3(-.32+visual_pitch*.65,0.,visual_lean)
	for label in ["head","torso","arm_l","arm_r","leg_l","leg_r"]: actor.avatar_parts[label].show()
	var pelvis:=actor.body_root.get_node_or_null("Pelvis") as Node3D
	if is_instance_valid(pelvis): pelvis.show()
	actor.avatar_parts.torso.rotation=Vector3(-.055,0.,-visual_lean*.12)
	actor.avatar_parts.head.rotation=Vector3(.12-visual_pitch*.25,0.,-visual_lean*.15)
	for side in ["L","R"]:
		var direction: float=-1. if side=="L" else 1.
		var leg: Node3D=actor.avatar_parts["leg_"+side.to_lower()]
		leg.rotation=Vector3(1.05+visual_pitch*.35,0.,direction*.045)
		var knee:=leg.get_node_or_null("Knee"+side) as Node3D
		if is_instance_valid(knee):
			knee.rotation=Vector3(-1.48,0.,direction*-.045)
			var shoe:=knee.get_node_or_null("Shoe"+side) as Node3D
			if is_instance_valid(shoe): shoe.rotation.x=.48
		if is_instance_valid(handlebar):
			var grip:=handlebar.get_node("GripLeft" if side=="L" else "GripRight") as Marker3D
			WarHumanRig.pose(actor,actor.avatar_parts["arm_"+side.to_lower()],grip.global_position,"arm"+side,grip)
