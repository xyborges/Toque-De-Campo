extends "res://tests/br_atmosphere_benchmark.gd"
func set_view(index: int) -> void:
	if "--scenery-only" in OS.get_cmdline_user_args():
		for actor in actors:actor.visible=false
	if index==1 and "--shelf-capture" in OS.get_cmdline_user_args() and map.has_meta("afghan_featured_shelf"):
		var feature: Dictionary=map.get_meta("afghan_featured_shelf");var p: Vector3=feature.position;var outward: Vector3=feature.outward
		camera.position=p+outward*35.+outward.cross(Vector3.UP)*18.+Vector3.UP*10.;camera.look_at(p+Vector3.UP*3.);return
	if index==2 and "--garden-capture" in OS.get_cmdline_user_args() and not Afghan.LAND.garden_layout().is_empty():
		var garden: Dictionary=Afghan.LAND.garden_layout()[0];var basis:=Basis(Vector3.UP,garden.yaw)
		var p: Vector3=garden.position+basis*Vector3(16,0,23)
		camera.position=Afghan.point(p.x,p.z)+Vector3.UP*9.;camera.look_at(garden.position+Vector3.UP*1.);return
	if index==1 and "--cliff-capture" in OS.get_cmdline_user_args() and map.has_meta("afghan_featured_cliff"):
		var feature: Dictionary=map.get_meta("afghan_featured_cliff");var p: Vector3=feature.position;var outward: Vector3=feature.outward
		camera.position=p+outward*27.+outward.cross(Vector3.UP)*12.+Vector3.UP*8.;camera.look_at(p+Vector3.UP*3.);return
	if "--isolate-shadow-acne" in OS.get_cmdline_user_args():lights.sun.shadow_enabled=false
	if "--village-captures" in OS.get_cmdline_user_args():
		var centre: Vector3=Afghan.LAND.village_centres()[0]
		var road: Dictionary={}
		for item: Dictionary in Afghan.LAND.roads():
			if item.kind=="village":road=item;break
		var street: Vector3=road.points[road.points.size()/3]
		var target: Vector3=road.points[mini(road.points.size()-1,road.points.size()/3+7)]
		var house: Dictionary=Afghan.building_layout()[0];var basis:=Basis(Vector3.UP,house.yaw)
		var views: Array=[
			[centre+Vector3(-70,55,90),centre+Vector3(10,0,-15)],
			[Afghan.point(street.x,street.z)+Vector3.UP*1.8,Afghan.point(target.x,target.z)+Vector3.UP*2.1],
			[house.position+basis*Vector3(-11,2,16),house.position+Vector3.UP*2.]]
		camera.position=views[index][0];camera.look_at(views[index][1]);return
	var farms: Array=Afghan.LAND.farmland_layout()
	var farm: Dictionary=farms[farms.size()/2]
	for candidate: Dictionary in farms:
		if candidate.position.z>300. and candidate.side>0:farm=candidate;break
	var p: Vector3=farm.position
	var views: Array=[
		[p+Vector3(150,145,170),p+Vector3(-70,0,-150)],
		[Afghan.point(farm.gate.x+8.,farm.gate.y+12.)+Vector3.UP*1.8,p+Vector3(0,1,-20)],
		[p+Vector3(-80,45,-45),p+Vector3(30,0,35)]]
	camera.position=views[index][0];camera.look_at(views[index][1])
