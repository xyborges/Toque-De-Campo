extends CharacterBody3D
class_name WarDrone
var drone_id := ""
var sent_state_sequence:=0
var received_state_sequence:=0
var received_state_usec:=0
var owner_id := 0
var driver := 0
var team := 0
var hp := 60.0
var battery := 65.0
var operator_origin := Vector3.ZERO
var heading := 0.0
var destination := Vector3.ZERO
var destroyed := false
var falling := false
var crashed := false
var rotors: Array[Node3D] = []
func _ready() -> void:
	name = drone_id
	collision_layer = 1|32
	collision_mask = 1
	set_meta("war_drone",drone_id)
	set_meta("surface","metal")
	var shape := SphereShape3D.new()
	shape.radius = .34
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	destination = global_position
	if DisplayServer.get_name()=="headless": return
	WarUniform.box(self,"DroneBody",Vector3.ZERO,Vector3(.32,.16,.42),WarVehicle.material("353d36"))
	for x in [-1,1]:
		for z in [-1,1]:
			var end := Vector3(x*.48,0,z*.48)
			var arm := WarUniform.box(self,"CarbonArm",end*.5,Vector3(.055,.05,.7),WarVehicle.material("252c29"))
			arm.rotation.y = atan2(x,z)
			var rotor := Node3D.new()
			rotor.position = end+Vector3.UP*.08
			add_child(rotor)
			WarUniform.box(rotor,"RotorBlade",Vector3.ZERO,Vector3(.45,.015,.045),WarVehicle.material("424b40"))
			WarUniform.box(rotor,"RotorBlade",Vector3.ZERO,Vector3(.045,.015,.45),WarVehicle.material("424b40"))
			rotors.append(rotor)
	WarUniform.box(self,"DroneCamera",Vector3(0,-.12,-.2),Vector3(.1,.1,.1),WarVehicle.material("232c2a"))
	WarUniform.box(self,"ExplosivePayload",Vector3(0,-.19,.04),Vector3(.22,.15,.30),WarVehicle.material("6f7253"))

func simulate(delta: float,control: Dictionary) -> void:
	if destroyed: return
	battery = maxf(0,battery-delta)
	if falling:
		velocity.x=move_toward(velocity.x,0,delta*2)
		velocity.z=move_toward(velocity.z,0,delta*2)
		velocity.y-=9.81*delta
		crashed=move_and_collide(velocity*delta)!=null
		if WarCoast.wet(global_position.x,global_position.z) and global_position.y<=WarCoast.wave(global_position,0): crashed=true
		return
	heading = float(control.get("yaw",heading))
	var wish: Vector3 = Basis(Vector3.UP,heading)*Vector3(float(control.get("strafe",0)),float(control.get("lift",0)),-float(control.get("throttle",0)))
	velocity = velocity.lerp(wish.limit_length(1)*16.1,1.0-exp(-delta*6.0))
	move_and_slide()
	var offset := global_position-operator_origin
	if offset.length()>500: global_position=operator_origin+offset.normalized()*500;velocity=Vector3.ZERO
	var floor_y := WarTerrain.height_at(global_position.x,global_position.z)+.45
	global_position.y=clampf(global_position.y,floor_y,floor_y+85)
	rotation.y = heading
	animate_rotors(delta)

func begin_fall() -> void:
	if destroyed or falling: return
	falling=true;driver=0
	velocity.y=minf(0,velocity.y)

func snapshot() -> Dictionary:
	sent_state_sequence+=1
	return {"id":drone_id,"sequence":sent_state_sequence,"owner":owner_id,"driver":driver,"team":team,"position":global_position,"velocity":velocity,"yaw":heading,"hp":hp,"battery":battery,"destroyed":destroyed,"falling":falling}

func receive(state: Dictionary) -> void:
	# Reliable repair and ordinary motion can cross in flight. Legacy servers
	# omit sequence; accept those only until a sequenced state has arrived.
	var state_sequence:=int(state.get("sequence",0))
	if received_state_sequence>0 and state_sequence<=received_state_sequence:return
	if state_sequence>0:received_state_sequence=state_sequence
	received_state_usec=Time.get_ticks_usec()
	owner_id=int(state.owner);driver=int(state.driver);team=int(state.team);destination=state.position;heading=float(state.yaw);hp=float(state.hp);battery=float(state.battery);destroyed=bool(state.destroyed)
	var reported: Variant=state.get("velocity",Vector3.ZERO)
	if reported is Vector3 and reported.is_finite(): velocity=reported.limit_length(25.)
	falling=bool(state.get("falling",false))
	visible=not destroyed
	collision_layer=0 if destroyed else 1|32

func render(delta: float) -> void:
	global_position=global_position.lerp(destination,1.0-exp(-delta*17))
	rotation.y=lerp_angle(rotation.y,heading,1.0-exp(-delta*17))
	animate_rotors(delta)

func animate_rotors(delta: float) -> void:
	for rotor in rotors: rotor.rotate_y(delta*(8 if falling else 65))
