extends SceneTree
## P0b visual baseline only; saves current renderer screens without changing gameplay.
const Fixture=preload("res://tests/war_optics_fixture.gd")

func _initialize() -> void:
	run.call_deferred()

func scenery(game: WarGame,label: String,p: Vector3,size: Vector3, tint: Color) -> void:
	var node:=MeshInstance3D.new()
	node.name=label
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=tint
	mat.roughness=.87
	node.material_override=mat
	node.position=p
	game.world_root.add_child(node)

func run() -> void:
	var rendered: bool=DisplayServer.get_name()!="headless"
	if rendered:
		DisplayServer.window_set_size(Vector2i(1280,720))
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	actor.weapon_id="g3"
	actor.owned=["g3","glock"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor.set_process(false)
	actor.set_physics_process(false)
	actor._refresh_weapon()
	scenery(game,"Wall Left",Vector3(-2.05,1.3,-6.5),Vector3(1.6,2.6,1.2),Color(.63,.49,.31))
	scenery(game,"Wall Right",Vector3(2.05,1.3,-6.5),Vector3(1.6,2.6,1.2),Color(.63,.49,.31))
	scenery(game,"Lintel",Vector3(0,2.35,-6.5),Vector3(3.25,.7,1.2),Color(.60,.48,.33))
	scenery(game,"Sill",Vector3(0,.42,-6.5),Vector3(3.25,.84,1.2),Color(.64,.49,.30))
	scenery(game,"Backdrop",Vector3(0,1.4,-11),Vector3(7.0,2.8,.25),Color(.39,.43,.37))
	actor.camera.make_current()
	var captures: Array[Dictionary]=[]
	for config in [
		{"name":"fpp_hip","tpp":false,"ads":false},
		{"name":"tpp_hip","tpp":true,"ads":false},
		{"name":"fpp_ads","tpp":false,"ads":true},
		{"name":"tpp_preference_ads","tpp":true,"ads":true}
	]:
		game.third_person=bool(config.tpp)
		actor.aiming=bool(config.ads)
		actor.iron_sights=bool(config.ads)
		actor._update_view()
		actor._animate_walk()
		actor._update_weapon_pose()
		actor._update_camera_collision(1.0/60.0)
		for i in 9: await process_frame
		await RenderingServer.frame_post_draw
		var effective: String="TPP" if actor.camera.get_parent()==actor.shoulder_arm else "FPP"
		var path: String="res://work/fpp-tpp-p0-20261104/"+str(config.name)+".png"
		var saved:=ERR_UNAVAILABLE
		var draws: int=-1
		if rendered:
			saved=root.get_texture().get_image().save_png(path)
			draws=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		captures.append({"name":config.name,"effective":effective,"camera_pos":str(actor.camera.global_position),"fov":actor.camera.fov,"draws":draws,"saved":saved,"file":path,"view_copy_visible":actor.view_root.visible,"world_weapon_visible":actor.weapon_root.visible})
	var out:=FileAccess.open("res://work/fpp-tpp-p0-20261104/visual-baseline.json",FileAccess.WRITE)
	if out:out.store_string(JSON.stringify({"rendered":rendered,"captures":captures},"\t"));out.close()
	print("TRUE_FPP_P0_VISUAL ",JSON.stringify({"rendered":rendered,"captures":captures}))
	game.queue_free()
	await process_frame
	quit(0 if rendered and captures.size()==4 and captures[0].saved==OK and captures[1].saved==OK else 1)
