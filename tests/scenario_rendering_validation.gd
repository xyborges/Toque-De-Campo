extends SceneTree
const SCENARIO=preload("res://scripts/scenario_rendering.gd")
var errors: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var kit:=EnvironmentKit.new(world,true,20.)
	kit.box("PhysicalCover",Vector3(0,1,-300),Vector3(3,2,1),"concrete",true)
	kit.box("Decoration",Vector3(20,1,-300),Vector3(3,2,1),"concrete",false)
	var near:=BoxMesh.new();var low:=BoxMesh.new()
	kit._instance(near,"concrete",Transform3D(Basis.IDENTITY,Vector3(0,1,-300)),false,low,900.)
	kit.flush()
	var collider:=world.find_children("PhysicalCover","CollisionShape3D",true,false)[0] as CollisionShape3D
	var shape_id:=collider.shape.get_instance_id();var original:=collider.global_transform
	var controller:=SCENARIO.new();world.add_child(controller)
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=70;camera.look_at(Vector3(0,1,-300))
	for metres in [250,400,650,900]:
		controller.configure(world,metres,1);controller.set_process(false)
		check(collider.shape.get_instance_id()==shape_id and collider.global_transform==original and not collider.disabled,"physical coverage retained at %d m"%metres)
		for node in get_nodes_in_group("scenario_rendering"):
			if bool(node.get_meta("scenario_optional",false)):check(node.visibility_range_end<=metres,"decorative range obeys choice")
	controller.configure(world,400,1);controller.set_process(false)
	check(controller.pairs.size()==2,"paired LOD and decorative group registered once")
	var pair: Dictionary=controller.pairs.filter(func(record):return not record.get("detail_only",false))[0];var proxy: GeometryInstance3D=pair.low.get_ref();var original_end:=proxy.visibility_range_end
	controller.update_focus(camera,false,.2);check(proxy.visibility_range_begin==85.,"ordinary camera retains near bubble")
	camera.fov=15;controller.update_focus(camera,true,.05);check(not controller.focus_active,"rapid aim does not promote distant detail")
	controller.update_focus(camera,true,.2);check(proxy.visibility_range_begin==400.,"stable optic promotes only the observed sector within selected distance")
	check(proxy.visibility_range_end==original_end,"physical silhouette remains at its original range")
	camera.look_at(Vector3(300,1,0));controller.update_focus(camera,true,.1)
	check(proxy.visibility_range_begin==400.,"optical detail has retention during a camera turn")
	controller.update_focus(camera,true,.7);check(proxy.visibility_range_begin==85.,"expired sector returns to regular LOD")
	check(world.find_children("*","CollisionShape3D",true,false).size()==1,"rendering never creates physical objects")
	check(controller.diagnostics().budget==24,"focus work is bounded per frame")
	var previous_path:=GameOptions.path;var previous_values:=GameOptions.values
	GameOptions.ensure();GameOptions.values={}
	check(GameOptions.scenario_distance()==400 and GameOptions.vegetation_level()==2,"new video defaults are 400 m and medium vegetation")
	GameOptions.values={"render_distance":700,"war_vegetation":0}
	check(GameOptions.scenario_distance()==650 and GameOptions.vegetation_level()==2,"legacy preferences migrate without disabling new grass")
	GameOptions.path=previous_path;GameOptions.values=previous_values
	print("SCENARIO_RENDERING_VALIDATION ",JSON.stringify({"checks":checks,"errors":errors,"ok":errors.is_empty()}))
	world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
