extends RefCounted
class_name WarMapContent
const LAYOUT:="res://modes/war/scenes/map_additions.tscn"
static func instantiate(parent: Node3D,path: String,position: Vector3,visuals: bool) -> Node3D:
	var scene: PackedScene=load(path)
	var result:=scene.instantiate() as Node3D
	result.position=position;parent.add_child(result)
	if not visuals:
		# Only presentation is omitted on the dedicated server. Authored
		# transforms, collision shapes and surface metadata stay identical.
		for mesh: GeometryInstance3D in result.find_children("*","GeometryInstance3D",true,false): mesh.free()
		for light: Light3D in result.find_children("*","Light3D",true,false): light.free()
	return result
static func build(parent: Node3D,visuals: bool) -> void:
	if ResourceLoader.exists(LAYOUT):
		var layer:=instantiate(parent,LAYOUT,Vector3.ZERO,visuals)
		if visuals: WarSceneryBatch.build(layer)
