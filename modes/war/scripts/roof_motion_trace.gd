extends RefCounted
## QA-only local player trace. Activated only by --v27-roof-trace.
## Samples physics after GamePlayer/GameStepMotion and camera obstruction.
const MAX_FRAMES := 7200
static var _stream: FileAccess
static var _frames := 0
static var _last_position := Vector3.ZERO
static var _last_camera := Vector3.ZERO
static var _started := false

static func record(actor: CharacterBody3D, delta: float) -> void:
	if _frames >= MAX_FRAMES: return
	if not _started:
		_started=true
		var path := "user://favela-v27-roof-"+str(Time.get_unix_time_from_system())+".jsonl"
		_stream=FileAccess.open(path,FileAccess.WRITE)
		if _stream == null:
			push_warning("V27 roof trace could not open "+path)
			return
		print("V27_ROOF_TRACE_FILE ",ProjectSettings.globalize_path(path))
		_last_position=actor.global_position
		var first_camera:=actor.get("camera") as Camera3D
		_last_camera=first_camera.global_position if is_instance_valid(first_camera) else Vector3.ZERO
	if _stream==null:return
	var camera:=actor.get("camera") as Camera3D
	var shoulder:=actor.get("shoulder_arm") as SpringArm3D
	var camera_position:=camera.global_position if is_instance_valid(camera) else Vector3.ZERO
	var displacement:=actor.global_position-_last_position
	var camera_delta:=camera_position-_last_camera
	var contacts: Array[Dictionary]=[]
	for i in mini(actor.get_slide_collision_count(),8):
		var contact:=actor.get_slide_collision(i)
		var collider:=contact.get_collider()
		contacts.append({"normal":contact.get_normal(),"point":contact.get_position(),
			"collider":str(collider.name) if collider is Node else str(collider),
			"travel":contact.get_travel()})
	var wish:=Vector2.ZERO
	if InputMap.has_action('move_left') and InputMap.has_action('move_right') and InputMap.has_action('move_forward') and InputMap.has_action('move_back'):
		wish=Input.get_vector('move_left','move_right','move_forward','move_back')
	var sample: Dictionary={
		"physics_frame":Engine.get_physics_frames(),
		"time_usec":Time.get_ticks_usec(),
		"dt":delta,
		"pos":actor.global_position,
		"delta":displacement,
		"velocity":actor.velocity,
		"floor":actor.is_on_floor(),
		"floor_normal":actor.get_floor_normal() if actor.is_on_floor() else Vector3.ZERO,
		"slide_count":actor.get_slide_collision_count(),
		"contacts":contacts,
		"step_contact_frame":actor.get_meta("step_contact_frame",-1),
		"input":wish,
		"camera":camera_position,
		"camera_delta":camera_delta,
		"camera_parent":str(camera.get_parent().name) if is_instance_valid(camera) and is_instance_valid(camera.get_parent()) else "",
		"spring_length":shoulder.spring_length if is_instance_valid(shoulder) else -1.0,
		"camera_close":actor.get("camera_close")
	}
	_stream.store_line(JSON.stringify(sample))
	_frames+=1
	_last_position=actor.global_position
	_last_camera=camera_position
	if _frames%30==0:_stream.flush()
	if _frames==MAX_FRAMES:
		_stream.flush()
		_stream.close()
