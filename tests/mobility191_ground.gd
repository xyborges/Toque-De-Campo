extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var slope:=StaticBody3D.new();slope.position=Vector3(0,9.5,0);slope.rotation=Vector3(.25,0,.18);slope.collision_layer=1
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(45,1,45);collision.shape=box;slope.add_child(collision);stage.add_child(slope)
	await physics_frame;await physics_frame
	var expected:=slope.basis.y
	for kind in ["guarani","bmp2","abrams","t90"]:
		var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="ground191_"+kind;stage.add_child(vehicle)
		for heading in [0.,PI*.5,PI,-PI*.5]:
			vehicle.position=Vector3(0,10.1,0);vehicle.heading=heading;vehicle.rotation=Vector3(0,heading,0);vehicle.ground_support=WarVehicleGround.new()
			for frame in 100: vehicle.ground_support.align(vehicle,1./60.)
			check(vehicle.basis.y.dot(expected)>.995,kind+" cross-slope alignment at yaw "+str(heading))
			var min_gap:=INF;var max_gap:=-INF
			for point in vehicle.ground_support.contacts:
				var foot:=vehicle.to_global(Vector3(point.x,.09,point.z))
				var ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*2,foot-Vector3.UP*2,1,[vehicle.get_rid()])
				var hit:=stage.get_world_3d().direct_space_state.intersect_ray(ray)
				var gap:=foot.y-Vector3(hit.get("position",foot+Vector3.DOWN*10)).y
				min_gap=minf(min_gap,gap);max_gap=maxf(max_gap,gap)
			check(min_gap>-.015 and max_gap<.08,kind+" supported footprint at yaw "+str(heading))
		vehicle.queue_free();await physics_frame;await physics_frame
	stage.queue_free();await physics_frame
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/mobility191-ground-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
