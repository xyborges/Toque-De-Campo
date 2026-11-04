extends SceneTree
const DIR:="res://modes/battle_royale/library/"
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var maximum_position_error:=0.;var maximum_color_error:=0.
	for pair in [["poplar_v6","poplar_v7"],["willow_v6","willow_v7"],["garden_shrub_v6","garden_shrub_v7"],["poplar_v4","poplar_far_v7"],["willow_v4","willow_far_v7"],["garden_shrub_v4","garden_shrub_far_v7"]]:
		var source: Node3D=load(DIR+pair[0]+".tscn").instantiate();var optimized: Node3D=load(DIR+pair[1]+".tscn").instantiate()
		var before: Mesh=source.get_node("Geometry").mesh;var after: Mesh=optimized.get_node("Geometry").mesh
		check(after.get_surface_count()==1,pair[1]+" uses one material")
		var a:=after.surface_get_arrays(0);var offset:=0
		for surface in before.get_surface_count():
			var b:=before.surface_get_arrays(surface)
			var material: StandardMaterial3D=before.surface_get_material(surface)
			for i in (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				var distance: float=b[Mesh.ARRAY_VERTEX][i].distance_to(a[Mesh.ARRAY_VERTEX][offset+i]);maximum_position_error=maxf(maximum_position_error,distance)
				check(distance<.0001,pair[1]+" vertex unchanged")
				var color: Color=b[Mesh.ARRAY_COLOR][i] if b[Mesh.ARRAY_COLOR] is PackedColorArray else Color.WHITE
				var expected:=color*material.albedo_color;var actual: Color=a[Mesh.ARRAY_COLOR][offset+i]
				var difference:=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)));maximum_color_error=maxf(maximum_color_error,difference)
				check(difference<.006,pair[1]+" vertex keeps original material colour")
			offset+=(b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		check(offset==(a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),pair[1]+" retains all vertices")
		var old_shapes:=source.find_children("*","CollisionShape3D",true,false);var new_shapes:=optimized.find_children("*","CollisionShape3D",true,false)
		check(old_shapes.size()==new_shapes.size(),pair[1]+" retains collision count")
		for i in old_shapes.size():
			check(old_shapes[i].transform.is_equal_approx(new_shapes[i].transform),pair[1]+" collision transform unchanged")
			check(var_to_bytes(old_shapes[i].shape.get_property_list())==var_to_bytes(new_shapes[i].shape.get_property_list()),pair[1]+" collision type unchanged")
			for property: Dictionary in old_shapes[i].shape.get_property_list():
				if property.usage&PROPERTY_USAGE_STORAGE and property.name not in ["resource_name","resource_path","resource_local_to_scene","script"]:check(old_shapes[i].shape.get(property.name)==new_shapes[i].shape.get(property.name),pair[1]+" collision dimensions unchanged")
		source.free();optimized.free()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"max_position_error_m":maximum_position_error,"max_colour_error":maximum_color_error,"scope":"Six vegetation meshes: all base vertices retained, material colours encoded into vertex colours, all collision properties retained. Native render LOD regenerated; visual comparison is separate."}
	NavalStorage.write_json("res://work/afghan-foliage-validation.json",report);print("AFGHAN_FOLIAGE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
