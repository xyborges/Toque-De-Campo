extends SceneTree
## Offline albedo only. Never bakes lighting, changes terrain or collision.
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(4096,4096);viewport.own_world_3d=true;root.add_child(viewport)
	var map:=MAP.new();viewport.add_child(map)
	var shader:=Shader.new();shader.code=FileAccess.get_file_as_string("res://modes/battle_royale/map/afghan_ground_source.gdshader").replace("render_mode cull_back;","render_mode unshaded, cull_back, fog_disabled;")
	map.terrain_material=ShaderMaterial.new();map.terrain_material.shader=shader
	for pair in [["sand","sand-albedo"],["gravel","concrete-albedo"],["rock","rock-albedo"],["soil_normal","sand-normal"]]:
		map.terrain_material.set_shader_parameter(pair[0],load("res://assets/environment/materials/"+pair[1]+".png"))
	map.terrain_material.set_shader_parameter("biome_mask",load("res://modes/battle_royale/map/afghan_biomes.png"))
	map.terrain_material.set_shader_parameter("agriculture",MAP.LAND.agriculture_texture())
	for z in 10:
		for x in 10: map._terrain_tile(x,z)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2000.;camera.far=5000.
	camera.position=Vector3(0,3000,0);camera.look_at(Vector3.ZERO,Vector3.FORWARD);camera.make_current()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image()
	var error:=result.save_png("res://modes/battle_royale/map/afghan_ground_baked.png")
	if error==OK: NavalStorage.write_json("res://modes/battle_royale/map/afghan_ground_baked.json",{"signature":preload("res://modes/battle_royale/map/afghan_ground_cache.gd").signature(),"resolution":4096})
	print("GROUND_BAKE ",error," ",result.get_size())
	viewport.free();quit(error)
