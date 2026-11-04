extends SceneTree
var checks:=0
var failures: Array[String]=[]
var world: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func hit(point: Vector3,exclusions: Array[RID]=[]) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*150,point-Vector3.UP*150,1,exclusions))
func run() -> void:
	var start:=Time.get_ticks_msec();world=Node3D.new();root.add_child(world);WarWorld.build(world,false)
	await physics_frame;await physics_frame
	var solids:=world.get_node("EnvironmentSolids") as StaticBody3D
	var exclude: Array[RID]=[solids.get_rid()]
	var range_min:=1000.;var range_max:=-1000.;var slopes: Array[float]=[]
	for z in range(-850,851,50):
		for x in range(-850,851,50):
			var h:=WarTerrain.height_at(x,z);range_min=minf(range_min,h);range_max=maxf(range_max,h)
			var dx:=WarTerrain.height_at(x+2,z)-WarTerrain.height_at(x-2,z);var dz:=WarTerrain.height_at(x,z+2)-WarTerrain.height_at(x,z-2)
			slopes.append(rad_to_deg(atan(Vector2(dx,dz).length()/4)))
	check(range_max-range_min>40,"battlefield has more than forty metres of true height variation")
	for team in 2:
		var base: Vector3=WarRules.BASES[team];var maximum:=0.
		for x in [-45.,0.,45.]:
			for z in [-35.,0.,35.]: maximum=maxf(maximum,absf(WarTerrain.height_at(base.x+x,base.z+z)))
		check(maximum<.001,"team base remains level with spawn and vehicle apron: "+str(team))
	var foundation_error:=0.;var coverage_error:=0.
	for building: Dictionary in world.get_meta("war_buildings",[]):
		var point: Vector3=building.position;var half: Vector2=building.half;var max_gap:=-100.
		for x in [-half.x,0.,half.x]:
			for z in [-half.y,0.,half.y]:
				var query_point:=point+Vector3(x,0,z);var result:=hit(query_point,exclude)
				if result.is_empty(): failures.append("missing foundation ground: "+str(point));continue
				max_gap=maxf(max_gap,float(building.foundation_bottom)-float(result.position.y));foundation_error=maxf(foundation_error,absf(float(result.position.y)-WarTerrain.height_at(query_point.x,query_point.z)))
		check(max_gap<=.025,"actual terrain reaches all foundation corners: "+str(point))
		if building.kind=="house":
			var query:=PhysicsRayQueryParameters3D.create(point+Vector3(0,.65,1),point+Vector3(4.5,.65,1),1)
			var result:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not result.is_empty() and absf(float(result.position.x)-(point.x+2.6))<.10,"chimney collision continues down to the floor: "+str(point))
	for support: Dictionary in world.get_meta("war_roof_supports",[]):
		var ground:=hit(support.bottom,exclude)
		var root_y: float=ground.get("position",Vector3(0,-1000,0)).y
		var top: Vector3=support.top
		check(support.bottom.y<=root_y+.02 and top.y>=float(support.roof_bottom),"shelter support intersects ground and roof")
		var point:=Vector3(top.x,float(support.roof_bottom)-.10,top.z)
		var query:=PhysicsRayQueryParameters3D.create(point-Vector3.RIGHT*.35,point+Vector3.RIGHT*.35,1)
		check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"physical post exists immediately below roof")
	var cover_error:=0.
	for point: Vector3 in world.get_meta("war_cover_feet",[]):
		var result:=hit(point,exclude)
		if result.is_empty(): cover_error=1000.;break
		cover_error=maxf(cover_error,absf(point.y-float(result.position.y)))
	check(cover_error<.025,"each field sandbag stack rests on its actual terrain point")
	var road:=world.get_meta("war_road_mesh") as ArrayMesh
	var vertices: PackedVector3Array=road.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),17):
		var point: Vector3=vertices[i];var ground:=hit(point,exclude)
		if ground.is_empty(): failures.append("road lost terrain");continue
		coverage_error=maxf(coverage_error,absf(point.y-float(ground.position.y)-.025))
	check(coverage_error<.025,"road follows physical terrain instead of suspended boxes")
	var seam_error:=0.
	for boundary in [-300.,300.]:
		for v in range(-290,291,20):
			for point in [Vector2(boundary-.01,v),Vector2(boundary+.01,v),Vector2(v,boundary-.01),Vector2(v,boundary+.01)]:
				var position:=WarTerrain.point(point.x,point.y);var result:=hit(position,exclude)
				if not result.is_empty(): seam_error=maxf(seam_error,absf(position.y-float(result.position.y)))
	check(seam_error<.025,"fine/coarse seams agree with actual collision surfaces")
	check(int(world.get_meta("war_tree_count"))>1800,"denser trees share server-side trunk collisions")
	var outside:=hit(Vector3(1250,0,-1100),exclude)
	check(not outside.is_empty(),"distant land has real projectile collision beyond playable border")
	var report:={"checks":checks,"failures":failures,"height_min":range_min,"height_max":range_max,"foundation_physics_error":foundation_error,"road_physics_error":coverage_error,"seam_physics_error":seam_error,"trees":world.get_meta("war_tree_count"),"elapsed_ms":Time.get_ticks_msec()-start}
	NavalStorage.write_json("res://tests/war-map169-contact-results.json",report);print(JSON.stringify(report));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
