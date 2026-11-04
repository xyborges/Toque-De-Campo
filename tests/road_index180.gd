extends SceneTree
func _initialize() -> void:
	WarRoads.prepare()
	var rng:=RandomNumberGenerator.new();rng.seed=180
	var points: Array[Vector2]=[]
	for i in 10000: points.append(Vector2(rng.randf_range(-1750,1750),rng.randf_range(-1750,1750)))
	for segment in WarRoads.segments:
		for t in [0.,.25,.5,.75,1.]:
			for offset in [-12.001,-12.,-9.5,0.,9.5,12.,12.001]: points.append(Vector2(segment.a).lerp(segment.b,t)+Vector2(offset,offset))
	var reference: Array[Vector2]=[]
	var start:=Time.get_ticks_usec()
	for p in points: reference.append(linear(p))
	var before:=Time.get_ticks_usec()-start
	start=Time.get_ticks_usec()
	var maximum:=0.;var failures:=0
	for i in points.size():
		var p:=points[i];var actual:=Vector2(WarRoads.grade(p.x,p.y,18.),WarRoads.distance(p))
		maximum=maxf(maximum,absf(actual.x-reference[i].x))
		if actual.x!=reference[i].x or actual.y!=reference[i].y: failures+=1
	var result:={"samples":points.size(),"failures":failures,"max_height_error":maximum,"linear_ms":before/1000.,"indexed_ms":(Time.get_ticks_usec()-start)/1000.}
	FileAccess.open("res://tests/road-index180-results.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result));quit(0 if failures==0 else 1)

func linear(p: Vector2) -> Vector2:
	# Pre-optimization traversal, retained only as a numerical reference.
	var height:=18.;var nearest_distance:=INF
	for segment in WarRoads.segments:
		var a: Vector2=segment.a;var b: Vector2=segment.b;var width:=float(segment.width)*.5
		if p.x>=minf(a.x,b.x)-12 and p.x<=maxf(a.x,b.x)+12 and p.y>=minf(a.y,b.y)-12 and p.y<=maxf(a.y,b.y)+12:
			nearest_distance=minf(nearest_distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
		if p.x<minf(a.x,b.x)-width-5 or p.x>maxf(a.x,b.x)+width+5 or p.y<minf(a.y,b.y)-width-5 or p.y>maxf(a.y,b.y)+width+5: continue
		var nearest:=Geometry2D.get_closest_point_to_segment(p,a,b);var d:=p.distance_to(nearest)
		if d<width+4: height=lerpf(height,WarTerrain._landform(nearest.x,nearest.y)-.08,1-smoothstep(width,width+4,d))
	return Vector2(height,nearest_distance)
