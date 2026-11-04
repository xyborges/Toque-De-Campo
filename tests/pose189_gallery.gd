extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func run() -> void:
	var gallery:=load("res://editor/war/biblioteca.tscn").instantiate() as Node3D;root.add_child(gallery)
	var players:=gallery.find_children("Poses","AnimationPlayer",true,false)
	check(players.size()==2,"both reference soldiers have animation previews")
	for id in ["mira","inclinar","recarregar"]:
		for player: AnimationPlayer in players:
			check(player.has_animation(id),"saved preview "+id)
			player.play(id);player.seek(player.get_animation(id).length*.25,true);player.pause()
			var model:=player.get_parent() as Node3D
			var torso:=model.get_node("Avatar/Torso") as Node3D
			var pelvis:=model.get_node("Avatar/Pelvis") as Node3D
			check(absf(pelvis.to_local(torso.to_global(Vector3(0,-.28,0))).x)<.10,"preview keeps waist over pelvis "+id)
		var camera:=gallery.get_node("Camera") as Camera3D;camera.position=Vector3(-1.,1.9,3.5);camera.look_at(Vector3(-1.6,1.05,0));camera.fov=43
		for i in 3: await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/pose189-gallery-"+id+".png")
	var event:=InputEventKey.new();event.keycode=KEY_P;event.pressed=true;gallery._unhandled_input(event)
	check(gallery.pose_index==1,"P advances the gallery animation")
	gallery.queue_free();await create_timer(.5).timeout
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/pose189-gallery-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
