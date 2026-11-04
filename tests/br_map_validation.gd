extends SceneTree
const Afghan=preload("res://modes/battle_royale/map/afghan_map.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var map:=Afghan.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame;await physics_frame
	check(map.get_child_count()>180,"Terrain and structures present headless")
	check(map.build_metrics.houses==Afghan.building_layout().size() and map.build_metrics.houses>=84,"Settlement structures match current authored layout (at least 84)")
	check(map.build_metrics.terrain_tiles==100,"100 bounded terrain sectors")
	check(Afghan.spawn_candidates().size()>=30,"At least 30 safe spawn candidates")
	check(Afghan.loot_points().size()>130,"Indoor and roof loot positions")
	var space:=world.get_world_3d().direct_space_state
	for p in Afghan.spawn_candidates():
		check(Afghan.accessible(p),"Spawn slope accessible %s"%p)
		var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*15.,p-Vector3.UP*15.,1)
		var hit:=space.intersect_ray(query)
		check(not hit.is_empty(),"Spawn has terrain collision %s"%p)
		if not hit.is_empty():check(absf(hit.position.y-Afghan.height_at(p.x,p.z))<.035,"Spawn mesh/height agreement %s"%p)
		var capsule:=CapsuleShape3D.new();capsule.radius=.38;capsule.height=1.8
		var shape_query:=PhysicsShapeQueryParameters3D.new();shape_query.shape=capsule;shape_query.collision_mask=1;shape_query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*1.)
		check(space.intersect_shape(shape_query,1).is_empty(),"Spawn capsule clear %s"%p)
	for p in Afghan.loot_points():
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.04,p-Vector3.UP*.6,1))
		check(not hit.is_empty(),"Loot supported by floor or roof %s"%p)
	for x in range(-950,951,50):
		for z in range(-950,951,50):
			var p:=Afghan.point(x+.7,z+.9)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*8.,p-Vector3.UP*8.,1))
			if not hit.is_empty() and str(hit.collider.name).begins_with("AfghanTerrain"):
				check(absf(hit.position.y-p.y)<.04,"Authoritative triangle-height consistency %s"%p)
	for p in [Vector3(1050,0,0),Vector3(-1050,0,0),Vector3(0,0,1050),Vector3(0,0,-1050)]:
		check(not Afghan.accessible(p),"Out-of-map not spawn accessible")
		check(space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*500,p-Vector3.UP*500,1)).is_empty(),"No physical terrain beyond playable boundary")
	var report:={"checks":checks,"failures":failures,"metrics":map.build_metrics,"physics":ProjectSettings.get_setting("physics/3d/physics_engine")}
	var f:=FileAccess.open("res://work/br-map-validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("BR_MAP_VALIDATION ",JSON.stringify(report));world.free();quit(0 if failures.is_empty() else 1)
