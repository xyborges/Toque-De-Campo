extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var mesh: NavigationMesh=load("res://modes/battle_royale/navigation/prepared/outdoor.res")
	var map:=NavigationServer3D.map_create();NavigationServer3D.map_set_use_async_iterations(map,false);NavigationServer3D.map_set_cell_size(map,.2);NavigationServer3D.map_set_cell_height(map,.1)
	NavigationServer3D.map_set_active(map,true)
	var region:=NavigationServer3D.region_create();NavigationServer3D.region_set_navigation_mesh(region,mesh);NavigationServer3D.region_set_map(region,map)
	for i in 10:
		await physics_frame;NavigationServer3D.map_force_update(map)
		var point:=mesh.get_vertices()[mesh.get_polygon(0)[0]]
		print("PROBE ",i," ",NavigationServer3D.map_get_iteration_id(map)," point ",point," nearest ",NavigationServer3D.map_get_closest_point(map,point)," polys ",mesh.get_polygon_count())
	NavigationServer3D.free_rid(region);NavigationServer3D.free_rid(map);quit()
