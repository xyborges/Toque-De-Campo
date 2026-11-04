extends SceneTree
const Prototype=preload("res://tests/impact_breakage_visual_prototype.gd")
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var floor:=StaticBody3D.new();floor.collision_layer=1;world.add_child(floor)
	var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(1000,1,100)
	var floor_node:=CollisionShape3D.new();floor_node.shape=floor_shape;floor_node.position.y=-.5;floor.add_child(floor_node)
	var fixture=Prototype.new();world.add_child(fixture);await process_frame
	var outcomes: Dictionary={}
	for item in [["guarani",18000.],["bmp2",14300.],["abrams",62000.],["t90",46500.]]:
		var kind: String=item[0];var mass: float=item[1]
		var slot:=outcomes.size();var tree:=Vector3(slot*100.+20.,0,10.)
		var cell: Vector2i=fixture.model.cell_for(tree)
		var slow_tree:=tree+Vector3(0,0,8)
		fixture.add_cell(cell,[{"kind":"thin","position":tree},{"kind":"pole","position":slow_tree}])
		var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="test_"+kind;world.add_child(vehicle)
		vehicle.global_position=tree+Vector3(-7,0,0);vehicle.speed=8.
		await physics_frame;await physics_frame
		var events: Array[Dictionary]=[]
		for tick in 90:
			await physics_frame
			vehicle.velocity=Vector3(8,0,0)
			var before:=vehicle.velocity
			vehicle.move_and_slide()
			events=fixture.vehicle_contact(vehicle,mass,before)
			if not events.is_empty(): break
		check(events.size()==1,kind+": no real collision event")
		check(vehicle.speed<8.,kind+": impact did not slow the vehicle")
		var speed_after:=vehicle.speed;vehicle.global_position=slow_tree+Vector3(-2.1,0,0);vehicle.velocity=Vector3.ZERO;vehicle.speed=.5
		await physics_frame;var touched:=false
		for tick in 150:
			await physics_frame
			vehicle.velocity=Vector3(.5,0,0);var before:=vehicle.velocity;vehicle.move_and_slide()
			for j in vehicle.get_slide_collision_count():
				if vehicle.get_slide_collision(j).get_collider()==fixture.cells[cell].body: touched=true
			check(fixture.vehicle_contact(vehicle,mass,before).is_empty(),kind+": slow contact caused breakage")
			if touched: break
		check(touched,kind+": slow-contact physics was not exercised")
		check(not fixture.model.broken.has(fixture.model.key(cell,1)),kind+": pole broke from a light touch")
		outcomes[kind]={"hit":events.size(),"speed_after":speed_after,"slow_contact":touched}
		vehicle.queue_free();await process_frame
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"vehicles":outcomes,"scope":"isolated Jolt collision fixture with real WarVehicle bodies; no map, networking, normal controls or gameplay integration"}))
	quit(0 if errors.is_empty() else 1)
