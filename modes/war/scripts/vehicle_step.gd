extends RefCounted
class_name WarVehicleStep

# The running-gear box has a vertical leading face, unlike a wheel/track.
# Recover a blocked, grounded tick over low scenery with the complete hull;
# changing acceleration or shrinking the collider cannot solve that contact.
const MAX_RISE:=.5
const MARGIN:=.001
const PROBE:=preload("res://scripts/performance_probe.gd")
var last_step_frame:=-100
var blocked_motion:=false
var up_contact:=KinematicCollision3D.new()
var landing:=KinematicCollision3D.new()

func move(vehicle: CharacterBody3D,delta: float) -> void:
	var started:=PROBE.begin(&"vehicle.step")
	_move(vehicle,delta)
	if started: PROBE.end(&"vehicle.step",started)

func _move(vehicle: CharacterBody3D,delta: float) -> void:
	blocked_motion=false
	var wanted:=vehicle.velocity
	var horizontal:=Vector3(wanted.x,0,wanted.z)*delta
	var start:=vehicle.global_position
	var supported:=vehicle.is_on_floor() or Engine.get_physics_frames()-last_step_frame<=2
	var slide_started:=PROBE.begin(&"vehicle.move_and_slide")
	vehicle.move_and_slide()
	if slide_started: PROBE.end(&"vehicle.move_and_slide",slide_started)
	if wanted.y>.1 or horizontal.length_squared()<.000001: return
	var blocked:=false
	var floor_y:=cos(vehicle.floor_max_angle)
	for index in vehicle.get_slide_collision_count():
		var contact:=vehicle.get_slide_collision(index)
		for hit in contact.get_collision_count():
			# Occupied hulls and characters are never a stair or support.
			if not contact.get_collider(hit) is StaticBody3D: blocked_motion=true;return
			if contact.get_normal(hit).y<floor_y: blocked=true
	blocked_motion=blocked
	if not blocked: return
	# Suspension deliberately leaves a small clearance above its support,
	# so is_on_floor alone is insufficient even when the tracks are planted.
	if not (supported or vehicle.is_on_floor()):
		if not vehicle.test_move(vehicle.global_transform,Vector3.DOWN*.12,landing,MARGIN): return
		if not landing.get_collider() is StaticBody3D or landing.get_normal().y<floor_y: return
	var travelled:=vehicle.global_position-start
	var remaining:=horizontal-Vector3(travelled.x,0,travelled.z)
	if remaining.length_squared()<.000001 or remaining.dot(horizontal)<=0: return
	var raised:=vehicle.global_transform
	var lift:=MAX_RISE
	# A low ceiling can leave enough space for a curb but not the maximum
	# rise. Keep only the lift actually clear for every collision shape.
	if vehicle.test_move(raised,Vector3.UP*lift,up_contact,MARGIN):
		lift=maxf(0,up_contact.get_travel().y-MARGIN)
	if lift<.015: return
	raised.origin.y+=lift
	if vehicle.test_move(raised,remaining,null,MARGIN): return
	var ahead:=raised
	ahead.origin+=remaining
	if not vehicle.test_move(ahead,Vector3.DOWN*(lift+.08),landing,MARGIN): return
	if not landing.get_collider() is StaticBody3D or landing.get_normal().y<floor_y: return
	var rise:=lift+landing.get_travel().y
	if rise<.015 or rise>MAX_RISE+MARGIN: return
	# All three continuous sweeps have succeeded. Consume only this tick's
	# missing horizontal motion, then establish the new floor contact.
	vehicle.global_position=ahead.origin+landing.get_travel()
	blocked_motion=false
	last_step_frame=Engine.get_physics_frames()
	var snap:=vehicle.floor_snap_length
	vehicle.floor_snap_length=0
	vehicle.velocity=Vector3(0,-.1,0)
	slide_started=PROBE.begin(&"vehicle.move_and_slide")
	vehicle.move_and_slide()
	if slide_started: PROBE.end(&"vehicle.move_and_slide",slide_started)
	vehicle.floor_snap_length=snap
	vehicle.velocity=Vector3(wanted.x,minf(0,vehicle.velocity.y),wanted.z)
