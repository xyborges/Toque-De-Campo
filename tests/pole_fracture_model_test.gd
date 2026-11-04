extends SceneTree

const Model=preload("res://tests/pole_fracture_model.gd")
var errors: Array[String]=[]

func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message)

func _initialize() -> void:
	var server=Model.new();server.authoritative=true
	var viewer=Model.new();var late=Model.new()
	var cell:=Vector2i(0,0)
	var points: Array=[Vector3(2,1,2),Vector3(5,1,2),Vector3(8,1,2),Vector3(11,1,2)]
	for model in [server,viewer,late]: check(model.register(cell,points),"register deterministic cell")
	check(not server.register(cell,points),"duplicate registration rejected")
	check(viewer.shot(cell,0,999.,Vector3(2,3,2),Vector3.RIGHT).is_empty(),"client cannot authorize damage")
	check(server.shot(cell,0,60.,Vector3(20,3,2),Vector3.RIGHT).is_empty(),"off-target shot ignored")
	check(server.shot(cell,0,60.,Vector3(2,2.5,2),Vector3.RIGHT).is_empty(),"first shot does not break pole")
	check(is_equal_approx(float(server.cells[cell][0].hp),60.),"valid shots accumulate damage")
	var low: Dictionary=server.shot(cell,0,60.,Vector3(2,2.5,2),Vector3.RIGHT)
	check(not low.is_empty() and int(low.height_cm)==150,"break follows low shot height")
	check(viewer.apply_event(low),"viewer applies authority event")
	check(not viewer.apply_event(low),"duplicate event is ignored")
	var high: Dictionary=server.shot(cell,1,120.,Vector3(5,7.2,2),Vector3.LEFT)
	check(not high.is_empty() and int(high.height_cm)==620,"break follows high shot height")
	check(int(high.height_cm)!=int(low.height_cm),"break is not fixed at mid-height")
	check(server.vehicle_impact(cell,2,62000.,.5,Vector3(8,2,2),Vector3.RIGHT).is_empty(),"slow contact does not break")
	var vehicle: Dictionary=server.vehicle_impact(cell,2,18000.,8.,Vector3(8,2,2),Vector3.RIGHT)
	check(not vehicle.is_empty() and int(vehicle.height_cm)==100,"vehicle impact retains collision height")
	var explosion: Array[Dictionary]=server.explosion(Vector3(11,4,2),300.,10.)
	check(explosion.size()==1 and int(explosion[0].height_cm)==300,"blast break uses nearest impact height")
	for state: Dictionary in server.snapshot():
		check(late.apply_event(state),"late join applies each snapshot event")
	check(late.snapshot()==server.snapshot(),"late join has the same heights and directions")
	var shielded=Model.new();shielded.authoritative=true;shielded.register(cell,[points[3]])
	check(not shielded.apply_event({"cell":cell,"index":0,"direction":Vector3.RIGHT,"height_cm":0}) and shielded.broken.is_empty(),"invalid height rejected before applying")
	var blocked:=func(_origin,_target,_cell,_index): return false
	check(shielded.explosion(Vector3(11,4,2),300.,10.,blocked).is_empty(),"occluded pole must remain intact")
	for mass in [18000.,14300.,62000.,46500.]:
		var test=Model.new();test.authoritative=true;test.register(cell,[points[0]])
		check(test.vehicle_impact(cell,0,mass,.5,Vector3(2,2,2),Vector3.RIGHT).is_empty(),"slow vehicle does not break")
		check(not test.vehicle_impact(cell,0,mass,8.,Vector3(2,2,2),Vector3.RIGHT).is_empty(),"vehicle at speed breaks")
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"broken":server.broken.size(),"late":late.broken.size()}))
	quit(0 if errors.is_empty() else 1)
