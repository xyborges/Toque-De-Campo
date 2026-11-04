extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path:="res://modes/war/scenes/detalhamento_190.tscn"
	var layout:=load(path).instantiate() as Node3D;root.add_child(layout)
	if layout.has_node("CraterasUrbanas"): layout.free();quit();return
	var group:=Node3D.new();group.name="CraterasUrbanas";layout.add_child(group);group.owner=layout
	for town: Vector2 in [Vector2(-610,610),Vector2(610,-610),WarUrbanLayout.CENTRES[0],WarUrbanLayout.CENTRES[1]]:
		for i in 3:
			var p:=town+Vector2(-43+i*37,-54)
			var node:=load(WarPrefabFactory.PATH+"cratera_impacto.tscn").instantiate() as Node3D
			node.position=WarTerrain.point(p.x,p.y);group.add_child(node,true);node.owner=layout
	var packed:=PackedScene.new();assert(packed.pack(layout)==OK);assert(ResourceSaver.save(packed,path)==OK)
	layout.queue_free();await process_frame;await process_frame;print("URBAN_CRATERS_ADDED 12");quit()
