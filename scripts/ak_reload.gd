extends RefCounted
class_name GameAKReload

# Authored on the existing imported mesh, in its original glTF coordinates.
const GRIP:=Vector3(-.265,-.012,0)
const SUPPORT:=Vector3(.09,.067,0)
const PIVOT:=Vector3(-.13,.032,0)

static func prepare(model: Node3D) -> void:
	if model.has_node("MagazineAssembly"):return
	var magazine:=model.find_child("MagazineGeometry",true,false) as MeshInstance3D
	if magazine:
		var original:=magazine.global_transform
		var pivot:=Node3D.new();pivot.name="MagazineAssembly";model.add_child(pivot);pivot.position=PIVOT
		magazine.reparent(pivot);magazine.global_transform=original
	var bolt:=MeshInstance3D.new();bolt.name="ReloadBolt";var shape:=BoxMesh.new();shape.size=Vector3(.044,.018,.027);bolt.mesh=shape
	bolt.material_override=EnvironmentKit.material("steel:343b37");bolt.position=Vector3(-.145,.102,.037);model.add_child(bolt)

static func apply(model: Node3D,pose: Dictionary) -> void:
	var magazine:=model.get_node_or_null("MagazineAssembly") as Node3D
	if magazine:
		magazine.position=PIVOT+Vector3(pose.magazine_offset);magazine.rotation=Vector3(0,0,float(pose.magazine_tilt));magazine.visible=bool(pose.magazine_visible)
	var bolt:=model.get_node_or_null("ReloadBolt") as Node3D
	if bolt:bolt.position=Vector3(-.145-float(pose.mechanism),.102,.037)

static func hand(model: Node3D,pose: Dictionary,support: bool) -> Vector3:
	return model.to_global(Vector3(pose.hand if support else pose.right_hand))

static func hand_basis(model: Node3D) -> Basis:
	return model.global_basis*Basis(model.get_meta("rest_basis",Basis.IDENTITY)).inverse()
