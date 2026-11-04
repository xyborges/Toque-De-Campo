extends "res://tests/afghan_interiors_validation.gd"
func run() -> void:
	world=Node3D.new();root.add_child(world)
	var map:=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame
	for entry: Dictionary in MAP.building_layout():
		if not ((absf(entry.position.x-533.624)<.1) or absf(entry.position.x+706.2925)<.1 or absf(entry.position.x+157.0354)<.1):continue
		var id: String=MAP.BUILDINGS[int(entry.variant)]
		var piece: Node3D
		for child in map.get_children():
			if child is Node3D and child.has_meta("library_id") and str(child.get_meta("library_id"))==id and child.position.distance_to(entry.position)<.1:piece=child;break
		print("ENTRY ",entry)
		for z in [0.,2.,4.,8.,10.,12.,14.]:
			var p: Vector3=piece.to_global(Vector3(0,0,z));print("GROUND ",z," ",MAP.height_at(p.x,p.z)," RAW ",MAP.LAND.rawheight(p.x,p.z)," ROAD ",MAP.LAND._near_road(Vector2(p.x,p.z)))
		await test_piece(piece,id,str(entry.position))
		var last: Dictionary=cases[-1];print("PROBE_CASE ",JSON.stringify(last))
	world.free();quit()
