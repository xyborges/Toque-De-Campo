extends SceneTree
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=712907
	var largest:=0.
	for i in 512:
		var x:=rng.randi_range(-200,200);var z:=rng.randi_range(-200,200)
		var difference:=absf(MAP._sample(x,z)-MAP.LAND.rawheight(x*MAP.STEP,z*MAP.STEP))
		largest=maxf(largest,difference);check(difference<.0001,"Prepared sample equals authoritative generator")
	check(MAP._prepared!=null,"Prepared terrain actually selected")
	var map:=MAP.new();map.render_visuals=false;root.add_child(map)
	var source: Node3D=load(MAP.LIB+"courtyard_wall_v2.tscn").instantiate()
	var shapes: Array[CollisionShape3D]=[]
	for child in source.get_children():
		if child is CollisionShape3D:shapes.append(child)
	var groups: Dictionary={}
	for i in 40:
		var transform:=Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(rng.randf_range(.7,2.5),.32,.9)),Vector3(rng.randf_range(-950.,950.),rng.randf_range(20.,120.),rng.randf_range(-950.,950.)))
		var body: Node3D=map.add_piece("courtyard_wall_v2",transform,groups)
		var count:=body.get_child_count()
		for j in shapes.size():
			var actual: CollisionShape3D=body.get_child(count-shapes.size()+j)
			var expected:=transform*shapes[j].transform
			check(actual.global_transform.is_equal_approx(expected),"Grouped wall shape retains world transform")
			check(actual.shape==shapes[j].shape,"Grouped walls share original shape resource")
		check(body.collision_layer==1 and body.collision_mask==0,"Static compound retains collision layer")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"max_height_error_m":largest,"wall_groups":map.wall_bodies.size(),"walls":40,"scope":"Prepared samples vs generator and grouped wall shapes vs original prefabs; no FPS claim."}
	NavalStorage.write_json("res://work/afghan-prepared-validation.json",report);print("AFGHAN_PREPARED ",JSON.stringify(report))
	source.free();map.free();quit(0 if failures.is_empty() else 1)
