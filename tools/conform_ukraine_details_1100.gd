extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var source:="res://modes/war/scenes/detalhamento_190.tscn"
	var scene:=load(source) as PackedScene;var layer:=scene.instantiate() as Node3D
	var changes: Array[Dictionary]=[]
	# Preserve every authored object and orientation. Only correct ground
	# origins left at old hill heights before the graded port roads existed.
	for node in layer.get_children():
		if not node is Node3D or str(node.get_meta("library_id","")) not in ["fachada_atingida","laje_desabada","entulho_tijolos","carro_carbonizado"]:continue
		var height:=WarTerrain._base(node.position.x,node.position.z)
		if absf(height-node.position.y)<.5:continue
		changes.append({"name":node.name,"before":node.position.y,"after":height});node.position.y=height
	var packed:=PackedScene.new();packed.pack(layer);var result:=ResourceSaver.save(packed,source)
	NavalStorage.write_json("res://work/ukraine-building-conform.json",{"ok":result==OK,"changes":changes});print("CONFORMED ",changes.size()," save=",result)
	layer.free();quit(0 if result==OK else 1)
