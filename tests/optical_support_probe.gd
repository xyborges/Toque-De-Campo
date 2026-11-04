extends RefCounted
## Independent rendered-geometry contact audit; never used during gameplay.
static var faces: Dictionary={}
static func measure(module: Node3D,root_node: Node3D) -> Array:
	var triangles:=PackedVector3Array()
	var inverse:=GameAttachmentManager.relative_transform(module,root_node).affine_inverse()
	for part: MeshInstance3D in root_node.find_children("*","MeshInstance3D",true,false):
		if not part.mesh:continue
		var cursor: Node=part;var skip:=false
		while cursor and cursor!=root_node:
			if cursor.name in ["AttachmentSockets","IronSightAssembly"]:skip=true;break
			cursor=cursor.get_parent()
		if skip and not (part.name=="ReceiverAdapter" and module.is_ancestor_of(part)):continue
		var key:=part.mesh.get_instance_id()
		if not faces.has(key):faces[key]=part.mesh.get_faces()
		var pose:=inverse*GameAttachmentManager.relative_transform(part,root_node)
		for vertex: Vector3 in faces[key]:triangles.append(pose*vertex)
	var result: Array=[]
	for contact: Dictionary in module.get_meta("support_contacts",[]):
		var foot:=module.get_node(str(contact.foot)) as MeshInstance3D
		var size: Vector3=foot.mesh.size
		var highest:=-INF
		for offset: Vector2 in [Vector2.ZERO,Vector2(-.45,-.45),Vector2(-.45,.45),Vector2(.45,-.45),Vector2(.45,.45)]:
			var ray:=Vector3(foot.position.x+offset.x*size.x,2.,foot.position.z+offset.y*size.z)
			for i in range(0,triangles.size(),3):
				var hit: Variant=Geometry3D.ray_intersects_triangle(ray,Vector3.DOWN,triangles[i],triangles[i+1],triangles[i+2])
				if hit!=null:highest=maxf(highest,Vector3(hit).y)
		var actual:=foot.position.y-size.y*foot.scale.y*.5
		result.append({"foot":contact.foot,"gap_m":actual-highest,"valid":is_finite(highest) and absf(actual-highest)<.003})
	return result
