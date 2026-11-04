extends RefCounted
class_name WarTVGuidance
var manager: Node
var flights: Dictionary={}
var pending: Dictionary={}
var view_id:=""
var state_clock:=0.0
var listener_active:=false
var states_received:=0

func _round(id: String) -> Dictionary:
	return manager.game.war_fx.find_round(id)

func register(shot: Dictionary) -> void:
	var id:=str(shot.shot_id)
	if flights.has(id): return
	flights[id]={"owner":int(shot.owner),"vehicle":str(shot.tv_vehicle),"life":int(shot.tv_life),"epoch":int(shot.tv_epoch),"linked":bool(shot.get("tv_linked",true)),"sequence":0,"last_command":float(manager.game.war_clock)}
	if is_instance_valid(manager.game.local_player) and int(shot.owner)==manager.game.local_player.peer_id:
		view_id=id
		var forward: Vector3=Vector3(shot.velocity).normalized()
		manager.orbit_yaw=atan2(-forward.x,-forward.z);manager.orbit_pitch=asin(clampf(forward.y,-1,1))
	if pending.has(id):
		var value: Array=pending[id];pending.erase(id);receive_state.callv(value)

func has_flight(vehicle: String) -> bool:
	for entry: Dictionary in flights.values():
		if str(entry.vehicle)==vehicle: return true
	return false

func _valid(entry: Dictionary) -> bool:
	var actor=manager.game.players.get(int(entry.owner))
	var vehicle=manager.find_target(str(entry.vehicle))
	return is_instance_valid(actor) and vehicle is WarVehicle and manager.is_operator(int(entry.owner)) and actor.life_id==int(entry.life) and vehicle.control_epoch==int(entry.epoch) and actor.vehicle_id==str(entry.vehicle)

func viewing() -> bool:
	return not view_id.is_empty() and flights.has(view_id) and bool(flights[view_id].linked) and _valid(flights[view_id]) and not _round(view_id).is_empty() and bool(_round(view_id).active)

func direction() -> Vector3:
	return Basis.from_euler(Vector3(manager.orbit_pitch,manager.orbit_yaw,0))*Vector3.FORWARD

func steer(shot: Dictionary,delta: float) -> void:
	var id:=str(shot.shot_id)
	if not flights.has(id): return
	var entry: Dictionary=flights[id]
	if not bool(entry.linked): return
	var desired: Vector3=Vector3(shot.velocity).normalized()
	if bool(shot.server):
		if not _valid(entry): release(int(entry.owner),id);return
		var control: Dictionary=manager.controls.get(int(entry.owner),{})
		if str(control.get("tv_id",""))==id and float(manager.game.war_clock)-float(control.get("at",-100))<.3:
			if not bool(control.get("guide",false)): release(int(entry.owner),id);return
			var requested: Variant=control.get("tv_direction",Vector3.ZERO)
			if requested is Vector3 and CombatRules.finite_vector(requested) and absf(requested.length()-1)<.02:
				desired=requested.normalized();entry.last_command=float(manager.game.war_clock)
		if float(manager.game.war_clock)-float(entry.last_command)>.65: release(int(entry.owner),id);return
	elif id==view_id: desired=direction()
	var velocity: Vector3=shot.velocity;var current:=velocity.normalized();var axis:=current.cross(desired)
	if axis.length_squared()<.000001 and current.dot(desired)<-.99: axis=current.cross(Vector3.UP if absf(current.y)<.9 else Vector3.RIGHT)
	if axis.length_squared()>.000001:
		shot.velocity=velocity.rotated(axis.normalized(),minf(current.angle_to(desired),float(WarRules.TV_MISSILE.turn_rate)*delta))

func tick(delta: float) -> void:
	if not manager.multiplayer.is_server(): return
	state_clock+=delta
	var send:=state_clock>=.1
	if send: state_clock=0
	for id in flights.keys():
		var entry: Dictionary=flights[id];var shot:=_round(id)
		if shot.is_empty() or not bool(shot.active):
			manager._broadcast("tv_finished",[id]);finish(id);continue
		if bool(entry.linked) and not _valid(entry): release(int(entry.owner),id)
		if send:
			entry.sequence=int(entry.sequence)+1
			manager._broadcast("tv_state",[id,int(entry.sequence),shot.position,shot.velocity,float(shot.life),bool(entry.linked),float(manager.game.war_clock)])

func receive_state(id: String,sequence: int,position: Vector3,velocity: Vector3,left: float,linked: bool,stamp: float) -> void:
	if not position.is_finite() or not velocity.is_finite() or not is_finite(left) or not is_finite(stamp): return
	if not flights.has(id):
		if pending.size()>16: pending.erase(pending.keys()[0])
		pending[id]=[id,sequence,position,velocity,left,linked,stamp];return
	var entry: Dictionary=flights[id]
	if sequence<=int(entry.sequence): return
	entry.sequence=sequence;entry.linked=linked;states_received+=1
	var shot:=_round(id)
	if shot.is_empty(): return
	var age:=clampf(float(manager.game.war_clock)-stamp,0,.15)
	var error:=position+velocity*age-Vector3(shot.position)
	if error.length()>12:
		shot.position=position+velocity*age;shot.history=[shot.position];shot.correction=Vector3.ZERO
	else: shot.correction=error
	shot.velocity=velocity;shot.life=maxf(0,left-age);shot.visual_wait=false
	if not linked and id==view_id: stop_view()

func request_release() -> void:
	if view_id.is_empty(): return
	var id:=view_id;stop_view()
	manager.request_command("tv_release",{"id":id})

func release(owner: int,id: String) -> void:
	if not flights.has(id) or int(flights[id].owner)!=owner: return
	flights[id].linked=false
	manager._broadcast("tv_link",[id,false])
	if id==view_id: stop_view()

func receive_link(id: String,linked: bool) -> void:
	if flights.has(id): flights[id].linked=linked
	if not linked and id==view_id: stop_view()

func finish(id: String) -> void:
	if id==view_id: stop_view()
	flights.erase(id);pending.erase(id)

func stop_view() -> void:
	if view_id.is_empty() and not listener_active: return
	view_id=""
	var vehicle=manager.find_target(manager._own_id())
	if vehicle is WarVehicle and vehicle.is_inside_tree() and vehicle.optic.is_inside_tree():
		var forward: Vector3=-vehicle.optic.global_basis.z.normalized()
		manager.orbit_yaw=atan2(-forward.x,-forward.z);manager.orbit_pitch=asin(clampf(forward.y,-1,1))
	if listener_active:
		listener_active=false
		if is_instance_valid(manager.tv_listener) and manager.tv_listener.is_inside_tree(): manager.tv_listener.clear_current()
		var actor=manager.game.local_player
		if is_instance_valid(actor) and is_instance_valid(actor.audio_listener) and actor.audio_listener.is_inside_tree(): actor.audio_listener.make_current()

func update_camera() -> bool:
	if not viewing():
		if not view_id.is_empty(): stop_view()
		return false
	var shot:=_round(view_id);var forward: Vector3=Vector3(shot.velocity).normalized()
	manager.camera.global_position=Vector3(shot.position)-forward*.10
	manager.camera.look_at(Vector3(shot.position)+forward*10);manager.camera.fov=70
	if not listener_active and is_instance_valid(manager.tv_listener): manager.tv_listener.make_current();listener_active=true
	return true

func hud() -> String:
	if not viewing(): return ""
	var shot:=_round(view_id)
	return "MÍSSIL TV · LINK ATIVO\nTEMPO %.1f s · %.0f m\nMOUSE · GUIAR / C · VOLTAR"%[float(shot.life),float(shot.distance)]

func clear() -> void:
	stop_view();flights.clear();pending.clear();state_clock=0

func has_link(vehicle: String) -> bool:
	for entry: Dictionary in flights.values():
		if str(entry.vehicle)==vehicle and bool(entry.linked): return true
	return false
func release_owner(owner: int) -> void:
	for id in flights.keys():
		if int(flights[id].owner)==owner and bool(flights[id].linked): release(owner,id)
