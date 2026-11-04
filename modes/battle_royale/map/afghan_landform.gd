extends RefCounted
class_name BRAfghanLandform
## Deterministic map data, independent of WarTerrain and its caches.
## Heights are metres, Y-up; x/z bounds of the playable valley are +/-1000.
const SEED:=712907
const CENTRES:=[Vector2(-340,570),Vector2(450,-510),Vector2(-450,-380),Vector2(-260,70),Vector2(-720,440),Vector2(700,350),Vector2(610,-80),Vector2(-120,-700),Vector2(-650,-760),Vector2(-70,355),Vector2(280,-240),Vector2(645,160),Vector2(-780,100),Vector2(-210,-165),Vector2(510,570)]
const COUNTS:=[28,12,12,12,4,4,4,4,4,8,8,8,8,8,8]
static var _ridge: FastNoiseLite
static var _erosion: FastNoiseLite
static var _detail: FastNoiseLite
static var _buildings: Array[Dictionary]=[]
static var _farms: Array[Dictionary]=[]
static var _gardens: Array[Dictionary]=[]
static var _groves: Array[Vector2]=[]
static var _channels: Array[Dictionary]=[]
static var _channel_cells: Dictionary={}
static var _paths: Array[Dictionary]=[]
static var _segments: Array[Dictionary]=[]
static var _road_cells: Dictionary={}
static var _earthwork_cells: Dictionary={}
static var _pad_cells: Dictionary={}
static var _farm_cells: Dictionary={}
static var _ready:=false

static func _noise() -> void:
	if _ridge: return
	_ridge=FastNoiseLite.new();_ridge.seed=SEED;_ridge.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency=.0017;_ridge.fractal_type=FastNoiseLite.FRACTAL_FBM;_ridge.fractal_octaves=3;_ridge.fractal_gain=.4
	_erosion=FastNoiseLite.new();_erosion.seed=SEED+97;_erosion.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_erosion.frequency=.006;_erosion.fractal_type=FastNoiseLite.FRACTAL_FBM;_erosion.fractal_octaves=2;_erosion.fractal_gain=.42
	_detail=FastNoiseLite.new();_detail.seed=SEED+711;_detail.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency=.027;_detail.fractal_type=FastNoiseLite.FRACTAL_FBM;_detail.fractal_octaves=2

static func stream_center(z: float) -> float:
	return -565.+48.*sin(z*.0029)+21.*sin(z*.0071+.6)

static func stream_water_height(z: float) -> float:
	# A shallow creek falls 24 m north-to-south. No upstream segments or sea.
	return 25.-z*.012

static func natural_height(x: float,z: float) -> float:
	_noise()
	var broad:=_ridge.get_noise_2d(x,z)
	var crest_variation:=_ridge.get_noise_2d(x*.45+317.,z*.65-191.)
	var west_line:=-920.+95.*sin(z*.0027)+55.*sin(z*.0062+.4)
	var north_line:=-925.+80.*sin(x*.0031)+29.*sin(x*.009)
	var east_line:=930.+66.*sin(z*.0042)+35.*sin(z*.009+1.)
	var west:=exp(-pow((x-west_line)/330.,2.))
	var north:=exp(-pow((z-north_line)/330.,2.))
	var east:=exp(-pow((x-east_line)/340.,2.))
	var southeast:=exp(-pow((z-950.+x*.14)/320.,2.))*smoothstep(-150.,650.,x)
	var mass:=maxf(maxf(west,north),maxf(east,southeast))
	var erosion:=absf(_erosion.get_noise_2d(x*1.25,z*.55))
	# Long mountain spines and dendritic grooves, rather than isolated cones.
	var h:=stream_water_height(z)+8.+broad*18.
	# Long, connected crests: abs(noise)^2.5 used to produce isolated narrow
	# cones. Low-frequency longitudinal variation now shapes broad shoulders.
	var crest:=190.+40.*crest_variation+18.*sin(z*.004+x*.0014)
	h+=mass*crest
	var ravine:=absf(_erosion.get_noise_2d(x*.8+broad*44.,z*1.4+crest_variation*35.))
	h-=mass*(1.-mass)*(1.-smoothstep(.015,.13,ravine))*18.
	h-=mass*pow(1.-clampf(erosion*3.5,0.,1.),2.5)*18.
	h+=_detail.get_noise_2d(x,z)*(.65+mass*1.7)
	# Low knolls and shallow hollows break up the uncultivated foothill floor.
	# Road grading and house pads are applied afterwards in rawheight().
	h+=_erosion.get_noise_2d(x*2.1+157.,z*1.7)*6.5*(1.-mass)
	# A cross-valley dry wadi exposes sediments between the mountain shoulders.
	var dry_line:=110.+67.*sin(x*.0025)+26.*sin(x*.0065)
	var dry:=exp(-pow((z-dry_line)/34.,2.))
	h-=dry*(3.5+mass*4.)
	# Sand is confined to the south-west, outside the rocky/irrigated valleys.
	var sand:=smoothstep(190.,790.,z)*(1.-smoothstep(-900.,-550.,x))
	h+=sand*(2.8*sin(x*.034+z*.009)+1.2*sin(x*.071-z*.016))
	# Bank grading surrounds a narrow wet bed. Fine terrain sampling is needed
	# near this strip (5 m or better) so a 3-6 m creek remains below its banks.
	var creek:=absf(x-stream_center(z))
	# The cultivated alluvial floor extends beyond the banks; a broad smooth
	# shoulder joins it to the mountain foot, rather than isolated flat cuts.
	var rolling:=2.2*sin(x*.013+z*.003)+6.8*_erosion.get_noise_2d(x*.65,z*.65)+_detail.get_noise_2d(x*.8,z*.8)*1.1
	var valley:=stream_water_height(z)+3.+creek*.045+broad*2.+rolling*smoothstep(20.,65.,creek)+_detail.get_noise_2d(x,z)*.3
	h=lerpf(h,valley,1.-smoothstep(75.,380.,creek))
	if creek<39.:
		var water:=stream_water_height(z)
		var bed:=water-.60+minf(creek*creek*.055,3.8)
		h=lerpf(bed,h,smoothstep(10.,39.,creek))
	return h

static func _point(x: float,z: float) -> Vector3:
	return Vector3(x,natural_height(x,z),z)

static func _catmull(a: Vector2,b: Vector2,c: Vector2,d: Vector2,t: float) -> Vector2:
	return .5*((2.*b)+(-a+c)*t+(2.*a-5.*b+4.*c-d)*t*t+(-a+3.*b-3.*c+d)*t*t*t)

static func _make_path(controls: Array,width: float,kind: String) -> void:
	var points: Array[Vector2]=[]
	for i in controls.size()-1:
		var a: Vector2=controls[maxi(0,i-1)];var b: Vector2=controls[i];var c: Vector2=controls[i+1];var d: Vector2=controls[mini(controls.size()-1,i+2)]
		var count:=maxi(2,ceili(b.distance_to(c)/8.))
		for step in count: points.append(_catmull(a,b,c,d,float(step)/count))
	points.append(controls[-1])
	# Insert the actual stream intersection before grading. Merely sampling
	# every 20 m can otherwise miss a narrow bed and produce a bridge cliff.
	var crossings: Array[Vector2]=[]
	for i in points.size()-1:
		var a: Vector2=points[i];var b: Vector2=points[i+1]
		crossings.append(a)
		if (a.x-stream_center(a.y))*(b.x-stream_center(b.y))<0.:
			var lo:=0.;var hi:=1.;var sign_a:=signf(a.x-stream_center(a.y))
			for iteration in 10:
				var middle: Vector2=a.lerp(b,(lo+hi)*.5)
				if signf(middle.x-stream_center(middle.y))==sign_a: lo=(lo+hi)*.5
				else: hi=(lo+hi)*.5
			crossings.append(a.lerp(b,(lo+hi)*.5))
	crossings.append(points[-1]);points=crossings
	var heights: Array[float]=[]
	for p in points: heights.append(_road_height(p.x,p.y,natural_height(p.x,p.y)))
	var anchors: Dictionary={}
	for i in points.size():
		var existing:=_near_road(points[i])
		if float(existing.distance)<float(existing.width)*.5+3.: anchors[i]=float(existing.height)
		if absf(points[i].x-stream_center(points[i].y))<8.: anchors[i]=stream_water_height(points[i].y)+.95
	# Cut/embank the road, with a bounded longitudinal grade. Two passes also
	# smooth a descent; geometry is not simply draped over every rock ridge.
	for pass_index in 3:
		for i in range(1,points.size()):
			var limit:=points[i].distance_to(points[i-1])*.22
			heights[i]=clampf(heights[i],heights[i-1]-limit,heights[i-1]+limit)
		for i in range(points.size()-2,-1,-1):
			var limit:=points[i].distance_to(points[i+1])*.22
			heights[i]=clampf(heights[i],heights[i+1]-limit,heights[i+1]+limit)
	for anchor: int in anchors:
		heights[anchor]=float(anchors[anchor])
		for i in range(anchor-1,-1,-1):
			var limit:=points[i].distance_to(points[i+1])*.22
			heights[i]=clampf(heights[i],heights[i+1]-limit,heights[i+1]+limit)
		for i in range(anchor+1,points.size()):
			var limit:=points[i].distance_to(points[i-1])*.22
			heights[i]=clampf(heights[i],heights[i-1]-limit,heights[i-1]+limit)
	var world: Array[Vector3]=[]
	for i in points.size(): world.append(Vector3(points[i].x,heights[i],points[i].y))
	_paths.append({"points":world,"width":width,"kind":kind})
	for i in points.size()-1:
		_index_road(world[i],world[i+1],width)

static func _index_road(from: Vector3,to: Vector3,width: float) -> void:
	var a:=Vector2(from.x,from.z);var b:=Vector2(to.x,to.z);var delta:=b-a
	var record: Dictionary={"a":a,"b":b,"delta":delta,"length2":delta.length_squared(),"height_a":from.y,"height_b":to.y,"width":width,"min":Vector2(minf(a.x,b.x)-24.,minf(a.y,b.y)-24.),"max":Vector2(maxf(a.x,b.x)+24.,maxf(a.y,b.y)+24.)}
	_segments.append(record)
	var low:=Vector2i(floori(record.min.x/64.),floori(record.min.y/64.));var high:=Vector2i(floori(record.max.x/64.),floori(record.max.y/64.))
	for gx in range(low.x,high.x+1):
		for gz in range(low.y,high.y+1):
			var key:=Vector2i(gx,gz)
			if not _road_cells.has(key): _road_cells[key]=[]
			_road_cells[key].append(record)
	# Store the wider cut/fill footprint separately from route proximity.
	# Route/lots planning keeps the same nearest-road semantics; only the
	# actual terrain receives a shoulder proportional to the vertical cut.
	var middle: Vector3=(from+to)*.5
	var cut:=maxf(absf(natural_height(from.x,from.z)-from.y),maxf(absf(natural_height(to.x,to.z)-to.y),absf(natural_height(middle.x,middle.z)-middle.y)))
	var reach:=minf(230.,maxf(24.,width*.5+8.+cut*2.8))
	var earthwork: Dictionary={"segment":record,"reach":reach}
	for gx in range(floori((minf(a.x,b.x)-reach)/64.),floori((maxf(a.x,b.x)+reach)/64.)+1):
		for gz in range(floori((minf(a.y,b.y)-reach)/64.),floori((maxf(a.y,b.y)+reach)/64.)+1):
			var key:=Vector2i(gx,gz)
			if not _earthwork_cells.has(key):_earthwork_cells[key]=[]
			_earthwork_cells[key].append(earthwork)

static func _earthwork_height(x: float,z: float,native: float) -> float:
	var p:=Vector2(x,z);var strongest:=0.;var sum:=0.;var weights:=0.
	for entry: Dictionary in _earthwork_cells.get(Vector2i(floori(x/64.),floori(z/64.)),[]):
		var segment: Dictionary=entry.segment;var reach: float=entry.reach
		var a: Vector2=segment.a;var b: Vector2=segment.b
		if x<minf(a.x,b.x)-reach or x>maxf(a.x,b.x)+reach or z<minf(a.y,b.y)-reach or z>maxf(a.y,b.y)+reach:continue
		var t:=clampf((p-a).dot(segment.delta)/maxf(.001,float(segment.length2)),0.,1.)
		var distance:=p.distance_to(a+Vector2(segment.delta)*t)
		if distance>=reach:continue
		var influence:=1.-smoothstep(float(segment.width)*.5+2.,reach,distance)
		var weight:=pow(influence,4.)
		var target:=lerpf(float(segment.height_a),float(segment.height_b),t)
		strongest=maxf(strongest,influence);sum+=target*weight;weights+=weight
	return lerpf(native,sum/weights,strongest) if weights>.00001 else native

static func _road_height(x: float,z: float,h: float) -> float:
	var p:=Vector2(x,z);var nearest:=INF;var target:=h;var width:=5.
	var cell:=Vector2i(floori(x/64.),floori(z/64.))
	if not _road_cells.has(cell): return h
	for segment: Dictionary in _road_cells[cell]:
		var lo: Vector2=segment.min;var hi: Vector2=segment.max
		if x<lo.x or x>hi.x or z<lo.y or z>hi.y: continue
		var t:=clampf((p-Vector2(segment.a)).dot(segment.delta)/maxf(.001,float(segment.length2)),0.,1.)
		var distance:=p.distance_to(Vector2(segment.a)+Vector2(segment.delta)*t)
		if distance<nearest:
			nearest=distance;target=lerpf(float(segment.height_a),float(segment.height_b),t);width=float(segment.width)
	if nearest<24.: return lerpf(target,h,smoothstep(width*.5+2.,width*.5+16.,nearest))
	return h

static func _near_road(p: Vector2) -> Dictionary:
	var result: Dictionary={"distance":INF,"point":p,"width":0.,"height":0.}
	var cell:=Vector2i(floori(p.x/64.),floori(p.y/64.))
	if not _road_cells.has(cell): return result
	for segment: Dictionary in _road_cells[cell]:
		var t:=clampf((p-Vector2(segment.a)).dot(segment.delta)/maxf(.001,float(segment.length2)),0.,1.)
		var nearest:=Vector2(segment.a)+Vector2(segment.delta)*t
		var distance:=p.distance_to(nearest)
		if distance<float(result.distance): result={"distance":distance,"point":nearest,"width":segment.width,"height":lerpf(float(segment.height_a),float(segment.height_b),t)}
	return result

static func _setup() -> void:
	if _ready: return
	_ready=true;_noise()
	_make_path([Vector2(-170,940),CENTRES[0],Vector2(-20,340),CENTRES[3],Vector2(310,-230),CENTRES[1],Vector2(250,-650),CENTRES[7],CENTRES[8],Vector2(-860,-910)],8.,"main")
	_make_path([CENTRES[0],Vector2(-430,515),CENTRES[4],Vector2(-780,100),Vector2(-650,-160),CENTRES[2],Vector2(-210,-165),CENTRES[3]],6.,"secondary")
	_make_path([CENTRES[1],Vector2(610,-340),CENTRES[6],Vector2(650,170),CENTRES[5],Vector2(510,570),CENTRES[0]],6.,"secondary")
	# Ascend along the mountain, with engineered grade; a summit is not an
	# isolated pedestal reached by a vertical cut beside a flat village.
	_make_path([CENTRES[4],Vector2(-800,275),Vector2(-865,70),Vector2(-880,-140),Vector2(-785,-305),CENTRES[2]],3.,"mountain")
	_make_path([CENTRES[5],Vector2(825,240),Vector2(900,30),Vector2(850,-210),CENTRES[1]],3.,"mountain")
	# Two engineered military supply roads join the original camps to the
	# primary road network. In particular, the high southern mountain camp
	# needs a graded switchback: the direct line crosses steep ravines.
	# _make_path controls terrain grading and generates the same collision
	# surface for the War and BR maps; no floating visual-only roadway.
	_make_path([Vector2(-420,900),Vector2(-315,900),Vector2(-230,925),Vector2(-170,940)],9.,"military")
	_make_path([Vector2(380,-880),Vector2(420,-845),Vector2(455,-810),Vector2(448,-775),Vector2(410,-740),Vector2(350,-705),Vector2(300,-675),Vector2(250,-650)],9.,"military")
	var rng:=RandomNumberGenerator.new();rng.seed=SEED+43
	for region in CENTRES.size():
		var centre: Vector2=CENTRES[region];var count: int=COUNTS[region]
		var angle:=.17*sin(region*1.7)-.12
		var tangent:=Vector2(cos(angle),sin(angle));var normal:=Vector2(-tangent.y,tangent.x)
		var rows:=ceili(count*.5)
		var local_points: Array[Vector3]=[]
		var local_anchors: Dictionary={}
		var street_steps: int=(rows+1)*4
		for row in street_steps+1:
			var s: float=(float(row)/street_steps-.5)*(rows+1)*22.
			var p:=centre+tangent*s+normal*(10.*sin(s*.020+region*.4))
			local_points.append(Vector3(p.x,_road_height(p.x,p.y,natural_height(p.x,p.y)),p.y))
			var near:=_near_road(p)
			if float(near.distance)<float(near.width)*.5+3.: local_anchors[row]=float(near.height)
		# The local street follows a gentle curve; lots face it with authored
		# variation instead of rows on a rectangular flattened platform.
		for pass_index in 2:
			for i in range(1,local_points.size()):
				var limit:=Vector2(local_points[i].x-local_points[i-1].x,local_points[i].z-local_points[i-1].z).length()*.22
				local_points[i].y=clampf(local_points[i].y,local_points[i-1].y-limit,local_points[i-1].y+limit)
			for i in range(local_points.size()-2,-1,-1):
				var limit:=Vector2(local_points[i].x-local_points[i+1].x,local_points[i].z-local_points[i+1].z).length()*.22
				local_points[i].y=clampf(local_points[i].y,local_points[i+1].y-limit,local_points[i+1].y+limit)
		for anchor: int in local_anchors:
			local_points[anchor].y=float(local_anchors[anchor])
			for i in range(anchor-1,-1,-1):
				var limit:=Vector2(local_points[i].x-local_points[i+1].x,local_points[i].z-local_points[i+1].z).length()*.22
				local_points[i].y=clampf(local_points[i].y,local_points[i+1].y-limit,local_points[i+1].y+limit)
			for i in range(anchor+1,local_points.size()):
				var limit:=Vector2(local_points[i].x-local_points[i-1].x,local_points[i].z-local_points[i-1].z).length()*.22
				local_points[i].y=clampf(local_points[i].y,local_points[i-1].y-limit,local_points[i-1].y+limit)
		_paths.append({"points":local_points,"width":5.0,"kind":"village"})
		for i in local_points.size()-1: _index_road(local_points[i],local_points[i+1],5.)
	# Reserve the entire road network before accepting any lots. Otherwise a
	# later village's street could cut through an earlier fallback house plot.
	_plan_agriculture()
	_plan_courtyard_fields()
	for region in CENTRES.size():
		var centre: Vector2=CENTRES[region];var count: int=COUNTS[region]
		var angle:=.17*sin(region*1.7)-.12
		var tangent:=Vector2(cos(angle),sin(angle));var normal:=Vector2(-tangent.y,tangent.x)
		var rows:=ceili(count*.5)
		for i in count:
			var row:=i/2;var side: int=-1 if i%2==0 else 1
			var s: float=(row-(rows-1)*.5)*22.+rng.randf_range(-2.0,2.0)
			var lane_bend:=10.*sin(s*.020+region*.4)
			var p:=centre+tangent*s+normal*(lane_bend+side*rng.randf_range(19.,25.))
			var variant:=i%5
			var size:=rng.randf_range(.87,1.13)
			var radius: float=(15. if variant==3 else 13.5)*size
			var accepted:=false
			for attempt in 192:
				if attempt>0:
					var theta:=attempt*2.399963+i*1.71+region*.37
					var radial:=30.+sqrt(float(attempt))*13.
					p=centre+Vector2(cos(theta),sin(theta))*radial
				var river_delta:=p.x-stream_center(p.y)
				if absf(river_delta)<radius+24.: p.x=stream_center(p.y)+(1. if river_delta>=0. else -1.)*(radius+24.)
				var road:=_near_road(p)
				var clearance:=radius+float(road.width)*.5+3.
				if float(road.distance)<clearance:
					var away: Vector2=(p-Vector2(road.point)).normalized()
					if away.length_squared()<.5: away=normal*side
					p=Vector2(road.point)+away*clearance
				var final_road:=_near_road(p)
				var blocked:=float(final_road.distance)<radius+float(final_road.width)*.5+2.99 or absf(p.x)>930. or absf(p.y)>930.
				# A collision-free lot is insufficient: a house twenty metres
				# above its doorstep road would require a cliff-like foundation.
				# Reject that location before creating buildings or their pads.
				if not is_finite(float(final_road.distance)):blocked=true
				elif absf(natural_height(p.x,p.y)-float(final_road.height))>maxf(3.,(float(final_road.distance)-10.)*.30):blocked=true
				var support_low:=INF;var support_high:=-INF
				for dx in [-9.,0.,9.]:
					for dz in [-9.,0.,9.]:
						var sample:=natural_height(p.x+dx,p.y+dz);support_low=minf(support_low,sample);support_high=maxf(support_high,sample)
				if support_high-support_low>5.5:blocked=true
				if in_farmland(p,radius+8.):blocked=true
				for other: Dictionary in _buildings:
					if Vector2(other.position.x,other.position.z).distance_to(p)<radius+float(other.radius)+5.: blocked=true;break
				if not blocked:accepted=true;break
			if not accepted:continue
			# Face the actual nearest lane, including fallback lots. The front
			# doorway is +Z in the shared building library.
			var front:=Vector2(_near_road(p).point)-p
			var yaw: float=atan2(front.x,front.y)+rng.randf_range(-.16,.16)
			var approach:=_near_road(p)
			var rise:=maxf(1.5,(float(approach.distance)-12.)*.25)
			var elevation:=snappedf(clampf(natural_height(p.x,p.y),float(approach.height)-rise,float(approach.height)+rise),.25)
			var record: Dictionary={"position":Vector3(p.x,elevation,p.y),"yaw":yaw,"region":region,"ruin":variant==4,"variant":variant,"scale":Vector3(size,1.+.055*sin(i*1.91+region),size),"radius":radius,"tint":Color(1.,rng.randf_range(.91,1.03),rng.randf_range(.86,1.02))}
			record["garden_side"]=-1 if i%2==0 else 1
			_buildings.append(record)
			var low:=Vector2i(floori((p.x-32.)/64.),floori((p.y-32.)/64.));var high:=Vector2i(floori((p.x+32.)/64.),floori((p.y+32.)/64.))
			for gx in range(low.x,high.x+1):
				for gz in range(low.y,high.y+1):
					var key:=Vector2i(gx,gz)
					if not _pad_cells.has(key): _pad_cells[key]=[]
					_pad_cells[key].append(record)
	_plan_property_access()
	_plan_gardens()
	_plan_groves()

static func _plan_groves() -> void:
	for region in CENTRES.size():
		var centre: Vector2=CENTRES[region]
		for side: int in [-1,1]:
			for candidate in 5:
				var angle: float=side*(.8+candidate*.55)+region*.23
				var p:=centre+Vector2(cos(angle),sin(angle))*(105.+candidate*9.)
				if absf(p.x)>900. or absf(p.y)>900. or in_farmland(p,22.):continue
				var near:=_near_road(p)
				if float(near.distance)<float(near.width)*.5+23.:continue
				var blocked:=false
				for house: Dictionary in _buildings:
					if p.distance_to(Vector2(house.position.x,house.position.z))<house.radius+23.:blocked=true;break
				for garden: Dictionary in _gardens:
					if p.distance_to(Vector2(garden.position.x,garden.position.z))<maxf(garden.size.x,garden.size.y)*.5+20.:blocked=true;break
				for grove: Vector2 in _groves:
					if p.distance_to(grove)<60.:blocked=true;break
				var slope:=Vector2(rawheight(p.x+4.,p.y)-rawheight(p.x-4.,p.y),rawheight(p.x,p.y+4.)-rawheight(p.x,p.y-4.))/8.
				if blocked or slope.length()>.37:continue
				_groves.append(p);break

static func _plan_gardens() -> void:
	# A garden belongs to a real house, sharing its orientation and access.
	# Its contour follows the existing ground; it never flattens a second pad.
	for index in _buildings.size():
		var house: Dictionary=_buildings[index];var basis:=Basis(Vector3.UP,house.yaw)
		var size:=Vector2(15.+float(index%3)*3.,18.+float(index%4)*2.)
		for offset: Vector3 in [Vector3(float(house.garden_side)*24.,0,-14.),Vector3(-float(house.garden_side)*24.,0,-14.),Vector3(4.,0,-29.)]:
			var centre: Vector3=house.position+basis*offset;var q:=Vector2(centre.x,centre.z)
			if in_farmland(q,maxf(size.x,size.y)*.6):continue
			var blocked:=false
			for other: Dictionary in _buildings:
				if other==house:continue
				if q.distance_to(Vector2(other.position.x,other.position.z))<float(other.radius)+maxf(size.x,size.y)*.55:blocked=true;break
			for other: Dictionary in _gardens:
				if q.distance_to(Vector2(other.position.x,other.position.z))<maxf(size.x,size.y)*.6+maxf(other.size.x,other.size.y)*.6:blocked=true;break
			var half:=size*.5
			var polygon:=PackedVector2Array()
			for local: Vector2 in [Vector2(-half.x+1.,-half.y+2.),Vector2(half.x-2.,-half.y),Vector2(half.x,half.y-2.),Vector2(-half.x+1.,half.y)]:
				var p: Vector3=centre+basis*Vector3(local.x,0,local.y);polygon.append(Vector2(p.x,p.z))
				var road:=_near_road(Vector2(p.x,p.z))
				if float(road.distance)<float(road.width)*.5+3.:blocked=true
			if blocked:continue
			var dx:=(rawheight(q.x+4.,q.y)-rawheight(q.x-4.,q.y))/8.
			var dz:=(rawheight(q.x,q.y+4.)-rawheight(q.x,q.y-4.))/8.
			if Vector2(dx,dz).length()>.32:continue
			centre.y=rawheight(q.x,q.y)
			_gardens.append({"position":centre,"size":size,"yaw":house.yaw,"outline":polygon,"house":index,"crop":"orchard" if index%3==0 else "vegetables"})
			break

static func _plan_property_access() -> void:
	for record: Dictionary in _buildings:
		var p:=Vector2(record.position.x,record.position.z)
		var nearest:=_near_road(p)
		if not is_finite(float(nearest.distance)):
			for road: Dictionary in _paths:
				for point: Vector3 in road.points:
					var d:=p.distance_to(Vector2(point.x,point.z))
					if d<float(nearest.distance):nearest={"distance":d,"point":Vector2(point.x,point.z),"height":point.y,"width":road.width}
		var front:=Vector2(sin(record.yaw),cos(record.yaw))
		var a:=p+front*(12.8*float(record.scale.x));var b: Vector2=nearest.point
		var distance:=a.distance_to(b)
		if distance<2. or distance>100. or absf(record.position.y-float(nearest.height))/distance>.4:continue
		var blocked:=false
		for i in 24:
			var at:=a.lerp(b,float(i)/23.)
			if in_farmland(at,2.):blocked=true
			for other: Dictionary in _buildings:
				if other==record:continue
				if at.distance_to(Vector2(other.position.x,other.position.z))<float(other.radius):blocked=true;break
		if blocked:continue
		var points: Array[Vector3]=[]
		for i in 9:
			var at:=a.lerp(b,float(i)/8.)
			points.append(Vector3(at.x,lerpf(record.position.y,float(nearest.height),float(i)/8.),at.y))
		_paths.append({"points":points,"width":2.1,"kind":"access"})
		for i in points.size()-1:_index_road(points[i],points[i+1],2.1)

static func _plan_agriculture() -> void:
	# Irrigated ribbons are reserved before properties. Adjacent parcels share
	# headlands and a supply ditch; access lanes connect to the road network.
	for row in 8:
		var z: float=-665.+row*178.
		for side: int in [-1,1]:
			for column in 2:
				var size:=Vector2(49.+(row%3)*7.+column*3.,65.+(row%3)*13.+column*5.)
				var x: float=stream_center(z)+side*(51.+column*70.)
				var p:=Vector2(x,z+column*9.)
				var blocked:=false
				for offset: Vector2 in [Vector2.ZERO,Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(-size.x*.5,size.y*.5),size*.5]:
					var road:=_near_road(p+offset)
					if float(road.distance)<float(road.width)*.5+8.:blocked=true
				if blocked:continue
				var position:=Vector3(p.x,natural_height(p.x,p.y),p.y)
				var gate:=Vector2(p.x,p.y+size.y*.5+9.)
				var access: Dictionary={"distance":INF,"point":gate,"height":position.y,"width":0.}
				# Search the whole existing lane graph only during authoring, not
				# per terrain sample. The normal local index is intentionally short.
				for road: Dictionary in _paths:
					for point: Vector3 in road.points:
						if signf(point.x-stream_center(point.z))!=side or absf(point.x-stream_center(point.z))<20.:continue
						var d:=gate.distance_to(Vector2(point.x,point.z))
						if d<float(access.distance):access={"distance":d,"point":Vector2(point.x,point.z),"width":road.width,"height":point.y}
				var direction: Vector2=(Vector2(access.point)-p).normalized()
				var edge:=minf(size.x*.5/maxf(.001,absf(direction.x)),size.y*.5/maxf(.001,absf(direction.y)))
				gate=p+direction*(edge+8.)
				# Connect through uncultivated land; reject any route across a
				# reserved parcel or the stream instead of inventing a ford.
				var controls: Array=[Vector2(access.point),gate]
				for segment in controls.size()-1:
					var a: Vector2=controls[segment];var b: Vector2=controls[segment+1]
					for sample in 24:
						var test:=a.lerp(b,float(sample)/23.)
						if in_farmland(test,6.) or absf(test.x-stream_center(test.y))<15.:blocked=true
				if blocked:continue
				_make_path(controls,3.,"farm")
				var crate:=gate+direction.orthogonal()*4.
				var record: Dictionary={"position":position,"size":size,"yaw":0.,"crop":["wheat","fodder","fallow"][(row+column+(1 if side>0 else 0))%3],"crate":Vector3(crate.x,0,crate.y),"gate":gate,"access":Vector2(access.point),"side":side,"parcel":_farms.size(),"source":"stream"}
				var half:=size*.5
				# The quadrilateral follows a headland and has unequal, gently
				# tapered sides. Reservation stays conservative around its bounds.
				record["outline"]=PackedVector2Array([p+Vector2(-half.x+4.+row%3,-half.y+8.),p+Vector2(half.x-12.,-half.y+2.+column*3.),p+Vector2(half.x-2.,-8.),p+Vector2(half.x-7.,half.y-3.),p+Vector2(-half.x+9.,half.y-1.),p+Vector2(-half.x+1.,12.)])
				_farms.append(record)
				for cx in range(floori((p.x-half.x-18.)/64.),ceili((p.x+half.x+18.)/64.)+1):
					for cz in range(floori((p.y-half.y-18.)/64.),ceili((p.y+half.y+18.)/64.)+1):
						var key:=Vector2i(cx,cz)
						if not _farm_cells.has(key):_farm_cells[key]=[]
						_farm_cells[key].append(record)
				var intake:=Vector2(stream_center(p.y-size.y*.5-35.),p.y-size.y*.5-35.)
				var corner:=Vector2(p.x-side*(size.x*.5+3.),p.y-size.y*.5-3.)
				_channels.append({"a":intake,"b":corner,"c":Vector2(corner.x,p.y+size.y*.5),"parcel":record.parcel})
				for pair in [[intake,corner],[corner,Vector2(corner.x,p.y+size.y*.5)]]:
					var a: Vector2=pair[0];var b: Vector2=pair[1]
					var low:=Vector2i(floori((minf(a.x,b.x)-5.)/64.),floori((minf(a.y,b.y)-5.)/64.))
					var high:=Vector2i(floori((maxf(a.x,b.x)+5.)/64.),floori((maxf(a.y,b.y)+5.)/64.))
					for cx in range(low.x,high.x+1):
						for cz in range(low.y,high.y+1):
							var key:=Vector2i(cx,cz)
							if not _channel_cells.has(key):_channel_cells[key]=[]
							_channel_cells[key].append([a,b])

static func _plan_courtyard_fields() -> void:
	# Smaller cultivated plots surround the village lanes, supplied by local
	# wells. Reserve them before houses; never stamp a field over a property.
	for region in [0,1,2,3,5,6,7]:
		var centre: Vector2=CENTRES[region]
		var angle:=.17*sin(region*1.7)-.12
		var tangent:=Vector2(cos(angle),sin(angle));var across:=tangent.orthogonal()
		for side: int in [-1,1]:
			var size:=Vector2(42.+(region%3)*4.,48.+(region%2)*10.)
			var p:=centre+across*side*86.+tangent*(-35. if side<0 else 35.)
			var blocked:=in_farmland(p,maxf(size.x,size.y)*.65)
			for offset: Vector2 in [Vector2.ZERO,Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(-size.x*.5,size.y*.5),size*.5]:
				var q:=p+offset;var near:=_near_road(q)
				if float(near.distance)<float(near.width)*.5+7. or absf(q.x-stream_center(q.y))<28.:blocked=true
			var slope:=Vector2(natural_height(p.x+8.,p.y)-natural_height(p.x-8.,p.y),natural_height(p.x,p.y+8.)-natural_height(p.x,p.y-8.))/16.
			if blocked or slope.length()>.32:continue
			var access:=_near_road(p)
			if not is_finite(float(access.distance)):
				for road: Dictionary in _paths:
					for point: Vector3 in road.points:
						var distance:=p.distance_to(Vector2(point.x,point.z))
						if distance<float(access.distance):access={"distance":distance,"point":Vector2(point.x,point.z),"height":point.y,"width":road.width}
			if not is_finite(float(access.distance)):continue
			var direction: Vector2=(Vector2(access.point)-p).normalized()
			var edge:=minf(size.x*.5/maxf(.001,absf(direction.x)),size.y*.5/maxf(.001,absf(direction.y)))
			var gate:=p+direction*(edge+8.)
			if absf(natural_height(p.x,p.y)-float(access.height))>maxf(3.,(float(access.distance)-edge)*.28):continue
			for i in 12:
				if in_farmland(gate.lerp(access.point,float(i)/11.),4.):blocked=true;break
			if blocked:continue
			_make_path([Vector2(access.point),gate],2.8,"farm")
			var y: float=_paths[-1].points[-1].y+(gate.y-p.y)*.012;var crate:=gate+direction.orthogonal()*4.
			var half:=size*.5
			var record: Dictionary={"position":Vector3(p.x,y,p.y),"size":size,"yaw":0.,"crop":"fodder" if region%2==0 else "wheat","crate":Vector3(crate.x,0,crate.y),"gate":gate,"access":Vector2(access.point),"side":side,"parcel":_farms.size(),"source":"well"}
			record["outline"]=PackedVector2Array([p+Vector2(-half.x+3.,-half.y+4.),p+Vector2(half.x-7.,-half.y+1.),p+Vector2(half.x-1.,3.),p+Vector2(half.x-5.,half.y-2.),p+Vector2(-half.x+4.,half.y-1.),p+Vector2(-half.x+1.,-2.)])
			_farms.append(record)
			for cx in range(floori((p.x-half.x-18.)/64.),ceili((p.x+half.x+18.)/64.)+1):
				for cz in range(floori((p.y-half.y-18.)/64.),ceili((p.y+half.y+18.)/64.)+1):
					var key:=Vector2i(cx,cz)
					if not _farm_cells.has(key):_farm_cells[key]=[]
					_farm_cells[key].append(record)

static func in_farmland(p: Vector2,margin:=0.) -> bool:
	for farm: Dictionary in _farms:
		if absf(p.x-farm.position.x)<farm.size.x*.5+margin and absf(p.y-farm.position.z)<farm.size.y*.5+margin:return true
	return false

static func channel_distance(p: Vector2) -> float:
	var nearest:=INF
	var cell:=Vector2i(floori(p.x/64.),floori(p.y/64.))
	for pair in _channel_cells.get(cell,[]):
			var a: Vector2=pair[0];var b: Vector2=pair[1];var delta:=b-a
			if absf(p.x-(a.x+b.x)*.5)>absf(delta.x)*.5+5. or absf(p.y-(a.y+b.y)*.5)>absf(delta.y)*.5+5.:continue
			var t:=clampf((p-a).dot(delta)/maxf(.01,delta.length_squared()),0.,1.)
			nearest=minf(nearest,p.distance_to(a+delta*t))
	return nearest

static func rawheight(x: float,z: float) -> float:
	_setup()
	var native:=natural_height(x,z)
	var h:=_road_height(x,z,_earthwork_height(x,z,native))
	# A road crossing does not dam the creek. Its traversable span is a bridge,
	# authored by the map at road_surface_height(), not a plug of solid soil.
	var bank:=absf(x-stream_center(z))
	if bank<12.: h=lerpf(native,h,smoothstep(8.,12.,bank))
	for farm: Dictionary in _farm_cells.get(Vector2i(floori(x/64.),floori(z/64.)),[]):
		var p: Vector3=farm.position;var half: Vector2=farm.size*.5
		var outside:=maxf(absf(x-p.x)-half.x,absf(z-p.z)-half.y)
		if outside<15.:
			var irregular:=.35*_detail.get_noise_2d(x*1.2,z*1.2)+.20*sin((x-p.x)*.075+float(farm.parcel))
			h=lerpf(p.y-(z-p.z)*.012+irregular,h,smoothstep(-2.,15.,outside))
	var ditch:=channel_distance(Vector2(x,z))
	if ditch<4.:h-=.65*(1.-smoothstep(.8,4.,ditch))
	var cell:=Vector2i(floori(x/64.),floori(z/64.))
	# A plot's fully flat core wins over a neighbour's feathered foundation.
	# Sequentially blending every pad used to tilt already flattened floors.
	if _pad_cells.has(cell):
		for record: Dictionary in _pad_cells[cell]:
			var p: Vector3=record.position;var local:=Vector2(x-p.x,z-p.z).rotated(float(record.yaw))
			var pad_x:=10.8 if int(record.variant)==3 else 9.8
			var pad_z:=14.5 if int(record.variant)==3 else 10.0
			var inside:=maxf(absf(local.x)-pad_x*float(record.scale.x),absf(local.y)-pad_z*float(record.scale.z))
			if inside<=.5: return p.y
	if _pad_cells.has(cell):
		for record: Dictionary in _pad_cells[cell]:
			var p: Vector3=record.position
			var delta:=Vector2(x-p.x,z-p.z).rotated(float(record.yaw))
			var pad_x:=10.8 if int(record.variant)==3 else 9.8
			var pad_z:=14.5 if int(record.variant)==3 else 10.0
			var inside:=maxf(absf(delta.x)-pad_x*float(record.scale.x),absf(delta.y)-pad_z*float(record.scale.z))
			if inside<10.: h=lerpf(p.y,h,smoothstep(.5,10.,inside))
	# Feathered plot/farm cuts must never raise an already graded road edge.
	# Full road cores take priority; its shoulders blend into the terraces.
	h=_road_height(x,z,h)
	if bank<12.: h=lerpf(native,h,smoothstep(8.,12.,bank))
	return h

static func road_surface_height(x: float,z: float) -> float:
	_setup();return _road_height(x,z,natural_height(x,z))

static func village_centres() -> Array[Vector3]:
	_setup();var result: Array[Vector3]=[]
	for p: Vector2 in CENTRES: result.append(Vector3(p.x,rawheight(p.x,p.y),p.y))
	return result

static func building_layout() -> Array[Dictionary]: _setup();return _buildings
static func farmland_layout() -> Array[Dictionary]: _setup();return _farms
static func garden_layout() -> Array[Dictionary]: _setup();return _gardens
static func grove_layout() -> Array[Vector2]: _setup();return _groves
static func irrigation_layout() -> Array[Dictionary]: _setup();return _channels
static func agriculture_texture() -> ImageTexture:
	_setup()
	var image:=Image.create(512,512,false,Image.FORMAT_RGBA8);image.fill(Color(0,0,0,0))
	# Moist scrub connects the cultivated corridor to the creek; it does not
	# create a second mesh or erase the user's hand-painted biome map.
	for y in 512:
		var z: float=(y+.5)/.256-1000.;var centre:=stream_center(z)
		for x in range(maxi(0,floori((centre-64.+1000.)*.256)),mini(512,ceili((centre+64.+1000.)*.256))):
			var wx: float=(x+.5)/.256-1000.;var bank:=absf(wx-centre)
			var color:=Color("4c573b")
			color.a=(1.-smoothstep(25.,60.+8.*sin(z*.037),bank))*smoothstep(5.,14.,bank)*.55
			image.set_pixel(x,y,color)
	for channel: Dictionary in _channels:
		for pair in [[channel.a,channel.b],[channel.b,channel.c]]:
			var a: Vector2=pair[0];var b: Vector2=pair[1]
			for y in range(maxi(0,floori((minf(a.y,b.y)-10.+1000.)*.256)),mini(512,ceili((maxf(a.y,b.y)+10.+1000.)*.256))):
				for x in range(maxi(0,floori((minf(a.x,b.x)-10.+1000.)*.256)),mini(512,ceili((maxf(a.x,b.x)+10.+1000.)*.256))):
					var q:=Vector2((x+.5)/.256-1000.,(y+.5)/.256-1000.)
					var distance:=q.distance_to(Geometry2D.get_closest_point_to_segment(q,a,b))
					var color:=Color("4e593c");color.a=(1.-smoothstep(2.,10.,distance))*.5
					if color.a>image.get_pixel(x,y).a:image.set_pixel(x,y,color)
	for farm: Dictionary in _farms:
		var p: Vector3=farm.position;var half: Vector2=farm.size*.5
		var lo:=Vector2i(floori((p.x-half.x+1000.)*.256),floori((p.z-half.y+1000.)*.256))
		var hi:=Vector2i(ceili((p.x+half.x+1000.)*.256),ceili((p.z+half.y+1000.)*.256))
		for y in range(maxi(0,lo.y),mini(512,hi.y)):
			for x in range(maxi(0,lo.x),mini(512,hi.x)):
				var q:=Vector2((x+.5)/.256-1000.,(y+.5)/.256-1000.)
				var polygon: PackedVector2Array=farm.outline
				var edge:=INF
				for i in polygon.size():edge=minf(edge,q.distance_to(Geometry2D.get_closest_point_to_segment(q,polygon[i],polygon[(i+1)%polygon.size()])))
				if not Geometry2D.is_point_in_polygon(q,polygon):edge=-edge
				var color: Color={"wheat":Color("665e3a"),"fodder":Color("3f4d32"),"fallow":Color("665b49")}[farm.crop]
				color.a=smoothstep(-3.,7.,edge)
				if color.a>image.get_pixel(x,y).a:image.set_pixel(x,y,color)
	# Property gardens and worn yards extend the land-use pattern into the
	# villages. This adds pixels, not another node or draw call per property.
	for house: Dictionary in _buildings:
		var p: Vector3=house.position
		for y in range(maxi(0,floori((p.z-25.+1000.)*.256)),mini(512,ceili((p.z+25.+1000.)*.256))):
			for x in range(maxi(0,floori((p.x-25.+1000.)*.256)),mini(512,ceili((p.x+25.+1000.)*.256))):
				var q:=Vector2((x+.5)/.256-1000.-p.x,(y+.5)/.256-1000.-p.z).rotated(house.yaw)
				var yard:=1.-smoothstep(12.,22.,maxf(absf(q.x),absf(q.y)))
				var garden:=1.-smoothstep(4.,13.,q.distance_to(Vector2(float(house.garden_side)*15.,-8.)))
				var color:=Color("625b46").lerp(Color("414f2d"),garden*.9)
				color.a=yard*.28+garden*.7
				var old:=image.get_pixel(x,y)
				if old.a<color.a:image.set_pixel(x,y,color)
	for garden: Dictionary in _gardens:
		var p: Vector3=garden.position;var reach: float=maxf(garden.size.x,garden.size.y)*.75
		for y in range(maxi(0,floori((p.z-reach+1000.)*.256)),mini(512,ceili((p.z+reach+1000.)*.256))):
			for x in range(maxi(0,floori((p.x-reach+1000.)*.256)),mini(512,ceili((p.x+reach+1000.)*.256))):
				var q:=Vector2((x+.5)/.256-1000.,(y+.5)/.256-1000.)
				var edge:=INF;var polygon: PackedVector2Array=garden.outline
				for i in polygon.size():edge=minf(edge,q.distance_to(Geometry2D.get_closest_point_to_segment(q,polygon[i],polygon[(i+1)%polygon.size()])))
				if not Geometry2D.is_point_in_polygon(q,polygon):edge=-edge
				var color:=Color("4f5937") if garden.crop=="orchard" else Color("4b5831")
				color.a=smoothstep(-4.,3.,edge)*.85
				if color.a>image.get_pixel(x,y).a:image.set_pixel(x,y,color)
	for grove: Vector2 in _groves:
		for y in range(maxi(0,floori((grove.y-33.+1000.)*.256)),mini(512,ceili((grove.y+33.+1000.)*.256))):
			for x in range(maxi(0,floori((grove.x-33.+1000.)*.256)),mini(512,ceili((grove.x+33.+1000.)*.256))):
				var q:=Vector2((x+.5)/.256-1000.,(y+.5)/.256-1000.)-grove
				var color:=Color("586044");color.a=(1.-smoothstep(14.,31.+3.*sin(q.angle()*3.),q.length()))*.65
				if color.a>image.get_pixel(x,y).a:image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)
static func roads() -> Array[Dictionary]: _setup();return _paths
static func mainroadpath() -> Array[Vector2]:
	_setup();var result: Array[Vector2]=[]
	for p: Vector3 in _paths[0].points: result.append(Vector2(p.x,p.z))
	return result

