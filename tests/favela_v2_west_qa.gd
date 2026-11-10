extends SceneTree
const TERRAIN=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	check(TOPO.left_gate_links().size()==1,"single access to west")
	check(not TOPO.reachable("mirante","base_norte","central_hub"),"no west bypass")
	var flights:=WEST.plan_steps()
	check(flights.size()==5,"five modular west staircase flights")
	var count:=0
	for flight: Dictionary in flights:
		var poses: Array[Transform3D]=flight["poses"]
		check(poses.size()>=18,"each flight contains many treads")
		count+=poses.size()
		for i in poses.size():
			var pose:Transform3D=poses[i]
			var q:Vector3=pose.origin
			check(absf(q.y-TERRAIN.height_at(q.x,q.z)-.10)<.04,"tread grounded on heightfield")
			check(q.x< -170.0,"all stairs strictly within hillside")
	check(count>=210,"detailed continuous steps across the western hill")
	var houses:=WEST.plan_houses()
	check(houses.size()>=18,"sufficient initial hillside residences")
	check(houses.size()<=105,"house budget limited")
	for house: Dictionary in houses:
		var p:Vector2=house["pos"]
		check(not WEST._near_cliff(p),"houses never intersect boundary cliffs")
		check(not WEST._near_lane(p),"house setback keeps alleys clear")
		check(WEST._house_slope(p)<=2.70,"house site slope within terraced foundation tolerance")
	for i in houses.size():
		for j in range(i+1,houses.size()):
			check((houses[i]["pos"] as Vector2).distance_to(houses[j]["pos"])>=11.3,
				"houses do not overlap")
	var template:=WarPrefabFactory.create("favela_v2_stair_tread")
	check(template!=null,"stair prefab registered in catalogue")
	if template:
		check(template.get_meta("library_id","")=="favela_v2_stair_tread","stair prefab metadata")
		var collision:=template.get_node("ColisaoDegrau") as CollisionShape3D
		check(collision!=null and collision.shape is BoxShape3D,"stair prefab collision")
		template.free()
	var parent:=Node3D.new()
	root.add_child(parent)
	TERRAIN.build(parent,false)
	var metrics:=WEST.build(parent,false)
	await physics_frame
	await physics_frame
	check(int(metrics.flights)==5,"five grouped static bodies")
	check(int(metrics.treads)==count,"all treads built in headless")
	check(int(metrics.houses)==houses.size(),"all houses have physical presence in headless")
	check(int(metrics.rails)==0,"no decorative rails on headless authority")
	var west:=parent.get_node("FavelaV2MorroEsquerdo")
	var grouped:=0
	for child:Node in west.get_children():
		if child is StaticBody3D and child.name.begins_with("LanceEscada_"):
			grouped+=1
			check((child.get_node("DegrausColisaoAgrupada") as CollisionShape3D).shape is ConcavePolygonShape3D,
				"grouped physical stair collider "+child.name)
	check(grouped==5,"only five stair bodies rather than hundreds")
	var state:=parent.get_world_3d().direct_space_state
	var ray_miss:=0
	var ray_walk:=0
	for flight:Dictionary in flights:
		var poses:Array[Transform3D]=flight["poses"]
		for i in range(4,poses.size()-4,13):
			var q:Vector3=poses[i].origin
			var ray:=PhysicsRayQueryParameters3D.create(q+Vector3.UP*1.0,q-Vector3.UP*.70,1)
			var hit:=state.intersect_ray(ray)
			if hit.is_empty() or not str((hit["collider"] as Node).name).begins_with("LanceEscada_"):
				ray_miss+=1
			ray_walk+=1
	check(ray_miss==0,"player sees concrete tread as physical top at all sampled stairs")
	# Use the actual server physics world to test that an infantry capsule
	# never overlaps a residence while following each declared western alley.
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.32
	capsule.height=1.78
	var house_corridor_hits:=0
	var corridor_samples:=0
	for lane: Dictionary in TOPO.LINKS:
		if not str(lane["id"]).begins_with("l"):continue
		var poly:=TOPO.polyline(lane)
		for seg in poly.size()-1:
			var a: Vector2=poly[seg]
			var b: Vector2=poly[seg+1]
			var count_seg:=maxi(1,ceili(a.distance_to(b)/4.0))
			for j in count_seg+1:
				var pos:Vector2=a.lerp(b,float(j)/float(count_seg))
				var ground:=TERRAIN.height_at(pos.x,pos.y)
				var probe:=PhysicsShapeQueryParameters3D.new()
				probe.shape=capsule
				probe.transform.origin=Vector3(pos.x,ground+.93,pos.y)
				probe.collision_mask=1
				for sample: Dictionary in state.intersect_shape(probe,24):
					var hit_body:=sample.get("collider") as Node
					if hit_body==null:continue
					var house_parent:=hit_body.get_parent()
					if house_parent!=null and str(house_parent.name).begins_with("CasaMorro_"):
						house_corridor_hits+=1
				corridor_samples+=1
	check(house_corridor_hits==0,"house bodies never block the center of western alleys")
	print("FAVELA_V2_WEST_QA ",JSON.stringify({
		"pass":failures.is_empty(),"checks":checks,
		"flights":flights.size(),"treads":count,
		"houses":houses.size(),"colliders_grouped":grouped,
		"sampled_treads":ray_walk,"misses":ray_miss,
		"corridor_samples":corridor_samples,"house_corridor_hits":house_corridor_hits,
		"errors":failures.slice(0,22)}))
	parent.queue_free()
	quit(0 if failures.is_empty() else 1)
