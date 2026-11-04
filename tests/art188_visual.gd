extends SceneTree
var gallery: Node3D
func _initialize() -> void: run.call_deferred()
func capture(id: String,point: Vector3,target: Vector3) -> void:
	var camera:=gallery.get_node("Camera") as Camera3D;camera.position=point;camera.look_at(target);camera.fov=48
	for i in 4: await process_frame
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/art188-"+id+".png")
func run() -> void:
	gallery=load("res://editor/war/biblioteca.tscn").instantiate();root.add_child(gallery)
	await capture("soldier-front",Vector3(-3.8,1.9,-3.2),Vector3(-1.7,1.1,-.1))
	await capture("soldier-back",Vector3(-3.,2.,3.4),Vector3(-1.7,1.1,0))
	await capture("hands",Vector3(-2.90,1.55,-1.50),Vector3(-1.85,1.30,-.34))
	await capture("guarani",Vector3(14,4,-7),Vector3(8,1.1,1))
	await capture("container",Vector3(-4,3.7,-1.5),Vector3(-10,1.2,-8))
	await capture("trees",Vector3(-22,6,2),Vector3(-16,3.7,-8))
	await capture("trench",Vector3(6,3.6,-6),Vector3(1,.7,-12))
	await capture("quay",Vector3(20,4,20),Vector3(13,-.7,12))
	await capture("ruin",Vector3(-6,5.2,18),Vector3(-13,1.5,10))
	gallery.queue_free();await process_frame;quit()
