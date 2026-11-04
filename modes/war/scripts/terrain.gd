@tool
extends RefCounted
class_name WarTerrain
static var HALF := 1750.0
static var operation_id:=WarOperation.UKRAINE

static func configure(operation: String) -> void:
	operation_id=WarOperation.normalize(operation)
	HALF=WarOperation.half(operation_id)
	reset_cache()
const CHUNK := 100.0
const TRENCH := [Vector2(-280,-120),Vector2(-230,-120),Vector2(-230,-65),Vector2(-170,-65),Vector2(-170,-125),Vector2(-100,-125),Vector2(-100,-65),Vector2(-35,-65),Vector2(0,-110),Vector2(35,-65),Vector2(100,-65),Vector2(100,-125),Vector2(170,-125),Vector2(170,-65),Vector2(230,-65),Vector2(230,-120),Vector2(280,-120)]
const BRANCHES := [[Vector2(-170,-65),Vector2(-170,0),Vector2(-100,0),Vector2(-100,65)], [Vector2(170,-65),Vector2(170,0),Vector2(100,0),Vector2(100,65)]]
const CRATERS := [Vector3(-230,8,125),Vector3(-55,7,-170),Vector3(65,10,-165),Vector3(210,8,125),Vector3(-320,11,-210),Vector3(330,9,-200),Vector3(-65,9,240),Vector3(210,10,230),Vector3(-360,12,210),Vector3(-260,8,-160),Vector3(265,9,-155),Vector3(-205,6,-175),Vector3(205,7,-180),Vector3(-130,9,-30),Vector3(130,8,-28),Vector3(-88,5,20),Vector3(88,7,18),Vector3(-40,8,-20),Vector3(45,6,20)]
static var tiles: Dictionary = {}
static var refined: Dictionary={}
static var fine_samples: Dictionary={}
static var tile_steps: Dictionary={}
static var material: ShaderMaterial

# Building footprints are graded before meshing, identically on server and
# clients. A level foundation must not float above a single centre sample.
const PADS := [Vector4(-250,-135,8,7),Vector4(250,-135,8,7),Vector4(-230,-205,8,7),Vector4(230,-205,8,7),Vector4(-66,82,8,7),Vector4(5,120,8,7),Vector4(64,88,8,7),Vector4(-45,150,8,7),Vector4(70,155,8,7),Vector4(10,45,8,7),Vector4(-125,165,12,10),Vector4(-450,-220,4,8),Vector4(-350,-220,4,8),Vector4(350,-220,4,8),Vector4(450,-220,4,8)]
static var pad_targets: Dictionary={}
static var settlement_cells: Dictionary={}
static var settlement_targets: Dictionary={}

static func step_for(ix: int,iz: int) -> float:
	# Authored town/port extents are constant. Ground, swimming, locomotion
	# and vehicle contacts repeatedly ask for the same tile's sampling step.
	var key:=Vector2i(ix,iz)
	if not tile_steps.has(key):tile_steps[key]=_tile_step(ix,iz)
	return tile_steps[key]

static func _tile_step(ix: int,iz: int) -> float:
	var centre:=Vector2((ix+.5)*CHUNK-HALF,(iz+.5)*CHUNK-HALF)
	if absf(centre.x)<310 and absf(centre.y)<310: return 2.0
	if absf(centre.x+1110)<420 and absf(centre.y+430)<410: return 5.0
	if absf(centre.x-1190)<240 and absf(centre.y-470)<220: return 5.0
	for town: Vector2 in WarUrbanLayout.CENTRES:
		if absf(centre.x-town.x)<140 and absf(centre.y-town.y)<135:return 5.0
	for village: Vector2 in WarOutskirts.VILLAGES:
		if absf(centre.x-village.x)<140 and absf(centre.y-village.y)<135:return 5.0
	return 10.0

static func _landform(x: float,z: float) -> float:
	var h:=18.0+6.5*sin(x*.009)*cos(z*.0105)+3.8*sin(z*.018+x*.011)
	h+=.70*sin(x*.070+z*.045)*sin(z*.056)
	h+=25.0*exp(-pow((x+355)/170,2)-pow((z+255)/145,2))
	h+=30.0*exp(-pow((x-355)/185,2)-pow((z-255)/170,2))
	h+=16.0*exp(-pow((x+30)/220,2)-pow((z+450)/155,2))
	h-=7.0*exp(-pow(x/240,2)-pow((z-270)/100,2))
	h+=18.0*exp(-pow((x+880)/260,2)-pow((z+250)/450,2))
	h+=22.0*exp(-pow((x-890)/270,2)-pow((z-350)/400,2))
	return h

static func _base(x: float,z: float,grade_settlements:=true) -> float:
	var h:=_landform(x,z)
	# The road follows the land's longitudinal grade, with a flat crossfall.
	# Multiplying terrain height towards zero created steep roadside cuts.
	var road_z:=25.0*sin(x*.009)
	var distance_to_road:=absf(z-road_z)
	if distance_to_road<15:
		h=lerpf(h,_landform(x,road_z)-.12,1-smoothstep(4,15,distance_to_road))
	for base: Vector3 in WarRules.BASES:
		var flat:=smoothstep(72,115,Vector2(x-base.x,z-base.z).length())
		h=lerpf(18,h,flat)
	for i in PADS.size():
		var pad: Vector4=PADS[i]
		var edge:=maxf(absf(x-pad.x)-pad.z,absf(z-pad.y)-pad.w)
		if edge>=6: continue
		if not pad_targets.has(i): pad_targets[i]=_landform(pad.x,pad.y)
		h=lerpf(h,float(pad_targets[i]),1-smoothstep(0,6,edge))
	h=WarRoads.grade(x,z,h)
	# Logistics roads must preserve the already level military aprons.
	for base: Vector3 in WarRules.BASES:
		h=lerpf(base.y,h,smoothstep(72,115,Vector2(x-base.x,z-base.z).length()))
	h=WarCoast.height(x,z,h)
	var bay_offset:=Vector2(x,z)-WarCoast.BAY_CENTER
	var bay_angle:=absf(atan2(bay_offset.y/245,bay_offset.x/280))
	var bay_edge:=absf(((bay_offset/Vector2(280,245)).length()-1)*245)
	if bay_angle>deg_to_rad(25) and bay_angle<deg_to_rad(92) and bay_edge<20:
		h=lerpf(h,3.65,1-smoothstep(7,20,bay_edge))
	for port: Vector3 in WarCoast.PORTS:
		var edge:=maxf(absf(x-port.x)-48,absf(z-port.z)-135)
		# The quay's walking surface is y=4. Its terrain bed is recessed;
		# coplanar terrain and concrete caused stripes at both ports.
		if edge<30: h=lerpf(h,3.65,1-smoothstep(0,30,edge))
	h=WarRoads.port_grade(x,z,h)
	# Grade at the final road/coast height. Grading before the port descent
	# left houses on narrow high mesas or buried their front foundations.
	return _settlement_grade(x,z,h) if grade_settlements else h

static func _prepare_settlements() -> void:
	if not settlement_cells.is_empty():return
	var sites: Array[Vector4]=[]
	for centre: Vector2 in WarUrbanLayout.CENTRES:
		for block in 6:
			var at:=centre+Vector2((block%3)*42-42,(block/3)*58-29);sites.append(Vector4(at.x,at.y,17,14))
	for centre: Vector2 in WarOutskirts.VILLAGES:
		for block in 8:
			var at:=centre+Vector2((block%4)*39-58,(block/4)*65-32);sites.append(Vector4(at.x,at.y,12,10))
	for site: Vector4 in sites:
		var low:=Vector2i(floori((site.x-site.z-8)/100.),floori((site.y-site.w-8)/100.))
		var high:=Vector2i(floori((site.x+site.z+8)/100.),floori((site.y+site.w+8)/100.))
		for iz in range(low.y,high.y+1):
			for ix in range(low.x,high.x+1):
				var cell:=Vector2i(ix,iz)
				if not settlement_cells.has(cell):settlement_cells[cell]=[]
				settlement_cells[cell].append(site)

static func _settlement_grade(x: float,z: float,height: float) -> float:
	_prepare_settlements()
	var road_weight:=1.
	for segment: Dictionary in WarRoads.cells.get(Vector2i(floori(x/WarRoads.INDEX_CELL),floori(z/WarRoads.INDEX_CELL)),[]):
		if not segment.has("port_profile"):continue
		var distance:=Vector2(x,z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x,z),segment.a,segment.b))
		road_weight=minf(road_weight,smoothstep(9.,12.,distance))
	if road_weight<=0.:return height
	for site: Vector4 in settlement_cells.get(Vector2i(floori(x/100.),floori(z/100.)),[]):
		var edge:=maxf(absf(x-site.x)-site.z,absf(z-site.y)-site.w)
		if edge>=8.:continue
		var key:=Vector2(site.x,site.y)
		if not settlement_targets.has(key):settlement_targets[key]=_base(site.x,site.y,false)
		height=lerpf(height,float(settlement_targets[key]),(1.-smoothstep(0.,8.,edge))*road_weight)
	return height

static func trench_distance(p: Vector2) -> float:
	if operation_id==WarOperation.AFGHAN:return INF
	var distance := INF
	for i in TRENCH.size()-1:
		distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,TRENCH[i],TRENCH[i+1])))
	for branch: Array in BRANCHES:
		for i in branch.size()-1:
			distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,branch[i],branch[i+1])))
	return distance

static func raw_height(x: float,z: float) -> float:
	if operation_id==WarOperation.AFGHAN:return BRAfghanMap.height_at(x,z)
	WarTerrainEdits.prepare()
	var h := _base(x,z)
	for port: Vector3 in WarCoast.PORTS:
		var d:=Vector2(x-port.x,z-port.z)
		if absf(d.x)>260 or absf(d.y)>300 or h<1.: continue
		if absf(d.x)<52 and absf(d.y)<140: continue
		var wear: float=(1.-smoothstep(90,260,d.length()))*smoothstep(8,16,WarRoads.distance(Vector2(x,z)))
		h+=.24*sin(x*.29+z*.19)*sin(z*.21-x*.17)*wear
	if absf(x)<295 and z>-145 and z<80:
		var d := trench_distance(Vector2(x,z))
		var ramp := smoothstep(0,12,280.0-absf(x))
		if z>45: ramp *= 1.0-smoothstep(45,66,z)
		# Preserve the infantry cover at the bottom, but grade the earth around
		# it: a near-vertical bank traps a vehicle's broad running-gear box.
		# This is shared by the visual mesh and authoritative terrain collision.
		h -= 1.9*(1.0-smoothstep(1.7,8.5,d))*ramp
	for crater: Vector3 in CRATERS:
		var distance := Vector2(x-crater.x,z-crater.z).length()/crater.y
		if distance<1.35:
			h -= 2.4*maxf(0,1.0-distance*distance)
			h += .55*exp(-pow((distance-1.05)*8.0,2))
	return WarTerrainEdits.apply_height(x,z,h)

static func tile(ix: int,iz: int) -> PackedFloat32Array:
	var key := Vector2i(ix,iz)
	if tiles.has(key): return tiles[key]
	var step := step_for(ix,iz)
	var side := int(CHUNK/step)+1
	var values := PackedFloat32Array()
	values.resize(side*side)
	for z in side:
		for x in side:
			var gx := ix*CHUNK-HALF+x*step
			var gz := iz*CHUNK-HALF+z*step
			var h := raw_height(gx,gz)
			# Match the actual adjacent coarse lattice, also at intermediate
			# fine vertices. Both sides keep the same collision/render seam.
			if step<10 and (x==0 or z==0 or x==side-1 or z==side-1):
				for edge in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
					var on_edge: bool=(edge.x==-1 and x==0) or (edge.x==1 and x==side-1) or (edge.y==-1 and z==0) or (edge.y==1 and z==side-1)
					var neighbour:=step_for(ix+edge.x,iz+edge.y)
					if not on_edge or neighbour<=step: continue
					var coordinate:=gz if edge.x!=0 else gx
					var low:=floorf(coordinate/neighbour)*neighbour
					h=lerpf(raw_height(gx,low),raw_height(gx,low+neighbour),(gz-low)/neighbour) if edge.x!=0 else lerpf(raw_height(low,gz),raw_height(low+neighbour,gz),(gx-low)/neighbour)

			values[z*side+x] = h
	tiles[key] = values
	return values

static func _coarse_height_at(x: float,z: float) -> float:
	x = clampf(x,-HALF,HALF-.001)
	z = clampf(z,-HALF,HALF-.001)
	var ix := floori((x+HALF)/CHUNK)
	var iz := floori((z+HALF)/CHUNK)
	var step := step_for(ix,iz)
	var side := int(CHUNK/step)+1
	var gx := (x+HALF-ix*CHUNK)/step
	var gz := (z+HALF-iz*CHUNK)/step
	var cx := mini(floori(gx),side-2)
	var cz := mini(floori(gz),side-2)
	var fx := gx-cx
	var fz := gz-cz
	var values := tile(ix,iz)
	var a := values[cz*side+cx]
	var b := values[cz*side+cx+1]
	var c := values[(cz+1)*side+cx]
	var d := values[(cz+1)*side+cx+1]
	return a+fx*(b-a)+fz*(c-a) if fx+fz<=1 else d+(1-fx)*(c-d)+(1-fz)*(b-d)

static func point(x: float,z: float) -> Vector3: return Vector3(x,height_at(x,z),z)

static func reset_cache() -> void:
	# Grid indices represent different world positions when HALF changes.
	tiles.clear();refined.clear();fine_samples.clear();tile_steps.clear()

static func cell_at(x: float,z: float) -> Vector4i:
	x=clampf(x,-HALF,HALF-.001);z=clampf(z,-HALF,HALF-.001)
	var ix:=floori((x+HALF)/CHUNK);var iz:=floori((z+HALF)/CHUNK);var step:=step_for(ix,iz)
	return Vector4i(ix,iz,floori((x+HALF-ix*CHUNK)/step),floori((z+HALF-iz*CHUNK)/step))

static func fine_cell(key: Vector4i) -> bool:
	if not WarTerrainEdits.active_tiles.has(Vector2i(key.x,key.y)): return false
	if refined.has(key): return refined[key]
	var step:=step_for(key.x,key.y)
	var rect:=Rect2(Vector2(key.x*CHUNK-HALF+key.z*step,key.y*CHUNK-HALF+key.w*step),Vector2.ONE*step)
	var result:=WarTerrainEdits.affects(rect);refined[key]=result;return result

static func fine_vertex(key: Vector4i,sx: int,sz: int) -> float:
	var step:=step_for(key.x,key.y);var count:=int(step/.5)
	var x:=key.x*CHUNK-HALF+key.z*step+sx*.5
	var z:=key.y*CHUNK-HALF+key.w*step+sz*.5
	# At the outside of a refined patch, keep vertices on the neighbour's
	# original triangles. Both sides of an excavation itself refine to 0.5 m.
	if sx==0 and not fine_cell(cell_at(x-.001,z)): return _coarse_height_at(x-.00001,z)
	if sx==count and not fine_cell(cell_at(x+.001,z)): return _coarse_height_at(x+.00001,z)
	if sz==0 and not fine_cell(cell_at(x,z-.001)): return _coarse_height_at(x,z-.00001)
	if sz==count and not fine_cell(cell_at(x,z+.001)): return _coarse_height_at(x,z+.00001)
	return raw_height(x,z)

static func height_at(x: float,z: float) -> float:
	if operation_id==WarOperation.AFGHAN:return BRAfghanMap.height_at(x,z)
	WarTerrainEdits.prepare()
	var key:=cell_at(x,z)
	if not fine_cell(key): return _coarse_height_at(x,z)
	x=clampf(x,-HALF,HALF-.001);z=clampf(z,-HALF,HALF-.001)
	var step:=step_for(key.x,key.y);var count:=int(step/.5)
	var fx: float=(x-(key.x*CHUNK-HALF+key.z*step))/.5
	var fz: float=(z-(key.y*CHUNK-HALF+key.w*step))/.5
	var cx:=mini(floori(fx),count-1);var cz:=mini(floori(fz),count-1)
	fx-=cx;fz-=cz
	var samples:=fine_values(key);var side:=count+1
	var a:=samples[cz*side+cx];var b:=samples[cz*side+cx+1];var c:=samples[(cz+1)*side+cx];var d:=samples[(cz+1)*side+cx+1]
	return a+fx*(b-a)+fz*(c-a) if fx+fz<=1 else d+(1-fx)*(c-d)+(1-fz)*(b-d)

static func fine_values(key: Vector4i) -> PackedFloat32Array:
	if fine_samples.has(key): return fine_samples[key]
	var side:=int(step_for(key.x,key.y)/.5)+1
	var values:=PackedFloat32Array();values.resize(side*side)
	for z in side:
		for x in side: values[z*side+x]=fine_vertex(key,x,z)
	fine_samples[key]=values;return values

static func mesh_data(ix: int,iz: int,visuals: bool) -> Dictionary:
	var step:=step_for(ix,iz);var count:=int(CHUNK/step);var side:=count+1
	var values:=tile(ix,iz);var origin:=Vector3(ix*CHUNK-HALF,0,iz*CHUNK-HALF)
	var verts:=PackedVector3Array();var colors:=PackedColorArray();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	for z in side:
		for x in side:
			verts.append(Vector3(x*step,values[z*side+x],z*step))
			if visuals:
				var dx:=values[z*side+maxi(0,x-1)]-values[z*side+mini(count,x+1)]
				var dz:=values[maxi(0,z-1)*side+x]-values[mini(count,z+1)*side+x]
				normals.append(Vector3(dx,step*2,dz).normalized());colors.append(vertex_color(origin.x+x*step,origin.z+z*step))
	var fine_count:=0
	for z in count:
		for x in count:
			var key:=Vector4i(ix,iz,x,z)
			if not fine_cell(key):
				var a:=z*side+x;indices.append_array(PackedInt32Array([a,a+1,a+side,a+1,a+side+1,a+side]));continue
			fine_count+=1
			var n:=int(step/.5);var grid:=n+1;var first:=verts.size()
			var samples:=fine_values(key)
			for fz in grid:
				for fx in grid:
					var px:=x*step+fx*.5;var pz:=z*step+fz*.5
					verts.append(Vector3(px,samples[fz*grid+fx],pz))
					if visuals:
						var dx:=samples[fz*grid+maxi(0,fx-1)]-samples[fz*grid+mini(n,fx+1)]
						var dz:=samples[maxi(0,fz-1)*grid+fx]-samples[mini(n,fz+1)*grid+fx]
						normals.append(Vector3(dx,1.,dz).normalized());colors.append(vertex_color(origin.x+px,origin.z+pz))
			for fz in n:
				for fx in n:
					var a:=first+fz*grid+fx;indices.append_array(PackedInt32Array([a,a+1,a+grid,a+1,a+grid+1,a+grid]))
	return {"vertices":verts,"normals":normals,"colors":colors,"indices":indices,"origin":origin,"refined":fine_count}

static func vertex_color(x: float,z: float) -> Color:
	return Color(.48,.45,.39).lerp(Color(.40,.49,.31),smoothstep(280,480,absf(z)))*(.70+.1*sin(x*.032+z*.017))

static func build(parent: Node3D,visuals: bool,selection: Array[Vector2i]=[]) -> void:
	WarTerrainEdits.prepare()
	var visual_sectors: Dictionary={}
	if visuals and material==null:
		material=ShaderMaterial.new();material.shader=preload("res://modes/war/shaders/ground.gdshader")
		material.set_shader_parameter("soil",load("res://assets/environment/materials/sand-albedo.png"));material.set_shader_parameter("gravel",load("res://assets/environment/materials/asphalt-albedo.png"))
		material.set_shader_parameter("soil_normal",load("res://assets/environment/materials/sand-normal.png"))
		material.set_shader_parameter("port_west",Vector2(WarCoast.PORTS[0].x,WarCoast.PORTS[0].z));material.set_shader_parameter("port_east",Vector2(WarCoast.PORTS[1].x,WarCoast.PORTS[1].z))
		material.set_shader_parameter("towns_a",Vector4(-610,610,610,-610));material.set_shader_parameter("towns_b",Vector4(WarUrbanLayout.CENTRES[0].x,WarUrbanLayout.CENTRES[0].y,WarUrbanLayout.CENTRES[1].x,WarUrbanLayout.CENTRES[1].y))
		var noise:=FastNoiseLite.new();noise.seed=27443;noise.frequency=.035
		var texture:=NoiseTexture2D.new();texture.width=256;texture.height=256;texture.seamless=true;texture.noise=noise;material.set_shader_parameter("variation",texture)
	for iz in int(HALF*2/CHUNK):
		for ix in int(HALF*2/CHUNK):
			if not selection.is_empty() and Vector2i(ix,iz) not in selection: continue
			var data:=mesh_data(ix,iz,visuals)
			var body:=StaticBody3D.new();body.name="WarTerrain_%d_%d"%[ix,iz];body.position=data.origin;body.collision_layer=1;body.collision_mask=0;parent.add_child(body)
			body.set_meta("refined_cells",data.refined)
			var faces:=PackedVector3Array()
			for index in data.indices: faces.append(data.vertices[index])
			var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
			var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
			if not visuals or Array(tile(ix,iz)).max()<=-1.: continue
			var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_COLOR]=data.colors;arrays[Mesh.ARRAY_INDEX]=data.indices
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var key:=Vector2i(ix/2,iz/2);var sector_origin:=Vector3(key.x*CHUNK*2-HALF,0,key.y*CHUNK*2-HALF)
			if not visual_sectors.has(key):
				var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);visual_sectors[key]={"surface":surface,"origin":sector_origin}
			var surface: SurfaceTool=visual_sectors[key].surface;surface.append_from(mesh,0,Transform3D(Basis.IDENTITY,data.origin-sector_origin))
	for sector_data: Dictionary in visual_sectors.values():
		var view:=MeshInstance3D.new();view.name="WarTerrainVisualSector";view.mesh=sector_data.surface.commit();view.position=sector_data.origin
		view.material_override=material;view.visibility_range_end=2500;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(view)

static func horizon(parent: Node3D,visuals: bool) -> void:
	var weather:=WarWeather.new();weather.name="WarWeather";weather.game=parent.get_parent();parent.add_child(weather)

