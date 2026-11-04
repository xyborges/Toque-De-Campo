extends SceneTree

# Structural inventory plus a controlled hide-and-restore measurement.
# Category deltas are not additive: visibility, culling and shadow passes vary.
var game: WarGame

func _initialize() -> void:
	run.call_deferred()

func category(node: GeometryInstance3D) -> String:
	if node is MeshInstance3D and node.material_override==WarTerrain.material: return "terrain"
	if node is MultiMeshInstance3D and node.multimesh:
		var mesh: Mesh=node.multimesh.mesh
		if mesh==WarVegetation.grass_mesh() or mesh==WarVegetation.grass_low_mesh(): return "grass"
		for green in [false,true]:
			for variant in 3:
				for low in [false,true]:
					if mesh==WarVegetation.tree_mesh(green,variant,low) and node.material_override==EnvironmentKit.materials.get("war_vegetation169"): return "tree_mesh_shared"
	var parent: Node=node
	while parent and parent!=game.world_root:
		if parent is WarPlayer: return "players"
		if parent is WarVehicle: return "vehicles"
		parent=parent.get_parent()
	return "other"

func draw_count() -> int:
	# Draw multiple frames after each visibility change to let rendering settle.
	for i in 3:
		await process_frame;RenderingServer.force_draw(false)
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func run() -> void:
	seed(193);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: push_error("inventory world did not load");quit(1);return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(4).timeout
	var camera:=Camera3D.new();camera.far=3000;root.add_child(camera)
	camera.position=WarTerrain.point(-80,-315)+Vector3(0,2.5,10);camera.look_at(WarTerrain.point(-80,-260)+Vector3.UP*.4);camera.make_current()
	var groups: Dictionary={}
	for node: GeometryInstance3D in game.world_root.find_children("*","GeometryInstance3D",true,false):
		var name:=category(node)
		if not groups.has(name): groups[name]=[]
		groups[name].append(node)
	RenderingServer.render_loop_enabled=false
	var baseline:=await draw_count();var report: Dictionary={}
	for name: String in groups:
		var changed: Array[GeometryInstance3D]=[]
		for node: GeometryInstance3D in groups[name]:
			if node.visible: changed.append(node);node.visible=false
		var hidden:=await draw_count()
		for node: GeometryInstance3D in changed: node.visible=true
		var restored:=await draw_count()
		report[name]={"nodes":groups[name].size(),"hidden_nodes":changed.size(),"baseline_draws":baseline,"without_category_draws":hidden,"draw_delta":baseline-hidden,"restored_draws":restored}
	var result:={"categories":report,"resolution":str(root.get_texture().get_size()),"participants":game.players.size(),"note":"One fixed viewpoint; tree mesh is also reused for other vegetation. Individual category visibility toggles affect shadows and culling. Deltas are not independent or additive and do not measure CPU by category."}
	NavalStorage.write_json("res://work/nova-render-inventory.json",result)
	print("NOVA_RENDER_INVENTORY ",JSON.stringify(result));game.queue_free();await process_frame;quit()
