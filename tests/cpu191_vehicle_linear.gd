extends "res://tests/cpu191_vehicle_world.gd"

# Four lanes east of the western base perimeter. Full world stays unchanged:
# terrain, the authored access road and every other map collider are retained.
# All hulls face east, start once, settle for eight seconds and never teleport.
func _initialize() -> void:
	scenario="linear"
	measure_after=8.
	super._initialize()

func initial_point(_kind: String,index: int) -> Vector3:
	return WarTerrain.point(-1078.,64.+index*24.)+Vector3.UP*.6

func initial_heading(_kind: String,_index: int) -> float:
	return -PI*.5

func control_for(vehicle: WarVehicle,_index: int) -> Dictionary:
	return {"throttle":.15,"steer":0.,"aim":vehicle.global_position+Vector3(500,1.5,0),"fire":false,"at":game.war_clock}

func validate_route() -> void:
	for index in vehicles.size():
		var vehicle:=vehicles[index]
		var origin:=initial_point(vehicle.kind,index)
		if vehicle.global_position.x-origin.x<20.: failures.append(vehicle.kind+" did not drive at least 20 m in its lane")
		if absf(vehicle.global_position.z-origin.z)>2.: failures.append(vehicle.kind+" left its straight lane")
		if vehicle.destroyed: failures.append(vehicle.kind+" flooded/destroyed on the selected terrain")
