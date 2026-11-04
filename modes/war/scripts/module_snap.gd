@tool
extends RefCounted
class_name WarModuleSnap

static func sockets(object: Node3D) -> Array[Node3D]:
	var result: Array[Node3D]=[]
	var holder:=object.get_node_or_null("Encaixes")
	if holder:
		for child in holder.get_children():
			if child is Marker3D: result.append(child)
	return result

static func compatible(a: Node3D,b: Node3D) -> bool:
	var pa:=str(a.get_meta("profile",""));var pb:=str(b.get_meta("profile",""))
	return (pa==pb or "surface" in [pa,pb] and pa in ["road","quay","surface"] and pb in ["road","quay","surface"]) and absf(float(a.get_meta("width",0))-float(b.get_meta("width",0)))<=1.1

static func nearest(object: Node3D,scene: Node3D,max_distance:=14.) -> Dictionary:
	var best:=max_distance*max_distance;var result: Dictionary={}
	for other in scene.find_children("*","Node3D",true,false):
		if other==object or object.is_ancestor_of(other) or other.is_ancestor_of(object) or not other.has_node("Encaixes"): continue
		if other.owner==null and other!=scene: continue
		for from in sockets(object):
			for to in sockets(other):
				if not compatible(from,to): continue
				var distance:=from.global_position.distance_squared_to(to.global_position)
				if distance>=best: continue
				best=distance
				var relative:=object.global_transform.affine_inverse()*from.global_transform
				# Match the socket orientation without inheriting the other module's scale.
				var rotation:=to.global_basis.orthonormalized()*Basis(Vector3.UP,PI)*relative.basis.orthonormalized().inverse()
				var basis:=rotation*Basis.from_scale(object.global_basis.get_scale())
				var target:=Transform3D(basis,to.global_position-basis*relative.origin)
				result={"transform":target,"source":from,"target":to,"distance":sqrt(best)}
	return result
