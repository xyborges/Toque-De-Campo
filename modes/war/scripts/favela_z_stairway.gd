extends RefCounted
## One continuous pedestrian staircase following the western Z mini-street.
## The road/terrain mesh stays intact underneath; both sides of stairs use
## identical collision meshes on clients and headless authority.
const ARCHITECTURE=preload("res://modes/war/scripts/favela_architecture.gd")
const RUN:=0.72
const TREAD_LENGTH:=0.68
const WIDTH:=2.30
const LANDING_INSET:=1.24
const RAIL_OFFSET:=1.13

static func plan(route: Array,height: Callable) -> Dictionary:
	var steps: Array[Dictionary]=[]
	var landings: Array[Vector3]=[]
	var max_rise:=0.0
	for vertex: Vector2 in route:
		landings.append(Vector3(vertex.x,float(height.call(vertex.x,vertex.y))+.01,vertex.y))
	for segment in route.size()-1:
		var a: Vector2=route[segment]
		var b: Vector2=route[segment+1]
		var length:=a.distance_to(b)
		if length<=2.*LANDING_INSET+RUN:continue
		var axis: Vector2=(b-a)/length
		var yaw:=atan2(axis.x,axis.y)
		var run_length:=length-2.*LANDING_INSET
		var count:=maxi(1,floori(run_length/RUN))
		var pitch:=run_length/float(count)
		var previous_h:=INF
		for j in count:
			var point:=a+axis*(LANDING_INSET+(float(j)+.5)*pitch)
			# A shallow footing follows the existing terrain grade; the upper
			# face stands 0.20m above terrain, keeping the riser visible without
			# forcing a new terrain or navigation rebuild.
			var ground:=float(height.call(point.x,point.y))
			var center:=Vector3(point.x,ground+.08,point.y)
			if is_finite(previous_h):
				max_rise=maxf(max_rise,absf(center.y-previous_h))
			previous_h=center.y
			steps.append({"position":center,"yaw":yaw,"segment":segment,
				"step":j,"pitch":pitch})
	return {"steps":steps,"landings":landings,"max_rise":max_rise}

static func populate(kit: EnvironmentKit,route: Array,height: Callable) -> Dictionary:
	var layout:=plan(route,height)
	var steps: Array=layout.steps
	var landings: Array=layout.landings
	# Six capped turn platforms smooth the geometry at the zig-zag's elbows.
	for i in landings.size():
		var at: Vector3=landings[i]
		kit.cylinder("PatamarEscadariaZ",at,1.23,.24,"concrete:95938a",true)
		if kit.visuals:
			kit.cylinder("AcabamentoPatamarZ",at+Vector3.UP*.126,
				1.18,.012,"concrete:b4b0a5",false)
	for n in steps.size():
		var item: Dictionary=steps[n]
		var origin: Vector3=item.position
		var yaw: float=item.yaw
		# Keep the reusable scene's original textured MultiMesh visuals, but do
		# not add 276 independent broad-phase collision shapes to the sector.
		ARCHITECTURE.place(kit,"favela_z_stair_tread",Transform3D(Basis(Vector3.UP,yaw),origin),false)
		if kit.visuals and n%13==7:
			var mark:=origin+Vector3.UP*.130
			kit.box("ReparoCimentoEscadariaZ",mark,Vector3(.32,.010,.11),
				"concrete:99988f",false,Vector3(0,yaw,0),true)
	# A short fitted collision ramp for each group of treads replaces 276
	# expensive step colliders; all visual treads remain. The identical fitted
	# BoxShapes are built for the client and the headless authority.
	_compact_collisions(kit,steps)
	var posts:=0
	if kit.visuals:
		# Railings and vertical posts stay outside the 2.30m usable footway.
		# Non-colliding: the pre-existing infantry step solver is unchanged.
		for segment in route.size()-1:
			var a: Vector2=route[segment]
			var b: Vector2=route[segment+1]
			var length:=a.distance_to(b)
			if length<2.0:continue
			var axis: Vector2=(b-a)/length
			var transverse:=Vector2(-axis.y,axis.x)
			var count:=maxi(2,ceili(length/3.6))
			for side in [-1.,1.]:
				var last:=Vector3.INF
				for i in count+1:
					var t:=float(i)/float(count)
					var point: Vector2=a.lerp(b,t)+transverse*(RAIL_OFFSET+.12)*float(side)
					var base:=Vector3(point.x,float(height.call(point.x,point.y))+.13,point.y)
					var top:=base+Vector3.UP*.88
					kit.pipe(base,top,.028,"steel:5c625f",false)
					posts+=1
					if last.is_finite():kit.pipe(last,top,.025,"steel:666d68",false)
					last=top
	return {"z_stair_treads":steps.size(),"z_stair_landings":landings.size(),
		"z_stair_max_rise":float(layout.max_rise),"z_stair_rails_posts":posts,
		"z_stair_route_length_m":_length(route)}

static func _compact_collisions(kit: EnvironmentKit, steps: Array) -> void:
	# Short aligned BoxShape ramps are cheap in Jolt's broad phase; the 276
	# textured visual treads remain unchanged. Small groups approximate the
	# continuous terrain below each step instead of triangle-mesh contacts.
	var group: Array[Dictionary]=[]
	var previous_segment: int=-1
	for item: Dictionary in steps:
		var segment:=int(item.segment)
		if not group.is_empty() and (segment!=previous_segment or group.size()>=6):
			_add_ramp_collider(kit,group)
			group.clear()
		group.append(item)
		previous_segment=segment
	if not group.is_empty():_add_ramp_collider(kit,group)

static func _add_ramp_collider(kit: EnvironmentKit, group: Array[Dictionary]) -> void:
	var start: Vector3=group.front().position
	var end: Vector3=group.back().position
	var horizontal:=Vector2(start.x,start.z).distance_to(Vector2(end.x,end.z))
	var tilt: float=-atan2(end.y-start.y,maxf(.001,horizontal))
	var slope_length:=horizontal/maxf(.001,cos(tilt))
	var shape:=BoxShape3D.new()
	shape.size=Vector3(WIDTH,.24,slope_length+TREAD_LENGTH)
	var pose:=Transform3D(
		Basis(Vector3.UP,float(group.front().yaw))*Basis(Vector3.RIGHT,tilt),
		(start+end)*.5)
	kit._collider("Favela_favela_z_stair_tread",shape,pose,"concrete")

static func _length(route: Array) -> float:
	var result:=0.0
	for i in route.size()-1:result+=(route[i] as Vector2).distance_to(route[i+1])
	return result
