extends SceneTree
var world: Node3D
var label:="after169"
var output:=""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--report-root="): output=arg.trim_prefix("--report-root=")
	run.call_deferred()
func run() -> void:
	var start:=Time.get_ticks_msec();world=Node3D.new();root.add_child(world);WarWorld.build(world,true)
	var camera:=Camera3D.new();camera.far=2200;camera.near=.08;camera.fov=65;world.add_child(camera);camera.make_current()
	for frame in 3: await process_frame
	var shots:=[
		["approach",Vector3(-430,9,-180),Vector3(-150,3,-80)],
		["village",Vector3(-30,13,55),Vector3(10,2,100)],
		["house",Vector3(30,6,25),Vector3(10,2,45)],
		["shelter",Vector3(-211,3,-137),Vector3(-220,1,-120)],
		["forest",Vector3(-420,5,440),Vector3(-275,8,540)],
		["overview",Vector3(-360,125,360),Vector3(0,6,-70)]]
	for item in shots:
		var point: Vector3=item[1];point.y+=WarTerrain.height_at(point.x,point.z)
		var target: Vector3=item[2];target.y+=WarTerrain.height_at(target.x,target.z)
		camera.position=point;camera.look_at(target)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("war-map-"+label+"-"+str(item[0])+".png"))
	var report:={"label":label,"protocol":WarRules.PROTOCOL,"trees":world.get_meta("war_tree_count",0),"grass":world.get_meta("war_grass_count",0),"instances":world.get_meta("environment_instances",0),"colliders":world.get_meta("environment_colliders",0),"startup_ms":Time.get_ticks_msec()-start,"screens":shots.size()}
	FileAccess.open(output.path_join("war-map-"+label+".json"),FileAccess.WRITE).store_string(JSON.stringify(report));print(JSON.stringify(report))
	world.queue_free();await process_frame;quit()
