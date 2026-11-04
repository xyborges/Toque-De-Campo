extends SceneTree
var used: Array[Rect2]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path:="res://modes/war/scenes/detalhamento_190.tscn";var layout:=load(path).instantiate() as Node3D;root.add_child(layout)
	if layout.get_meta("safe_sites_v2",false): layout.free();quit();return
	WarTerrainEdits.configure([])
	for town: Vector2 in WarUrbanLayout.CENTRES:
		for block in 6:
			var p:=town+Vector2((block%3)*42-42,(block/3)*58-29)
			used.append(Rect2(p-Vector2(16,14),Vector2(32,28)))
	for town: Vector2 in [Vector2(-610,610),Vector2(610,-610),Vector2(-480,-790),Vector2(600,800)]:
		for row in 2:
			for col in 4:
				var p:=town+Vector2(col*39-58,row*65-32)
				used.append(Rect2(p-Vector2(16,13),Vector2(32,26)))
	var moved:=0;var unresolved:=0
	for node: Node3D in layout.find_children("*","Node3D",true,false):
		var id:=str(node.get_meta("library_id",""))
		if id not in ["fachada_atingida","laje_desabada","carro_carbonizado","entulho_tijolos","cratera_impacto"]: continue
		var original:=Vector2(node.position.x,node.position.z);var yaw:=node.rotation.y
		var half: Vector2=Vector2(node.get_meta("footprint",Vector2(6,6)))*.5
		var chosen:=Vector3.INF
		for ring in 18:
			for angle_index in (1 if ring==0 else 12):
				var angle:=angle_index*TAU/12.;var p:=original+Vector2(cos(angle),sin(angle))*ring*6.
				if WarRoads.distance(p)<(18. if id=="fachada_atingida" else 12.): continue
				var rect:=Rect2(p-half,half*2).grow(1.)
				if used.any(func(other):return other.intersects(rect)): continue
				var h:=WarTerrain.height_at(p.x,p.y)
				if h<5.: continue
				var limit:=1.5 if id=="fachada_atingida" else .38
				var valid:=true
				for x in [-1.,1.]:
					for z in [-1.,1.]:
						if absf(WarTerrain.height_at(p.x+x*half.x,p.y+z*half.y)-h)>limit: valid=false
				if not valid: continue
				chosen=Vector3(p.x,h,p.y);used.append(rect);break
			if chosen.is_finite(): break
		if not chosen.is_finite(): unresolved+=1;continue
		if node.position.distance_to(chosen)>1.: moved+=1
		node.position=chosen;node.rotation=Vector3(0,yaw,0)
	if unresolved>0: push_error("No safe placement for "+str(unresolved)+" objects");layout.free();quit(1);return
	layout.set_meta("safe_sites_v2",true)
	var packed:=PackedScene.new();assert(packed.pack(layout)==OK);assert(ResourceSaver.save(packed,path)==OK)
	layout.queue_free();await process_frame;await process_frame;print("SETTLED_OBJECTS ",moved);quit()
