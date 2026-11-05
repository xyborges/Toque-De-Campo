extends RefCounted
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")

static func populate(map: Node3D,scenery: Dictionary,plants: Dictionary,details: Dictionary,detail: Callable) -> void:
	var count: Dictionary={"rural_remnants":0,"work_corners":0,"canal_trees":0,"gardens":0,"groves":0}
	_canal_growth(map,plants,details,detail,count)
	_gardens(map,scenery,plants,details,detail,count)
	_village_groves(map,plants,details,detail,count)
	_property_details(map,scenery,details,detail,count)
	_road_edges(map,scenery,plants,details,detail,count)
	_field_divisions(map,scenery,details,detail)
	map.set_meta("afghan_context",count)

static func clear(p: Vector3,road_margin:=5.,house_margin:=3.,owner: Dictionary={}) -> bool:
	if absf(p.x)>975. or absf(p.z)>975.:return false
	var road:=LAND._near_road(Vector2(p.x,p.z))
	if float(road.distance)<float(road.width)*.5+road_margin:return false
	for house: Dictionary in LAND.building_layout():
		if house==owner:continue
		if Vector2(p.x-house.position.x,p.z-house.position.z).length()<house.radius+house_margin:return false
	return true

static func gradient(map: Node3D,p: Vector3) -> Vector2:
	return Vector2(map.height_at(p.x+3.,p.z)-map.height_at(p.x-3.,p.z),map.height_at(p.x,p.z+3.)-map.height_at(p.x,p.z-3.))/6.

static func on_ground(map: Node3D,p: Vector3,yaw: float) -> Transform3D:
	p.y=map.height_at(p.x,p.z)
	var slope:=gradient(map,p);var up:=Vector3(-slope.x,1.,-slope.y).normalized()
	var forward:=Vector3(sin(yaw),0,cos(yaw));var right:=up.cross(forward).normalized()
	return Transform3D(Basis(right,up,right.cross(up)),p)

static func _canal_growth(map: Node3D,plants: Dictionary,details: Dictionary,detail: Callable,count: Dictionary) -> void:
	for channel: Dictionary in LAND.irrigation_layout():
		var a: Vector2=channel.a;var b: Vector2=channel.b
		var direction: Vector2=(b-a).normalized();var across:=direction.orthogonal()
		var steps:=mini(7,maxi(2,floori(a.distance_to(b)/17.)))
		for i in range(1,steps):
			var q:=a.lerp(b,float(i)/steps)+across*(3.5 if i%2==0 else -3.5)
			var p: Vector3=map.point(q.x,q.y)
			if not clear(p,4.,2.) or LAND.in_farmland(q,1.):continue
			var scale:=.46+float((i+int(channel.parcel))%6)*.12
			map.add_piece("willow_v7" if i%3==0 else "poplar_v7",Transform3D(Basis(Vector3.UP,i*.73).scaled(Vector3.ONE*scale),p),plants)
			count.canal_trees+=1
			for j in 3:
				var t:=p+Vector3(across.x,0,across.y)*(j-1)*2.7;t.y=map.height_at(t.x,t.z)
				if clear(t,2.,1.):map.add_piece("garden_shrub_v7",Transform3D(Basis(Vector3.UP,j*.8).scaled(Vector3.ONE*.7),t),plants)
				if map.render_visuals:detail.call(details,"dry_scrub_patch_v8",Transform3D(Basis(Vector3.UP,j).scaled(Vector3.ONE*.6),t),Color(.65,.75,.51))
				if map.render_visuals:detail.call(details,"wild_margin_v9",on_ground(map,t,j*.8).scaled_local(Vector3.ONE*(.65+.1*j)),Color(.72,.85,.58))

static func _gardens(map: Node3D,scenery: Dictionary,plants: Dictionary,details: Dictionary,detail: Callable,count: Dictionary) -> void:
	for garden: Dictionary in LAND.garden_layout():
		var house: Dictionary=LAND.building_layout()[int(garden.house)]
		var basis:=Basis(Vector3.UP,garden.yaw);var polygon: PackedVector2Array=garden.outline
		# Back and side walls only; the approach towards the house stays open.
		for edge in [0,1,3]:
			var a:=polygon[edge];var b:=polygon[(edge+1)%polygon.size()]
			var segments:=maxi(1,ceili(a.distance_to(b)/5.5));var span:=a.distance_to(b)/segments
			var direction: Vector2=(b-a).normalized();var yaw:=atan2(-direction.y,direction.x)
			for i in segments:
				var q:=a.lerp(b,(i+.5)/segments);var p: Vector3=map.point(q.x,q.y)
				if not clear(p,3.,2.,house):continue
				var end_a: Vector2=a.lerp(b,float(i)/segments);var end_b: Vector2=a.lerp(b,float(i+1)/segments)
				var low: float=minf(map.height_at(end_a.x,end_a.y),map.height_at(end_b.x,end_b.y))
				p.y=low-.12
				var height:=maxf(.65,(map.height_at(q.x,q.y)-low)+.65)
				map.add_piece("courtyard_wall_v2",Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(span/6.,height/2.1,.9)),p),scenery)
		for x in [-1,1]:
			for z in [-1,1]:
				var p: Vector3=garden.position+basis*Vector3(x*garden.size.x*.32,0,z*garden.size.y*.32);p.y=map.height_at(p.x,p.z)
				if garden.crop=="orchard" and clear(p,3.,2.,house):
					var scale:=.45+float((int(garden.house)+x+z+3)%4)*.09
					map.add_piece("willow_v7",Transform3D(Basis(Vector3.UP,garden.house*.7+x).scaled(Vector3.ONE*scale),p),plants)
				elif map.render_visuals:detail.call(details,"field_furrows_v8",on_ground(map,p,garden.yaw).scaled_local(Vector3(.7,1.,.7)),Color(.66,.74,.50))
		for i in 8:
			var p: Vector3=garden.position+basis*Vector3(sin(i*2.4)*garden.size.x*.38,0,cos(i*2.4)*garden.size.y*.38);p.y=map.height_at(p.x,p.z)
			if not clear(p,2.,1.,house):continue
			if i%3==0:map.add_piece("garden_shrub_v7",Transform3D(Basis(Vector3.UP,i).scaled(Vector3.ONE*(.6+.12*(i%3))),p),plants,Color(.91,1.,.86))
			if map.render_visuals:detail.call(details,"wild_margin_v9",on_ground(map,p,i*.8).scaled_local(Vector3.ONE*.65),Color(.77,.86,.61))
		count.gardens+=1

static func _property_details(map: Node3D,scenery: Dictionary,details: Dictionary,detail: Callable,count: Dictionary) -> void:
	for i in LAND.building_layout().size():
		var house: Dictionary=LAND.building_layout()[i];var basis:=Basis(Vector3.UP,house.yaw)
		var distance:=17. if int(house.variant)==3 else 10.8
		var p: Vector3=house.position+basis*Vector3(float(house.garden_side)*distance,0,-9.)
		p.y=map.height_at(p.x,p.z)
		if i%2==0 and clear(p,2.,2.,house):
			map.add_piece("farm_work_corner_v8",Transform3D(basis,p),scenery);count.work_corners+=1
		for j in 5:
			var q: Vector3=house.position+basis*Vector3(((-1 if j%2==0 else 1)*(12.+j)),0,-14.+j*2.5)
			q.y=map.height_at(q.x,q.z)
			if not clear(q,2.,1.,house):continue
			if map.render_visuals:
				detail.call(details,"dry_scrub_patch_v8",Transform3D(Basis(Vector3.UP,i*.7+j).scaled(Vector3.ONE*(.5+.08*(j%3))),q),Color(.83,.87,.64))
				if j%2==0:detail.call(details,"talus_fan_v8",on_ground(map,q,house.yaw).scaled_local(Vector3.ONE*.25),Color(.81,.77,.67))

static func _village_groves(map: Node3D,plants: Dictionary,details: Dictionary,detail: Callable,count: Dictionary) -> void:
	for centre: Vector2 in LAND.grove_layout():
		for i in 19:
			var radius:=sqrt(float(i)/19.)*19.
			var q:=centre+Vector2(cos(i*2.39996),sin(i*2.39996))*radius
			var p: Vector3=map.point(q.x,q.y)
			if not clear(p,5.,6.) or LAND.in_farmland(q,3.):continue
			var scale:=.48+float((i*7)%11)*.065
			map.add_piece("willow_v7" if i%3!=0 else "poplar_v7",Transform3D(Basis(Vector3.UP,i*.87).scaled(Vector3.ONE*scale),p),plants,Color(.91,1.,.85))
			var small:=p+Vector3(cos(i*1.1)*2.,0,sin(i*1.1)*2.);small.y=map.height_at(small.x,small.z)
			if i%2==0:map.add_piece("garden_shrub_v7",Transform3D(Basis(Vector3.UP,i*.7).scaled(Vector3.ONE*.8),small),plants)
			if map.render_visuals:detail.call(details,"wild_margin_v9",on_ground(map,p,i).scaled_local(Vector3.ONE*.9),Color(.74,.85,.57))
		count.groves+=1

static func _road_edges(map: Node3D,scenery: Dictionary,plants: Dictionary,details: Dictionary,detail: Callable,count: Dictionary) -> void:
	for road: Dictionary in LAND.roads():
		if road.kind not in ["main","secondary","village","mountain"]:continue
		for i in range(3,road.points.size()-2,5):
			var p: Vector3=road.points[i]
			var tangent: Vector3=(road.points[i+1]-road.points[i-1]).normalized();var across:=tangent.cross(Vector3.UP)
			for sign_value: int in [-1,1]:
				var q: Vector3=p+across*sign_value*(float(road.width)*.5+1.8);q.y=map.height_at(q.x,q.z)
				if not clear(q,.5,2.) or LAND.in_farmland(Vector2(q.x,q.z),1.):continue
				if map.render_visuals:
					if road.kind!="mountain" and gradient(map,q).length()<.25:detail.call(details,"talus_fan_v8",on_ground(map,q,i*.77).scaled_local(Vector3.ONE*.28),Color(.93,.88,.78))
					if i%2==0:detail.call(details,"dry_scrub_patch_v8",Transform3D(Basis(Vector3.UP,i*.7).scaled(Vector3.ONE*.7),q),Color(.89,.87,.67))
					if i%3!=0:detail.call(details,"wild_margin_v9",on_ground(map,q+across*sign_value*1.2,i*.6).scaled_local(Vector3.ONE*.85),Color(.82,.88,.68))
			# A small abandoned enclosure occupies a usable roadside patch;
			# it is a coherent set, with the approach kept open towards the lane.
			if road.kind!="secondary" or i%20!=3 or count.rural_remnants>=12:continue
			var base:=p+across*23.;base.y=map.height_at(base.x,base.z)
			if not clear(base,12.,55.) or LAND.in_farmland(Vector2(base.x,base.z),15.) or gradient(map,base).length()>.4:continue
			var yaw:=atan2(tangent.x,tangent.z);var basis:=Basis(Vector3.UP,yaw)
			for offset: Vector3 in [Vector3(-4.,0,-3.),Vector3(3.,0,-3.)]:
				var q:=base+basis*offset;q.y=map.height_at(q.x,q.z)
				map.add_piece("collapsed_farm_wall_v8",Transform3D(basis,q),scenery)
			map.add_piece("farm_work_corner_v8",Transform3D(basis,base),scenery)
			for j in 4:
				var q:=base+basis*Vector3((j-1.5)*3.5,0,-6.);q.y=map.height_at(q.x,q.z)
				map.add_piece("garden_shrub_v7",Transform3D(Basis(Vector3.UP,j).scaled(Vector3.ONE*.8),q),plants)
			count.rural_remnants+=1

static func _field_divisions(map: Node3D,scenery: Dictionary,details: Dictionary,detail: Callable) -> void:
	for farm: Dictionary in LAND.farmland_layout():
		var centre: Vector3=farm.position
		var half: Vector2=farm.size*.5
		# Low physical boundary marks, kept clear of gates and access lanes.
		for side in [-1,1]:
			var p: Vector3=map.point(centre.x+side*half.x*.72,centre.z-half.y*.88)
			if clear(p,3.,4.):map.add_piece("collapsed_farm_wall_v8",Transform3D(Basis(Vector3.UP,.06*int(farm.parcel)),p),scenery)
		if not map.render_visuals:continue
		for x in range(-2,3):
			for z in range(-3,4):
				var p: Vector3=map.point(centre.x+x*9.,centre.z+z*9.)
				if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),farm.outline):continue
				var transform:=on_ground(map,p,0.)
				detail.call(details,"field_furrows_v8",transform,Color(.79,.78,.60) if farm.crop=="wheat" else Color(.67,.72,.53))

