extends Node3D

# Parent only for a QA vehicle using the real WarVehicle simulate/step path.
# The normal WarVehicles manager remains untouched.
var game: Node
var adapter: RefCounted
var lab: Node3D
var events: Array[Dictionary]=[]

func ram_light_obstacles(vehicle: WarVehicle,speed: float,direction: Vector3) -> void:
	for event: Dictionary in adapter.vehicle_contacts(vehicle,speed,direction):
		events.append(event)
		lab.present(event)

func flood_vehicle(_vehicle: WarVehicle) -> void:
	pass
