extends SceneTree
const Afghan=preload("res://modes/battle_royale/map/afghan_map.gd")
var frames:=0
var world: Node3D
var camera: Camera3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	world=Node3D.new();root.add_child(world)
	var map:=Afghan.new();world.add_child(map);map.build()
	var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.61,.70,.75);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.70,.75,.81);environment.ambient_light_energy=.65;environment.fog_enabled=true;environment.fog_light_color=Color(.65,.67,.65);environment.fog_density=.00035;env.environment=environment;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-37,-25,0);sun.light_energy=1.1;sun.shadow_enabled=true;sun.directional_shadow_max_distance=130;world.add_child(sun)
	camera=Camera3D.new();world.add_child(camera);camera.current=true
	camera.position=Afghan.point(-285,690)+Vector3.UP*58.;camera.look_at(Afghan.point(-180,570)+Vector3.UP*2.)
	for i in 24:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/br-map-village.png")
	camera.position=Afghan.point(-190,615)+Vector3.UP*1.8;camera.look_at(Afghan.point(-164,563)+Vector3.UP*2.)
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/br-map-street.png")
	print("BR_MAP_VISUAL ",JSON.stringify(map.build_metrics));world.free();quit()
