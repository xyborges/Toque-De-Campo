extends SceneTree
## Offline orthographic renders of the exact gameplay meshes. Never used in
## the HUD render loop; the game only loads the resulting transparent PNGs.
const OUTPUT:="res://assets/ui/weapons/"
const WIDTH:=1024
const HEIGHT:=320
const IDS:=["fal","ak","sniper","glock","rpg","stinger"]
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var metadata: Dictionary={}

func _initialize() -> void:run.call_deferred()

func source(id: String) -> Node3D:
	if id=="fal":return FALModel.create()
	if id=="glock":return GlockModel.create()
	if id in ["rpg","stinger"]:return WarLauncherModels.build(id)
	var root: Node3D=load("res://assets/weapons/%s.glb"%("ak_animated" if id=="ak" else id)).instantiate()
	root.rotation.y=PI*.5
	return root

func surfaces(node: Node,result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:result.append(node)
	for child in node.get_children():surfaces(child,result)

func bounds_for(meshes: Array[MeshInstance3D]) -> AABB:
	var first:=true;var result:=AABB()
	for mesh in meshes:
		var aabb:=mesh.get_aabb()
		for x in [aabb.position.x,aabb.end.x]:
			for y in [aabb.position.y,aabb.end.y]:
				for z in [aabb.position.z,aabb.end.z]:
					var p:=mesh.global_transform*Vector3(x,y,z)
					if first:result=AABB(p,Vector3.ZERO);first=false
					else:result=result.expand(p)
	return result

func hide_non_mesh(node: Node) -> void:
	if node is Label3D:node.hide()
	if node is AnimationPlayer:node.active=false
	for child in node.get_children():hide_non_mesh(child)

func normalized(point: Vector3) -> Array:
	var screen:=camera.unproject_position(point)
	return [screen.x/WIDTH,screen.y/HEIGHT]

func anchors(id: String,root: Node3D,bounds: AABB) -> Dictionary:
	var center:=bounds.get_center();var low:=bounds.position;var high:=bounds.end
	var points: Dictionary={
		"optics":Vector3(center.x,high.y,lerpf(low.z,high.z,.64)),
		"muzzle":Vector3(center.x,lerpf(center.y,high.y,.5),low.z),
		"magazine":Vector3(center.x,low.y,lerpf(low.z,high.z,.62)),
		"stock":Vector3(center.x,center.y,high.z),
		"underbarrel":Vector3(center.x,center.y,lerpf(low.z,high.z,.35)),
		"side":Vector3(center.x,center.y,lerpf(low.z,high.z,.52))}
	if id=="fal":
		points.muzzle=root.to_global(FALModel.MUZZLE);points.optics=root.to_global(Vector3(0,.14,-.08));points.magazine=Vector3(center.x,low.y+.01,-.135);points.underbarrel=root.to_global(FALModel.SUPPORT);points.stock=root.to_global(Vector3(0,-.04,.31))
	elif id=="glock":
		points.muzzle=root.to_global(GlockModel.MUZZLE);points.optics=root.to_global(Vector3(0,.083,.005));points.magazine=root.to_global(Vector3(0,-.12,.012));points.underbarrel=root.to_global(Vector3(0,-.03,-.115));points.stock=root.to_global(Vector3(0,-.06,.035))
	elif id=="ak":
		points.muzzle=root.to_global(Vector3(.502,.084,0));points.optics=root.to_global(Vector3(-.12,.12,0));points.magazine=root.to_global(Vector3(-.03,-.18,0));points.stock=root.to_global(Vector3(-.49,.04,0));points.underbarrel=root.to_global(Vector3(.15,.015,0))
	var result: Dictionary={}
	for key in points:result[key]=normalized(points[key])
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport=SubViewport.new();viewport.size=Vector2i(WIDTH,HEIGHT);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;stage.add_child(camera);camera.current=true
	var silhouette:=StandardMaterial3D.new();silhouette.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette.albedo_color=Color("d9dfd6");silhouette.cull_mode=BaseMaterial3D.CULL_DISABLED
	var preview:=Image.create(1280,800,false,Image.FORMAT_RGBA8);preview.fill(Color("18201e"))
	var index:=0
	for id in IDS:
		var model:=source(id);stage.add_child(model)
		if id=="ak":
			var magazine:=model.find_child("MagazineGeometry",true,false)
			if magazine:magazine.owner=null
			GameAKReload.prepare(model)
		hide_non_mesh(model)
		var meshes: Array[MeshInstance3D]=[];surfaces(model,meshes)
		for mesh in meshes:
			mesh.material_override=silhouette;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.visibility_range_begin=0.;mesh.visibility_range_end=0.
		var bounds:=bounds_for(meshes);var center:=bounds.get_center()
		camera.size=maxf(bounds.size.y*1.18,bounds.size.z/(float(WIDTH)/HEIGHT)*1.10)
		camera.position=center+Vector3(maxf(3.,bounds.size.length()*2.),0,0);camera.look_at(center,Vector3.UP);camera.near=.01;camera.far=20.
		await process_frame;await RenderingServer.frame_post_draw
		await process_frame;await RenderingServer.frame_post_draw
		var shot:=viewport.get_texture().get_image();shot.convert(Image.FORMAT_RGBA8)
		var rectangle:=shot.get_used_rect();var error:=shot.save_png(OUTPUT+id+".png")
		metadata[id]={"path":OUTPUT+id+".png","size":[WIDTH,HEIGHT],"alpha_bounds":[float(rectangle.position.x)/WIDTH,float(rectangle.position.y)/HEIGHT,float(rectangle.size.x)/WIDTH,float(rectangle.size.y)/HEIGHT],"anchors":anchors(id,model,bounds),"source":"gameplay mesh","muzzle":"right","meshes":meshes.size()}
		print("WEAPON_SILHOUETTE ",id," ",rectangle," meshes ",meshes.size()," status ",error)
		var tile:=shot.duplicate();tile.resize(600,188,Image.INTERPOLATE_LANCZOS)
		preview.blend_rect(tile,Rect2i(0,0,600,188),Vector2i(20+(index%2)*630,38+(index/2)*252));index+=1
		stage.remove_child(model);model.free();meshes.clear()
	var file:=FileAccess.open(OUTPUT+"silhouettes.json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"\t"));file.close()
	preview.save_png("res://work/weapon-silhouettes-preview.png")
	viewport.queue_free();await process_frame;quit()
