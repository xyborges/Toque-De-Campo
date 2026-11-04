extends Node3D

# Visual experiment only: a compact carpet with one MultiMesh per 20 m cell.
# It does not replace the existing grass, edit gameplay, or run headless.
const LAB=preload("res://tests/nova_grama_lab.gd")
const CELL:=20.0
const PATCH:=2.0
const BLADES_PER_SIDE:=8
const CELL_RADIUS:=2
const DRAW_DISTANCE:=50.0
var batches: Array[MultiMeshInstance3D]=[]
var counts: Dictionary={"patches":0,"blades":0,"triangles_per_patch":0,"cells":0,"rejected_boundary":0}

func _blade_mesh() -> ArrayMesh:
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=728302
	for x in BLADES_PER_SIDE:
		for z in BLADES_PER_SIDE:
			var spacing:=PATCH/BLADES_PER_SIDE
			var p:=Vector3(-PATCH*.5+(x+.5)*spacing+rng.randf_range(-.10,.10),0.,-PATCH*.5+(z+.5)*spacing+rng.randf_range(-.10,.10))
			var h:=rng.randf_range(.32,.62);var w:=rng.randf_range(.065,.105);var yaw:=rng.randf_range(0,TAU)
			var base:=Color("405832").lightened(rng.randf_range(0,.03));var tip:=Color("6c8b4f").lightened(rng.randf_range(0,.04))
			for cross in 2:
				var side:=Vector3.RIGHT.rotated(Vector3.UP,yaw+cross*PI*.5)*w*.5
				var root_l:=p-side;var root_r:=p+side;var tip_l:=p-side*.26+Vector3.UP*h;var tip_r:=p+side*.26+Vector3.UP*h
				for v in [[root_l,base],[root_r,base],[tip_r,tip],[root_l,base],[tip_r,tip],[tip_l,tip]]:
					s.set_normal(Vector3.UP);s.set_color(v[1]);s.add_vertex(v[0])
	counts.triangles_per_patch=BLADES_PER_SIDE*BLADES_PER_SIDE*4
	return s.commit()

func build(world: Node3D,centre: Vector2) -> bool:
	if DisplayServer.get_name()=="headless": return false
	var mask=LAB.new()
	if not mask.load_map(): mask.free();push_error("carpet biome unavailable");return false
	var mesh:=_blade_mesh();var mat:=ShaderMaterial.new();mat.shader=load("res://tests/nova_grass_carpet.gdshader")
	var centre_cell:=Vector2i(floori(centre.x/CELL),floori(centre.y/CELL))
	for cx in range(-CELL_RADIUS,CELL_RADIUS+1):
		for cz in range(-CELL_RADIUS,CELL_RADIUS+1):
			var origin:=Vector2((centre_cell.x+cx)*CELL,(centre_cell.y+cz)*CELL)
			var rng:=RandomNumberGenerator.new();rng.seed=(centre_cell.x+cx)*71231+(centre_cell.y+cz)*93187+329
			var poses: Array[Transform3D]=[]
			for ix in int(CELL/PATCH):
				for iz in int(CELL/PATCH):
					var p:=origin+Vector2((ix+.5)*PATCH,(iz+.5)*PATCH)
					var entirely_field:=true
					for corner in [Vector2.ZERO,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
						if mask.biome(p+corner*(PATCH*.5+.15))!=0: entirely_field=false;break
					if not entirely_field: counts.rejected_boundary+=1;continue
					if WarRoads.distance(p)<10. or WarTerrain.trench_distance(p)<6.: continue
					var point:=WarTerrain.point(p.x,p.y)
					if point.y<3.8: continue
					var normal:=Vector3(WarTerrain.height_at(p.x-.4,p.y)-WarTerrain.height_at(p.x+.4,p.y),.8,WarTerrain.height_at(p.x,p.y-.4)-WarTerrain.height_at(p.x,p.y+.4)).normalized()
					var yaw:=rng.randi_range(0,3)*PI*.5
					var scale:=Vector3(1.,rng.randf_range(.82,1.15),1.)
					poses.append(Transform3D(Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)*Basis.from_scale(scale),point))
			if poses.is_empty(): continue
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=poses.size()
			for i in poses.size(): mm.set_instance_transform(i,poses[i])
			var batch:=MultiMeshInstance3D.new();batch.name="GrassCarpetTest";batch.multimesh=mm;batch.material_override=mat
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;batch.visibility_range_end=DRAW_DISTANCE
			world.add_child(batch);batches.append(batch);counts.patches+=poses.size();counts.cells+=1
	counts.blades=counts.patches*BLADES_PER_SIDE*BLADES_PER_SIDE
	mask.free()
	return not batches.is_empty()
