extends SceneTree
# Diagnostico e regressao: terreno real do mapa Afegao, sem carregar a cena.
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
var problems: Array[String]=[]
func verify(condition: bool,message: String) -> void:
	if not condition: problems.append(message)
func _initialize() -> void:
	var probes: Array[Vector2]=[
		Vector2(380,-880),Vector2(-420,900),
		Vector2(-120,-700),Vector2(-150,-740),Vector2(250,-650),
		Vector2(220,-600),Vector2(0,-620),Vector2(-340,-600),
		Vector2(-800,275),Vector2(-835,200),Vector2(-800,180),
		Vector2(-750,340),Vector2(-700,460),Vector2(-630,430),
		Vector2(-780,100),Vector2(-360,760),Vector2(-250,840),
		Vector2(-450,-650),Vector2(-300,-680),Vector2(-250,-720),
		Vector2(-330,-710),Vector2(-180,-690),Vector2(-40,-690),
		Vector2(50,-680),Vector2(110,-680),Vector2(330,-650),
		Vector2(-810,170),Vector2(-800,200),Vector2(-775,120),
		Vector2(-790,130),Vector2(-755,125),Vector2(-770,80),
		Vector2(-390,-690),Vector2(-400,-700),Vector2(-390,-715),
		Vector2(-365,-730),Vector2(-342,-732),Vector2(-360,-736),
		Vector2(-335,-712),Vector2(-350,-710),Vector2(-375,-735),
		Vector2(-775,105),Vector2(-785,128),Vector2(-805,170),
		Vector2(-785,180),Vector2(-795,225),Vector2(-835,160),
		Vector2(-415,875),Vector2(-430,880),Vector2(-405,860),
		Vector2(-435,855),Vector2(-390,865),Vector2(-450,870),
		Vector2(-420,920),Vector2(-400,915),Vector2(-455,890),
		Vector2(245,-655),Vector2(250,-670),Vector2(270,-650),
		Vector2(220,-655),Vector2(225,-675),Vector2(265,-675),
		Vector2(275,-630),Vector2(285,-645),Vector2(240,-640),
		Vector2(-385,900),Vector2(-410,905),Vector2(-435,895),
		Vector2(433,-831),Vector2(440,-820),Vector2(362,-891)
	]
	var roads: Array=LAND.roads()
	for p: Vector2 in probes:
		var height: float=LAND.rawheight(p.x,p.y)
		var max_delta:=0.
		for dx in [-10.,0.,10.]:
			for dz in [-10.,0.,10.]:
				max_delta=maxf(max_delta,absf(height-LAND.rawheight(p.x+dx,p.y+dz)))
		var near:=INF;var kind:=""
		for road: Dictionary in roads:
			if str(road.kind)=="village":continue
			var points: Array=road.points
			for index in range(0,points.size(),3):
				var q: Vector3=points[index]
				var d: float=p.distance_to(Vector2(q.x,q.z))
				if d<near:near=d;kind=str(road.kind)
		print("TERRAIN p=%s h=%.1f max10=%.1f road=%.1f kind=%s"%[p,height,max_delta,near,kind])
	# Original locations are swapped exactly; Ukraine is untouched.
	var bases:=WarOperation.bases(WarOperation.AFGHAN)
	verify(bases[0]==Vector3(-420,0,900),"USA original low-base position")
	verify(bases[1]==Vector3(380,0,-880),"Mujahideen original mountain-base position")
	var ukraine:=WarOperation.bases(WarOperation.UKRAINE)
	verify(ukraine[0]==Vector3(-1160,18,100),"Ukraine original base unchanged")
	var military: Array[Dictionary]=[]
	for road: Dictionary in roads:
		if str(road.get("kind",""))=="military":military.append(road)
	verify(military.size()==2,"Two authored military supply roads")
	WarRules.configure(WarOperation.AFGHAN)
	WarTerrain.configure(WarOperation.AFGHAN)
	for base_index in bases.size():
		var nearest:=INF
		for road: Dictionary in military:
			for position: Vector3 in road.points:
				nearest=minf(nearest,Vector2(position.x,position.z).distance_to(Vector2(bases[base_index].x,bases[base_index].z)))
		verify(nearest<10.,"Each base connects directly to a graded supply road")
	var transit:=WarBotTransit.new()
	var start:=WarTerrain.point(390,-872)
	var destination:=WarTerrain.point(450,-510)
	var route: Array[Vector3]=transit.path(start,destination,true)
	verify(route.size()>10,"Vehicle path from mountain to southern road is connected")
	var max_grade:=0.
	for index in range(1,route.size()):
		var a:=route[index-1]
		var b:=route[index]
		var horizontal:=Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
		if horizontal>1.:max_grade=maxf(max_grade,absf(b.y-a.y)/horizontal)
	print("AFGHAN_VEHICLE_ROUTE nodes=",route.size()," grade=",max_grade)
	verify(max_grade<.46,"Vehicle route has no near-vertical shortcuts")
	verify(not route.is_empty() and start.distance_to(route[0])<20.,"Mountain bay joins the road without a cross-country hop")
	var car:=WarVehicle.new()
	car.kind="guarani"
	verify(car.allocate_seat(201)==0,"Bot occupies driver seat")
	var old_revision:=car.seats_revision
	var old_epoch:=car.control_epoch
	verify(car.hand_over_driver(5,201),"Human takes bot driver's seat")
	verify(car.driver==5 and car.seat_of(5)==0 and car.seat_of(201)>0,"Bot moves to passenger seat")
	verify(car.seats_revision==old_revision+1 and car.control_epoch==old_epoch+1,"Driver swap increments occupancy ordering")
	verify(not car.hand_over_driver(6,201),"Human cannot displace human driver")
	verify(car.driver==5,"Rejected handover keeps current driver")
	car.free()
	var bike:=WarVehicle.new()
	bike.kind="bike_0"
	verify(bike.allocate_seat(201)==0 and not bike.hand_over_driver(5,201),"One-seat vehicles require server-validated bot exit")
	bike.free()
	if problems.is_empty():
		print("AFGHAN_SPAWN_AI_PASS bases, roads, route and pilot seats")
		quit(0)
	else:
		for problem in problems:push_error("AFGHAN_SPAWN_AI_FAIL: "+problem)
		quit(1)
