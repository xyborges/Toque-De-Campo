extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path:="res://modes/war/scenes/detalhamento_190.tscn";var layout:=load(path).instantiate() as Node3D;root.add_child(layout)
	if layout.get_meta("ground_conformed",false): layout.free();quit();return
	var count:=0
	for node: Node3D in layout.find_children("*","Node3D",true,false):
		if node.get_meta("library_id","") not in ["carro_carbonizado","laje_desabada","entulho_tijolos","cratera_impacto"]: continue
		var p:=node.global_position
		var normal:=Vector3(WarTerrain.height_at(p.x-3,p.z)-WarTerrain.height_at(p.x+3,p.z),6,WarTerrain.height_at(p.x,p.z-3)-WarTerrain.height_at(p.x,p.z+3)).normalized()
		var rotation_y:=node.rotation.y
		if node.get_meta("library_id","")!="cratera_impacto": node.position.y=WarTerrain.height_at(p.x,p.z)
		node.basis=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,rotation_y);count+=1
	layout.set_meta("ground_conformed",true)
	var packed:=PackedScene.new();assert(packed.pack(layout)==OK);assert(ResourceSaver.save(packed,path)==OK)
	layout.queue_free();await process_frame;await process_frame;print("GROUND_CONFORMED ",count);quit()
