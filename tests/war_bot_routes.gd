extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func run() -> void:
	var game:=WarGame.new();var world:=Node3D.new();root.add_child(world);game.world_root=world
	var barrier:=StaticBody3D.new();barrier.position=WarTerrain.point(-400,300)+Vector3.UP
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12,2,28);shape.shape=box
	barrier.add_child(shape);world.add_child(barrier)
	var thin_wall:=StaticBody3D.new();thin_wall.position=WarTerrain.point(-351,300)+Vector3.UP
	var thin_shape:=CollisionShape3D.new();var thin_box:=BoxShape3D.new();thin_box.size=Vector3(.1,2,16);thin_shape.shape=thin_box
	thin_wall.add_child(thin_shape);world.add_child(thin_wall)
	var high_roof:=StaticBody3D.new();high_roof.position=WarTerrain.point(400,300)+Vector3.UP*5
	var roof_shape:=CollisionShape3D.new();var roof_box:=BoxShape3D.new();roof_box.size=Vector3(10,.3,10);roof_shape.shape=roof_box
	high_roof.add_child(roof_shape);world.add_child(high_roof)
	var director:=WarBotDirector.new();var nav:=WarBotDirector.BotRoutes.new()
	var start:=Time.get_ticks_usec();nav.setup(game);var setup_ms:=(Time.get_ticks_usec()-start)*.001
	check(nav.grid.region.size==Vector2i(351,251),"regional navigation covers both bases and three objectives")
	check(not nav.walkable(nav.point_id(barrier.global_position)),"existing standing-height static collider blocks bot path")
	check(not nav.walkable(nav.point_id(thin_wall.global_position)),"thin wall between cell centres remains represented in navigation")
	check(nav.walkable(nav.point_id(high_roof.global_position)),"high roof does not block a path on the ground")
	var from:=nav.nearest(WarTerrain.point(-430,300));var to:=nav.nearest(WarTerrain.point(-370,300))
	var path:=nav.grid.get_id_path(from,to)
	check(path.size()>2,"path goes around a solid obstacle")
	var enters_barrier:=false
	for id in path:
		var p:=nav.world_point(id)
		if absf(p.x+400)<6.4 and absf(p.z-300)<14.4: enters_barrier=true
	check(not enters_barrier,"planned route never traverses the expanded collider footprint")
	for objective in ["A","B","C"]:
		var p: Vector3=WarRules.OBJECTIVES[objective].position
		var id:=nav.nearest(WarTerrain.point(p.x,p.z))
		check(nav.walkable(id),objective+" has reachable terrain navigation cell")
		check(absf(nav.world_point(id).y-WarTerrain.height_at(nav.world_point(id).x,nav.world_point(id).z)-.08)<.0001,objective+" uses WarTerrain height instead of the desert height function")
	game.offline_operation=false;director.setup(game)
	check(not director.enabled,"director remains disabled outside explicit offline operations")
	director.free();game.free();world.queue_free();await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"setup_ms":setup_ms,"grid_cells":351*251}
	NavalStorage.write_json("res://tests/war-bot-routes-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
