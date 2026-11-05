extends RefCounted
## One template per module. Repeated objects are flattened into the map's
## sector batches and collision bodies, without keeping a scene tree per item.
const MODULES := {
	"janela_grade": preload("res://modes/war/library/favela_janela_grade.tscn"),
	"janela_madeira": preload("res://modes/war/library/favela_janela_madeira.tscn"),
	"porta_entrada": preload("res://modes/war/library/favela_porta_entrada.tscn"),
	"sacada": preload("res://modes/war/library/favela_sacada.tscn"),
	"laje_domestica": preload("res://modes/war/library/favela_laje_domestica.tscn"),
	"laje_obra": preload("res://modes/war/library/favela_laje_obra.tscn"),
	"escada_externa": preload("res://modes/war/library/favela_escada_externa.tscn"),
	"puxadinho_chapa": preload("res://modes/war/library/favela_puxadinho_chapa.tscn"),
	"carro_compacto": preload("res://modes/war/library/favela_carro_compacto.tscn"),
}
static var modules: Dictionary={}

static func place(kit: EnvironmentKit, id: String, pose: Transform3D, solid:=false) -> void:
	if not solid and not kit.visuals:return
	if not modules.has(id):
		var scene: PackedScene=MODULES[id]
		var template:=scene.instantiate() as Node3D
		var model:=template.get_node("Forma") as MeshInstance3D
		var shapes: Array[Dictionary]=[]
		for node: CollisionShape3D in template.find_children("*","CollisionShape3D",true,false):
			shapes.append({"shape":node.shape,"pose":node.transform,"surface":node.get_meta("surface","")})
		modules[id]={"mesh":model.mesh,"distance":model.visibility_range_end,"shapes":shapes}
		EnvironmentKit.materials["favela_module_"+id]=model.material_override
		template.free()
	var module: Dictionary=modules[id]
	var sector_size:=85.0 if id=="puxadinho_chapa" else 48.0
	kit._instance(module.mesh,"favela_module_"+id,pose,false,null,module.distance,
		{"shadows":false,"optional":not solid,"sector":sector_size})
	if not solid:return
	for shape: Dictionary in module.shapes:
		var transform: Transform3D=pose*shape.pose
		var resource: Shape3D=shape.shape
		if resource is ConvexPolygonShape3D:
			# Stair rise and run vary, but the sector collider stays unscaled.
			var points:=PackedVector3Array()
			for point: Vector3 in resource.points:
				var fitted_point:=transform.basis*point
				if id=="escada_externa" and point.z>-.01:
					# Carry the sloped collision under the ground at the first riser.
					fitted_point+=Vector3(0,-.13,.23)
				elif id=="escada_externa" and point.z< -8.59:
					fitted_point.z-=.15
				points.append(fitted_point)
			var fitted:=ConvexPolygonShape3D.new()
			fitted.points=points
			resource=fitted
			transform.basis=Basis.IDENTITY
		kit._collider("Favela_"+id,resource,transform,shape.surface)
