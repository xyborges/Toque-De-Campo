extends SceneTree

const Lab=preload("res://tests/pole_fracture_visual_lab.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("9aa8aa")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.65
	environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.;world.add_child(sun)
	var floor_node:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(60,30);floor_node.mesh=floor_mesh
	var ground:=StandardMaterial3D.new();ground.albedo_color=Color("687359");floor_node.material_override=ground;world.add_child(floor_node)
	var lab=Lab.new();world.add_child(lab)
	var cell:=Vector2i(0,0);var positions: Array=[Vector3(2,0,4),Vector3(10,0,4),Vector3(18,0,4),Vector3(26,0,4)]
	if not lab.setup(positions,[[cell,0,cell,1],[cell,1,cell,2],[cell,2,cell,3]]): push_error("setup failed");quit(1);return
	lab.present({"cell":cell,"index":1,"direction":Vector3(0,0,1),"height_cm":150},false)
	lab.present({"cell":cell,"index":2,"direction":Vector3(0,0,1),"height_cm":620},false)
	var camera:=Camera3D.new();camera.position=Vector3(14,11,30);camera.far=150;world.add_child(camera);camera.look_at(Vector3(14,3,4));camera.make_current()
	await process_frame;await process_frame;await process_frame
	var picture:=root.get_texture().get_image();var path:=ProjectSettings.globalize_path("res://work/pole-fracture-lab.png")
	if picture.save_png(path)!=OK: push_error("capture failed");quit(1);return
	print("POLE_CAPTURE ",path);quit()
