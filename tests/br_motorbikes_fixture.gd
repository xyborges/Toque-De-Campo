extends BRMotorbikes

func _ready() -> void:
	name="Motorbikes"
	for index in 2:
		var bike: WarVehicle=BIKE.new()
		bike.kind="bike_0";bike.vehicle_id="br_bike_%02d"%index;bike.position=Vector3(index*10,.05,0)
		add_child(bike);bikes[bike.vehicle_id]=bike
	set_physics_process(false)
