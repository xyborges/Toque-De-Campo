extends RefCounted
class_name WarClientVisualLOD

## Client-only visual workload scheduler. Never throttles the local player,
## server authority, physics processing, incoming RPCs or shot registration.
## A camera snapshot is shared across all remote actors per physics tick.
const REAR_START_DISTANCE_SQUARED:=625.0 # 25 m: close combat remains unchanged.
const NEAR_DISTANCE_SQUARED:=6400.0       # 80 m: existing legacy tier.
const MID_DISTANCE_SQUARED:=62500.0       # 250 m: existing legacy tier.
const MIN_CAMERA_DOT_FACTOR:=0.14         # Hysteresis near the rear hemisphere.
const RESTORE_CAMERA_DOT_FACTOR:=0.08

static var pilot_enabled:=not OS.get_cmdline_user_args().has("--war-client-visual-lod-legacy")
static var stats_enabled:=OS.get_cmdline_user_args().has("--client-lod-stats")
static var count_skipped_rear:=0
static var count_poses_rear:=0
static var count_reacquired:=0
static var count_poses_front:=0
static var _cached_physics_tick: int=-1
static var _cached_viewport_id: int=-1
static var _camera_position:=Vector3.ZERO
static var _camera_forward:=Vector3.FORWARD
static var _camera_available:=false

static func active_for(game: WarGame) -> bool:
	return pilot_enabled and is_instance_valid(game) and game.online and not game.multiplayer.is_server()

static func legacy_interval_usec(distance_sq: float) -> int:
	return 33333 if distance_sq<NEAR_DISTANCE_SQUARED else (66666 if distance_sq<MID_DISTANCE_SQUARED else 125000)

static func interval_usec(distance_sq: float,rear: bool) -> int:
	var interval:=legacy_interval_usec(distance_sq)
	if rear and distance_sq>=REAR_START_DISTANCE_SQUARED:
		# Half the remote pose update rate for truly out-of-view actors;
		# no freezing and no change to existing forward-view intervals.
		interval=maxi(interval,100000 if distance_sq<NEAR_DISTANCE_SQUARED else (200000 if distance_sq<MID_DISTANCE_SQUARED else 250000))
	return interval

static func behind_camera(distance_sq: float,forward_dot: float,was_rear: bool) -> bool:
	if distance_sq<REAR_START_DISTANCE_SQUARED:return false
	# Enter behind only beyond 98 degrees, and leave behind once a
	# camera turn approaches visibility again. Prevents edge flicker.
	var margin:=sqrt(distance_sq)*(RESTORE_CAMERA_DOT_FACTOR if was_rear else -MIN_CAMERA_DOT_FACTOR)
	return forward_dot<margin

static func _update_camera(actor: Node3D,game: WarGame) -> void:
	var tick:=Engine.get_physics_frames()
	var viewport:=actor.get_viewport()
	var viewport_id:=viewport.get_instance_id()
	if _cached_physics_tick==tick and _cached_viewport_id==viewport_id:return
	_cached_physics_tick=tick
	_cached_viewport_id=viewport_id
	var camera:=viewport.get_camera_3d()
	_camera_available=is_instance_valid(camera)
	if _camera_available:
		_camera_position=camera.global_position
		_camera_forward=-camera.global_basis.z
	else:
		_camera_position=game.local_player.global_position
		_camera_forward=Vector3.FORWARD

static func should_update(actor: WarPlayer,game: WarGame,now_usec: int) -> bool:
	# The ordinary, already proven 30/15/8 Hz distance LOD remains the
	# fallback. This function is invoked only by non-authoritative clients.
	var dirty: bool=actor.client_lod_last_weapon!=actor.weapon_id or actor.client_lod_last_gadget!=actor.gadget_equipped or actor.client_lod_last_prone!=actor.prone or actor.client_lod_last_crouched!=actor.crouched
	if not dirty and not actor.client_lod_behind and now_usec<actor.next_pose_usec:
		return false # Fast front path: no camera fetch, dot product or allocations.
	_update_camera(actor,game)
	var offset:=actor.global_position-_camera_position
	var distance_sq:=offset.length_squared()
	var rear:=_camera_available and behind_camera(distance_sq,offset.dot(_camera_forward),actor.client_lod_behind)
	var reacquired:=actor.client_lod_behind and not rear
	actor.client_lod_behind=rear
	if not dirty and not reacquired and now_usec<actor.next_pose_usec:
		if rear and stats_enabled:count_skipped_rear+=1
		return false
	actor.client_lod_last_weapon=actor.weapon_id
	actor.client_lod_last_gadget=actor.gadget_equipped
	actor.client_lod_last_prone=actor.prone
	actor.client_lod_last_crouched=actor.crouched
	actor.next_pose_usec=now_usec+interval_usec(distance_sq,rear)
	if stats_enabled:
		if reacquired:count_reacquired+=1
		if rear:count_poses_rear+=1
		else:count_poses_front+=1
	return true

static func diagnostics() -> Dictionary:
	return {"pilot_enabled":pilot_enabled,"skipped_rear":count_skipped_rear,
		"posed_rear":count_poses_rear,"posed_front":count_poses_front,
		"camera_reacquired":count_reacquired}
