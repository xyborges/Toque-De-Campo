@tool
extends RefCounted
class_name WarRoads
const ROUTES:=[
	[Vector2(-1160,100),Vector2(-980,100),Vector2(-800,70),Vector2(-560,0)],
	[Vector2(1160,-100),Vector2(980,-100),Vector2(800,-70),Vector2(560,0)],
	[Vector2(-560,0),Vector2(-680,-130),Vector2(-790,-310),Vector2(-755,-420),Vector2(-780,-490),Vector2(-820,-490)],
	[Vector2(560,0),Vector2(730,170),Vector2(850,340),Vector2(887,340),Vector2(887,435),Vector2(975,435),Vector2(1070,450),Vector2(1110,470),Vector2(1190,470)],
	[Vector2(-560,0),Vector2(-700,240),Vector2(-698,470),Vector2(-698,610),Vector2(-610,610)],
	[Vector2(560,0),Vector2(720,-230),Vector2(698,-440),Vector2(698,-610),Vector2(610,-610)],
	[Vector2(-710,-360),Vector2(-720,-610),Vector2(-568,-610),Vector2(-568,-790),Vector2(-480,-790)],
	[Vector2(795,615),Vector2(707,615),Vector2(707,800),Vector2(600,800)]]
const CENTRES:=[Vector2(-625,-430),Vector2(975,435),Vector2(-465,-480),Vector2(-625,-610),Vector2(-435,-630),Vector2(-330,-410),Vector2(800,435),Vector2(975,610),Vector2(795,615),Vector2(880,775),Vector2(-610,610),Vector2(610,-610),Vector2(-480,-790),Vector2(600,800)]
static var segments: Array[Dictionary]=[]
const INDEX_CELL:=128.0
static var cells: Dictionary={}
static func prepare() -> void:
	if not segments.is_empty(): return
	for route_index in ROUTES.size():
		var route: Array=ROUTES[route_index]
		var path:=rounded(route)
		var total:=0.;var travelled:=0.
		for i in path.size()-1: total+=path[i].distance_to(path[i+1])
		for i in path.size()-1:
			var span:=path[i].distance_to(path[i+1])
			var entry: Dictionary={"a":path[i],"b":path[i+1],"width":12. if route_index in [2,3] else 9.,"dirt":absf(Vector2(path[i]).y)>600 or absf(Vector2(path[i+1]).y)>600}
			if route_index in [2,3]:
				var start:=WarTerrain._landform(path[0].x,path[0].y)-.08
				entry.port_profile=Vector2(lerpf(start,3.65,smoothstep(0,total,travelled)),lerpf(start,3.65,smoothstep(0,total,travelled+span)))
			segments.append(entry);travelled+=span
	for index in range(2,WarUrbanLayout.CENTRES.size()):
		var p: Vector2=WarUrbanLayout.CENTRES[index];var nearest: Vector2=WarUrbanLayout.CENTRES[0];var best:=INF
		for before in index:
			var candidate: Vector2=WarUrbanLayout.CENTRES[before]
			if p.distance_squared_to(candidate)<best: nearest=candidate;best=p.distance_squared_to(candidate)
		var route: Array[Vector2]=[];var route_score:=INF
		# Choose a service avenue around all existing lots, not a straight
		# shortcut through a third neighbourhood's houses.
		for avenue in [(p.x+nearest.x)*.5,minf(p.x,nearest.x)-88,maxf(p.x,nearest.x)+88]:
			var candidate: Array[Vector2]=[p,Vector2(avenue,p.y),Vector2(avenue,nearest.y),nearest]
			var score:=0.
			for part in candidate.size()-1:
				score+=candidate[part].distance_to(candidate[part+1])
				for centre: Vector2 in WarUrbanLayout.CENTRES:
					for block in 6:
						var lot:=centre+Vector2((block%3)*42-42,(block/3)*58-29)
						if crosses_lot(candidate[part],candidate[part+1],lot): score+=10000
			if score<route_score: route_score=score;route=candidate
		for segment in route.size()-1: segments.append({"a":route[segment],"b":route[segment+1],"width":10.})
	for centre: Vector2 in CENTRES:
		segments.append({"a":centre+Vector2(-90,0),"b":centre+Vector2(90,0),"width":11.})
		for sign_value in [-1.,1.]:
			var a:=centre+Vector2(sign_value*88,-58);var b:=centre+Vector2(sign_value*88,58)
			var clear:=true
			for quarter: Vector2 in WarUrbanLayout.CENTRES:
				for block in 6:
					if crosses_lot(a,b,quarter+Vector2((block%3)*42-42,(block/3)*58-29)): clear=false
			if clear: segments.append({"a":a,"b":b,"width":7.})
	# Terrain generation samples hundreds of thousands of points. Keep road
	# ordering, but inspect only segments whose padded bounds cover this cell.
	for segment in segments:
		var a: Vector2=segment.a;var b: Vector2=segment.b
		var padding:=maxf(12.,float(segment.width)*.5+5.)
		if segment.has("port_profile"): padding=64.
		var low:=Vector2i(floori((minf(a.x,b.x)-padding)/INDEX_CELL),floori((minf(a.y,b.y)-padding)/INDEX_CELL))
		var high:=Vector2i(floori((maxf(a.x,b.x)+padding)/INDEX_CELL),floori((maxf(a.y,b.y)+padding)/INDEX_CELL))
		for z in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var key:=Vector2i(x,z)
				if not cells.has(key): cells[key]=[]
				cells[key].append(segment)
static func crosses_lot(a: Vector2,b: Vector2,lot: Vector2) -> bool:
	return maxf(a.x,b.x)>lot.x-16 and minf(a.x,b.x)<lot.x+16 and maxf(a.y,b.y)>lot.y-14 and minf(a.y,b.y)<lot.y+14

static func rounded(route: Array) -> Array[Vector2]:
	var result: Array[Vector2]=[route[0]]
	for i in range(1,route.size()-1):
		var p: Vector2=route[i]
		var radius:=minf(70.,minf(p.distance_to(route[i-1]),p.distance_to(route[i+1]))*.42)
		var a:=p+(Vector2(route[i-1])-p).normalized()*radius
		var b:=p+(Vector2(route[i+1])-p).normalized()*radius
		result.append(a)
		for step in range(1,5):
			var t:=step/4.;result.append(a.lerp(p,t).lerp(p.lerp(b,t),t))
	result.append(route[-1]);return result

static func port_grade(x: float,z: float,height: float) -> float:
	prepare();var p:=Vector2(x,z);var best:=64.;var goal:=height
	for segment in cells.get(Vector2i(floori(x/INDEX_CELL),floori(z/INDEX_CELL)),[]):
		if not segment.has("port_profile"): continue
		var a: Vector2=segment.a;var b: Vector2=segment.b
		var nearest:=Geometry2D.get_closest_point_to_segment(p,a,b)
		var d:=p.distance_to(nearest)
		if d>=best: continue
		var t:=clampf((nearest-a).dot(b-a)/(b-a).length_squared(),0,1)
		best=d;goal=lerpf(segment.port_profile.x,segment.port_profile.y,t)
	if best<64.: height=lerpf(height,goal,1-smoothstep(6.,64.,best))
	return height
static func distance(point: Vector2) -> float:
	prepare();var result:=INF
	for segment in cells.get(Vector2i(floori(point.x/INDEX_CELL),floori(point.y/INDEX_CELL)),[]):
		var a: Vector2=segment.a;var b: Vector2=segment.b
		if point.x<minf(a.x,b.x)-12 or point.x>maxf(a.x,b.x)+12 or point.y<minf(a.y,b.y)-12 or point.y>maxf(a.y,b.y)+12: continue
		result=minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
	return result

static func roadside(point: Vector2,clearance:=11.0) -> Vector2:
	# Generated fixtures belong on the verge, including where two roads meet.
	# Move the complete fixture before creating its visual and collision nodes.
	prepare()
	var result:=point
	for iteration in 4:
		var moved:=false
		for segment in cells.get(Vector2i(floori(result.x/INDEX_CELL),floori(result.y/INDEX_CELL)),[]):
			var nearest:=Geometry2D.get_closest_point_to_segment(result,segment.a,segment.b)
			var offset:=result-nearest
			var margin:=maxf(clearance,float(segment.width)*.5+3.)
			if offset.length()>=margin: continue
			if offset.length_squared()<.001:
				var direction: Vector2=(segment.b-segment.a).normalized()
				offset=Vector2(-direction.y,direction.x)
			result=nearest+offset.normalized()*margin;moved=true
		if not moved: break
	if _verge_clear(result,clearance): return result
	# At converging avenues, alternating projection alone can oscillate
	# between the two carriageways. Search outside their union instead.
	for radius in [12.,20.,30.,42.,56.]:
		for index in 24:
			var candidate: Vector2=point+Vector2.from_angle(index*TAU/24.)*float(radius)
			if _verge_clear(candidate,clearance): return candidate
	return result

static func _verge_clear(point: Vector2,clearance: float) -> bool:
	for segment in cells.get(Vector2i(floori(point.x/INDEX_CELL),floori(point.y/INDEX_CELL)),[]):
		var nearest:=Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)
		if point.distance_to(nearest)<maxf(clearance,float(segment.width)*.5+3.)-.01: return false
	for centre: Vector2 in WarUrbanLayout.CENTRES:
		if absf(point.x-centre.x)>74 or absf(point.y-centre.y)>48: continue
		for block in 6:
			var lot:=centre+Vector2((block%3)*42-42,(block/3)*58-29)
			if absf(point.x-lot.x)<15 and absf(point.y-lot.y)<13: return false
	return true
static func foot_surface(point: Vector2,wet: bool) -> String:
	prepare()
	for segment in cells.get(Vector2i(floori(point.x/INDEX_CELL),floori(point.y/INDEX_CELL)),[]):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b))<=float(segment.width)*.5:
			return ("mud" if wet else "dirt") if segment.get("dirt",false) else "asphalt"
	return ""
static func grade(x: float,z: float,height: float) -> float:
	prepare();var p:=Vector2(x,z)
	for segment in cells.get(Vector2i(floori(x/INDEX_CELL),floori(z/INDEX_CELL)),[]):
		var a: Vector2=segment.a;var b: Vector2=segment.b
		var width:=float(segment.width)*.5
		if x<minf(a.x,b.x)-width-5 or x>maxf(a.x,b.x)+width+5 or z<minf(a.y,b.y)-width-5 or z>maxf(a.y,b.y)+width+5: continue
		var nearest:=Geometry2D.get_closest_point_to_segment(p,a,b);var d:=p.distance_to(nearest)
		if d<width+4: height=lerpf(height,WarTerrain._landform(nearest.x,nearest.y)-.08,1-smoothstep(width,width+4,d))
	return height
static func build(k: EnvironmentKit) -> void:
	prepare()
	for segment in segments:
		var start: Vector2=segment.a;var end: Vector2=segment.b
		for span in WarTerrainEdits.remaining_road(start,end):
			draw_segment(k,start.lerp(end,span.x),start.lerp(end,span.y),float(segment.width),bool(segment.get("dirt",false)))
	for centre: Vector2 in CENTRES:
		for side in [-1.,1.]:
			for index in 34:
				var p:=WarTerrain.point(centre.x-84+index*5,centre.y+side*6.1)
				if WarTerrainEdits.replaces_road(Vector2(p.x,p.z)): continue
				if index%9 in [3,4]: continue
				k.box("BrokenCurb",p+Vector3.UP*.1,Vector3(4.7,.2,.28),"concrete:8d8f84",false)
	k.root.set_meta("war_road_links",ROUTES.size());k.root.set_meta("war_street_blocks",CENTRES.size())

static func draw_segment(k: EnvironmentKit,a: Vector2,b: Vector2,width: float,dirt: bool) -> void:
	if not k.visuals: return # Walking/projectile contact is already the terrain.
	var direction: Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*width*.5
	var count:=maxi(1,ceili(a.distance_to(b)/2.));var lanes:=maxi(1,ceili(width/2.))
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in count:
		var from:=a.lerp(b,float(index)/count);var to:=a.lerp(b,float(index+1)/count)
		# Sampling only both shoulders made a wide straight chord float above
		# the real terrain between them, especially beside graded foundations.
		for lane in lanes:
			var left:=side*(float(lane)/lanes*2.-1.);var right:=side*(float(lane+1)/lanes*2.-1.)
			var corners: Array[Vector2]=[from+left,from+right,to+right,to+left]
			var points: Array[Vector3]=[]
			for p in corners: points.append(WarTerrain.point(p.x,p.y)+Vector3.UP*.035)
			var normal: Vector3=(points[1]-points[0]).cross(points[3]-points[0]).normalized()
			for vertex in [0,2,1,0,3,2]: surface.set_normal(normal);surface.set_uv(corners[vertex]*.2);surface.add_vertex(points[vertex])
	if k.visuals:
		surface.index()
		var node:=MeshInstance3D.new();node.name="DamagedRoad";node.mesh=surface.commit();node.material_override=EnvironmentKit.material("sand:77715f" if bool(dirt) else "asphalt:6c6e67");node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;k.root.add_child(node)
