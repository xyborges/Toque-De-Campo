extends RefCounted

# Optional test of reclassifying existing batched trees. No physics shapes or
# authored user scenes are altered. High/low LOD instances are both replaced.
func activate(lab) -> Dictionary:
	var world: Node=lab.get_parent();var lookup: Dictionary={}
	for green in [false,true]:
		for variant in 3:
			for low in [false,true]: lookup[WarVegetation.tree_mesh(green,variant,low)]={"green":green,"variant":variant,"low":low}
	var stats:={"batches":0,"field_to_green":0,"burn_to_charred":0,"unchanged":0}
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if node in lab.generated or node.multimesh==null or not lookup.has(node.multimesh.mesh) or node.material_override!=EnvironmentKit.materials.get("war_vegetation169"): continue
		var source: Dictionary=lookup[node.multimesh.mesh];var groups: Dictionary={true:[],false:[]}
		for i in node.multimesh.instance_count:
			var transform:=node.multimesh.get_instance_transform(i)
			var pos:=node.to_global(transform.origin);var biome: int=lab.biome(Vector2(pos.x,pos.z))
			var green: bool=source.green
			if biome==0: green=true
			elif biome==1: green=false
			if green!=source.green:
				if green: stats.field_to_green+=1
				else: stats.burn_to_charred+=1
			else: stats.unchanged+=1
			var color:=node.multimesh.get_instance_color(i) if node.multimesh.use_colors else Color.WHITE
			groups[green].append({"transform":transform,"color":color})
		for green in [true,false]:
			var entries: Array=groups[green]
			if entries.is_empty(): continue
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=node.multimesh.use_colors
			mm.mesh=WarVegetation.tree_mesh(green,source.variant,source.low);mm.instance_count=entries.size()
			for i in entries.size():
				mm.set_instance_transform(i,entries[i].transform)
				if mm.use_colors: mm.set_instance_color(i,entries[i].color)
			var clone:=MultiMeshInstance3D.new();clone.name="NovaBiomeTrees";clone.multimesh=mm;clone.material_override=node.material_override
			clone.transform=node.transform;clone.visibility_range_begin=node.visibility_range_begin;clone.visibility_range_end=node.visibility_range_end
			clone.visibility_range_begin_margin=node.visibility_range_begin_margin;clone.visibility_range_end_margin=node.visibility_range_end_margin
			clone.visibility_range_fade_mode=node.visibility_range_fade_mode;clone.custom_aabb=node.custom_aabb;clone.cast_shadow=node.cast_shadow;clone.layers=node.layers
			node.get_parent().add_child(clone);clone.visible=node.visible;lab.generated.append(clone);stats.batches+=1
		lab.legacy.append({"node":node,"visible":node.visible});node.hide()
	return stats
