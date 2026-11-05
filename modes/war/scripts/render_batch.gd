extends RefCounted
class_name WarRenderBatch

static var cache: Dictionary={}

# Merge only rigid decoration. Animated pivots, marker transforms, collision
# shapes and independently rotating wheels stay in the original hierarchy.
static func merge(parent: Node3D,key: String,roots: Array[Node],protection_slot:="") -> void:
	if roots.is_empty(): return
	if not cache.has(key):
		var groups: Dictionary={}
		for root in roots: _collect(root,root.transform,groups)
		var built: Array[Dictionary]=[]
		for group: Dictionary in groups.values():
			var surface:=SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for piece: Dictionary in group.pieces:
				# Mixing indexed primitives and non-indexed authored meshes would
				# leave the latter's vertices unreferenced in the merged index buffer.
				if piece.mesh is ArrayMesh and piece.mesh.surface_get_format(piece.surface)&Mesh.ARRAY_FORMAT_INDEX==0:
					var indexed:=SurfaceTool.new()
					indexed.create_from(piece.mesh,piece.surface);indexed.index()
					surface.append_from(indexed.commit(),0,piece.transform)
				else: surface.append_from(piece.mesh,piece.surface,piece.transform)
			surface.set_material(group.material)
			built.append({"mesh":surface.commit(),"heat":group.heat})
		cache[key]=built
	for root in roots:
		parent.remove_child(root)
		root.free()
	for data: Dictionary in cache[key]:
		var node:=MeshInstance3D.new()
		node.name="RigidDetail_"+str(data.heat)
		node.mesh=data.mesh
		node.set_meta("uniform_attachment",true)
		node.set_meta("thermal_region",data.heat)
		if not protection_slot.is_empty():node.set_meta("protection_slot",protection_slot)
		node.visibility_range_end=110 if key.begins_with("uniform:") else 950
		if key.begins_with("uniform:"): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Body still casts; small gear keeps receiving light.
		parent.add_child(node)

static func _collect(node: Node3D,relative: Transform3D,groups: Dictionary,heat := "body") -> void:
	var label:=str(node.name)
	if label.begins_with("Engine"): heat="engine"
	elif label.contains("Coaxial"): heat="coax"
	elif label.begins_with("Gun") or label.begins_with("Muzzle"): heat="gun"
	if node is MeshInstance3D and node.mesh:
		for index in node.mesh.get_surface_count():
			var mat: Material=node.get_active_material(index)
			var key:=str(mat.get_instance_id() if mat else 0)+":"+heat
			if not groups.has(key): groups[key]={"material":mat,"heat":heat,"pieces":[]}
			groups[key].pieces.append({"mesh":node.mesh,"surface":index,"transform":relative})
	for child in node.get_children():
		if child is Node3D: _collect(child,relative*child.transform,groups,heat)

static func uniform(actor: GamePlayer,team: int,role: String) -> void:
	for label in actor.avatar_parts:
		var part: Node3D=actor.avatar_parts[label]
		var groups: Dictionary={"":[],"vest":[],"helmet":[]}
		for child in part.get_children():
			if child is MeshInstance3D and child.has_meta("uniform_attachment"):groups[str(child.get_meta("protection_slot",""))].append(child)
		for slot: String in groups:
			var attachments: Array[Node]=[];attachments.assign(groups[slot])
			merge(part,"uniform:%d:%s:%s:%s"%[team,role,label,slot],attachments,slot)

static func vehicle(actor: WarVehicle) -> void:
	for label in ["hull","turret","elevation"]:
		var parent: Node3D=actor if label=="hull" else (actor.turret if label=="turret" else actor.elevation)
		var attachments: Array[Node]=[]
		for child in parent.get_children():
			if child is MeshInstance3D and child not in actor.wheels: attachments.append(child)
		merge(parent,"vehicle:%s:%d:%s"%[actor.kind,actor.team,label],attachments)
