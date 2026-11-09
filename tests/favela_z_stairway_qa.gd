extends SceneTree
const Z=preload("res://modes/war/scripts/favela_z_stairway.gd")
var failures: Array[String]=[]
var checks:=0
func expect(condition: bool,label: String)->void:
	checks+=1
	if not condition: failures.append(label)

func _initialize()->void:
	run.call_deferred()

func run()->void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var route: Array=WarFavelaMap.MINI_STREETS[WarFavelaMap.Z_STAIR_ROUTE_INDEX]
	var roads:=WarFavelaMap.road_envelopes()
	var marked:=0
	for r: Dictionary in roads:
		if r.points==route:
			marked+=1
			expect(not bool(r.get("asphalt",true)),"Z street must stop painting asphalt")
	expect(marked==1,"only one Z route is marked")
	var layout:=Z.plan(route,func(x: float,z: float)->float:return WarFavelaMap.height_at(x,z))
	var treads: Array=layout.steps
	var landings: Array=layout.landings
	expect(treads.size()>150,"full staircase across five Z arms")
	expect(landings.size()==route.size(),"landings at each bend and end")
	expect(float(layout.max_rise)<.20,"rises stay within character step limit")
	var scene:=WarPrefabFactory.create("favela_z_stair_tread")
	expect(scene!=null,"reusable stair module exists in catalog")
	if scene:
		expect(scene.get_meta("library_id","")=="favela_z_stair_tread","module library id")
		expect(scene.find_children("*","CollisionShape3D",true,false).size()==1,"physical tread")
		expect(scene.find_children("*","MeshInstance3D",true,false).size()==2,"concrete with nosing")
		scene.free()
	for item: Dictionary in treads:
		var p: Vector3=item.position
		var i:=int(item.segment)
		var start: Vector2=route[i]
		var end: Vector2=route[i+1]
		var axis: Vector2=(end-start).normalized()
		var planar:=Vector2(p.x,p.z)
		expect(absf((planar-start).cross(axis))<.01,"tread on original corridor")
		expect(item.pitch>=.69 and item.pitch<.80,"spaced treads without collision overlap")
	var world:=Node3D.new()
	root.add_child(world)
	WarWorld.build(world,false)
	await physics_frame
	var map:=world.get_node_or_null("FavelaWar") as WarFavelaMap
	expect(map!=null,"favela world built")
	if map:
		var data:=map.build_metrics
		expect(int(data.get("z_stair_treads",0))==treads.size(),"authority builds all treads")
		expect(int(data.get("z_stair_landings",0))==route.size(),"authority builds landings")
		expect(int(data.get("z_stair_rails_posts",-1))==0,"no decorative rail mesh on dedicated server")
		print("FAVELA_Z_STAIRWAY_QA ",JSON.stringify({"ok":failures.is_empty(),
			"checks":checks,"failures":failures.slice(0,16),
			"treads":treads.size(),"landings":landings.size(),
			"rise_max":layout.max_rise,"length_m":data.get("z_stair_route_length_m",-1)}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
