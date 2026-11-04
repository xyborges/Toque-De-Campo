extends RefCounted
class_name WarVehicleView

var external:=false
var zoom_level:=0
var distance_now:=11.0
var barrel_point:=Vector3.ZERO
var barrel_range:=0.0
var damage_pulse:=0.0
var previous_hp:=-1.0
var intent_point:=Vector3.ZERO
var view_yaw:=0.0
var view_pitch:=0.0
var view_initialized:=false

func reset(passenger: bool) -> void:
	external=passenger;zoom_level=0;distance_now=11.;previous_hp=-1.;damage_pulse=0;view_initialized=false

func zoom_factor() -> float: return [1.,2.,4.][zoom_level]
func fov(base: float) -> float:
	return rad_to_deg(2*atan(tan(deg_to_rad(base)*.5)/zoom_factor()))

func update(manager: WarVehicles,vehicle: WarVehicle,operator: bool,delta: float) -> void:
	var camera:=manager.camera
	var optic:=vehicle.optic
	var command_direction:=Basis.from_euler(Vector3(manager.orbit_pitch,manager.orbit_yaw,0))*Vector3.FORWARD
	var origin:=vehicle.turret.to_global(Vector3(vehicle.sensor.optic)+vehicle.elevation.position)
	var target_query:=PhysicsRayQueryParameters3D.create(origin,origin+command_direction*1600,CombatRules.SHOT_MASK,manager.owner_excludes(manager.game.local_player.peer_id))
	target_query.collide_with_areas=true
	var target:=manager.get_world_3d().direct_space_state.intersect_ray(target_query)
	# Input describes an independent WORLD direction. Never feed the delayed
	# optic camera rotation back into the desired turret rotation.
	intent_point=target.get("position",origin+command_direction*1600)
	if operator: manager.aim_point=intent_point
	if not operator or external:
		if not view_initialized: view_yaw=manager.orbit_yaw;view_pitch=manager.orbit_pitch;view_initialized=true
		view_yaw=rotate_toward(view_yaw,manager.orbit_yaw,delta*2.8)
		view_pitch=move_toward(view_pitch,manager.orbit_pitch,delta*1.8)
		var view_direction:=Basis.from_euler(Vector3(view_pitch,view_yaw,0))*Vector3.FORWARD
		var anchor:=vehicle.global_position+Vector3.UP*(float(vehicle.spec.size.y)+1.2)
		var desired:=anchor-view_direction*manager.distance
		var safe:=CameraObstruction.resolve(manager.get_world_3d(),anchor,desired,manager.owner_excludes(manager.game.local_player.peer_id),.35,1|16)
		var length_value:=anchor.distance_to(safe.position)
		distance_now=minf(distance_now,length_value) if length_value<distance_now else lerpf(distance_now,length_value,1-exp(-delta*8))
		camera.global_position=anchor-view_direction*distance_now
		camera.look_at(camera.global_position+view_direction)
		camera.fov=lerpf(camera.fov,67.,1-exp(-delta*12))
	else:
		# Elevation rotates the sight, not the observer's seating height.
		# The immediate command cue remains independent of this actual optic.
		camera.global_position=origin
		camera.global_basis=optic.global_basis
		camera.fov=lerpf(camera.fov,fov(float(vehicle.sensor.fov)),1-exp(-delta*12))
	var marker:=vehicle.secondary_muzzle if vehicle.selected=="secondary" else vehicle.muzzle
	var gun_direction: Vector3=-marker.global_basis.z.normalized()
	var query:=PhysicsRayQueryParameters3D.create(marker.global_position,marker.global_position+gun_direction*1600,CombatRules.SHOT_MASK,manager.owner_excludes(manager.game.local_player.peer_id))
	query.collide_with_areas=true
	var hit:=manager.get_world_3d().direct_space_state.intersect_ray(query)
	barrel_point=hit.get("position",marker.global_position+gun_direction*1600)
	barrel_range=marker.global_position.distance_to(barrel_point)
	if previous_hp>=0 and vehicle.hp<previous_hp: damage_pulse=.45
	previous_hp=vehicle.hp;damage_pulse=maxf(0,damage_pulse-delta)
