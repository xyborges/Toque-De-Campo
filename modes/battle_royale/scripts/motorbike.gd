extends "res://modes/war/scripts/motorbike.gd"

var engine: AudioStreamPlayer3D
var spawn_heading:=0.
var engine_load:=0.
func _ready() -> void:
	super._ready()
	spawn_heading=heading
	remove_meta("war_vehicle");set_meta("br_bike",vehicle_id)
	if DisplayServer.get_name()!="headless":
		GameAudioSettings.ensure()
		engine=AudioStreamPlayer3D.new();engine.stream=preload("res://audio/war/engine-bike.wav");engine.bus="Veiculos"
		engine.max_distance=110.;engine.unit_size=8.;engine.panning_strength=1.1;engine.volume_db=-15.;add_child(engine)
		engine.finished.connect(func():if driver>0 and not destroyed:engine.play())

func simulate(delta: float,control: Dictionary) -> void:
	if destroyed:return
	engine_load=clampf(absf(float(control.get("throttle",0.))),0.,1.)
	if _skip_resting_motion(delta,control):return
	steering=clampf(float(control.get("steer",0)),-1.,1.)
	var throttle:=clampf(float(control.get("throttle",0)),-1.,1.)
	speed=move_toward(speed,throttle*(25. if throttle>=0. else 4.),delta*7.*(1. if absf(throttle)>.01 else 2.))
	heading-=steering*1.15*clampf(absf(speed)/6.,0.,1.)*delta*signf(speed)
	basis=Basis(Vector3.UP,heading)*ground_support.tilt
	var forward: Vector3=Basis(Vector3.UP,heading)*Vector3.FORWARD
	velocity.x=forward.x*speed;velocity.z=forward.z*speed;velocity.y-=15.*delta
	var motion_start:=global_position
	step_motion.move(self,delta)
	if is_on_floor():velocity.y=minf(velocity.y,0.)
	if step_motion.blocked_motion:
		var actual_speed: float=(global_position-motion_start).dot(forward)/maxf(delta,.001)
		if absf(actual_speed)<absf(speed)*.5:speed=actual_speed
	ground_support.align(self,delta);animate_running_gear(delta)
	global_position.x=clampf(global_position.x,-985.,985.);global_position.z=clampf(global_position.z,-985.,985.)
	_observe_ground_rest(delta,control)

func render(delta: float) -> void:
	super.render(delta)
	# Rider/camera pose reads heading, while the base renderer interpolates
	# rotation. Keep both on the same presented hull instead of spawn yaw.
	heading=rotation.y

func network_state() -> Array:
	# Motorcycles have no gun, reload or turret state. Keep movement packets
	# small enough to fit the transport MTU instead of sending an APC schema.
	var state := [vehicle_id,global_position,rotation,driver,seats_revision,control_epoch,spawn_generation,hp,speed,steering,destroyed,engine_load]
	if seats.has(1): state.append(int(seats[1]))
	return state

func receive_network_state(state: Array) -> void:
	var occupants := {}
	if int(state[3])>0: occupants[0]=int(state[3])
	if state.size()==13 and int(state[12])>0: occupants[1]=int(state[12])
	var packet: Dictionary={"position":state[1],"rotation":state[2],"driver":int(state[3]),"seats":occupants,"seats_revision":int(state[4]),"control_epoch":int(state[5]),"spawn_generation":int(state[6]),"hp":float(state[7]),"speed":float(state[8]),"steering":float(state[9]),"destroyed":bool(state[10]),"ammo":0,"secondary_ammo":0,"selected":"primary","reload":0.,"wait":0.,"turret":0.,"pitch":0.}
	receive(packet)
	engine_load=clampf(float(state[11]),0.,1.)

func _process(delta: float) -> void:
	if not is_instance_valid(engine):return
	var running:=driver>0 and not destroyed
	if running and not engine.playing:engine.play()
	if not running and engine.playing:engine.stop()
	engine.pitch_scale=lerpf(engine.pitch_scale,.75+absf(speed)/25.*.90+engine_load*.15,1.-exp(-delta*6.))
	engine.volume_db=lerpf(engine.volume_db,-16.+minf(1.,absf(speed)/18.)*7.,1.-exp(-delta*5.))
