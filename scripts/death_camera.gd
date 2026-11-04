extends Node3D
class_name GameDeathCamera
var camera: Camera3D
var previous: WeakRef
var target: WeakRef
var anchor := Vector3.ZERO
var heading := Vector3.FORWARD
var active := false
var minimum_y := -10000.0

func follow(body: Node3D,point: Vector3,direction: Vector3,min_y := -10000.0) -> void:
	if DisplayServer.get_name()=="headless": return
	var old := get_viewport().get_camera_3d()
	if old!=camera: previous = weakref(old) if old else null
	if camera==null:
		camera = Camera3D.new()
		camera.fov = 65
		camera.near = .04
		camera.far = 2000
		add_child(camera)
	target = weakref(body) if is_instance_valid(body) else null
	anchor = point+Vector3.UP*.7
	heading = Vector3(direction.x,0,direction.z).normalized()
	if heading.length_squared()<.1: heading = Vector3.FORWARD
	minimum_y = min_y
	active = true
	camera.make_current()
	position_camera(.016,true)

func stop() -> void:
	active = false
	if camera: camera.current = false
	if previous and is_instance_valid(previous.get_ref()): previous.get_ref().make_current()
	target = null

func _process(delta: float) -> void:
	if active: position_camera(delta,false)

func position_camera(delta: float,immediate: bool) -> void:
	var desired_anchor := anchor
	if target and is_instance_valid(target.get_ref()): desired_anchor = target.get_ref().global_position+Vector3.UP*.35
	anchor = desired_anchor if immediate else anchor.lerp(desired_anchor,1.0-exp(-delta*7.0))
	var desired := anchor-heading*3.9+Vector3.UP*1.65+heading.cross(Vector3.UP)*1.1
	desired.y = maxf(minimum_y,desired.y)
	var safe := CameraObstruction.resolve(get_world_3d(),anchor,desired,[],.22)
	camera.global_position = safe.position
	if camera.global_position.distance_squared_to(anchor)>.001: camera.look_at(anchor)
