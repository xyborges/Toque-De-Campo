extends SceneTree

const Candidate=preload("res://tests/nova_grass_existing.gd")
var errors: Array[String]=[]

func check(value: bool,message: String) -> void:
	if not value: errors.append(message)

func _initialize() -> void: run.call_deferred()

func make_batch(parent: Node,mesh: Mesh,material: Material) -> MultiMeshInstance3D:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=1
	mm.set_instance_transform(0,Transform3D.IDENTITY)
	var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material;parent.add_child(node)
	return node

func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var original:=StandardMaterial3D.new()
	var near:=make_batch(world,WarVegetation.grass_mesh(),original)
	var far:=make_batch(world,WarVegetation.grass_low_mesh(),original)
	var other:=make_batch(world,WarVegetation.tree_mesh(true,0,false),original)
	far.hide()
	var candidate:=Candidate.new();var result: Dictionary=candidate.apply(world)
	check(bool(result.ok) and result.near==1 and result.far==1,"applies to both grass LODs")
	check(near.material_override==far.material_override and near.material_override!=original,"uses one shared grass material")
	check(other.material_override==original and not far.visible,"trees and visibility unchanged")
	var changed_elsewhere:=StandardMaterial3D.new();near.material_override=changed_elsewhere
	candidate.restore()
	check(near.material_override==changed_elsewhere and far.material_override==original,"restores only untouched material slots")
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"scope":"isolated materials, not full-map or biome test"}))
	quit(0 if errors.is_empty() else 1)
