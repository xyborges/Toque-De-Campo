extends SceneTree
## Real integration smoke test: 1:1 sample from the existing Favela V2
## height_at() authority, native Terrain3D v1.1.0 terrain and physics.
const ORIGINAL=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const GRID:=256
const SPACING:=4.0
const ORIGIN:=Vector2(-512.0,-512.0)
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	var ok:=ClassDB.class_exists("Terrain3D")
	var scatter:Script=load("res://addons/proton_scatter/src/scatter.gd")
	if not ok or scatter==null or not scatter.can_instantiate():
		print("V2_TERRAIN3D_PILOT ",JSON.stringify({"pass":false,
			"terrain_available":ok,"proton_loaded":scatter!=null and scatter.can_instantiate()}))
		quit(2)
		return
	var began:=Time.get_ticks_msec()
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var terrain:Node3D=ClassDB.instantiate("Terrain3D")
	terrain.name="TerrenoV2Clipmap"
	terrain.set("region_size",GRID)
	terrain.set("vertex_spacing",SPACING)
	terrain.set("collision_mode",0)
	root.add_child(terrain)
	await process_frame
	var data:Object=terrain.get("data")
	if data==null:
		print("V2_TERRAIN3D_PILOT ",JSON.stringify({"pass":false,
			"error":"Terrain3D data not initialized in Godot scene"}))
		terrain.queue_free()
		quit(3)
		return
	var image:=Image.create(GRID,GRID,false,Image.FORMAT_RF)
	for j in GRID:
		var z:=ORIGIN.y+SPACING*float(j)
		for i in GRID:
			var x:=ORIGIN.x+SPACING*float(i)
			image.set_pixel(i,j,Color(ORIGINAL.height_at(x,z),0,0,1))
	var images:Array[Image]=[]
	images.resize(3)
	images[0]=image
	data.call("import_images",images,Vector3(ORIGIN.x,0,ORIGIN.y),0.0,1.0)
	await process_frame
	var active_regions:int=data.call("get_regions_active").size()
	var errors:=0
	var max_error:=0.0
	var results:Array[Dictionary]=[]
	for id in ["base_sul","praca","central_hub","base_norte"]:
		var p:Vector2=ORIGINAL.TOPO.NODES[id]["p"]
		var ideal:=ORIGINAL.height_at(p.x,p.y)
		var actual:float=float(data.call("get_height",Vector3(p.x,0,p.y)))
		var err:=absf(actual-ideal)
		max_error=maxf(max_error,err)
		if not is_finite(actual) or err>2.75:errors+=1
		results.append({"id":id,"expected":snappedf(ideal,.01),
			"actual":snappedf(actual,.01),"error":snappedf(err,.02)})
	print("V2_TERRAIN3D_PILOT ",JSON.stringify({
		"pass":active_regions>0 and errors==0,
		"plugin":"Terrain3D 1.1.0-stable","godot":Engine.get_version_info().string,
		"grid_px":GRID,"spacing_m":SPACING,
		"regions":active_regions,"height_error_max_m":max_error,
		"sampling_and_import_ms":Time.get_ticks_msec()-began,
		"sample_points":results,"failed":errors}))
	terrain.queue_free()
	quit(0 if active_regions>0 and errors==0 else 1)
