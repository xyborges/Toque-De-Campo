extends RefCounted

# Test-only adapter: off by default and never instantiated by normal gameplay.
# It observes actual WarPowerPole collision information but changes only the
# separate mirror model. It is not an RPC and does not validate weapon ammo.
const MASSES:={"guarani":18000.,"bmp2":14300.,"abrams":62000.,"t90":46500.}
var enabled:=false
var game: Node
var model: RefCounted
var lookup: Dictionary={}
var events: Array[Dictionary]=[]

func _resolve(collider: Object,shape: Object,point: Vector3) -> Dictionary:
	if not enabled or not is_instance_valid(game) or not game.multiplayer.is_server(): return {}
	if not collider is WarPowerPole or not is_instance_valid(shape) or not shape is CollisionShape3D or not point.is_finite(): return {}
	var pole:=collider as WarPowerPole
	if not is_instance_valid(game.power_grid) or game.power_grid.poles.get(pole.pole_id)!=pole or not lookup.has(pole.pole_id): return {}
	if shape.get_parent()!=pole or (shape as CollisionShape3D).disabled: return {}
	return lookup[pole.pole_id]

func shot(hit: Dictionary,damage: float,direction: Vector3) -> Dictionary:
	if not enabled: return {"handled":false}
	var body:=hit.get("collider") as CollisionObject3D
	if not is_instance_valid(body) or not body is WarPowerPole: return {"handled":false}
	# While the isolated test is enabled, never fall through to real pole
	# damage even if the contact is malformed or the pole is outside the copy.
	if not hit.has("shape") or not hit.has("position"): return {"handled":true,"event":{},"invalid":true}
	# The body shape index from the authoritative ray uniquely identifies the
	# contacted CollisionShape3D; no node names or guessed nearest pole.
	var owner_id:=body.shape_find_owner(int(hit.shape))
	var shape:=body.shape_owner_get_owner(owner_id)
	var ref: Dictionary=_resolve(body,shape,hit.position)
	if ref.is_empty(): return {"handled":true,"event":{},"invalid":true}
	var event: Dictionary=model.shot(ref.cell,ref.index,damage,hit.position,direction)
	if not event.is_empty(): events.append(event)
	return {"handled":true,"event":event}

func vehicle_contacts(vehicle: WarVehicle,speed: float,direction: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not enabled or not is_instance_valid(game) or not game.multiplayer.is_server() or not MASSES.has(vehicle.kind): return result
	if not is_finite(speed) or speed<2. or not direction.is_finite() or direction.length_squared()<.000001: return result
	for slide in vehicle.get_slide_collision_count():
		var contact:=vehicle.get_slide_collision(slide)
		for index in contact.get_collision_count():
			var collider:=contact.get_collider(index)
			var point:=contact.get_position(index)
			var ref: Dictionary=_resolve(collider,contact.get_collider_shape(index),point)
			if ref.is_empty() or direction.normalized().dot(-contact.get_normal(index))<.25: continue
			var event: Dictionary=model.vehicle_impact(ref.cell,ref.index,float(MASSES[vehicle.kind]),speed,point,direction)
			if event.is_empty(): continue
			vehicle.speed*=.68;events.append(event);result.append(event)
	return result
