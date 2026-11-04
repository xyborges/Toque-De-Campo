extends Node3D
class_name BRMotorbikes

const BIKE=preload("res://modes/battle_royale/scripts/motorbike.gd")
var game: BattleRoyaleGame
var bikes: Dictionary={}
var controls: Dictionary={}
var sequences: Dictionary={}
var epoch:=0
var sequence:=0
var snapshot_sequence:=0
var latest_sequence:=-1
var state_sequences: Dictionary={}
var clock:=0.
var send_clock:=0.

func _ready() -> void:
	name="Motorbikes"
	var buildings:=BRAfghanLandform.building_layout()
	for i in range(0,buildings.size(),8):
		if bikes.size()>=18:break
		var house: Dictionary=buildings[i];var near:=BRAfghanLandform._near_road(Vector2(house.position.x,house.position.z))
		if not is_finite(float(near.distance)):continue
		var away: Vector2=(Vector2(house.position.x,house.position.z)-Vector2(near.point)).normalized()
		var p: Vector2=Vector2(near.point)+away*(float(near.width)*.5+2.)
		var position:=BRAfghanMap.point(p.x,p.y)+Vector3.UP*.12
		if not BRAfghanMap.accessible(position) or BRAfghanMap.is_water(position):continue
		var bike: WarVehicle=BIKE.new();bike.kind="bike_0";bike.vehicle_id="br_bike_%02d"%bikes.size();bike.position=position;bike.heading=float(house.yaw);bike.rotation.y=bike.heading
		add_child(bike);bikes[bike.vehicle_id]=bike

func occupied(actor: GamePlayer) -> bool:return bikes.has(actor.vehicle_id) and bikes[actor.vehicle_id].driver==actor.peer_id

func interact() -> bool:
	var actor:=game.local_player
	if not is_instance_valid(actor) or actor.hp<=0 or game.phase!="active":return false
	var id:=actor.vehicle_id
	if id.is_empty():
		var best:=2.8
		for bike: WarVehicle in bikes.values():
			var distance:=actor.global_position.distance_to(bike.global_position)
			if distance<best and bike.driver<=0 and not bike.destroyed:best=distance;id=bike.vehicle_id
	if id.is_empty():return false
	if game.multiplayer.is_server():_interact(actor.peer_id,id,actor.life_id,game.br_generation)
	else:rpc_id(1,"server_interact",id,actor.life_id,game.br_generation)
	return true

@rpc("any_peer","call_remote","reliable")
func server_interact(id: String,life: int,generation: int) -> void:
	if game.multiplayer.is_server():_interact(multiplayer.get_remote_sender_id(),id,life,generation)

func _interact(peer: int,id: String,life: int,generation: int) -> void:
	if not game.multiplayer.is_server():return
	var actor:=game.players.get(peer) as GamePlayer
	if not actor or actor.hp<=0 or actor.life_id!=life or game.br_generation!=generation or game.phase!="active" or not bikes.has(id):return
	if not game.network_guard.allow(peer,"br_bike_interact",3,3):return
	var bike: WarVehicle=bikes[id]
	if occupied(actor):release(peer);return
	if not actor.vehicle_id.is_empty():return
	if bike.driver>0 or bike.destroyed or actor.global_position.distance_to(bike.global_position)>3.:return
	# Proximity alone cannot board through a building wall or closed door.
	var sight:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.9,bike.global_position+Vector3.UP*.9,1|16,[actor.get_rid(),bike.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():return
	if bike.allocate_seat(peer)!=0:return
	_prepare_rider(actor);actor.vehicle_id=id;epoch+=1
	controls.erase(peer);sequences.erase(peer)
	if actor.body_collision:actor.body_collision.set_deferred("disabled",true)
	game.heal_pending.erase(peer);GameDiagnostics.record("br_bike_enter",{"peer":peer,"bike":id})
	pose(actor);_send_occupancy(bike);_send_state()

func release(peer: int,forced:=false) -> bool:
	if not game.multiplayer.is_server():return false
	var actor:=game.players.get(peer) as GamePlayer
	for bike: WarVehicle in bikes.values():
		if bike.driver!=peer:continue
		var exit: Dictionary={}
		if is_instance_valid(actor) and actor.hp>0:
			exit=safe_exit(bike,actor)
			if exit.is_empty() and not forced:return false
		bike.vacate_seat(peer);bike.speed=0.;controls.erase(peer);sequences.erase(peer)
		if is_instance_valid(actor):
			# Death/disconnect must release the reservation without relocating the
			# corpse. Destruction/reset can force a living rider out of the seat.
			if actor.hp>0:actor.global_position=exit.get("position",bike.global_position+Vector3.UP*1.5)
			actor.reset_physics_interpolation()
			_restore_actor(actor)
		GameDiagnostics.record("br_bike_leave",{"peer":peer,"bike":bike.vehicle_id})
		_send_occupancy(bike,actor.global_position if is_instance_valid(actor) else bike.global_position,peer)
		_send_state();return true
	controls.erase(peer);sequences.erase(peer)
	if is_instance_valid(actor) and not actor.vehicle_id.is_empty():_restore_actor(actor)
	return true

func safe_exit(bike: WarVehicle,actor: GamePlayer) -> Dictionary:
	var excluded: Array[RID]=[bike.get_rid(),actor.get_rid()]
	var shape:=CapsuleShape3D.new();shape.radius=.36;shape.height=1.8
	var space:=get_world_3d().direct_space_state
	var origin:=bike.global_position+Vector3.UP*.95
	# Test both sides and ends. Do not teleport through a wall to a farther
	# candidate; the full capsule must fit at the endpoint and along the route.
	var offsets: Array[Vector3]=[Vector3(1.3,0,0),Vector3(-1.3,0,0),Vector3(0,0,1.8),Vector3(0,0,-1.8)]
	for radius in [1.8,2.4]:
		for index in 8:offsets.append(Vector3(cos(TAU*index/8.)*radius,0,sin(TAU*index/8.)*radius))
	for offset: Vector3 in offsets:
		var point:=bike.global_position+Basis(Vector3.UP,bike.heading)*offset
		if absf(point.x)>985. or absf(point.z)>985.:continue
		var floor_query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.,point-Vector3.UP*3.,1|16,excluded)
		var hit:=space.intersect_ray(floor_query)
		if hit.is_empty() or not hit.collider is StaticBody3D or Vector3(hit.normal).y<.7:continue
		point=Vector3(hit.position)+Vector3.UP*.08
		if BRAfghanMap.is_water(point):continue
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1|4|16|32;query.exclude=excluded
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
		if not space.intersect_shape(query,1).is_empty():continue
		query.transform.origin=origin;query.motion=point+Vector3.UP*.95-origin
		var travel:=space.cast_motion(query)
		if travel.size()!=2 or travel[0]<.999:continue
		return {"position":point}
	return {}

func _restore_actor(actor: GamePlayer) -> void:
	actor.vehicle_id="";actor.velocity=Vector3.ZERO;actor.trigger_held=false
	actor.camera_pivot.rotation.y=0.;actor.rotation.y=actor.yaw
	actor.stance.advance(actor,1.)
	if actor.body_collision:actor.body_collision.set_deferred("disabled",actor.hp<=0)
	if actor.hp>0:actor._animate_walk();actor._update_weapon_pose()
	actor._update_view()

func _prepare_rider(actor: GamePlayer) -> void:
	actor.cancel_reload();actor.cancel_melee();actor.trigger_held=false;actor.clear_aim()
	# A prone/crouched rig carries displaced hips, head and knee pivots.
	# Clear that on-foot stance before applying the shared seated IK.
	actor.set_posture(0,false,true);actor.stance.crouch_weight=0.;actor.stance.prone_weight=0.
	GameInfantryPose.reset(actor);actor.stance.advance(actor,1.);actor.stance.pose(actor)

func _send_occupancy(bike: WarVehicle,point:=Vector3.ZERO,exited:=0) -> void:
	if not game.online:return
	for id in game._human_ids():
		if id in game.multiplayer.get_peers() and game._network_peer_ready(id):rpc_id(id,"remote_occupancy",bike.vehicle_id,bike.seats.duplicate(),bike.seats_revision,bike.control_epoch,point,exited,game.br_generation)

@rpc("authority","call_remote","reliable")
func remote_occupancy(id: String,seats: Dictionary,revision: int,control_epoch: int,point: Vector3,exited: int,generation: int) -> void:
	if generation!=game.br_generation or not bikes.has(id):return
	var bike: WarVehicle=bikes[id]
	if revision<bike.seats_revision:return
	bike.receive_seats(seats,revision,control_epoch)
	if exited>0 and game.players.has(exited):
		var actor: GamePlayer=game.players[exited]
		if actor.vehicle_id==id or actor.vehicle_id.is_empty():
			if actor.hp>0:actor.global_position=point;actor.network_target=point;actor.previous_position=point;actor.reset_physics_interpolation()
			_restore_actor(actor)
	_sync_rider(bike)

func _sync_rider(bike: WarVehicle) -> void:
	if bike.driver<=0 or not game.players.has(bike.driver):return
	var actor: GamePlayer=game.players[bike.driver]
	var entering:=actor.vehicle_id!=bike.vehicle_id
	if entering:_prepare_rider(actor)
	actor.vehicle_id=bike.vehicle_id;actor.trigger_held=false
	if actor.body_collision:actor.body_collision.set_deferred("disabled",true)
	pose(actor)
	_send_state()

func pose(actor: GamePlayer) -> void:
	if not occupied(actor):return
	var bike: WarVehicle=bikes[actor.vehicle_id]
	actor.global_position=bike.global_position+bike.global_basis*Vector3(0,.07,0)
	actor.velocity=Vector3.ZERO;actor.weapon_root.hide();actor.camera_pivot.position.y=1.5
	bike.pose_rider(actor)
	if actor.is_local:
		actor.camera_close=false;actor.weapon_optics.stop()
		actor.camera_pivot.rotation.y=angle_difference(bike.heading,actor.yaw)
		# Riding uses an external orbit without changing the selected on-foot
		# FPP/TPP mode. Exclude this bike from the obstruction sweep.
		var anchor:=actor.camera_pivot.global_position
		var desired:=actor.camera_pivot.to_global(Vector3(.55,.28,3.1))
		var safe:=CameraObstruction.resolve(get_world_3d(),anchor,desired,[actor.get_rid(),bike.get_rid()],.18,1|16)
		actor.camera.global_transform=Transform3D(actor.camera_pivot.global_basis,safe.position)
		actor.camera.fov=67.
		if is_instance_valid(actor.view_root):actor.view_root.hide()
		if is_instance_valid(actor.grenade_view):actor.grenade_view.hide()
		if is_instance_valid(game.scope_overlay):game.scope_overlay.hide()
		if is_instance_valid(game.aim_dot):game.aim_dot.hide()

@rpc("any_peer","call_remote","unreliable",2)
func server_control(number: int,life: int,generation: int,throttle: float,steer: float,bike_id:="",control_epoch:=-1) -> void:
	_accept_control(multiplayer.get_remote_sender_id(),number,life,generation,throttle,steer,bike_id,control_epoch)

func _accept_control(id: int,number: int,life: int,generation: int,throttle: float,steer: float,bike_id: String,control_epoch: int) -> void:
	if not game.multiplayer.is_server():return
	var actor:=game.players.get(id) as GamePlayer
	if not actor or actor.hp<=0 or not occupied(actor) or game.phase!="active" or actor.life_id!=life or generation!=game.br_generation or number<=int(sequences.get(id,-1)) or not is_finite(throttle) or not is_finite(steer):return
	var bike: WarVehicle=bikes[actor.vehicle_id]
	if bike_id!=actor.vehicle_id or control_epoch!=bike.control_epoch:return
	if not game.network_guard.allow(id,"br_bike_control",24,8):return
	sequences[id]=number;controls[id]={"throttle":clampf(throttle,-1.,1.),"steer":clampf(steer,-1.,1.),"at":Time.get_ticks_msec()}

func _physics_process(delta: float) -> void:
	if game.closing:return
	var actor:=game.local_player
	send_clock+=delta
	if actor and occupied(actor) and send_clock>=.05:
		send_clock=0.;sequence+=1
		var allowed:=game.gameplay_input_allowed() and actor.hp>0 and game.phase=="active"
		var throttle:=Input.get_axis("move_back","move_forward") if allowed else 0.
		var steer:=Input.get_axis("move_left","move_right") if allowed else 0.
		if game.multiplayer.is_server():_accept_control(actor.peer_id,sequence,actor.life_id,game.br_generation,throttle,steer,actor.vehicle_id,bikes[actor.vehicle_id].control_epoch)
		else:rpc_id(1,"server_control",sequence,actor.life_id,game.br_generation,throttle,steer,actor.vehicle_id,bikes[actor.vehicle_id].control_epoch)
	for bike: WarVehicle in bikes.values():
		if game.multiplayer.is_server():
			var rider:=game.players.get(bike.driver) as GamePlayer
			if bike.driver>0 and (not rider or rider.hp<=0 or game.phase!="active"):release(bike.driver,true)
			var control: Dictionary=controls.get(bike.driver,{})
			if Time.get_ticks_msec()-int(control.get("at",0))>300:control={}
			bike.simulate(delta,control)
		else:bike.render(delta)
	clock+=delta
	if game.multiplayer.is_server() and clock>=.1:clock=0.;_send_state()

func _send_state() -> void:
	if not game.online or not game.multiplayer.is_server():return
	snapshot_sequence+=1
	var states: Array=[]
	for bike: WarVehicle in bikes.values():
		states.append(bike.network_state())
		if states.size()==6:
			GameNetworkBroadcast.send(self,"remote_state",[snapshot_sequence,game.br_generation,states]);states=[]
	if not states.is_empty():GameNetworkBroadcast.send(self,"remote_state",[snapshot_sequence,game.br_generation,states])

@rpc("authority","call_remote","unreliable",2)
func remote_state(number: int,generation: int,states: Array) -> void:
	if generation!=game.br_generation or states.size()>6:return
	latest_sequence=maxi(number,latest_sequence)
	for state: Variant in states:
		if not state is Array or state.size()!=12:continue
		var id:=str(state[0]);var bike:=bikes.get(id) as WarVehicle
		if not bike or number<=int(state_sequences.get(id,-1)):continue
		state_sequences[id]=number
		var previous:=bike.driver;bike.receive_network_state(state)
		if previous>0 and previous!=bike.driver and game.players.has(previous):
			var old: GamePlayer=game.players[previous]
			if old.vehicle_id==bike.vehicle_id:_restore_actor(old)
		_sync_rider(bike)

func reset_round() -> void:
	for bike: WarVehicle in bikes.values():
		if bike.driver>0:
			if game.multiplayer.is_server():release(bike.driver,true)
			elif game.players.has(bike.driver):_restore_actor(game.players[bike.driver])
		bike.seats.clear();bike.seat_order.clear();bike.driver=0
		bike.destroyed=false;bike.hp=220.;bike.position=bike.spawn_position;bike.destination=bike.spawn_position;bike.speed=0.;bike.velocity=Vector3.ZERO;bike.collision_layer=1|16
		bike._wake_ground_rest();bike.ground_support.tilt=Basis.IDENTITY
		bike.engine_load=0.
		bike.heading=bike.spawn_heading;bike.rotation=Vector3(0,bike.heading,0);bike.destination_rotation=bike.rotation
		if game.multiplayer.is_server():bike.spawn_generation+=1
	controls.clear();sequences.clear();state_sequences.clear()
