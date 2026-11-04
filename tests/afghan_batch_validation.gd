extends SceneTree
## Verify the static batching output independently of GPU timing and physics.
const BUILDER=preload("res://modes/battle_royale/map/afghan_batch_builder.gd")
const HOUSE=preload("res://modes/battle_royale/library/adobe_house_v2.tscn")
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message)

func color_near(a: Color,b: Color) -> bool:
	return absf(a.r-b.r)<0.005 and absf(a.g-b.g)<0.005 and absf(a.b-b.b)<0.005 and absf(a.a-b.a)<0.005

func lod_counts(mesh: ArrayMesh) -> Array[int]:
	var counts: Array[int]=[]
	var surfaces: Variant=mesh.get("_surfaces")
	if surfaces is Array:
		for surface: Dictionary in surfaces: counts.append((surface.get("lods",[]) as Array).size())
	return counts

func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	
	var model: Node3D=HOUSE.instantiate();var mesh: ArrayMesh=model.get_node("Geometry").mesh
	var source_lods:=lod_counts(mesh)
	var offset_a:=Transform3D(Basis.IDENTITY,Vector3(20,0,20))
	var offset_b:=Transform3D(Basis.IDENTITY,Vector3(55,0,20))
	var colors: Array=[Color(1.,.8,.7,1.),Color(.65,.9,1.,1.)]
	var entries:=[{"source":mesh,"transform":offset_a,"tint":colors[0]},{"source":mesh,"transform":offset_b,"tint":colors[1]}]
	var rendered:=MeshInstance3D.new()
	rendered.mesh=BUILDER.build(entries,Vector2i.ZERO)
	world.add_child(rendered)
	check(rendered!=null,"Merged cell exists")
	if rendered:
		var result:=rendered.mesh as ArrayMesh
		check(result!=null,"Merged mesh exists")
		if result:
			var output_lods:=lod_counts(result)
			if source_lods.any(func(c):return c>0): check(output_lods.any(func(c):return c>0),"Output contains LOD when source does")
			else: check(false,"Fixture source must contain LOD")
			var found_a:=false;var found_b:=false
			for surface in result.get_surface_count():
				var arrays:=result.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var values: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
				if values.size()!=vertices.size(): continue
				for i in vertices.size():
					if vertices[i].x<35. and color_near(values[i],colors[0]): found_a=true
					if vertices[i].x>40. and color_near(values[i],colors[1]): found_b=true
			check(found_a and found_b,"Merged vertices preserve distinct instance tints")
			check(rendered.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Shadows stay enabled on request")
			print("AFGHAN_BATCH_LODS ",source_lods," -> ",output_lods)
	var fixture:=ArrayMesh.new()
	var fixture_arrays:=[]; fixture_arrays.resize(Mesh.ARRAY_MAX)
	fixture_arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD])
	fixture_arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP])
	fixture_arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP])
	fixture_arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(.5,.5,.5),Color.WHITE,Color.WHITE])
	fixture_arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
	fixture.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,fixture_arrays)
	var transformed:=BUILDER.build([{"source":fixture,"transform":Transform3D(Basis.IDENTITY,Vector3(170,3,-150)),"tint":Color(.5,1.,1.)}],Vector2i(1,-1))
	var actual:=transformed.surface_get_arrays(0)
	check((actual[Mesh.ARRAY_VERTEX] as PackedVector3Array)[0].is_equal_approx(Vector3(10,3,10)),"Cell origin and transforms stay consistent")
	check(color_near((actual[Mesh.ARRAY_COLOR] as PackedColorArray)[0],Color(.25,.5,.5)),"Existing vertex colors multiply instance tint")
	check((actual[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0].distance_to(Vector3.UP)<0.005,"Normals preserved")
	check((actual[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size()==3,"UV preserved")
	var report:={"checks":checks,"failures":failures,"ok":failures.is_empty(),"source_lods":source_lods}
	NavalStorage.write_json("res://work/afghan-batch-validation.json",report)
	print("AFGHAN_BATCH_VALIDATION ",JSON.stringify(report))
	model.free();world.free();quit(0 if failures.is_empty() else 1)

