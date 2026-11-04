extends RefCounted

func run(lab) -> Dictionary:
	var green:=WarVegetation.grass_mesh();var far:=WarVegetation.grass_low_mesh()
	var examined:=0;var incorrectly_burnt:=0;var green_cells:=0
	for node in lab.generated:
		if not node is MultiMeshInstance3D or node.multimesh==null: continue
		if node.multimesh.mesh!=green and node.multimesh.mesh!=far and node.material_override!=lab.grass_material: continue
		green_cells+=1
		for i in node.multimesh.instance_count:
			var transform: Transform3D=node.multimesh.get_instance_transform(i)
			var point: Vector3=node.to_global(transform.origin)
			examined+=1
			if lab.biome(Vector2(point.x,point.z))==1: incorrectly_burnt+=1
	return {"grass_representations_examined":examined,"batches":green_cells,"grass_in_burnt":incorrectly_burnt,"note":"Includes both original near/far representations; excludes dry grass meshes authored separately."}
