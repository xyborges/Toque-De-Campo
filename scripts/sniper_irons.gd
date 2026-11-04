extends RefCounted
class_name GameSniperIrons

# The imported sniper's native axis is +X; its parent rotates it into -Z.
# Only iron sights are added here. The detachable optic is a separate module.
const NATIVE_SIGHT_Y := 0.118

static func install(model: Node3D) -> void:
	var rig:=Node3D.new()
	rig.name="IronSightAssembly"
	model.add_child(rig)
	var dark:=WarArtStyle.material("gunmetal")
	var steel:=WarArtStyle.material("bare_metal")
	# Rear post, open notch. The top of both sights is in the same plane.
	_box(rig,"RearBase",Vector3(-.184,.078,0),Vector3(.035,.034,.060),dark)
	for side in [-1,1]:
		_box(rig,"RearEar",Vector3(-.184,.108,side*.022),Vector3(.013,.028,.012),dark)
	_box(rig,"RearWhite",Vector3(-.184,.110,0),Vector3(.012,.012,.002),steel)
	# Front post, inside two protective ears.
	_box(rig,"FrontBase",Vector3(.385,.079,0),Vector3(.031,.029,.052),dark)
	for side in [-1,1]:
		_box(rig,"FrontEar",Vector3(.385,.103,side*.020),Vector3(.012,.030,.010),dark)
	_box(rig,"FrontBlade",Vector3(.385,NATIVE_SIGHT_Y-.010,0),Vector3(.010,.030,.004),steel)
	var rear:=Marker3D.new();rear.name="RearIron";rear.position=Vector3(-.184,NATIVE_SIGHT_Y,0);rig.add_child(rear)
	var front:=Marker3D.new();front.name="FrontIron";front.position=Vector3(.385,NATIVE_SIGHT_Y,0);rig.add_child(front)

static func _box(parent: Node3D,label: String,at: Vector3,size: Vector3,mat: Material) -> void:
	var shape:=BoxMesh.new();shape.size=size
	var m:=MeshInstance3D.new();m.name=label;m.mesh=shape;m.position=at;m.material_override=mat
	parent.add_child(m)
