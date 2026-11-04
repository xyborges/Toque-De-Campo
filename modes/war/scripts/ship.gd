extends WarVehicle
class_name WarShip
var hull: NavalShip
var naval_kind:="assault"
var naval_weapon:="lightMG"
var naval_ammo: Dictionary={}
var naval_reserve: Dictionary={}
var naval_waits: Dictionary={}
var motion:=GameSnapshotMotion.new()
var server_clock:=0.0
var sample_clock:=0.0
var born:=false
func _ready() -> void:
	spec=WarRules.VEHICLES[kind];sensor=WarRules.VEHICLE_SENSORS[kind];team=int(spec.team);hp=float(spec.hp);name=vehicle_id
	set_meta("war_vehicle",vehicle_id);set_meta("surface","vehicle");naval_kind=str(spec.naval)
	collision_layer=1|16;collision_mask=1|16
	var shape:=BoxShape3D.new();shape.size=Vector3(spec.size.x,2.2,spec.size.z)*Vector3(.85,1,.9)
	var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=.5;add_child(collider)
	hull=NavalShip.new();add_child(hull);hull.build(naval_kind,0,"",str(spec.name));hull.collision_layer=0;hull.collision_mask=0
	# Keep the authored upper-cabin/hull contact volumes on the authoritative
	# vehicle body. A visual child with collision_layer=0 cannot receive hits.
	for child in hull.get_children():
		if child is CollisionShape3D: child.reparent(self,true)
	for id in hull.turrets:
		naval_ammo[id]=int(NavalCatalog.WEAPONS[id].ammo);naval_reserve[id]=int(NavalCatalog.WEAPONS[id].ammo)*2;naval_waits[id]=0.
	hull.turrets.heavyMG.position.y+=1.5
	spawn_position=global_position;destination=global_position;aim_target=global_position+Vector3.FORWARD*400
	optic=Marker3D.new()
	var bridge:=get_node("BridgeCollision") as CollisionShape3D
	var bridge_size: Vector3=(bridge.shape as BoxShape3D).size
	optic.position=bridge.position+Vector3(0,bridge_size.y*.35,-bridge_size.z*.5-.35)
	add_child(optic)
	turret_shape=collider
	_update_mount()
	if DisplayServer.get_name()!="headless":
		_troop_deck()
		var roots: Array[Node]=[]
		for child in hull.get_children():
			if child is MeshInstance3D: roots.append(child)
		WarRenderBatch.merge(hull,"war-ship:"+naval_kind,roots)
		roots.clear()
		for child in get_children():
			if child is MeshInstance3D: roots.append(child)
		WarRenderBatch.merge(self,"war-ship-seats:"+naval_kind,roots)
		# Keep each animated pivot, recoil node and muzzle intact; merge only
		# rigid geometry underneath them. Distant ships keep a complete silhouette.
		for gun: NavalTurret in hull.turrets.values():
			for part: Node3D in [gun.yaw_pivot,gun.visual]:
				roots.clear()
				for child in part.get_children():
					if child is MeshInstance3D: roots.append(child)
				WarRenderBatch.merge(part,"war-ship-gun:%s:%s"%[gun.weapon,"yaw" if part==gun.yaw_pivot else "barrel"],roots)
		for detail: MeshInstance3D in find_children("*","MeshInstance3D",true,false): detail.visibility_range_end=450
		var distant:=Node3D.new();distant.name="ShipDistantLOD";add_child(distant)
		NavalGeometry.hull(distant,naval_kind)
		NavalGeometry.box(distant,"Bridge",bridge.position,bridge_size,Color("758789"))
		NavalGeometry.box(distant,"Mast",bridge.position+Vector3.UP*(bridge_size.y*.5+1.3),Vector3(.16,2.6,.16),Color("4e626a"))
		for detail: MeshInstance3D in distant.get_children():
			detail.visibility_range_begin=450;detail.visibility_range_end=2400
	born=true
func _troop_deck() -> void:
	var deck:=float(hull.spec.height)*.55
	var mount:=hull.turrets.heavyMG as NavalTurret
	NavalGeometry.cylinder(hull,"RaisedSternGunPedestal",mount.position-Vector3.UP*.75,.35,1.5,Color("4a5d60"))
	for seat in range(1,seat_capacity()):
		var feet:=seat_position(seat);feet.y=deck
		NavalGeometry.box(self,"TroopSeat",feet+Vector3(0,.45,0),Vector3(.65,.18,.65),Color("505f50"))
		NavalGeometry.box(self,"TroopBackrest",feet+Vector3(0,.83,.3),Vector3(.65,.65,.12),Color("505f50"))
		for dx in [-.23,.23]: NavalGeometry.cylinder(self,"SeatLeg",feet+Vector3(dx,.22,0),.035,.45,Color("293b3b"))
	# Two access gates and rails, clear of turret sweep and the central route.
	for side in [-1.,1.]:
		for z in [2.,4.,6.,8.]: NavalGeometry.cylinder(self,"TroopRailPost",Vector3(side*float(hull.spec.width)*.43,deck+.55,z),.04,1.1,Color("607272"))
		NavalGeometry.box(self,"TroopHandrail",Vector3(side*float(hull.spec.width)*.43,deck+1.1,5),Vector3(.07,.07,6.2),Color("607272"))
	NavalGeometry.box(self,"BoardingStep",Vector3(0,deck+.06,float(hull.spec.length)*.43),Vector3(2,.15,1),Color("687770"))
func _update_mount() -> void:
	var mount:=hull.turrets[naval_weapon] as NavalTurret
	turret=mount.yaw_pivot;elevation=mount.pitch_pivot;muzzle=mount.muzzle;secondary_muzzle=muzzle
	selected="primary";ammo=int(naval_ammo.get(naval_weapon,0));reserve=int(naval_reserve.get(naval_weapon,0));fire_wait=float(naval_waits.get(naval_weapon,0))
	turret_yaw=mount.yaw;gun_pitch=mount.elevation
func choose_weapon(slot: int) -> void:
	var allowed: Array=hull.spec.weapons
	if slot<1 or slot>allowed.size() or reloading: return
	naval_weapon=str(allowed[slot-1]);_update_mount()
func simulate(delta: float,control: Dictionary) -> void:
	if destroyed: return
	server_clock=float(get_parent().game.war_clock)
	for id in naval_waits: naval_waits[id]=maxf(0,float(naval_waits[id])-delta)
	if reloading:
		reload_left=maxf(0,reload_left-delta)
		if reload_left==0:
			var amount:=mini(capacity()-int(naval_ammo[naval_weapon]),int(naval_reserve[naval_weapon]));naval_ammo[naval_weapon]+=amount;naval_reserve[naval_weapon]-=amount;reloading=false
	var throttle:=float(control.get("throttle",0));var steer:=float(control.get("steer",0))
	speed=move_toward(speed,throttle*(float(spec.speed) if throttle>=0 else float(spec.reverse)),delta*float(spec.acceleration))
	heading=wrapf(heading-steer*float(spec.turn)*delta*clampf(absf(speed)/4,.15,1),-PI,PI)
	var forward:=Basis(Vector3.UP,heading)*Vector3.FORWARD;velocity=forward*speed
	var proposed:=global_position+velocity*delta
	if WarTerrain.height_at(proposed.x,proposed.z)>-1.0: velocity=Vector3.ZERO;speed=0.
	if velocity.length_squared()>.000001:
		var collision:=move_and_collide(velocity*delta)
		if collision: speed*=.5;velocity=velocity.slide(collision.get_normal())*.5
	global_position.x=clampf(global_position.x,-WarTerrain.HALF+25,WarTerrain.HALF-25);global_position.z=clampf(global_position.z,-WarTerrain.HALF+25,WarTerrain.HALF-25)
	global_position.y=WarCoast.wave(global_position,server_clock)
	var right:=Basis(Vector3.UP,heading)*Vector3.RIGHT
	var pitch_value:=atan2(WarCoast.wave(global_position+forward*4,server_clock)-WarCoast.wave(global_position-forward*4,server_clock),8)
	var roll_value:=atan2(WarCoast.wave(global_position+right*3,server_clock)-WarCoast.wave(global_position-right*3,server_clock),6)
	basis=Basis(Vector3.UP,heading)*Basis.from_euler(Vector3(pitch_value,0,roll_value))

	# Uncrewed ships retain their local gun angles. Solving sixteen ballistic
	# intercepts every tick at empty berths consumed server time needlessly.
	if driver>0:
		aim(delta,control.get("aim",aim_target));gun_blocked=protected_lane()
	_update_mount()
func aim(delta: float,point: Vector3,immediate:=false) -> void:
	aim_target=point
	for gun: NavalTurret in hull.turrets.values():
		gun.step(point,velocity,20. if immediate else delta)
		var origin:=gun.muzzle.global_position
		var direction: Vector3=-gun.muzzle.global_basis.z.normalized()
		for id: int in occupant_ids():
			var head:=to_global(seat_position(seat_of(id)))+Vector3.UP*1.9
			var flat:=Vector2(head.x-origin.x,head.z-origin.z);var heading_direction:=Vector2(direction.x,direction.z).normalized()
			if flat.dot(heading_direction)<=0 or absf(flat.cross(heading_direction))>1.1: continue
			var safe_pitch:=atan2(head.y+.5-origin.y,maxf(.1,flat.length()))
			if gun.elevation<safe_pitch: gun.elevation=minf(safe_pitch,float(NavalCatalog.WEAPONS[gun.weapon].max_pitch));gun.pitch_pivot.rotation.x=gun.elevation
func protected_lane() -> bool:
	var origin:=muzzle.global_position;var end:=origin-muzzle.global_basis.z*float(spec.size.z)*1.5
	for id: int in occupant_ids():
		var centre:=to_global(seat_position(seat_of(id)))+Vector3.UP*1.05
		if centre.distance_to(Geometry3D.get_closest_point_to_segment(centre,origin,end))<.8: return true
	# Explicit cabin volume: own hull is excluded from projectile rays, so
	# this safety test must not depend on the shooter collision exclusions.
	var cabin:=get_node_or_null("BridgeCollision") as CollisionShape3D
	if cabin and cabin.shape is BoxShape3D:
		var shape:=cabin.shape as BoxShape3D
		var inverse:=cabin.global_transform.affine_inverse()
		return AABB(-shape.size*.5,shape.size).intersects_segment(inverse*origin,inverse*end)!=null
	return false

func start_reload() -> bool:
	if destroyed or reloading or ammo>=capacity() or reserve<=0: return false
	reloading=true;reload_left=float(NavalCatalog.WEAPONS[naval_weapon].reload);return true
func capacity() -> int: return int(NavalCatalog.WEAPONS[naval_weapon].ammo)
func snapshot() -> Dictionary:
	var data:=super.snapshot();data.time=server_clock;data.velocity=velocity
	var packed:=PackedFloat32Array()
	for id: String in hull.spec.weapons:
		var gun:=hull.turrets[id] as NavalTurret
		packed.append_array(PackedFloat32Array([float(naval_ammo[id]),float(naval_reserve[id]),float(naval_waits[id]),gun.yaw,gun.elevation]))
	data.naval=packed;data.slot=hull.spec.weapons.find(naval_weapon)
	return data
func receive(state: Dictionary) -> void:
	if int(state.get("seats_revision",0))<seats_revision: return
	if int(state.get("spawn_generation",0))<spawn_generation: return
	# super.receive() can reject a packet; reject here too, before applying
	# naval fields or appending an interpolation sample from that packet.
	if received_state_sequence>0 and int(state.get("sequence",0))<=received_state_sequence: return
	var old_destroyed:=destroyed;var old_generation:=spawn_generation;super.receive(state);team=int(state.team)
	if not state.has("naval"): return
	var packed: PackedFloat32Array=state.naval;var guns: Dictionary={}
	if packed.size()!=hull.spec.weapons.size()*5: return
	for index in hull.spec.weapons.size():
		var id:=str(hull.spec.weapons[index]);naval_ammo[id]=int(packed[index*5]);naval_reserve[id]=int(packed[index*5+1]);naval_waits[id]=packed[index*5+2]
		guns[id]={"yaw":packed[index*5+3],"pitch":packed[index*5+4],"valid":true,"blocked":false}
	naval_weapon=str(hull.spec.weapons[clampi(int(state.slot),0,hull.spec.weapons.size()-1)]);velocity=state.velocity
	sample_clock=float(state.time)
	if (old_destroyed and not destroyed) or spawn_generation!=old_generation: motion.clear()
	motion.push(state.position,state.velocity,state.rotation,sample_clock)
	server_clock=motion.render_clock
	set_meta("gun_state",guns);_update_mount()
func render(delta: float) -> void:
	server_clock=motion.advance(delta)
	if not motion.samples.is_empty(): global_transform=motion.sample(server_clock)
	var states: Dictionary=get_meta("gun_state",{})
	for id in states:
		if hull.turrets.has(id): hull.turrets[id].apply_snapshot(states[id],delta)
	_update_mount()
