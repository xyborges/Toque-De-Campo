extends Node3D
class_name WarVehicles
const NetworkCadence=preload("res://scripts/network_cadence.gd")
const MOTORBIKE=preload("res://modes/war/scripts/motorbike.gd")
var game: WarGame
var vehicles: Dictionary = {}
var drones: Dictionary = {}
var controls: Dictionary = {}
var sequences: Dictionary = {}
var locks: Dictionary = {}
var healing: Dictionary = {}
var send_clock := 0.0
var snapshot_clock := 0.0
var sequence := 0
var fire_held := false
var orbit_yaw := 0.0
var orbit_pitch := -.22
var distance := 11.0
var zoom := false
var thermal := false
var camera: Camera3D
var last_controlled := ""
var last_control_role := ""
var aim_point := Vector3.ZERO
var lock_target := ""
var lock_progress := 0.0
var last_gadget_clock := -100.0
var effect_clock := 0.0
var last_sent: Dictionary = {}
var vehicle_sent_usec: Dictionary = {}
var vehicle_state_sequences: Dictionary = {}
const VEHICLE_HEARTBEAT_USEC := 500000
var retired_drones: Dictionary = {}
var shot_events: Dictionary={}
var blast_events: Dictionary={}
var last_damage_confirmation: Dictionary={} 
var runover_recent: Dictionary={}
var point_supply_at: Dictionary={}
var smoke_screens: Dictionary={}
var smoke_cooldowns: Dictionary={}
var smoke_overlay: ColorRect
var vehicle_view:=WarVehicleView.new()
var tv:=WarTVGuidance.new()
var tv_listener: AudioListener3D
var hull_shock:=0.0
var shock_clock:=0.0
var impact_events: Dictionary={}

func _ready() -> void:
	name = "WarVehicles"
	tv.manager=self
	for kind in WarRules.VEHICLES:
		if not WarRules.vehicle_enabled(kind):continue
		var data: Dictionary = WarRules.VEHICLES[kind]
		for copy in WarRules.vehicle_count(kind):
			var transport:=bool(data.get("transport",false))
			var vehicle: WarVehicle=MOTORBIKE.new() if transport else (WarShip.new() if data.has("naval") else WarVehicle.new())
			vehicle.kind=kind
			vehicle.vehicle_id="v_"+kind+("_"+str(copy) if transport or WarRules.vehicle_count(kind)>1 else "")
			var base: Vector3=WarRules.BASES[int(data.team)]
			vehicle.position=WarTerrain.point(base.x+(8 if kind in ["guarani","bmp2"] else -8),base.z-12)
			# In Afghanistan the infantry outpost can be uphill. Park armour on
			# preselected road-access bays rather than inside its ravines.
			if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN and kind in ["guarani","bmp2","abrams","t90"]:
				var bay:=WarOperation.armor_bay(WarRules.CURRENT_OPERATION,int(data.team),kind in ["abrams","t90"])
				vehicle.position=WarTerrain.point(bay.x,bay.z)
			if WarRules.CURRENT_OPERATION==WarOperation.FAVELA and kind=="guarani":
				var bay: Vector3=WarOperation.data(WarOperation.FAVELA).armor_bays[0][copy]
				vehicle.position=WarTerrain.point(bay.x,bay.z)
			if transport:
				var transport_spawn:=WarRules.transport_spawn(kind,copy)
				vehicle.position=WarTerrain.point(transport_spawn.x,transport_spawn.z)
			if data.has("naval"): vehicle.position=WarCoast.BERTHS[int(data.team)][0 if str(kind).contains("assault") else 1]
			vehicle.heading=PI*.5 if data.has("naval") and int(data.team)==0 else (-PI*.5 if data.has("naval") else (-PI*.5 if int(data.team)==0 else PI*.5))
			if WarRules.CURRENT_OPERATION in [WarOperation.AFGHAN,WarOperation.FAVELA] and not data.has("naval"):
				vehicle.heading=WarOperation.armor_heading(WarRules.CURRENT_OPERATION,int(data.team))
			vehicle.rotation.y=vehicle.heading
			if not data.has("naval"): vehicle.position=_land_spawn_height(vehicle.position,vehicle.heading,data)
			add_child(vehicle);vehicles[vehicle.vehicle_id]=vehicle
	camera = NavalCamera.new()
	camera.far = 2400
	camera.near = .06
	camera.fov = 67
	add_child(camera)
	tv_listener=AudioListener3D.new();camera.add_child(tv_listener)
	if DisplayServer.get_name()!="headless":
		var guide:=WarShipGuide.new();guide.manager=self;add_child(guide)
		var reticle:=preload("res://modes/war/scripts/vehicle_reticle.gd").new();reticle.manager=self;game.hud_layer.add_child(reticle)
		var slots:=WarVehicleSlots.new();slots.manager=self;game.war_ui.vehicle_panel.get_child(0).add_child(slots)
	if DisplayServer.get_name()!="headless":
		var viewer:=WarThermal.new();viewer.game=game;add_child(viewer)
		# Obscure the camera image while leaving the player's HUD legible.
		var overlay_layer:=CanvasLayer.new();overlay_layer.layer=0;add_child(overlay_layer)
		smoke_overlay=ColorRect.new();smoke_overlay.color=Color(.36,.37,.35,0.);smoke_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay_layer.add_child(smoke_overlay);smoke_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game.ui_focus: game.ui_focus.changed.connect(clear_trigger)
	get_window().focus_exited.connect(clear_trigger)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		fire_held=false
		_send_trigger(false)
	if not game.gameplay_input_allowed(): return
	if tv.viewing():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_C: tv.request_release();get_viewport().set_input_as_handled()
			elif event.keycode==KEY_T: toggle_thermal();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B: request_command("drone",{})
		if event.keycode==KEY_H:
			var actor:=game.local_player as WarPlayer
			request_command("point_supply" if is_instance_valid(actor) and not supply_point_for(actor).is_empty() else "ammo",{})
		if _local_is_operator() and not _transport(find_target(_own_id())):
			if event.keycode==KEY_R: request_command("reload",{})
			if event.keycode==KEY_Q: request_command("smoke",{});get_viewport().set_input_as_handled()
			if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
				request_command("weapon",{"slot":int(event.keycode-KEY_1)+1});get_viewport().set_input_as_handled()
			if event.keycode==KEY_T: toggle_thermal();get_viewport().set_input_as_handled()
		if event.keycode==KEY_C and find_target(_own_id()) is WarVehicle and not _transport(find_target(_own_id())):
			if _local_is_operator() and not find_target(_own_id()) is WarShip:
				vehicle_view.external=not vehicle_view.external
				if vehicle_view.external and thermal: toggle_thermal()
			get_viewport().set_input_as_handled()
	if _own_id().is_empty(): return
	if _transport(find_target(_own_id())):
		fire_held=false;zoom=false
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(4.,distance-.5)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(9.,distance+.5)
		return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			fire_held=event.pressed and _local_is_operator()
			_send_trigger(fire_held)
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and _local_is_operator():
			if find_target(_own_id()) is WarShip: zoom=not zoom
			elif find_target(_own_id()) is WarVehicle:
				vehicle_view.zoom_level=(vehicle_view.zoom_level+1)%3;zoom=vehicle_view.zoom_level>0
			else: zoom=not zoom
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: distance=maxf(6,distance-1)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: distance=minf(19,distance+1)

func clear_trigger() -> void:
	fire_held=false
	_send_trigger(false)
	if tv.viewing(): tv.request_release()

func _own_id() -> String:
	return str(game.local_player.vehicle_id) if is_instance_valid(game.local_player) else ""

func _transport(vehicle: Node) -> bool:
	return is_instance_valid(vehicle) and vehicle is WarVehicle and bool(vehicle.spec.get("transport",false))

func reset_transport_pose(vehicle: Node, actor: GamePlayer) -> void:
	if _transport(vehicle): MOTORBIKE.reset_rider_pose(actor)

func _local_is_operator() -> bool:
	return is_instance_valid(game.local_player) and is_operator(game.local_player.peer_id)

func seat_of(id: int) -> int:
	if not game.members.has(id): return -1
	var current:=find_target(str(game.members[id].vehicle))
	return current.seat_of(id) if current is WarVehicle else (0 if current is WarDrone and current.driver==id else -1)

func is_operator(id: int) -> bool:
	if not game.players.has(id) or not game.members.has(id): return false
	var actor:=game.players[id] as WarPlayer
	if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed: return false
	var current:=find_target(str(game.members[id].vehicle))
	return is_instance_valid(current) and not current.destroyed and current.driver==id and (not current is WarVehicle or current.seat_of(id)==0)

func _control_epoch(id: int) -> int:
	if not game.members.has(id): return -1
	var current:=find_target(str(game.members[id].vehicle))
	return current.control_epoch if current is WarVehicle else (int(game.players[id].life_id) if current is WarDrone and game.players.has(id) else -1)

func look(relative: Vector2) -> void:
	var factor:=1.0;var own:=find_target(_own_id())
	var guided:=tv.viewing();var aimed:=zoom or guided
	if own is WarShip:
		var naval_camera:=camera as NavalCamera
		naval_camera.orbit_yaw=orbit_yaw;naval_camera.orbit_pitch=orbit_pitch;naval_camera.zoom=zoom
		naval_camera.mouse(relative,own.naval_kind,own.naval_weapon)
		orbit_yaw=naval_camera.orbit_yaw;orbit_pitch=naval_camera.orbit_pitch
		return
	elif own is WarVehicle:
		factor=GameAimSensitivity.factor("war:"+own.kind,aimed)
		if _local_is_operator() and not _transport(own):
			var mount: String="tv" if guided else (str(own.spec.gun) if own.selected=="primary" else ("tv" if own.kind in ["guarani","bmp2"] else "coax"))
			factor*=GameAimSensitivity.factor("mount:"+mount,aimed)
	elif own is WarDrone: factor=GameAimSensitivity.factor("war:drone",aimed)
	orbit_yaw-=relative.x*.0015*(.45 if aimed else 1)*factor
	orbit_pitch=clampf(orbit_pitch-relative.y*.0015*(.45 if aimed else 1)*factor,-1.25 if guided else -.75,1.25 if guided else .7)

func _send_trigger(pressed: bool) -> void:
	if not _local_is_operator(): return
	pressed=pressed and game._battle_active()
	if game.offline_operation and is_instance_valid(game.local_player):
		var id:=game.local_player.peer_id
		var state: Dictionary=controls.get(id,{})
		state.fire=pressed;state.at=game.war_clock;controls[id]=state
		return
	if not game.online or game.multiplayer.is_server() or not game.join_ready: return
	sequence+=1
	rpc_id(1,"trigger",sequence,pressed,_control_epoch(game.local_player.peer_id),_own_id(),game.local_player.life_id)

@rpc("any_peer","call_remote","reliable")
func trigger(value: int,pressed: bool,epoch: int=-1,vehicle_id: String="",life: int=-1) -> void:
	if not multiplayer.is_server(): return
	if pressed and not game.network_guard.allow(multiplayer.get_remote_sender_id(),"vehicle_trigger",12,8): return
	accept_trigger(multiplayer.get_remote_sender_id(),value,pressed,epoch,vehicle_id,life)

func _control_identity_valid(id: int,vehicle_id: String,life: int,epoch: int) -> bool:
	return is_operator(id) and str(game.members[id].vehicle)==vehicle_id and int(game.players[id].life_id)==life and _control_epoch(id)==epoch

func accept_trigger(id: int,value: int,pressed: bool,epoch: int,vehicle_id: String,life: int) -> void:
	if not multiplayer.is_server() or not _control_identity_valid(id,vehicle_id,life,epoch) or value<=int(sequences.get(id,0)): return
	sequences[id]=value
	var state: Dictionary = controls.get(id,{})
	state.fire=pressed and not _transport(find_target(vehicle_id));state.at=game.war_clock
	controls[id]=state

@rpc("any_peer","call_remote","unreliable_ordered")
func control(value: int,input: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var id:=multiplayer.get_remote_sender_id()
	if not game.network_guard.allow(id,"vehicle_control",40,10): return
	accept_control(id,value,input)

func accept_control(id: int,value: int,input: Dictionary) -> void:
	if not multiplayer.is_server(): return
	if not _control_identity_valid(id,str(input.get("vehicle","")),int(input.get("life",-1)),int(input.get("occupancy",-1))) or value<=int(sequences.get(id,0)) or var_to_bytes(input).size()>650: return
	var target: Variant = input.get("aim",Vector3.ZERO)
	if not target is Vector3 or not CombatRules.finite_vector(target) or not is_finite(float(input.get("yaw",0))): return
	for field in ["throttle","steer","strafe","lift"]:
		if not is_finite(float(input.get(field,0))): return
		input[field]=clampf(float(input.get(field,0)),-1,1)
	if input.has("tv_direction"):
		var direction: Variant=input.tv_direction
		if not direction is Vector3 or not direction.is_finite() or absf(direction.length()-1)>.02: return
	sequences[id]=value
	if _transport(find_target(str(input.get("vehicle","")))): input.fire=false
	input.at=game.war_clock
	controls[id]=input

func _physics_process(delta: float) -> void:
	if not (game.online or game.offline_operation): return
	if game.match_ended: return
	if game.offline_operation and _local_is_operator():
		sequence+=1
		accept_control(1,sequence,_local_control())
	if multiplayer.is_server():
		for key in smoke_screens.keys():
			if game.war_clock>=float(smoke_screens[key].until): smoke_screens.erase(key)
		_step_port_control()
		_step_vehicle_respawns(delta)
		for vehicle: WarVehicle in vehicles.values():
			if vehicle.destroyed:
				continue
			var input: Dictionary = controls.get(vehicle.driver,{}) if vehicle.driver>0 else {}
			if game.war_clock-float(input.get("at",-100))>.28: input={}
			if tv.has_link(vehicle.vehicle_id):
				input=input.duplicate();input.throttle=0.;input.steer=0.;input.fire=false;input.aim=vehicle.aim_target
			vehicle.simulate(delta,input)
			sync_occupants(vehicle)
			if not _transport(vehicle) and is_operator(vehicle.driver) and bool(input.get("fire",false)): _fire_vehicle(vehicle)
		for drone: WarDrone in drones.values().duplicate():
			if drone.destroyed: continue
			var input: Dictionary = controls.get(drone.driver,{})
			if game.war_clock-float(input.get("at",-100))>.28: input={}
			drone.simulate(delta,input)
			if drone.crashed:
				explode(drone.owner_id,drone.global_position,180,9,"drone",drone.drone_id+":crash");_destroy_drone(drone,drone.owner_id)
			elif drone.battery<=0: _destroy_drone(drone,drone.owner_id)
			elif bool(input.get("fire",false)): explode(drone.owner_id,drone.global_position,180,9,"drone",drone.drone_id+":detonate");_destroy_drone(drone,drone.owner_id)
		tv.tick(delta)
		_update_gadgets(delta)
		snapshot_clock+=delta
		if NetworkCadence.due(snapshot_clock,.05):
			snapshot_clock=NetworkCadence.consume(snapshot_clock,.05)
			# One state per packet stays below MTU. Never fragment the entire
			# vehicle/drone collection into a large unreliable dictionary.
			for vehicle: WarVehicle in vehicles.values():
				var state:=_vehicle_snapshot_for_send(vehicle)
				if not state.is_empty(): _broadcast("vehicle_state",[state])
			for drone: WarDrone in drones.values(): _broadcast("drone_state",[drone.snapshot()])
	else:
		send_clock+=delta
		if NetworkCadence.due(send_clock,.05) and _local_is_operator():
			send_clock=NetworkCadence.consume(send_clock,.05)
			sequence+=1
			rpc_id(1,"control",sequence,_local_control())

func resolve_runover(vehicle: WarVehicle,impact_speed: float,direction: Vector3) -> void:
	if not multiplayer.is_server() or not game._battle_active() or vehicle.destroyed or not is_operator(vehicle.driver) or vehicle is WarShip: return
	if not is_finite(impact_speed) or impact_speed<3.0 or not direction.is_finite() or direction.length_squared()<.1: return
	for index in vehicle.get_slide_collision_count():
		var contact:=vehicle.get_slide_collision(index)
		for hit in contact.get_collision_count():
			var victim:=contact.get_collider(hit) as WarPlayer
			if not is_instance_valid(victim) or victim.hp<=0 or not victim.deployed or not victim.vehicle_id.is_empty() or vehicle.seat_of(victim.peer_id)>=0: continue
			# Require contact against the moving side, excluding light scrapes.
			if direction.normalized().dot(-contact.get_normal(hit))<.25: continue
			var key: String=vehicle.vehicle_id+":"+str(victim.peer_id)+":"+str(victim.life_id)
			if game.war_clock-float(runover_recent.get(key,-100.))<1.0: continue
			runover_recent[key]=game.war_clock
			if runover_recent.size()>256:
				for old in runover_recent.keys():
					if game.war_clock-float(runover_recent[old])>8.: runover_recent.erase(old)
			var damage:=clampf(25.0+(impact_speed-3.0)*20.0,25.0,150.0)
			game._apply_hit(vehicle.driver,{"collider":victim.hit_regions.chest,"position":contact.get_position(hit)},damage,"chest","runover",direction.normalized())

func _vehicle_snapshot_for_send(vehicle: WarVehicle,now_usec: int=-1) -> Dictionary:
	if now_usec<0: now_usec=Time.get_ticks_usec()
	var state:=vehicle.snapshot()
	var encoded:=var_to_bytes(state)
	var id:=vehicle.vehicle_id
	if encoded==last_sent.get(id,PackedByteArray()) and now_usec-int(vehicle_sent_usec.get(id,0))<VEHICLE_HEARTBEAT_USEC: return {}
	last_sent[id]=encoded;vehicle_sent_usec[id]=now_usec
	vehicle_state_sequences[id]=int(vehicle_state_sequences.get(id,0))+1
	# Sequence is per vehicle and survives its respawn. A final lost pose is
	# repaired by the heartbeat even when the vehicle has stopped moving.
	state.sequence=vehicle_state_sequences[id]
	return state

func _local_control() -> Dictionary:
	var enabled:=game.gameplay_input_allowed()
	var wish:=Input.get_vector("move_left","move_right","move_forward","move_back") if enabled else Vector2.ZERO
	var lift: float=(1. if Input.is_action_pressed("jump") else 0.)-(1. if Input.is_action_pressed("crouch") else 0.)
	if tv.viewing():
		var own:=find_target(_own_id()) as WarVehicle
		return {"throttle":0.,"steer":0.,"strafe":0.,"lift":0.,"yaw":own.heading,"aim":own.aim_target,"fire":false,"occupancy":_control_epoch(game.local_player.peer_id),"vehicle":_own_id(),"life":game.local_player.life_id,"tv_id":tv.view_id,"guide":enabled,"tv_direction":tv.direction()}
	return {"throttle":-wish.y,"steer":wish.x,"strafe":wish.x,"lift":lift if enabled else 0,"yaw":orbit_yaw,"aim":aim_point,"fire":not _transport(find_target(_own_id())) and fire_held and enabled and game._battle_active(),"occupancy":_control_epoch(game.local_player.peer_id) if is_instance_valid(game.local_player) else -1,"vehicle":_own_id(),"life":game.local_player.life_id if is_instance_valid(game.local_player) else -1}

func _process(delta: float) -> void:
	if not (game.online or game.offline_operation) or (multiplayer.is_server() and not game.offline_operation): return
	if not multiplayer.is_server():
		for vehicle: WarVehicle in vehicles.values(): vehicle.render(delta)
		for drone: WarDrone in drones.values(): drone.render(delta)
	elif game.offline_operation:
		for vehicle: WarVehicle in vehicles.values(): vehicle.update_wreck(delta)
	for vehicle: WarVehicle in vehicles.values():
		sync_occupants(vehicle)
		vehicle.animate_cannon_recoil(delta)
	var own_id := _own_id()
	var role:="operator" if _local_is_operator() else ("passenger" if not own_id.is_empty() else "")
	if own_id!=last_controlled or role!=last_control_role:
		tv.stop_view()
		last_controlled=own_id
		last_control_role=role
		fire_held=false;zoom=false
		vehicle_view.reset(role!="operator" or find_target(own_id) is WarShip or _transport(find_target(own_id)))
		if find_target(own_id) is WarShip: distance=32;vehicle_view.distance_now=32
		elif _transport(find_target(own_id)): distance=5.3;orbit_pitch=-.18
		if thermal: toggle_thermal()
		var target := find_target(own_id)
		if target:
			orbit_yaw=target.rotation.y
			if target is WarShip: orbit_pitch=-.12
			elif target is WarVehicle and role=="operator" and not _transport(target):
				var forward: Vector3=-target.optic.global_basis.z.normalized()
				orbit_yaw=atan2(-forward.x,-forward.z);orbit_pitch=asin(clampf(forward.y,-1,1))
			camera.make_current()
		elif is_instance_valid(game.local_player) and game.local_player.hp>0 and game.local_player.deployed:
			game.local_player.camera.make_current()
			game.local_player._update_view()
	game.player_in_vehicle=not own_id.is_empty()
	# Seat replication and death presentation may be processed in different
	# frames. Never leave an unoccupied vehicle camera active after respawn.
	if own_id.is_empty() and is_instance_valid(game.local_player) and game.local_player.hp>0 and game.local_player.deployed and get_viewport().get_camera_3d()==camera:
		game.local_player.camera.make_current();game.local_player._update_view()
	if game.infantry_hud: game.infantry_hud.visible=own_id.is_empty()
	var vehicle := find_target(own_id)
	if thermal and not thermal_allowed(): toggle_thermal()
	if vehicle is WarShip:
		vehicle_view.external=true
		var naval_camera:=camera as NavalCamera
		naval_camera.orbit_yaw=orbit_yaw;naval_camera.orbit_pitch=orbit_pitch;naval_camera.zoom=zoom
		naval_camera.follow_body(vehicle,vehicle.hull.spec,delta,1|16,owner_excludes(game.local_player.peer_id))
		if _local_is_operator(): aim_point=naval_camera.target_point(float(NavalCatalog.WEAPONS[vehicle.naval_weapon].range),CombatRules.SHOT_MASK,owner_excludes(game.local_player.peer_id))
		game.local_player._hide_dead_presentations();game.local_player.weapon_root.hide()
		game.local_player.body_root.visible=vehicle.seat_of(game.local_player.peer_id)>0
		game.aim_dot.visible=_local_is_operator()
	elif _transport(vehicle):
		_update_transport_camera(vehicle,delta)
		game.aim_dot.hide()
	elif vehicle is WarVehicle:
		if not tv.update_camera(): vehicle_view.update(self,vehicle,_local_is_operator(),delta)
		if is_instance_valid(game.local_player):
			game.local_player._hide_dead_presentations();game.local_player.weapon_root.hide();game.local_player.body_root.hide()
		if is_instance_valid(game.local_player): game.aim_dot.hide()
	elif vehicle:
		var direction := Basis.from_euler(Vector3(orbit_pitch,orbit_yaw,0))*Vector3.FORWARD
		var anchor := vehicle.global_position+Vector3.UP*(2.8 if vehicle is WarVehicle else .35)
		var desired := anchor-direction*distance
		var safe := CameraObstruction.resolve(get_world_3d(),anchor,desired,owner_excludes(multiplayer.get_unique_id()),.4)
		camera.global_position=safe.position
		camera.look_at(camera.global_position+direction)
		camera.fov=lerpf(camera.fov,17.0 if zoom else 67.0,1.0-exp(-delta*12))
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+direction*1600,CombatRules.SHOT_MASK,owner_excludes(multiplayer.get_unique_id()))
		ray.collide_with_areas=true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		aim_point=hit.position if not hit.is_empty() else camera.global_position+direction*1600
		if is_instance_valid(game.local_player): game.aim_dot.visible=_local_is_operator()
	_update_smoke_overlay(delta)
	shock_clock+=delta
	if vehicle is WarVehicle and hull_shock>0 and not tv.viewing():
		var amplitude:=hull_shock*.012*camera.fov/67.
		camera.rotate_object_local(Vector3.RIGHT,sin(shock_clock*53)*amplitude)
		camera.rotate_object_local(Vector3.UP,sin(shock_clock*41+.8)*amplitude*.65)
		camera.rotate_object_local(Vector3.BACK,sin(shock_clock*37)*amplitude*.55)
	hull_shock=maxf(0,hull_shock-delta*2.5) if vehicle is WarVehicle else 0.
	if is_instance_valid(game.local_player) and game.local_player.gadget_equipped and game.local_player.gadget=="stinger":
		var result := acquire(game.local_player)
		if str(result.get("id",""))==lock_target and not result.is_empty(): lock_progress=minf(1.0,lock_progress+delta/1.25)
		else: lock_target=str(result.get("id",""));lock_progress=0

func _update_transport_camera(vehicle: WarVehicle,delta: float) -> void:
	vehicle_view.external=true;zoom=false
	var direction:=Basis.from_euler(Vector3(orbit_pitch,orbit_yaw,0))*Vector3.FORWARD
	var anchor:=vehicle.global_position+Vector3.UP*1.55
	var desired:=anchor-direction*clampf(distance,4.,9.)
	var safe:=CameraObstruction.resolve(get_world_3d(),anchor,desired,owner_excludes(game.local_player.peer_id),.20,1|16)
	camera.global_position=safe.position;camera.look_at(camera.global_position+direction)
	camera.fov=lerpf(camera.fov,67.,1.-exp(-delta*12.))
	if is_instance_valid(game.local_player):
		game.local_player._hide_dead_presentations();game.local_player.weapon_root.hide()
		vehicle.pose_rider(game.local_player)

func _states() -> Array:
	var states: Array=[]
	for vehicle: WarVehicle in vehicles.values(): states.append(vehicle.snapshot())
	return states
func _drone_states() -> Array:
	var states: Array=[]
	for drone: WarDrone in drones.values(): states.append(drone.snapshot())
	return states
func send_initial(id: int,include_aircraft:=true) -> void:
	if include_aircraft:rpc_id(id,"initial",_states(),_drone_states())
	else:rpc_id(id,"baseline_vehicles",_states())
	for key in smoke_screens:
		var smoke: Dictionary=smoke_screens[key]
		if float(smoke.until)>game.war_clock: rpc_id(id,"smoke_event",str(key),smoke.point,float(smoke.until),smoke.get("forward",Vector3.FORWARD),str(smoke.get("kind","abrams")))
	# A late observer receives the current physical missile, not its old
	# launch position. Guidance remains reserved to the original operator.
	for key in tv.flights:
		var shot: Dictionary=game.war_fx.find_round(str(key))
		if shot.is_empty() or not bool(shot.active): continue
		var entry: Dictionary=tv.flights[key]
		var velocity_value: Vector3=shot.velocity
		var extra: Dictionary={"speed":velocity_value.length(),"gravity":shot.gravity,"damage":shot.damage,"radius":shot.radius,"range":maxf(1,float(shot.range)-float(shot.distance)),"life":shot.life,"guided":true,"tv_vehicle":entry.vehicle,"tv_life":entry.life,"tv_epoch":entry.epoch,"tv_linked":entry.linked}
		rpc_id(id,"projectile_event",int(shot.owner),shot.position,velocity_value.normalized(),str(shot.weapon),str(key),extra)
@rpc("authority","call_remote","reliable")
func baseline_vehicles(states: Array) -> void:
	for state: Dictionary in states:
		if vehicles.has(state.id):vehicles[state.id].receive(state)

@rpc("authority","call_remote","reliable")
func baseline_drone(state: Dictionary) -> void:drone_state(state)

@rpc("authority","call_remote","reliable")
func initial(states: Array,aircraft: Array) -> void: snapshot(states,aircraft)
@rpc("authority","call_remote","unreliable_ordered")
func snapshot(states: Array,aircraft: Array) -> void:
	for state: Dictionary in states:
		if vehicles.has(state.id): vehicles[state.id].receive(state)
	var present := {}
	for state: Dictionary in aircraft:
		present[state.id]=true
		if not drones.has(state.id):
			var drone := WarDrone.new()
			drone.drone_id=str(state.id);drone.position=state.position
			add_child(drone)
			drones[state.id]=drone
		drones[state.id].receive(state)
	for id in drones.keys():
		if not present.has(id): drones[id].queue_free();drones.erase(id)

@rpc("authority","call_remote","unreliable")
func vehicle_state(state: Dictionary) -> void:
	if vehicles.has(state.id):
		var vehicle: WarVehicle=vehicles[state.id]
		var previous_sequence:=vehicle.received_state_sequence
		vehicle.receive(state)
		if vehicle.received_state_sequence>previous_sequence and is_instance_valid(game) and is_instance_valid(game.local_player) and game.local_player.vehicle_id==vehicle.vehicle_id:
			var pacing: Variant=game.get("frame_pacing")
			if pacing!=null:pacing.snapshot(Time.get_ticks_usec())

@rpc("authority","call_remote","reliable")
func vehicle_occupancy(id: String,seats: Dictionary,revision: int,epoch: int) -> void:
	if vehicles.has(id): vehicles[id].receive_seats(seats,revision,epoch)

func _send_occupancy(vehicle: WarVehicle) -> void:
	_broadcast("vehicle_occupancy",[vehicle.vehicle_id,vehicle.seats.duplicate(),vehicle.seats_revision,vehicle.control_epoch])

func sync_occupants(vehicle: WarVehicle) -> void:
	for id: int in vehicle.occupant_ids():
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or actor.vehicle_id!=vehicle.vehicle_id: continue
		actor.global_position=vehicle.to_global(vehicle.seat_position(vehicle.seat_of(id)))
		actor.velocity=Vector3.ZERO
		if actor.hp>0:
			actor.body_root.visible=_transport(vehicle) or (vehicle is WarShip and vehicle.seat_of(id)>0);actor.weapon_root.hide()
			if _transport(vehicle): vehicle.pose_rider(actor)
			if vehicle is WarShip:
				actor.rotation.y=vehicle.heading
				for side in ["l","r"]:
					var leg:=actor.avatar_parts.get("leg_"+side) as Node3D
					if leg: leg.rotation.x=1.1
		if is_instance_valid(actor.view_root): actor.view_root.hide()

@rpc("authority","call_remote","unreliable_ordered")
func drone_state(state: Dictionary) -> void:
	if retired_drones.has(str(state.id)): return
	if not drones.has(state.id):
		var drone := WarDrone.new()
		drone.drone_id=str(state.id);drone.position=state.position
		add_child(drone);drones[state.id]=drone
	drones[state.id].receive(state)

@rpc("authority","call_remote","reliable")
func drone_removed(id: String) -> void:
	retired_drones[id]=true
	if retired_drones.size()>256: retired_drones.erase(retired_drones.keys()[0])
	if drones.has(id): game._retire_avatar(drones[id]);drones.erase(id)

func find_target(id: String) -> Node3D: return vehicles.get(id,drones.get(id))
func owner_excludes(id: int) -> Array[RID]:
	var values: Array[RID]=[]
	if game.players.has(id): values.append(game.players[id].get_rid())
	if game.members.has(id):
		var controlled := find_target(str(game.members[id].vehicle))
		if controlled:
			values.append(controlled.get_rid())
			if controlled is WarVehicle:
				for occupant in controlled.occupant_ids():
					var actor:=game.players.get(occupant) as GamePlayer
					if not is_instance_valid(actor): continue
					values.append(actor.get_rid())
					for region: Area3D in actor.hit_regions.values(): values.append(region.get_rid())
	return values

func request_interact() -> void:
	var actor:=game.local_player as WarPlayer
	if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed: return
	if not _own_id().is_empty(): request_command("exit",{});return
	var closest := _nearby(actor)
	if closest: request_command("enter",{"id":closest.vehicle_id})

func boarding_distance(actor: GamePlayer,vehicle: WarVehicle) -> float:
	if not vehicle is WarShip: return actor.global_position.distance_to(vehicle.global_position)
	var p:=vehicle.to_local(actor.global_position);var half:=Vector3(vehicle.spec.size)*.5
	return Vector2(maxf(0,absf(p.x)-half.x),maxf(0,absf(p.z)-half.z)).length() if absf(p.y)<6 else INF

func _can_take_bot_driver(actor: GamePlayer,vehicle: WarVehicle) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(vehicle): return false
	var requester: Dictionary=game.members.get(actor.peer_id,{})
	var current_driver: Dictionary=game.members.get(vehicle.driver,{})
	return not requester.is_empty() and not bool(requester.get("bot",false)) and not current_driver.is_empty() and bool(current_driver.get("bot",false)) and vehicle.driver>0 and not vehicle.destroyed and vehicle.team==actor.war_team

func _nearby(actor: GamePlayer) -> WarVehicle:
	if not is_instance_valid(actor): return null
	var nearest: WarVehicle
	var best := 5.5
	for vehicle: WarVehicle in vehicles.values():
		var distance_to := boarding_distance(actor,vehicle)
		if (vehicle.first_available_seat()>=0 or _can_take_bot_driver(actor,vehicle)) and not vehicle.destroyed and vehicle.team==actor.war_team and distance_to<best:
			nearest=vehicle;best=distance_to
	return nearest

@rpc("any_peer","call_remote","reliable")
func command(action: String,data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	if not game.network_guard.allow(multiplayer.get_remote_sender_id(),"vehicle_command",10,6): return
	command_for(multiplayer.get_remote_sender_id(),action,data)

func request_command(action: String,data: Dictionary) -> void:
	if game.offline_operation: command_for(1,action,data)
	else: rpc_id(1,"command",action,data)

func command_for(id: int,action: String,data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	if not game.members.has(id) or not game.players.has(id) or var_to_bytes(data).size()>500: return
	var actor := game.players[id] as WarPlayer
	var member: Dictionary = game.members[id]
	var current := find_target(str(member.vehicle))
	if actor.hp<=0 or not actor.deployed: return
	if action=="exit": release(id);return
	if _transport(current): return
	if actor.in_water(): return
	match action:
		"enter":
			var vehicle := vehicles.get(str(data.get("id",""))) as WarVehicle
			if actor._grenade_active() or current or not is_instance_valid(vehicle) or vehicle.destroyed or vehicle.team!=actor.war_team or boarding_distance(actor,vehicle)>5.5: return
			for other: WarVehicle in vehicles.values():
				if other.seat_of(id)>=0: return
			var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,actor.global_position.lerp(vehicle.global_position,.2)+Vector3.UP if vehicle is WarShip else vehicle.global_position+Vector3.UP,1|16,[actor.get_rid(),vehicle.get_rid()])
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): game._notice(id,"Entrada bloqueada por um obstáculo.");return
			var taking_over:=_can_take_bot_driver(actor,vehicle)
			var previous_driver:=vehicle.driver if taking_over else 0
			if taking_over and vehicle.first_available_seat()<0:
				# Prefer dismounting a BOT passenger; leave every human
				# passenger in place. With no BOT passenger, dismount only the
				# BOT driver without promoting an existing human passenger.
				var bot_to_exit:=0
				for peer: int in vehicle.occupant_ids():
					if peer!=previous_driver and bool(game.members.get(peer,{}).get("bot",false)):
						bot_to_exit=peer
						break
				if bot_to_exit==0: bot_to_exit=previous_driver
				if not release(bot_to_exit,false,bot_to_exit!=previous_driver):
					game._notice(id,"Sem saída segura para assumir o piloto.")
					return
			var seat:=-1
			if taking_over and vehicle.driver==previous_driver and vehicle.hand_over_driver(id,previous_driver):
				seat=0
				controls.erase(previous_driver);sequences.erase(previous_driver)
				locks.erase(previous_driver);healing.erase(previous_driver)
				var old_member: Dictionary=game.members.get(previous_driver,{})
				if not old_member.is_empty():
					old_member.vehicle_seat=vehicle.seat_of(previous_driver)
					old_member.vehicle_role="passenger"
					game._broadcast("war_identity",[previous_driver,old_member])
			else:
				seat=vehicle.allocate_seat(id)
			if seat<0: game._notice(id,"Veículo lotado.");return
			actor.grenade_selected=false;actor.grenade_aiming=false;actor.clear_aim();_set_utility(id,"")
			actor.stance.reset(actor);member.posture=0
			member.vehicle=vehicle.vehicle_id
			member.vehicle_seat=seat;member.vehicle_role="operator" if seat==0 else "passenger";member.shield=0.0
			actor.vehicle_id=vehicle.vehicle_id
			actor.trigger_held=false;actor.velocity=Vector3.ZERO;actor.cancel_reload();actor.cancel_melee();actor._set_hitboxes_enabled(_transport(vehicle));actor.body_collision.set_deferred("disabled",true);actor.body_root.hide();actor.weapon_root.hide()
			if is_instance_valid(actor.view_root): actor.view_root.hide()
			actor.set_gadget(false,actor.gadget)
			controls.erase(id);sequences.erase(id);locks.erase(id);healing.erase(id)
			sync_occupants(vehicle);_send_occupancy(vehicle)
			game._broadcast("war_identity",[id,member])
		"tv_release": tv.release(id,str(data.get("id","")))
		"reload":
			if current is WarVehicle and is_operator(id) and not tv.has_link(current.vehicle_id): current.start_reload()
		"weapon":
			if current is WarVehicle and is_operator(id) and not tv.has_link(current.vehicle_id):
				var slot:=int(data.get("slot",2 if current.selected=="primary" else 1))
				if current is WarShip:
					current.choose_weapon(slot)
					if controls.has(id): controls[id].fire=false
					return
				if slot not in [1,2]: return
				current.selected="primary" if slot==1 else "secondary"
				if controls.has(id): controls[id].fire=false
		"drone": launch_drone(id)
		"gadget": use_gadget(id)
		"utility":
			var wanted:=str(data.get("mode",""))
			if wanted=="" or (wanted=="medic" and actor.war_class=="medic") or (wanted=="binoculars" and actor.war_class=="marksman"):
				if not current and game._eligible(id): _set_utility(id,wanted)
		"utility_zoom":
			# A reliable zoom belongs to one living infantry life. Do not let a
			# queued command reopen optics after death, boarding or a class swap.
			var requested_level: Variant=data.get("level",null)
			var requested_life: Variant=data.get("life",null)
			if not requested_level is int or not requested_life is int: return
			if int(requested_level) not in [0,1,2] or int(requested_life)!=actor.life_id: return
			if current or not actor.vehicle_id.is_empty() or not game._eligible(id) or actor.utility_mode!="binoculars" or actor.war_class!="marksman" or str(member.role)!="marksman": return
			actor.set_utility_zoom(int(requested_level))
			member.utility_zoom=actor.utility_zoom
			_broadcast("utility_zoom_state",[id,actor.life_id,actor.utility_zoom])
		"med_hold":
			if not bool(data.get("pressed",false)): healing.erase(id)
			elif actor.utility_mode=="medic" and game._eligible(id) and game._battle_active():
				if healing.has(id) and bool(healing[id].get("held",false)): healing[id].lease=game.war_clock+1.2
				elif int(member.charges)>0:
					member.charges-=1;member.last_gadget=game.war_clock;game.sync_class_resources(id)
					healing[id]={"held":true,"until":game.war_clock+3.,"lease":game.war_clock+1.2,"next":game.war_clock}
		"ammo": resupply(id)
		"point_supply": resupply_point(id)
		"smoke": deploy_smoke(id)
		"select":
			if actor.war_class!="antitank" or data.get("gadget") not in ["rpg","stinger"] or current: return
			if not WarRules.launcher_allowed(actor.war_team,str(data.gadget)): return
			member.gadget=str(data.gadget)
			actor.set_gadget(bool(data.get("enabled",false)),str(data.gadget))
			_broadcast("gadget_selected",[id,actor.gadget,actor.gadget_equipped])

@rpc("authority","call_remote","reliable")
func gadget_selected(id: int,gadget: String,enabled: bool) -> void:
	if game.players.has(id): game.players[id].set_gadget(enabled,gadget)

func select_gadget(id: String) -> void:
	var actor := game.local_player as WarPlayer
	if not is_instance_valid(actor) or not actor.vehicle_id.is_empty(): return
	if actor.war_class!="antitank" or not WarRules.launcher_allowed(actor.war_team,id): return
	var enabled := not actor.gadget_equipped or actor.gadget!=id
	actor.set_gadget(enabled,id)
	request_command("select",{"gadget":id,"enabled":enabled})

func release(id: int,forced := false,promote_driver := true) -> bool:
	var member: Dictionary=game.members.get(id,{})
	var current := find_target(str(member.get("vehicle","")))
	# Clean stale reservations even if the member was already erased by a
	# disconnect path. A seat must never outlive the connection that owns it.
	if not current:
		for candidate: WarVehicle in vehicles.values():
			if candidate.seat_of(id)>=0: current=candidate;break
	if not current:
		# An exit request without a reservation is not permission to spawn an
		# undeployed/dead avatar, enable its collider or flood identity updates.
		controls.erase(id);sequences.erase(id);locks.erase(id);healing.erase(id)
		if not member.is_empty(): member.vehicle="";member.vehicle_seat=-1;member.vehicle_role=""
		if game.players.has(id): game.players[id].vehicle_id="";game.players[id].trigger_held=false
		return true
	var actor := game.players.get(id) as WarPlayer
	var exit_position := Vector3.ZERO
	if current is WarVehicle and is_instance_valid(actor) and actor.hp>0:
		var exit:=safe_exit(current,actor)
		if not bool(exit.get("ok",false)) and not forced:
			game._notice(id,"Saída bloqueada. Mova o veículo para uma área livre.");return false
		exit_position=exit.get("position",game.find_spawn(id) if forced else actor.global_position)
	tv.release_owner(id)
	var promoted:=0
	if current is WarVehicle: promoted=current.vacate_seat(id,promote_driver and not current.destroyed)
	elif current is WarDrone: current.begin_fall()
	controls.erase(id);sequences.erase(id);locks.erase(id);healing.erase(id)
	if not member.is_empty(): member.vehicle="";member.vehicle_seat=-1;member.vehicle_role=""
	if is_instance_valid(actor):
		actor.vehicle_id="";actor.velocity=Vector3.ZERO;actor.trigger_held=false
		actor.fire_cooldown=0;actor.cancel_reload();actor.cancel_melee();actor.clear_aim()
		reset_transport_pose(current,actor)
		if actor.hp>0:
			if current is WarVehicle: actor.global_position=exit_position
			actor.body_root.show();actor._set_hitboxes_enabled(true);actor.body_collision.set_deferred("disabled",false)
			actor.restore_infantry_presentation_after_vehicle_exit()
			if id in multiplayer.get_peers(): rpc_id(id,"exit_confirmed",actor.global_position)
		if actor.hp>0: game.sync_inventory(actor)
	if not member.is_empty(): game._broadcast("war_identity",[id,member])
	if current is WarVehicle:
		if promoted>0:
			controls.erase(promoted);sequences.erase(promoted);locks.erase(promoted);healing.erase(promoted)
			if game.members.has(promoted):
				game.members[promoted].vehicle_seat=0;game.members[promoted].vehicle_role="operator"
				game._broadcast("war_identity",[promoted,game.members[promoted]])
			if game.players.has(promoted): game.players[promoted].trigger_held=false
			sync_occupants(current)
		_send_occupancy(current)
	return true

func _exit_endpoint_outside_hull(vehicle: WarVehicle,actor: WarPlayer,point: Vector3,shape: Shape3D,space: PhysicsDirectSpaceState3D) -> bool:
	# Seat and departure path must ignore the vehicle collider, but the
	# destination must NOT: on slopes the floor ray can land below its hull.
	# Horizontal clearance also rejects a point under a suspended vehicle.
	var half: Vector3=Vector3(vehicle.spec.size)*.5
	var planar: Vector3=Basis(Vector3.UP,vehicle.rotation.y).inverse()*(point-vehicle.global_position)
	if absf(planar.x)<half.x+.45 and absf(planar.z)<half.z+.45:return false
	var endpoint:=PhysicsShapeQueryParameters3D.new()
	endpoint.shape=shape;endpoint.collision_mask=1|16
	endpoint.exclude=[actor.get_rid()]
	endpoint.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
	return space.intersect_shape(endpoint,1).is_empty()

func safe_exit(vehicle: WarVehicle,actor: WarPlayer) -> Dictionary:
	var half: Vector3=Vector3(vehicle.spec.size)*.5
	var offsets: Array[Vector3]=[]
	for z in [-half.z*.55,0.0,half.z*.55]:
		offsets.append(Vector3(-half.x-.85,0,z));offsets.append(Vector3(half.x+.85,0,z))
	for x in [-half.x*.55,0.0,half.x*.55]:
		offsets.append(Vector3(x,0,half.z+.85));offsets.append(Vector3(x,0,-half.z-.85))
	# A wall or a bank can block the complete first ring. Search a wider
	# perimeter without bypassing the route/capsule tests below.
	for extra in [1.5,3.0]:
		for index in 16:
			var angle:=TAU*index/16.
			offsets.append(Vector3(cos(angle)*(half.x+.85+extra),0,sin(angle)*(half.z+.85+extra)))
	var shape:=CapsuleShape3D.new();shape.radius=.36;shape.height=1.8
	var excluded: Array[RID]=[actor.get_rid(),vehicle.get_rid()]
	var origin:=vehicle.to_global(vehicle.seat_position(maxi(0,vehicle.seat_of(actor.peer_id))))+Vector3.UP*.95
	if vehicle is WarShip: origin.y=maxf(origin.y,vehicle.global_position.y+5.4)
	var space:=get_world_3d().direct_space_state
	var water_candidates: Array[Vector3]=[]
	for offset in offsets:
		var point:=vehicle.to_global(offset)
		if absf(point.x)>WarTerrain.HALF-10 or absf(point.z)>WarTerrain.HALF-10: continue
		if vehicle is WarShip:
			var floor_query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*7,point-Vector3.UP*8,1,excluded)
			var floor_hit:=space.intersect_ray(floor_query)
			if floor_hit.is_empty() or Vector3(floor_hit.position).y<1:
				if WarCoast.wet(point.x,point.z) and WarTerrain.height_at(point.x,point.z)<-1.8:
					water_candidates.append(Vector3(point.x,WarCoast.wave(point,game.war_clock)-.85,point.z))
				continue
			if Vector3(floor_hit.normal).y<.7: continue
			point=Vector3(floor_hit.position)+Vector3.UP*.16
		else:
			# Exit onto the real collision surface: terrain is below raised
			# roads, authored slabs and quays. Testing a buried capsule made
			# every otherwise clear APC exit fail in those locations.
			var floor_query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.5,point-Vector3.UP*5,1|16,excluded)
			var floor_hit:=space.intersect_ray(floor_query)
			if floor_hit.is_empty() or not floor_hit.collider is StaticBody3D or Vector3(floor_hit.normal).y<.7: continue
			point=Vector3(floor_hit.position)+Vector3.UP*.08
			if point.y<WarCoast.wave(point,game.war_clock)+.1 and WarCoast.wet(point.x,point.z): continue
			if not _exit_endpoint_outside_hull(vehicle,actor,point,shape,space):continue
		# Reject steep edges, occupied spaces, other hulls and routes through
		# walls. Excluding only this hull permits leaving its interior safely.
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1|4|16|32;query.exclude=excluded
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
		if not space.intersect_shape(query,1).is_empty(): continue
		query.transform.origin=origin;query.motion=point+Vector3.UP*.95-origin
		var travel:=space.cast_motion(query)
		if travel.size()<2 or travel[0]<.999: continue
		return {"ok":true,"position":point}
	# Prefer a safe pier, but a ship at sea must also permit disembarking.
	# Use the existing swimming state; never fall to the seabed or teleport.
	for point in water_candidates:
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1|4|16|32;query.exclude=excluded
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
		if not space.intersect_shape(query,1).is_empty(): continue
		query.transform.origin=origin;query.motion=point+Vector3.UP*.95-origin
		var travel:=space.cast_motion(query)
		if travel.size()==2 and travel[0]>=.999: return {"ok":true,"position":point,"water":true}
	return {"ok":false}

func reset_occupancy() -> void:
	# Round reset has already undeployed actors. Never promote while clearing.
	tv.clear()
	controls.clear();sequences.clear();locks.clear();healing.clear();shot_events.clear();blast_events.clear();last_damage_confirmation.clear();impact_events.clear();runover_recent.clear();point_supply_at.clear();smoke_screens.clear();smoke_cooldowns.clear();hull_shock=0
	if is_instance_valid(smoke_overlay): smoke_overlay.color=Color(.36,.37,.35,0.)
	if is_instance_valid(game.grenades_system) and is_instance_valid(game.grenades_system.smoke_clouds): game.grenades_system.smoke_clouds.clear_clouds()
	for vehicle: WarVehicle in vehicles.values():
		for id: int in vehicle.clear_seats():
			if game.members.has(id): game.members[id].vehicle="";game.members[id].vehicle_seat=-1;game.members[id].vehicle_role=""
			var actor := game.players.get(id) as WarPlayer
			if is_instance_valid(actor):
				actor.vehicle_id="";actor.trigger_held=false
				reset_transport_pose(vehicle,actor)
		_send_occupancy(vehicle)
	for drone: WarDrone in drones.values(): drone.driver=0
	last_controlled="";last_control_role="";fire_held=false;zoom=false;vehicle_view.reset(false)

@rpc("authority","call_remote","reliable")
func exit_confirmed(point: Vector3) -> void:
	var actor:=game.local_player as WarPlayer
	if is_instance_valid(actor):
		# The identity packet that clears this field is sent immediately after
		# this reliable confirmation.  Clear the local presentation state here
		# as well so the restoration below cannot be skipped by packet order.
		var former := find_target(actor.vehicle_id)
		actor.vehicle_id=""
		reset_transport_pose(former,actor)
		actor.global_position=point;actor.velocity=Vector3.ZERO
		actor.restore_infantry_presentation_after_vehicle_exit()

func flood_vehicle(vehicle: WarVehicle) -> void:
	if not multiplayer.is_server() or vehicle is WarShip or vehicle.destroyed: return
	damage_from_hit(0,vehicle,100000.,"water",Vector3.DOWN)

func ram_light_obstacles(vehicle: WarVehicle,_impact_speed:=0.0,_impact_direction:=Vector3.ZERO) -> void:
	if _transport(vehicle): return
	if not multiplayer.is_server() or not is_instance_valid(game.power_grid): return
	# Only authored breakable poles participate. Buildings, rocks, hulls
	# and anonymous decoration retain their original blocking collision.
	for index in vehicle.get_slide_collision_count():
		var contact:=vehicle.get_slide_collision(index)
		var collider:=contact.get_collider() as Node
		if is_instance_valid(collider) and collider.has_meta("war_pole"):
			game.power_grid.hit(collider,160.,-vehicle.global_basis.z)

func _step_port_control() -> void:
	for vehicle: WarVehicle in vehicles.values():
		if not vehicle is WarShip or not vehicle.seats.is_empty(): continue
		var objective: String="D" if int(vehicle.spec.team)==0 else "E"
		vehicle.team=int(game.objective_states[objective].owner)

func _fire_ship(ship: WarShip) -> void:
	if not game._battle_active() or ship.destroyed or not is_operator(ship.driver) or ship.reloading or ship.fire_wait>0 or game.war_fx.available.is_empty(): return
	if ship.ammo<=0: ship.start_reload();return
	ship.gun_blocked=ship.protected_lane()
	if ship.gun_blocked: return
	var weapon:=ship.naval_weapon
	var data: Dictionary=NavalCatalog.WEAPONS[weapon]
	var direction: Vector3=-ship.muzzle.global_basis.z.normalized()
	var extra: Dictionary={"speed":data.speed,"gravity":data.gravity,"damage":data.damage,"radius":4. if weapon=="missile" else (5. if weapon=="torpedo" else 0.),"drag":NavalBallistics.drag_for(weapon),"range":data.range,"life":data.life,"inherited":Vector3(ship.velocity.x,0,ship.velocity.z),"waterborne":weapon=="torpedo"}
	ship.shot_sequence+=1
	var key:=ship.vehicle_id+":"+str(ship.shot_sequence)
	if not game.war_fx.spawn(ship.driver,ship.muzzle.global_position,direction,weapon,true,key,extra): return
	ship.naval_ammo[weapon]-=1;ship.naval_waits[weapon]=float(data.cadence);ship._update_mount()
	_broadcast("projectile_event",[ship.driver,ship.muzzle.global_position,direction,weapon,key,extra])

func _fire_vehicle(vehicle: WarVehicle) -> void:
	if _transport(vehicle): return
	if vehicle is WarShip:
		_fire_ship(vehicle);return
	if not game._battle_active() or vehicle.destroyed or not is_operator(vehicle.driver) or game.war_fx.available.is_empty() or tv.has_link(vehicle.vehicle_id): return
	var secondary:=vehicle.selected=="secondary"
	if (vehicle.secondary_fire_wait if secondary else vehicle.fire_wait)>0 or (vehicle.secondary_reload_left if secondary else vehicle.reload_left)>0: return
	if (vehicle.secondary_ammo if secondary else vehicle.ammo)<=0:
		vehicle.start_reload();return
	var weapon: String=str(WarRules.SECONDARY[vehicle.kind].weapon) if secondary else str(vehicle.spec.gun)
	if weapon=="tv" and tv.has_flight(vehicle.vehicle_id): return
	var marker: Marker3D=vehicle.secondary_muzzle if secondary else vehicle.muzzle
	var direction: Vector3=-marker.global_basis.z.normalized()
	if not secondary and float(vehicle.spec.get("spread",0))>0:
		var rng:=RandomNumberGenerator.new();rng.seed=hash(vehicle.vehicle_id+":"+str(vehicle.shot_sequence+1))
		var cone:=deg_to_rad(float(vehicle.spec.spread))*sqrt(rng.randf());var azimuth:=rng.randf()*TAU
		direction=(direction*cos(cone)+(marker.global_basis.x*cos(azimuth)+marker.global_basis.y*sin(azimuth))*sin(cone)).normalized()
	var obstruction:=PhysicsRayQueryParameters3D.create(vehicle.elevation.global_position,marker.global_position,1|16,owner_excludes(vehicle.driver))
	vehicle.gun_blocked=not get_world_3d().direct_space_state.intersect_ray(obstruction).is_empty()
	if vehicle.gun_blocked:
		if secondary: vehicle.secondary_fire_wait=.1
		else: vehicle.fire_wait=.1
		return
	var extra: Dictionary={"speed":780.0 if secondary else float(vehicle.spec.speed_shot),"gravity":9.81 if secondary else float(vehicle.spec.gravity),"damage":25.0 if secondary else float(vehicle.spec.damage),"radius":0.0 if secondary else float(vehicle.spec.blast),"drag":0.0 if secondary else float(vehicle.spec.get("drag",0)),"range":2200.0,"inherited":Vector3(vehicle.velocity.x,0,vehicle.velocity.z),"infantry_damage":float(vehicle.spec.get("infantry_damage",vehicle.spec.damage)) if not secondary else 25.0}
	if weapon in ["tank","autocannon"]: extra.life=15.
	if weapon=="tv":
		for field in ["speed","gravity","damage","radius","range","life"]: extra[field]=WarRules.TV_MISSILE[field]
		extra.guided=true;extra.tv_vehicle=vehicle.vehicle_id;extra.tv_life=game.players[vehicle.driver].life_id;extra.tv_epoch=vehicle.control_epoch
	vehicle.shot_sequence+=1
	var key:=vehicle.vehicle_id+":"+str(vehicle.shot_sequence)
	if not game.war_fx.spawn(vehicle.driver,marker.global_position,direction,weapon,true,key,extra): return
	if secondary:
		vehicle.secondary_ammo-=1;vehicle.secondary_fire_wait=float(WarRules.SECONDARY[vehicle.kind].cooldown)
		if vehicle.secondary_ammo==0: vehicle.start_secondary_reload()
	else:
		vehicle.ammo-=1;vehicle.fire_wait=float(vehicle.spec.cooldown)
		if vehicle.ammo==0: vehicle.start_reload()
	_broadcast("projectile_event",[vehicle.driver,marker.global_position,direction,weapon,key,extra])

@rpc("authority","call_remote","reliable")
func projectile_event(owner: int,origin: Vector3,direction: Vector3,weapon: String,id: String,extra: Dictionary) -> void:
	if shot_events.has(id): return
	game.war_fx.spawn(owner,origin,direction,weapon,false,id,extra)
	_present_shot(owner,origin,direction,weapon,id)

func _present_shot(owner: int,origin: Vector3,direction: Vector3,weapon: String,id: String) -> void:
	if shot_events.has(id): return
	shot_events[id]=true
	if shot_events.size()>512: shot_events.erase(shot_events.keys()[0])
	game.war_fx.flash(origin)
	var vessel:=find_target(str(game.members.get(owner,{}).get("vehicle",""))) as WarShip
	if vessel and vessel.hull.turrets.has(weapon): vessel.hull.turrets[weapon].show_recoil()
	if weapon=="tank":
		var cannon:=find_target(str(game.members.get(owner,{}).get("vehicle",""))) as WarVehicle
		if is_instance_valid(cannon): cannon.present_cannon_recoil()
		if _local_is_operator() and is_instance_valid(game.local_player) and owner==game.local_player.peer_id:
			hull_shock=maxf(hull_shock,.65);shock_clock=0
	if game.combat_audio: game.combat_audio.play(owner,weapon,origin,0.0 if game.offline_operation or game.multiplayer.is_server() else game._melee_network_delay(1))
	if is_instance_valid(game.combat_effects): game.combat_effects.muzzle_smoke(origin,direction,weapon,hash(id),owner)
	var actor:=game.players.get(owner) as WarPlayer
	if weapon in ["rpg","stinger"] and is_instance_valid(actor): actor.accepted_launcher_shot(id,weapon)

func _broadcast(method: String,args: Array) -> void:
	if game.offline_operation:
		if method=="projectile_event":
			_present_shot(int(args[0]),args[1],args[2],str(args[3]),str(args[4]))
		elif method in ["explosion_event","health_update","hull_impact"]: callv(method,args)
		return
	if not game.online: return
	if not game.loading_baselines.is_empty():
		for peer_id in multiplayer.get_peers():
			if game.loading_baselines.has(peer_id):
				var transfer: WarJoinTransfer=game.loading_baselines[peer_id]
				if method=="drone_state":transfer.queue_drone(str(args[0].id))
				elif method=="drone_removed":transfer.queue_drone(str(args[0]),true)
				elif method=="snapshot":
					for state: Dictionary in args[1]:transfer.queue_drone(str(state.id))
			elif game._network_peer_ready(peer_id):callv("rpc_id",[peer_id,method]+args)
		return
	GameNetworkBroadcast.send(self,method,args)

func context_text() -> String:
	if tv.viewing(): return "MÍSSIL TV · MOUSE GUIAR · C VOLTAR · F SAIR DO VEÍCULO"
	if not is_instance_valid(game.local_player): return ""
	if game.local_player.in_water(): return "NADANDO"
	if not _own_id().is_empty():
		if _transport(find_target(_own_id())): return "F · SAIR"
		if find_target(_own_id()) is WarShip: return "F · SAIR    T · TÉRMICA" if _local_is_operator() else "PASSAGEIRO · F · SAIR"
		var keys:="1–4" if find_target(_own_id()) is WarShip else "1–2"
		var extra:=" · Q FUMAÇA" if find_target(_own_id()) is WarVehicle and find_target(_own_id()).kind in ["abrams","t90"] else ""
		if not supply_point_for(game.local_player).is_empty(): extra+=" · H MUNIÇÃO"
		return "OPERADOR · F SAIR · C CÂMERA · RMB ZOOM · T TÉRMICA · R RECARGA · "+keys+" ARMAS"+extra if _local_is_operator() else "PASSAGEIRO · F · SAIR    MOUSE · OBSERVAR"
	if game.local_player.gadget_equipped and game.local_player.gadget=="stinger": return "SEM ALVO" if lock_target.is_empty() else ("ALVO TRAVADO" if lock_progress>=1 else "TRAVANDO · %d%%" % int(lock_progress*100))
	var nearby:=_nearby(game.local_player)
	if nearby: return "F · ENTRAR NO %s · %s · %d/%d" % [str(nearby.spec.name).to_upper(),"OPERADOR" if nearby.driver==0 or _can_take_bot_driver(game.local_player,nearby) else "PASSAGEIRO",nearby.seats.size(),nearby.seat_capacity()]
	if not supply_point_for(game.local_player).is_empty(): return "H · MUNIÇÃO"
	var returning: PackedStringArray=[]
	for vehicle: WarVehicle in vehicles.values():
		if vehicle.destroyed and vehicle.team==game.local_player.war_team:
			returning.append("%s · RETORNA EM %02d:%02d" % [vehicle.spec.name.to_upper(),int(ceilf(vehicle.respawn_left))/60,int(ceilf(vehicle.respawn_left))%60])
	return "\n".join(returning) if not returning.is_empty() else "G · EQUIPAMENTO    B · DRONE    M · IMPLANTAÇÃO"

func hud_text() -> String:
	if tv.viewing(): return tv.hud()
	var own:=find_target(_own_id())
	if _transport(own): return "MOTO · %d%% · %d km/h"%[int(100*own.hp/float(own.spec.hp)),int(absf(own.speed)*3.6)]
	if own is WarShip and _local_is_operator():
		return "%s · OPERADOR    %d%% · %d km/h%s"%[own.spec.name,int(100*own.hp/float(own.spec.hp)),int(absf(own.speed)*3.6)," · RECARREGANDO %.1fs"%own.reload_left if own.reloading else (" · BLOQUEADO" if own.gun_blocked else "")]
	if own is WarVehicle:
		if not _local_is_operator(): return "%s · PASSAGEIRO\n%d / %d HP · %d km/h\nOCUPAÇÃO %d / %d · F PARA SAIR" % [own.spec.name,int(own.hp),int(own.spec.hp),int(absf(own.speed)*3.6),own.seats.size(),own.seat_capacity()]
		var view:="EXTERNA" if vehicle_view.external else "ÓPTICA"
		var weapon_name: String={"tank":"CANHÃO PRINCIPAL","autocannon":"AUTOCANHÃO 30 mm","hmg":"METRALHADORA .50"}.get(str(own.spec.gun),"PRINCIPAL") if own.selected=="primary" else str(WarRules.SECONDARY[own.kind].name)
		var reload_time: float=own.reload_left if own.selected=="primary" else own.secondary_reload_left
		var ready_text:="PRONTO · 1–2 ARMAS" if game._battle_active() else "AGUARDANDO OPONENTE"
		return "%s · OPERADOR\n%s · %d / %d\n%s\nBLINDAGEM %d%% · %d km/h\n%s · ZOOM %dx · TÉRMICA %s\nTORRE %+.0f° · ELEVAÇÃO %+.0f°%s" % [own.spec.name,weapon_name,own.ammo if own.selected=="primary" else own.secondary_ammo,own.reserve if own.selected=="primary" else own.secondary_reserve,("RECARREGANDO — %.1f s"%reload_time) if reload_time>0 else ready_text,int(100*own.hp/float(own.spec.hp)),int(absf(own.speed)*3.6),view,int(vehicle_view.zoom_factor()) if not vehicle_view.external else 1,"ON" if thermal else "OFF",rad_to_deg(own.turret_yaw),rad_to_deg(own.gun_pitch),"\nCANHÃO BLOQUEADO" if own.gun_blocked else ""]
	if own is WarDrone: return "DRONE · %d HP\nBATERIA %.0f s · CLIQUE PARA DETONAR" % [int(own.hp),own.battery]
	return ""

func thermal_allowed() -> bool:
	return _local_is_operator() and find_target(_own_id()) is WarVehicle and (find_target(_own_id()) is WarShip or tv.viewing() or not vehicle_view.external)

func toggle_thermal() -> void:
	if not thermal and not thermal_allowed(): return
	thermal=not thermal
	# Heat signatures and terrain contrast are managed by the thermal component.
	if has_node("Thermal"): get_node("Thermal").set_enabled(thermal)

func launch_drone(id: int) -> void:
	if not game._eligible(id) or game.water_restricted(game.players[id]) or not game.players[id].get_meta("drone_enabled",true): return
	var member: Dictionary=game.members[id]
	if member.get("drone_used",false): return
	for drone: WarDrone in drones.values():
		if drone.team==int(member.team) and not drone.destroyed: game._notice(id,"Sua equipe já tem um drone ativo.");return
	var actor: WarPlayer=game.players[id]
	if not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending: return
	actor.grenade_selected=false;actor.grenade_aiming=false;actor.clear_aim();actor.cancel_reload();actor.cancel_melee();actor.fire_cooldown=0;_set_utility(id,"")
	var drone:=WarDrone.new()
	drone.drone_id="drone_"+str(id)+"_"+str(actor.life_id);drone.owner_id=id;drone.driver=id;drone.team=int(member.team);drone.operator_origin=actor.global_position;drone.position=actor.global_position+Vector3.UP*2.3
	add_child(drone)
	drones[drone.drone_id]=drone
	member.drone_used=true;member.vehicle=drone.drone_id;member.vehicle_seat=0;member.vehicle_role="operator";actor.vehicle_id=drone.drone_id;actor.velocity=Vector3.ZERO;actor.trigger_held=false
	member.shield=0.
	actor._set_hitboxes_enabled(true);actor.body_collision.set_deferred("disabled",false)
	game.sync_inventory(actor)
	if is_instance_valid(actor.view_root): actor.view_root.hide()
	game._broadcast("war_identity",[id,member])

func _destroy_drone(drone: WarDrone,killer: int) -> void:
	if drone.destroyed: return
	if game.members.has(killer) and int(game.members[killer].team)!=drone.team: game.match_stats.award(killer,75,"drone:"+drone.drone_id)
	drone.destroyed=true;drone.hp=0;drone.collision_layer=0
	if drone.driver>0: release(drone.driver,true)
	_broadcast("explosion_event",["destroy:"+drone.drone_id,drone.global_position,2.0,"","drone_wreck"])
	_broadcast("drone_removed",[drone.drone_id])
	drones.erase(drone.drone_id);game._retire_avatar(drone)

func _step_vehicle_respawns(delta: float) -> void:
	if not multiplayer.is_server(): return
	for vehicle: WarVehicle in vehicles.values():
		if not vehicle.destroyed:
			if _transport(vehicle) and vehicle.abandoned_return_due(delta): _respawn_vehicle(vehicle)
			continue
		vehicle.respawn_left=maxf(0.0,vehicle.respawn_left-delta)
		if vehicle.respawn_left<=.00001: _respawn_vehicle(vehicle)

# A centre sample alone can place the running gear inside uneven ground.
# Fit a level hull over the terrain footprint; suspension settles it later.
func _land_spawn_height(at: Vector3,yaw: float,data: Dictionary) -> Vector3:
	var size: Vector3=data.size
	var rotation:=Basis(Vector3.UP,yaw)
	var top:=-INF
	for x in [-.5,-.25,0.,.25,.5]:
		for z in [-.5,-.25,0.,.25,.5]:
			var p:=at+rotation*Vector3(size.x*float(x),0,size.z*float(z))
			top=maxf(top,WarTerrain.height_at(p.x,p.z))
	return Vector3(at.x,top+.12,at.z)

func _clear_land_spawn(vehicle: WarVehicle,yaw: float) -> Variant:
	var offsets: Array[Vector2]=[Vector2.ZERO,Vector2(0,10),Vector2(0,-10),Vector2(0,20),Vector2(0,-20),Vector2(10,10),Vector2(-10,10),Vector2(10,-10),Vector2(-10,-10)]
	var query:=PhysicsShapeQueryParameters3D.new();query.exclude=[vehicle.get_rid()];query.collision_mask=1|4|16;query.margin=.001
	var space:=vehicle.get_world_3d().direct_space_state
	for offset in offsets:
		var candidate:=_land_spawn_height(vehicle.spawn_position+Vector3(offset.x,0,offset.y),yaw,vehicle.spec)
		var pose:=Transform3D(Basis(Vector3.UP,yaw),candidate)
		var clear:=true
		for node in vehicle.get_children():
			if not node is CollisionShape3D or node.disabled or node.shape==null: continue
			query.shape=node.shape;query.transform=pose*node.transform
			if not space.intersect_shape(query,1).is_empty(): clear=false;break
		if clear: return candidate
	return null

func _respawn_vehicle(vehicle: WarVehicle) -> void:
	var spawn_yaw: float=(PI*.5 if vehicle.team==0 else -PI*.5) if vehicle is WarShip else (-PI*.5 if vehicle.team==0 else PI*.5)
	if WarRules.CURRENT_OPERATION in [WarOperation.AFGHAN,WarOperation.FAVELA] and not vehicle.spec.has("naval"):
		spawn_yaw=WarOperation.armor_heading(WarRules.CURRENT_OPERATION,vehicle.team)
	var safe_spawn: Variant=vehicle.spawn_position if vehicle is WarShip else _clear_land_spawn(vehicle,spawn_yaw)
	if safe_spawn==null:
		# Retry rather than materialise inside another occupant or obstruction.
		if vehicle.destroyed: vehicle.respawn_left=.5
		elif _transport(vehicle): vehicle.abandoned_left=.5
		return
	# Also clean a diagnostic/manual respawn of an occupied hull. A normal
	# destruction has already killed/released every occupant before this point.
	vehicle.destroyed=true # No transient promotion during a bulk reset.
	for occupant: int in vehicle.occupant_ids(): release(occupant,true)
	vehicle.clear_seats()
	vehicle._wake_ground_rest();vehicle.ground_support=WarVehicleGround.new();vehicle.step_motion.last_step_frame=-100;vehicle.step_motion.blocked_motion=false
	vehicle.destroyed=false;vehicle.gun_blocked=false;vehicle.respawn_left=0.0;vehicle.visible=true;vehicle.hp=float(vehicle.spec.hp);vehicle.ammo=mini(int(vehicle.spec.ammo),vehicle.capacity());vehicle.reserve=int(vehicle.spec.ammo)-vehicle.ammo;vehicle.secondary_ammo=int(WarRules.SECONDARY[vehicle.kind].capacity);vehicle.secondary_reserve=int(WarRules.SECONDARY[vehicle.kind].reserve);vehicle.secondary_reload_left=0;vehicle.secondary_fire_wait=0;vehicle.selected="primary";vehicle.reload_left=0;vehicle.reloading=false;vehicle.fire_wait=0;vehicle.speed=0;vehicle.velocity=Vector3.ZERO;vehicle.global_position=safe_spawn;vehicle.collision_layer=1|16;vehicle.driver=0;vehicle.spawn_generation+=1
	vehicle.update_wreck(0)
	if vehicle is WarShip:
		for weapon in vehicle.naval_ammo:
			vehicle.naval_ammo[weapon]=int(NavalCatalog.WEAPONS[weapon].ammo);vehicle.naval_reserve[weapon]=int(NavalCatalog.WEAPONS[weapon].ammo)*2;vehicle.naval_waits[weapon]=0.
		vehicle.motion.clear();vehicle.naval_weapon="lightMG";vehicle._update_mount()
	vehicle.heading=spawn_yaw
	vehicle.rotation=Vector3(0,vehicle.heading,0)
	vehicle.turret_yaw=0;vehicle.gun_pitch=0;vehicle.steering=0
	vehicle.turret.rotation=Vector3.ZERO;vehicle.elevation.rotation=Vector3.ZERO;vehicle.turret_shape.rotation=Vector3.ZERO
	vehicle.aim_target=vehicle.global_position-vehicle.global_basis.z*500
	vehicle.destination=vehicle.global_position;vehicle.destination_rotation=vehicle.rotation
	vehicle.reset_physics_interpolation()
	if _transport(vehicle): vehicle.reset_abandonment()
	_send_occupancy(vehicle)

func damage_from_hit(owner: int,object: Node,amount: float,weapon: String,direction: Vector3) -> bool:
	if is_instance_valid(object) and object.has_meta("tv_shot_id"):
		if multiplayer.is_server() and is_finite(amount) and amount>0: game.war_fx.intercept_tv(str(object.get_meta("tv_shot_id")),owner,amount)
		return true
	var target:=object
	while is_instance_valid(target) and not target is WarVehicle and not target is WarDrone: target=target.get_parent()
	if not is_instance_valid(target): return false
	if not multiplayer.is_server(): return true
	if not is_finite(amount) or amount<=0 or target.hp<=0 or target.destroyed: return true
	if target is WarVehicle and not target is WarShip and not _transport(target) and not WarRules.can_damage_armor(weapon): return true
	var friendly: bool=game.members.has(owner) and target.team==int(game.members[owner].team)
	var before: float=target.hp
	var feedback_point: Vector3=target.global_position+Vector3.UP*2.7
	if target is WarDrone:
		target.hp=maxf(0,target.hp-amount)
		if not friendly: game.match_stats.valid_damage(owner,before-target.hp)
		if target.hp<=0: _destroy_drone(target,owner)
	else:
		var resistance:=.07 if weapon in ["ak","fal","g3","glock","sniper","hmg"] else 1.0
		if _transport(target): resistance=1.0
		if target.kind in ["guarani","bmp2"]: resistance=maxf(resistance,.16)
		target.hp=maxf(0,target.hp-amount*resistance)
		if not friendly: game.match_stats.valid_damage(owner,before-target.hp)
		if target.hp<=0 and not target.destroyed:
			if not friendly: game.match_stats.award(owner,200,"vehicle:"+target.vehicle_id+":"+str(game.war_clock))
			target.destroyed=true;target.respawn_left=WarRules.SHIP_RESPAWN_SECONDS if target is WarShip else WarRules.VEHICLE_RESPAWN_SECONDS;target.collision_layer=0;target.visible=true;target.update_wreck(0)
			target.speed=0;target.velocity=Vector3.ZERO;target.reloading=false;target.reload_left=0
			var occupants: Array[int]=target.occupant_ids()
			_broadcast("explosion_event",["destroy:"+target.vehicle_id+":"+str(game.war_clock),target.global_position,9.0,"","tank_wreck" if target.kind in ["abrams","t90"] else "armor_wreck"])
			# Keep reservations until each real death is recorded. destroyed=true
			# suppresses promotion while the death callback releases occupants.
			for occupant: int in occupants:
				if game.players.has(occupant):
					var actor:=game.players[occupant] as WarPlayer
					if game.members.has(occupant): game.members[occupant].shield=0.0
					actor.global_position=target.to_global(target.seat_position(maxi(0,target.seat_of(occupant))))
					if actor.hp>0: game._apply_hit(owner,{"collider":actor.hit_regions.chest,"position":actor.global_position},1000,"chest",weapon,direction)
				if target.seat_of(occupant)>=0: release(occupant,true)
			if not target.seats.is_empty(): target.clear_seats()
			_send_occupancy(target)
	var removed:=before-float(target.hp)
	if removed>0:
		if target is WarVehicle and weapon in ["rpg","stinger","tv","missile","tank","autocannon"]:
			var strength:=clampf(removed/240.,.18,1.6)
			_broadcast("hull_impact",[target.vehicle_id,target.global_position+Vector3.UP,str(target.vehicle_id)+":"+str(before)+":"+str(game.war_clock),strength])
		last_damage_confirmation={"owner":owner,"target":str(target.name),"damage":removed,"killed":target.hp<=0}
		game._damage_confirmed(owner,feedback_point,removed,false)
		if target.hp<=0: game._combat_notice(owner,"VEÍCULO DESTRUÍDO")
	return true

@rpc("authority","call_remote","reliable")
func hull_impact(vehicle_id: String,point: Vector3,event_id: String,strength: float) -> void:
	if impact_events.has(event_id) or not vehicles.has(vehicle_id): return
	impact_events[event_id]=true
	if impact_events.size()>128: impact_events.erase(impact_events.keys()[0])
	if is_instance_valid(game.combat_feedback): game.combat_feedback.impact(event_id,point,"vehicle")
	if _own_id()==vehicle_id:
		hull_shock=maxf(hull_shock,clampf(strength,.18,1.6));shock_clock=0
		if is_instance_valid(game.combat_feedback): game.combat_feedback.play("vehicle",camera.global_position+Vector3.DOWN*.5)

func explode(owner: int,point: Vector3,amount: float,radius: float,weapon: String,id: String,impact: Dictionary={},infantry_amount: float=-1.0) -> void:
	if not multiplayer.is_server() or radius<=0 or not point.is_finite() or blast_events.has(id): return
	blast_events[id]=true
	if blast_events.size()>512: blast_events.erase(blast_events.keys()[0])
	var kills_before:=game.multi_kill_count(owner)
	game.environment_blast(point,amount,radius)
	var space:=get_world_3d().direct_space_state
	var normal: Vector3=impact.get("normal",Vector3.UP)
	var direct: Object=impact.get("collider")
	var surface:="water" if bool(impact.get("water",false)) else ("mud" if impact.is_empty() else ("" if is_instance_valid(direct) and direct.has_meta("hit_region") else GameImpactSurface.detect(impact,"war")))
	for actor: GamePlayer in game.players.values().duplicate():
		if actor.hp<=0 or (not actor.vehicle_id.is_empty() and not actor.vehicle_id.begins_with("drone_")): continue
		if actor.global_position.distance_to(point)>radius+2.5: continue
		var exposure:=WarBlast.exposed_point(space,point,normal,actor,direct)
		if exposure.is_empty() or float(exposure.distance)>radius: continue
		var before: float=actor.hp
		game._apply_hit(owner,{"collider":actor.hit_regions.chest,"position":exposure.point},(infantry_amount if infantry_amount>=0 else amount)*(1.0-float(exposure.distance)/radius*.8),"chest",weapon,(Vector3(exposure.point)-point).normalized())
		if before>0 and actor.hp<=0: game._combat_notice(owner,"ELIMINAÇÃO · "+str(actor.name).left(24))
	for target: Node3D in vehicles.values()+drones.values():
		var distance_to:=target.global_position.distance_to(point)
		if distance_to<radius+2:
			var ray:=PhysicsRayQueryParameters3D.create(point+normal.normalized()*.08,target.global_position+Vector3.UP,1|16)
			var obstacle:=space.intersect_ray(ray)
			if not obstacle.is_empty() and obstacle.collider!=target: continue
			damage_from_hit(owner,target,amount*(1.0-clampf(distance_to/(radius+2),0,1)*.75),weapon,(target.global_position-point).normalized())
	# Missiles are pooled projectiles rather than vehicle nodes. Resolve
	# blast contact against their physical position as well, with cover.
	for slot in game.war_fx.active_slots.duplicate():
		var missile: Dictionary=game.war_fx.rounds[slot]
		if not bool(missile.get("active",false)) or not bool(missile.get("guided",false)): continue
		var distance_to:=point.distance_to(missile.position)
		if distance_to>radius: continue
		var ray:=PhysicsRayQueryParameters3D.create(point+normal.normalized()*.08,missile.position,1|16)
		if not space.intersect_ray(ray).is_empty(): continue
		game.war_fx.intercept_tv(str(missile.shot_id),owner,amount*(1-distance_to/radius*.8))
	game.notify_multi_kill(owner,kills_before,id)
	_broadcast("explosion_event",[id,point,radius,surface,weapon])

@rpc("authority","call_remote","reliable")
func explosion_event(id: String,point: Vector3,radius: float,surface:="",weapon:="") -> void:
	game.war_fx.cancel_shot(id)
	tv.finish(id)
	if game.seen_impacts.has(id): return
	game.seen_impacts[id]=true
	var kind:="drone" if weapon=="drone_wreck" else ("destroy" if id.begins_with("destroy:") else weapon)
	var visual_kind:=weapon if weapon in ["tank_wreck","armor_wreck"] else kind
	if game.combat_effects: game.combat_effects.explosion(point,radius,hash(id),visual_kind)
	game.war_fx.flash(point+Vector3.UP*.5)
	if game.combat_audio: game.combat_audio.explosion(id,point,kind)
	if is_instance_valid(game.combat_feedback) and surface in GameImpactSurface.SOUNDS: game.combat_feedback.impact(id+":contact",point,surface)
	if surface in ["metal","vehicle"] and is_instance_valid(game.metal_sparks): game.metal_sparks.burst(point,Vector3.UP,id)

func acquire(actor: WarPlayer) -> Dictionary:
	var direction: Vector3=actor.global_basis*(Basis(Vector3.RIGHT,actor.pitch)*Vector3.FORWARD)
	var origin:=actor.camera_pivot.global_position
	var best:=650.0
	var result: Dictionary={}
	for drone: WarDrone in drones.values():
		if drone.destroyed or drone.team==actor.war_team: continue
		var offset:=drone.global_position-origin
		if offset.length()>best or direction.dot(offset.normalized())<cos(deg_to_rad(4)): continue
		var query:=PhysicsRayQueryParameters3D.create(origin,drone.global_position,1,owner_excludes(actor.peer_id))
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider!=drone: continue
		best=offset.length();result={"id":drone.drone_id}
	for vehicle: WarVehicle in vehicles.values():
		if not is_instance_valid(vehicle) or vehicle is WarShip or vehicle.destroyed or vehicle.hp<=0 or vehicle.team==actor.war_team: continue
		var target: Vector3=vehicle.global_position+Vector3.UP*1.2
		var offset:=target-origin
		if offset.length()>best or offset.length_squared()<.001 or direction.dot(offset.normalized())<cos(deg_to_rad(4)): continue
		var query:=PhysicsRayQueryParameters3D.create(origin,target,1|16,owner_excludes(actor.peer_id))
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider!=vehicle: continue
		best=offset.length();result={"id":vehicle.vehicle_id}
	return result

func request_gadget() -> void:
	if game.war_clock-last_gadget_clock<.25: return
	last_gadget_clock=game.war_clock
	request_command("gadget",{})

func use_gadget(id: int) -> void:
	if not game._eligible(id) or game.water_restricted(game.players[id]) or not game._battle_active() or not game.players[id].get_meta("class_equipment",true): return
	var actor:=game.players[id] as WarPlayer
	var member: Dictionary=game.members[id]
	if actor.war_class in ["medic","marksman"] and not bool(member.get("bot",false)):
		var wanted:="medic" if actor.war_class=="medic" else "binoculars"
		_set_utility(id,"" if actor.utility_mode==wanted else wanted);return
	if int(member.charges)<=0 or game.war_clock-float(member.last_gadget)<1: return
	if actor.war_class=="medic":
		var nearest: GamePlayer
		var best:=4.0
		for ally: GamePlayer in game.players.values():
			if ally.hp<=0 or ally.hp>=100 or ally.war_team!=actor.war_team or not ally.vehicle_id.is_empty(): continue
			var distance_to:=actor.global_position.distance_to(ally.global_position)
			if distance_to<best: nearest=ally;best=distance_to
		if nearest:
			healing[id]={"target":nearest.peer_id,"until":game.war_clock+3,"next":game.war_clock}
			member.charges-=1;member.last_gadget=game.war_clock
			game.sync_class_resources(id)
		return
	if actor.war_class=="marksman":
		var ray:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,actor.camera_pivot.global_position-actor.weapon_root.global_basis.z*650,CombatRules.SHOT_MASK,game._collision_excludes(id,false))
		ray.collide_with_areas=true
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		var target: Node=hit.get("collider")
		while is_instance_valid(target) and not target is GamePlayer: target=target.get_parent()
		if target is GamePlayer and target.war_team!=actor.war_team:
			member.charges-=1;member.last_gadget=game.war_clock
			game.sync_class_resources(id)
			for peer in game.members:
				if int(game.members[peer].team)==actor.war_team: game._notice(peer,"CONTATO AVISTADO · "+str(target.name))
		return
	if actor.war_class=="soldier": return # Shared five-second grenade system owns infantry grenades.
	if not actor.gadget_equipped or actor.weapon_id!=actor.gadget or not is_instance_valid(actor.launcher_muzzle): return
	if not WarRules.launcher_allowed(actor.war_team,actor.gadget): return
	var weapon: String=actor.gadget
	var data: Dictionary=WarRules.SPECIAL[weapon]
	if game.war_clock-float(member.last_gadget)<float(data.cooldown): return
	var target_id:=""
	if weapon=="stinger":
		var lock: Dictionary=locks.get(id,{})
		var current_target:=acquire(actor)
		if float(lock.get("progress",0))<1 or str(lock.get("target","")).is_empty() or str(current_target.get("id",""))!=str(lock.target): game._notice(id,"Trave um alvo inimigo antes de disparar.");return
		target_id=str(lock.target)
	actor._update_weapon_pose()
	var marker: Node3D=actor.launcher_muzzle if actor.war_class=="antitank" and is_instance_valid(actor.launcher_muzzle) else actor.muzzle_marker
	var origin:=marker.global_position
	var direction: Vector3=-actor.weapon_root.global_basis.z.normalized()
	var ray:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,origin,1,game._collision_excludes(id,false))
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
	var extra:=data.duplicate();extra["target"]=target_id
	var key:="gadget:"+str(id)+":"+str(actor.life_id)+":"+str(game.war_clock)
	if not game.war_fx.spawn(id,origin,direction,weapon,true,key,extra): return
	member.charges-=1;member.last_gadget=game.war_clock
	game.sync_class_resources(id)
	_broadcast("projectile_event",[id,origin,direction,weapon,key,extra])

func _update_gadgets(delta: float) -> void:
	for id in game.members:
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or not game._eligible(id): locks.erase(id);continue
		if actor.gadget_equipped and actor.gadget=="stinger":
			var bot:=bool(game.members[id].get("bot",false))
			var record: Dictionary=locks.get(id,{"target":"","progress":0.0})
			# Human lock-on remains frame-responsive. AI shares a 5 Hz sensor
			# budget instead of raycasting every bot's seeker 60 times a second.
			if bot and game.war_clock<float(record.get("next_at",0.)): continue
			var since:=clampf(game.war_clock-float(record.get("last_at",game.war_clock-delta)),0.,.25)
			var result:=acquire(actor)
			if result.get("id","")==record.target and not result.is_empty(): record.progress=minf(1.,float(record.progress)+since/1.25)
			else: record={"target":str(result.get("id","")),"progress":0.0}
			record.last_at=game.war_clock
			record.next_at=game.war_clock+(.2 if bot else 0.)
			locks[id]=record
	for id in healing.keys():
		var record: Dictionary=healing[id]
		var medic:=game.players.get(id) as WarPlayer
		if bool(record.get("held",false)):
			if not is_instance_valid(medic) or not game._eligible(id) or medic.utility_mode!="medic" or game.war_clock>float(record.lease): healing.erase(id);continue
			if game.war_clock>float(record.until):
				if int(game.members[id].charges)<=0: healing.erase(id);continue
				game.members[id].charges-=1;game.sync_class_resources(id);record.until=game.war_clock+3.
			if game.war_clock>=float(record.next):
				record.next=game.war_clock+.5
				var target:=_medical_target(medic)
				if is_instance_valid(target):
					var before:=target.hp;target.hp=minf(100.,target.hp+7.5)
					if target!=medic: game.match_stats.support(id,target.peer_id,target.hp-before,"heal",game.war_clock,"heal:%d:%s"%[id,str(game.war_clock)])
					_broadcast("health_update",[target.peer_id,target.hp])
			continue
		var patient:=game.players.get(int(record.target)) as WarPlayer
		if not is_instance_valid(medic) or not is_instance_valid(patient) or not game._eligible(id) or not patient.vehicle_id.is_empty() or medic.hp<=0 or patient.hp<=0 or medic.global_position.distance_to(patient.global_position)>4 or game.war_clock>float(record.until): healing.erase(id);continue
		var ray:=PhysicsRayQueryParameters3D.create(medic.global_position+Vector3.UP,patient.global_position+Vector3.UP,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): healing.erase(id);continue
		if game.war_clock>=float(record.next):
			record.next=game.war_clock+.5
			var before:=patient.hp
			patient.hp=minf(100,patient.hp+7.5)
			game.match_stats.support(id,patient.peer_id,patient.hp-before,"heal",game.war_clock,"heal:%d:%s"%[id,str(game.war_clock)])
			_broadcast("health_update",[patient.peer_id,patient.hp])

func _set_utility(id: int,value: String) -> void:
	var actor:=game.players.get(id) as WarPlayer
	if not is_instance_valid(actor): return
	var reset_zoom:=actor.utility_mode!=value or value.is_empty()
	healing.erase(id);actor.set_utility(value)
	if reset_zoom: actor.set_utility_zoom(0)
	if game.members.has(id):
		game.members[id].utility=value
		game.members[id].utility_zoom=actor.utility_zoom
	_broadcast("utility_state",[id,actor.life_id,value])

@rpc("authority","call_remote","reliable")
func utility_state(id: int,life: int,value: String) -> void:
	var actor:=game.players.get(id) as WarPlayer
	if is_instance_valid(actor) and actor.life_id==life:
		actor.set_utility(value)
		if value.is_empty(): actor.set_utility_zoom(0)
		if game.members.has(id):
			game.members[id].utility=value
			game.members[id].utility_zoom=actor.utility_zoom

@rpc("authority","call_remote","reliable")
func utility_zoom_state(id: int,life: int,level: int) -> void:
	var actor:=game.players.get(id) as WarPlayer
	if not is_instance_valid(actor) or actor.life_id!=life or level not in [0,1,2]: return
	actor.set_utility_zoom(level)
	if game.members.has(id): game.members[id].utility_zoom=actor.utility_zoom

func _medical_target(medic: WarPlayer) -> WarPlayer:
	var nearby:=false;var result: WarPlayer=null;var best:=-1.0
	var look: Vector3=-medic.camera_pivot.global_basis.z.normalized()
	for ally: WarPlayer in game.players.values():
		if ally==medic or ally.hp<=0 or ally.war_team!=medic.war_team or not ally.deployed or not ally.vehicle_id.is_empty(): continue
		var offset:=ally.global_position-medic.global_position
		if offset.length()>1.: continue
		nearby=true
		var dot:=look.dot(offset.normalized())
		if dot<.45 or dot<=best: continue
		var query:=PhysicsRayQueryParameters3D.create(medic.global_position+Vector3.UP,ally.global_position+Vector3.UP,1,[medic.get_rid(),ally.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best=dot;result=ally
	return result if nearby else medic

@rpc("authority","call_remote","reliable")
func health_update(id: int,hp: float) -> void:
	if game.players.has(id):
		game.players[id].hp=hp
		if game.players[id].is_local: game.damage_feedback(hp)

func resupply(id: int) -> void:
	if not game._eligible(id) or game.water_restricted(game.players[id]): return
	var member: Dictionary=game.members[id]
	if member.role!="soldier" or int(member.charges)<=0 or game.war_clock-float(member.last_gadget)<6: return
	for actor: WarPlayer in game.players.values():
		if actor.war_team!=int(member.team) or actor.hp<=0 or actor.global_position.distance_to(game.players[id].global_position)>4: continue
		var supplied:=0
		for weapon in actor.active_weapons():
			if not actor.reserves.has(weapon): continue
			var previous:=int(actor.reserves[weapon]);var stock: Array=[int(CombatRules.weapon(weapon).reserve),int(GameWeapons.ITEMS[weapon].mag)*2]
			actor.reserves[weapon]=mini(int(stock[0]),previous+int(stock[1]));supplied+=int(actor.reserves[weapon])-previous
		game.match_stats.support(id,actor.peer_id,supplied,"ammo",game.war_clock,"ammo:%d:%s"%[id,str(game.war_clock)])
		game.sync_inventory(actor)
	member.charges-=1;member.last_gadget=game.war_clock
	game.sync_class_resources(id)

func supply_point_for(actor: WarPlayer) -> String:
	if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed: return ""
	var current:=find_target(actor.vehicle_id)
	if current and (not current is WarVehicle or current is WarShip): return ""
	for id in game.supply_points:
		var state: Dictionary=game.objective_states.get(id,{})
		if int(state.get("owner",-1))!=actor.war_team: continue
		var at: Vector3=game.supply_points[id]
		var point: Vector3=current.global_position if current else actor.global_position
		if Vector2(point.x-at.x,point.z-at.z).length()<(WarRules.CAPTURE_RADIUS if current else 4.) and absf(point.y-at.y)<5.: return str(id)
	return ""

func resupply_point(id: int) -> void:
	if not multiplayer.is_server() or not game._battle_active() or not game.players.has(id): return
	var actor:=game.players[id] as WarPlayer
	var point:=supply_point_for(actor)
	if point.is_empty() or game.water_restricted(actor): return
	var current:=find_target(actor.vehicle_id) as WarVehicle
	if current and not is_operator(id): return
	var key: String="vehicle:"+current.vehicle_id if current else "player:"+str(id)+":"+str(actor.life_id)
	if game.war_clock-float(point_supply_at.get(key,-100.))<20.: return
	var changed:=false
	if current:
		var primary:=maxi(0,int(current.spec.ammo)-current.capacity())
		var secondary:=int(WarRules.SECONDARY[current.kind].reserve)
		changed=current.reserve<primary or current.secondary_reserve<secondary
		current.reserve=maxi(current.reserve,primary);current.secondary_reserve=maxi(current.secondary_reserve,secondary)
	else:
		for weapon in actor.active_weapons():
			if not actor.reserves.has(weapon): continue
			var stock:=int(CombatRules.weapon(weapon).reserve)
			if int(actor.reserves[weapon])<stock: actor.reserves[weapon]=stock;changed=true
		if changed: game.sync_inventory(actor)
	if changed:
		point_supply_at[key]=game.war_clock
		game._combat_notice(id,"MUNIÇÃO REPOSTA")

func deploy_smoke(id: int) -> void:
	if not multiplayer.is_server() or not game._battle_active() or not is_operator(id): return
	var vehicle:=find_target(str(game.members[id].vehicle)) as WarVehicle
	# All land armor uses the same smoke protocol: Abrams, T-90, BMP-2, Guarani.
	if not is_instance_valid(vehicle) or vehicle.kind not in ["abrams","t90","bmp2","guarani"] or vehicle.destroyed: return
	if game.war_clock-float(smoke_cooldowns.get(vehicle.vehicle_id,-1000.))<90.: return
	smoke_cooldowns[vehicle.vehicle_id]=game.war_clock
	var event:=vehicle.vehicle_id+":"+str(game.war_clock)
	var point:=vehicle.global_position+Vector3.UP*.35
	var forward: Vector3=-vehicle.turret.global_basis.z if is_instance_valid(vehicle.turret) else -vehicle.global_basis.z
	var expires:=game.war_clock+GameSmokeClouds.VEHICLE_DURATION
	register_smoke(event,point,expires,forward,vehicle.kind)
	_broadcast("smoke_event",[event,point,expires,forward,vehicle.kind])

@rpc("authority","call_remote","reliable")
func smoke_event(id: String,point: Vector3,until: float,forward: Vector3=Vector3.FORWARD,kind: String="abrams") -> void:
	register_smoke(id,point,until,forward,kind)

func _update_smoke_overlay(delta: float) -> void:
	if not is_instance_valid(smoke_overlay): return
	var opacity:=0.0
	for key in smoke_screens.keys():
		var screen: Dictionary=smoke_screens[key]
		var remaining: float=float(screen.until)-game.war_clock
		if remaining<=0: smoke_screens.erase(key);continue
		if tv.viewing():
			var proximity:=1.0-smoothstep(10.,23.,camera.global_position.distance_to(screen.point))
			var fade:=smoothstep(0.,5.,remaining)*smoothstep(0.,1.2,GameSmokeClouds.VEHICLE_DURATION-remaining)
			opacity=maxf(opacity,.94*proximity*fade)
	var color:=smoke_overlay.color
	color.a=lerpf(color.a,opacity,1.-exp(-delta*8.))
	smoke_overlay.color=color

func register_smoke(id: String,point: Vector3,until: float,forward: Vector3=Vector3.FORWARD,kind: String="abrams") -> void:
	if id.is_empty() or not point.is_finite() or not forward.is_finite() or not is_finite(until) or smoke_screens.has(id): return
	if kind not in ["abrams","t90","guarani","bmp2"]: return
	var remaining:=until-game.war_clock
	if remaining<=0. or remaining>GameSmokeClouds.VEHICLE_DURATION+1.: return
	smoke_screens[id]={"point":point,"until":until,"forward":forward,"kind":kind}
	if is_instance_valid(game.grenades_system) and is_instance_valid(game.grenades_system.smoke_clouds):
		game.grenades_system.smoke_clouds.add_vehicle(id,point,forward,GameSmokeClouds.VEHICLE_DURATION-remaining,kind)

@rpc("authority","call_remote","unreliable_ordered")
func tv_state(id: String,sequence_value: int,point: Vector3,velocity_value: Vector3,left: float,linked: bool,stamp: float) -> void:
	tv.receive_state(id,sequence_value,point,velocity_value,left,linked,stamp)
@rpc("authority","call_remote","reliable")
func tv_link(id: String,linked: bool) -> void: tv.receive_link(id,linked)
@rpc("authority","call_remote","reliable")
func tv_finished(id: String) -> void:
	game.war_fx.cancel_shot(id);tv.finish(id)
func _exit_tree() -> void: tv.clear()
