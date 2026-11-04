extends SceneTree

const Model=preload("res://tests/impact_breakage_model.gd")
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: errors.append(message)
func _initialize() -> void:
	var server=Model.new();var viewer=Model.new();var late=Model.new()
	var cell:=Vector2i(0,0);var neighbour:=Vector2i(1,0)
	var items: Array=[{"kind":"pole","position":Vector3(2,0,2)},{"kind":"thin","position":Vector3(5,0,2)},{"kind":"burnt","position":Vector3(8,0,2)},{"kind":"thick","position":Vector3(12,0,2)}]
	for model in [server,viewer,late]:
		model.register(cell,items)
		model.register(neighbour,[{"kind":"thin","position":Vector3(91,0,2)}])
	check(server.impact(cell,0,30000.,1.,Vector3.RIGHT).is_empty(),"low speed must not break pole")
	check(server.impact(cell,1,-1.,50.,Vector3.RIGHT).is_empty(),"negative mass must be rejected")
	var event: Dictionary=server.impact(cell,0,30000.,2.,Vector3.RIGHT)
	check(not event.is_empty(),"vehicle impact must break pole")
	check(viewer.apply_event(event),"viewer must apply authority event")
	check(not viewer.apply_event(event),"event must be idempotent")
	var blast: Array[Dictionary]=server.explosion(Vector3(7,0,2),180.,10.)
	for hit in blast: check(viewer.apply_event(hit),"viewer must apply explosion")
	check(server.broken.has(server.key(cell,2)),"burnt trees should be vulnerable")
	check(not server.broken.has(server.key(cell,3)),"thick tree must use higher threshold")
	check(not server.broken.has(server.key(neighbour,0)),"far cell should remain intact")
	# These provisional gameplay masses must not be treated as a live vehicle
	# test: WarVehicle is currently kinematic and has no authored mass field.
	for vehicle_mass in [18000.,14300.,62000.,46500.]:
		var test=Model.new();test.register(cell,[items[0],items[1]])
		check(test.impact(cell,0,vehicle_mass,.5,Vector3.RIGHT).is_empty(),"a vehicle must not break a pole merely by touching")
		check(not test.impact(cell,1,vehicle_mass,8.,Vector3.RIGHT).is_empty(),"four vehicle mass profiles should break thin trees at speed")
	for state in server.snapshot(): check(late.apply_event(state),"late join snapshot must apply")
	check(late.broken.size()==server.broken.size() and viewer.broken.size()==server.broken.size(),"state must converge")
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"destroyed":server.broken.size(),"late_join_count":late.broken.size()}))
	quit(0 if errors.is_empty() else 1)
