extends RefCounted

# Compare 40 m cells against 20 m cells while retaining every original
# transform, mesh, material and color. Grouping may change frustum/LOD culling.
func merge(lab) -> Dictionary:
	var groups: Dictionary={};var old: Array[MultiMeshInstance3D]=[]
	for child in lab.generated:
		if not child is MultiMeshInstance3D or not child.has_meta("nova_detail"): continue
		var node:=child as MultiMeshInstance3D;old.append(node)
		for i in node.multimesh.instance_count:
			var transform:=node.multimesh.get_instance_transform(i)
			var at:=node.to_global(transform.origin)
			var cell:=Vector2i(floori(at.x/40.),floori(at.z/40.))
			var key: String="%s:%s:%s:%s:%s"%[cell,node.multimesh.mesh.get_instance_id(),node.material_override.get_instance_id(),node.visibility_range_begin,node.visibility_range_end]
			if not groups.has(key): groups[key]={"node":node,"entries":[]}
			var tint:=node.multimesh.get_instance_color(i) if node.multimesh.use_colors else Color.WHITE
			groups[key].entries.append({"transform":transform,"color":tint})
	var instance_count:=0
	for data: Dictionary in groups.values():
		var source: MultiMeshInstance3D=data.node;var entries: Array=data.entries
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=source.multimesh.use_colors;mm.mesh=source.multimesh.mesh;mm.instance_count=entries.size()
		for i in entries.size():
			mm.set_instance_transform(i,entries[i].transform)
			if mm.use_colors: mm.set_instance_color(i,entries[i].color)
		var node:=MultiMeshInstance3D.new();node.name="NovaGramaMergedCell";node.multimesh=mm;node.material_override=source.material_override
		node.transform=source.transform;node.visibility_range_begin=source.visibility_range_begin;node.visibility_range_end=source.visibility_range_end
		node.cast_shadow=source.cast_shadow;node.layers=source.layers;source.get_parent().add_child(node);lab.generated.append(node)
		instance_count+=entries.size()
	for node in old: lab.generated.erase(node);node.hide();node.queue_free()
	return {"previous_batches":old.size(),"merged_batches":groups.size(),"instances":instance_count,"cell_metres":40}
