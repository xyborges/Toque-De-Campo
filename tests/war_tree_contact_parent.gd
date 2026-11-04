extends Node3D

# Test adapter for the vehicle's real simulate/step-motion path. It uses the
# pre-collision speed supplied by WarVehicle rather than the already-clipped
# speed after a blocked slide. The live vehicle system is not replaced.
var game: Node
var tree_index: RefCounted
var events: Array[Dictionary]=[]
var apply_break:=true
const MASSES:={"guarani":18000.,"bmp2":14300.,"abrams":62000.,"t90":46500.}
const Model=preload("res://tests/impact_breakage_model.gd")

func ram_light_obstacles(vehicle: WarVehicle,impact_speed: float,impact_direction: Vector3) -> void:
	if impact_speed<2.0 or not impact_direction.is_finite(): return
	for i in vehicle.get_slide_collision_count():
		var contact:=vehicle.get_slide_collision(i)
		for j in contact.get_collision_count():
			var shape:=contact.get_collider_shape(j) as CollisionShape3D
			if not is_instance_valid(shape) or not tree_index.shape_to_id.has(shape.get_instance_id()): continue
			if impact_direction.normalized().dot(-contact.get_normal(j))<.25: continue
			var id: Dictionary=tree_index.shape_to_id[shape.get_instance_id()]
			if not apply_break:
				var kind: String=tree_index.model.cells[id.cell][id.index].kind
				if float(MASSES[vehicle.kind])*impact_speed>=float(Model.MOMENTUM[kind]): events.append({"cell":id.cell,"index":id.index,"direction":impact_direction.normalized()})
				continue
			var event: Dictionary=tree_index.impact(id.cell,id.index,float(MASSES[vehicle.kind]),impact_speed,impact_direction)
			if event.is_empty(): continue
			vehicle.speed*=.68;events.append(event)
