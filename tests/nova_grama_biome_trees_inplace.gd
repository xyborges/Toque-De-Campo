extends RefCounted

# Test alternative: keep unchanged batches; reuse the existing node for the
# largest resulting group and allocate an extra node only for mixed batches.
var originals: Array[Dictionary]=[]

func activate(lab) -> Dictionary:
	var world: Node=lab.get_parent();var lookup: Dictionary={}
	for green in [false,true]:
		for variant in 3:
			for low in [false,true]: lookup[WarVegetation.tree_mesh(green,variant,low)]={"green":green,"variant":variant,"low":low}
	var stats:={"unchanged_batches":0,"mutated_batches":0,"extra_batches":0,"field_to_green":0,"burn_to_charred":0}
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if node in lab.generated or node.multimesh==null or not lookup.has(node.multimesh.mesh) or node.material_override!=EnvironmentKit.materials.get("war_vegetation169"): continue
		var source: Dictionary=lookup[node.multimesh.mesh];var groups: Dictionary={true:[],false:[]};var changed:=0
		for i in node.multimesh.instance_count:
			var transform:=node.multimesh.get_instance_transform(i);var pos:=node.to_global(transform.origin)
			var biome: int=lab.biome(Vector2(pos.x,pos.z));var green: bool=source.green
			if biome==0: green=true
			elif biome==1: green=false
			if green!=source.green:
				changed+=1
				if green: stats.field_to_green+=1
				else: stats.burn_to_charred+=1
			var tint:=node.multimesh.get_instance_color(i) if node.multimesh.use_colors else Color.WHITE
			groups[green].append({"transform":transform,"color":tint})
		if changed==0: stats.unchanged_batches+=1;continue
		var original:=node.multimesh
		originals.append({"node":node,"multimesh":original,"aabb":node.custom_aabb})
		# A burnt group's original bounds may be too narrow for live foliage.
		# Expand equally for its near and far representation to limit popping.
		var bounds:=node.custom_aabb
		if bounds.size!=Vector3.ZERO: bounds=AABB(bounds.position-Vector3.ONE*4.,bounds.size+Vector3.ONE*8.)
		var primary: bool=groups[true].size()>=groups[false].size()
		node.multimesh=_make_mesh(original,groups[primary],primary,source);node.custom_aabb=bounds;stats.mutated_batches+=1
		var other: bool=not primary
		if not groups[other].is_empty():
			var clone:=MultiMeshInstance3D.new();clone.name="NovaBiomeMixedTrees";clone.multimesh=_make_mesh(original,groups[other],other,source)
			clone.material_override=node.material_override;clone.transform=node.transform;clone.custom_aabb=bounds
			clone.visibility_range_begin=node.visibility_range_begin;clone.visibility_range_end=node.visibility_range_end
			clone.visibility_range_begin_margin=node.visibility_range_begin_margin;clone.visibility_range_end_margin=node.visibility_range_end_margin
			clone.visibility_range_fade_mode=node.visibility_range_fade_mode;clone.cast_shadow=node.cast_shadow;clone.layers=node.layers
			node.get_parent().add_child(clone);clone.visible=node.visible;lab.generated.append(clone);stats.extra_batches+=1
	return stats

func _make_mesh(original: MultiMesh,entries: Array,green: bool,source: Dictionary) -> MultiMesh:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=original.use_colors
	mm.mesh=WarVegetation.tree_mesh(green,source.variant,source.low);mm.instance_count=entries.size()
	for i in entries.size():
		mm.set_instance_transform(i,entries[i].transform)
		if mm.use_colors: mm.set_instance_color(i,entries[i].color)
	return mm

func restore() -> void:
	for item in originals:
		if is_instance_valid(item.node): item.node.multimesh=item.multimesh;item.node.custom_aabb=item.aabb
	originals.clear()
