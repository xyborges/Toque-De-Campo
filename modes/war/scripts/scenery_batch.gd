extends RefCounted
class_name WarSceneryBatch

# Only the saved, static authoring layer is batched. Colliders, markers and
# library scenes remain intact; gameplay vehicles/characters never enter it.
static func build(layer: Node3D) -> void:
	var groups: Dictionary={}
	for mesh: MeshInstance3D in layer.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.visible: continue
		var p:=mesh.global_position
		var key:="%s:%s:%s:%s:%s:%s:%s"%[mesh.mesh.get_instance_id(),mesh.material_override.get_instance_id() if mesh.material_override else 0,floori(p.x/100),floori(p.z/100),mesh.visibility_range_begin,mesh.visibility_range_end,mesh.cast_shadow]
		if not groups.has(key): groups[key]=[]
		groups[key].append(mesh)
	var saved:=0
	for members: Array in groups.values():
		if members.size()<2: continue
		var source:=members[0] as MeshInstance3D
		var pool:=MultiMesh.new();pool.transform_format=MultiMesh.TRANSFORM_3D;pool.mesh=source.mesh;pool.instance_count=members.size()
		var node:=MultiMeshInstance3D.new();node.name="ObjetosInstanciados";node.multimesh=pool;node.material_override=source.material_override
		node.cast_shadow=source.cast_shadow;node.visibility_range_begin=source.visibility_range_begin;node.visibility_range_end=source.visibility_range_end
		layer.add_child(node)
		for i in members.size(): pool.set_instance_transform(i,node.global_transform.affine_inverse()*members[i].global_transform)
		for mesh: MeshInstance3D in members: mesh.free()
		saved+=members.size()-1
	# Single occurrences cannot benefit from instancing. Bake their rigid
	# geometry by sector/material without merging collision or authoring nodes.
	var sectors: Dictionary={}
	for mesh: MeshInstance3D in layer.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.visible: continue
		var p:=mesh.global_position
		var key:="%s:%s:%s:%s:%s"%[floori(p.x/100),floori(p.z/100),mesh.visibility_range_begin,mesh.visibility_range_end,mesh.cast_shadow]
		if not sectors.has(key): sectors[key]=[]
		sectors[key].append(mesh)
	for key: String in sectors:
		var members: Array=sectors[key]
		if members.size()<2: continue
		var begin: float=members[0].visibility_range_begin;var end: float=members[0].visibility_range_end;var shadow: int=members[0].cast_shadow
		var holder:=Node3D.new();holder.name="SetorDeObjetos";layer.add_child(holder)
		var signature: Array=[];var roots: Array[Node]=[]
		for mesh: MeshInstance3D in members:
			mesh.reparent(holder,true);roots.append(mesh);signature.append([mesh.mesh.resource_path,mesh.transform])
		WarRenderBatch.merge(holder,"scenery190:"+key+":"+str(hash(signature)),roots)
		for mesh: MeshInstance3D in holder.get_children(): mesh.visibility_range_begin=begin;mesh.visibility_range_end=end;mesh.cast_shadow=shadow
		saved+=members.size()-holder.get_child_count()
	layer.set_meta("scenery_draws_saved",saved)
