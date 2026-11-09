extends RefCounted
## Dirt footpaths from existing residential doors to the nearest viable street edge.
## Visual-only combined mesh: no new collision shapes or physics step discontinuities.
const MAX_ACCESS := 1600
const MAX_LENGTH := 9.5
const MIN_LENGTH := 0.85
const COLOR_A := Color("8e7050")
const COLOR_B := Color("aa8965")

static func plan(doors: Array[Dictionary], roads: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for door: Dictionary in doors:
		if result.size() >= MAX_ACCESS: break
		var entrance: Vector2 = door.position
		var outward: Vector2 = door.outward.normalized()
		if outward.length_squared() < .95:continue
		var best_score:=INF
		var best_edge:=Vector2.INF
		var best_road:=-1
		for road: Dictionary in roads:
			var route: Array = road.points
			var half_width:=float(road.width)*.5
			for segment in route.size()-1:
				var a: Vector2=route[segment]
				var b: Vector2=route[segment+1]
				var ab:=b-a
				var alpha:=clampf((entrance-a).dot(ab)/maxf(ab.length_squared(),.001),0.,1.)
				var center:=a+ab*alpha
				var delta:=center-entrance
				var dist:=delta.length()
				if dist<=half_width+.3 or dist>MAX_LENGTH+half_width:continue
				if delta.normalized().dot(outward)<.68:continue
				var edge:=center-delta.normalized()*half_width
				var distance:=entrance.distance_to(edge)
				if distance<MIN_LENGTH or distance>MAX_LENGTH:continue
				var score:=distance+(0.15 if half_width>3.0 else 0.)
				if score<best_score:
					best_score=score
					best_edge=edge
					best_road=int(road.id)
		if best_road<0:continue
		result.append({"from":entrance,"to":best_edge,"road":best_road,
			"length":entrance.distance_to(best_edge)})
	return result

static func populate(parent: Node3D,doors: Array[Dictionary],roads: Array[Dictionary],
		terrain_height: Callable,visuals: bool) -> Dictionary:
	var paths:=plan(doors,roads)
	if not visuals or paths.is_empty():
		return {"door_footpaths":paths.size(),"door_footpaths_triangles":0}
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for i in paths.size():
		var path: Dictionary=paths[i]
		var origin: Vector2=path["from"]
		var destination: Vector2=path["to"]
		var tangent: Vector2=(destination-origin).normalized()
		var side:=Vector2(-tangent.y,tangent.x)
		var steps:=maxi(2,ceili(float(path.length)/1.2))
		var start_index:=vertices.size()
		var width:=1.12+float(i%5)*.07
		for j in steps+1:
			var fraction:=float(j)/float(steps)
			var center:=origin.lerp(destination,fraction)
			var taper:=.76+.24*sin(PI*fraction)
			for sign_side in [-1.0,1.0]:
				var pos: Vector2=center+side*sign_side*width*.5*taper
				var h:=float(terrain_height.call(pos.x,pos.y))+.07
				vertices.append(Vector3(pos.x,h,pos.y))
				normals.append(Vector3.UP)
				colors.append(COLOR_A.lerp(COLOR_B,float((i*7+j*3)%11)/10.0))
			if j>0:
				var a:=start_index+(j-1)*2
				var b:=start_index+j*2
				indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1.0
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var view:=MeshInstance3D.new()
	view.name="CaminhosDeTerraPortas"
	view.mesh=mesh
	view.material_override=material
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return {"door_footpaths":paths.size(),"door_footpaths_triangles":indices.size()/3}
