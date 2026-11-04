extends RefCounted

# Test-only material switch, no node per blade or change to terrain/physics.
# Do not use in the live game until render/thermal/night/biome tests pass.
var changed: Array[Dictionary]=[]
var material: ShaderMaterial

func apply(world: Node3D) -> Dictionary:
	if not changed.is_empty(): return {"ok":false,"reason":"already active"}
	material=ShaderMaterial.new();material.shader=load("res://tests/nova_grass_existing.gdshader")
	var near:=0;var far:=0
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh==null: continue
		var mesh:=node.multimesh.mesh
		if mesh!=WarVegetation.grass_mesh() and mesh!=WarVegetation.grass_low_mesh(): continue
		changed.append({"node":weakref(node),"original":node.material_override})
		node.material_override=material
		if mesh==WarVegetation.grass_mesh(): near+=1
		else: far+=1
	return {"ok":near>0 and far>0,"near":near,"far":far}

func restore() -> void:
	for entry: Dictionary in changed:
		var node: MultiMeshInstance3D=entry.node.get_ref()
		# Don't overwrite another system's intentional material change.
		if is_instance_valid(node) and node.material_override==material: node.material_override=entry.original
	changed.clear();material=null
