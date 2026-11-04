extends Node3D
class_name GameSmokeClouds

# One shared, bounded smoke renderer for infantry and armored vehicles.
# No collision bodies, particles, lights, shadows or per-puff Nodes.
const MAX_EVENTS := 40
const MAX_SPRITES := 192
const HAND_DURATION := 64.0
const VEHICLE_DURATION := 70.0
const DRAW_DISTANCE := 340.0
const UPDATE_INTERVAL := 0.08

var clouds: Dictionary = {}
var cloud_order: Array[String] = []
var pool: MultiMesh
var overlay: ColorRect
var smoke_audio: GameSmokeAudio
var draw_clock := 0.0
var overlay_alpha := 0.0

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.,2.)
	pool=MultiMesh.new()
	pool.transform_format=MultiMesh.TRANSFORM_3D
	pool.use_colors=true
	pool.mesh=quad
	pool.instance_count=MAX_SPRITES
	pool.visible_instance_count=0
	var mesh:=MultiMeshInstance3D.new()
	mesh.multimesh=pool
	mesh.custom_aabb=AABB(Vector3(-2200,-100,-2200),Vector3(4400,600,4400))
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new()
	material.shader=preload("res://modes/war/shaders/smoke.gdshader")
	mesh.material_override=material
	add_child(mesh)
	var layer:=CanvasLayer.new()
	layer.layer=0
	add_child(layer)
	overlay=ColorRect.new()
	overlay.color=Color(.37,.40,.38,0.)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smoke_audio=GameSmokeAudio.new()
	smoke_audio.source=self
	add_child(smoke_audio)

func add_hand(id: String,origin: Vector3,elapsed:=0.0) -> void:
	if id.is_empty() or not origin.is_finite() or clouds.has(id): return
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(id)
	var puffs: Array[Dictionary]=[]
	for index in 14:
		var angle:=TAU*(float(index)+rng.randf_range(-.15,.15))/14.
		var radius:=rng.randf_range(.3,3.2)
		var offset:=Vector3(cos(angle)*radius,rng.randf_range(1.0,2.9),sin(angle)*radius)
		puffs.append({"index":index,"point":origin+offset,"size":rng.randf_range(2.3,3.45),"drift":Vector3(rng.randf_range(-.08,.08),rng.randf_range(.05,.13),rng.randf_range(-.08,.08))})
	_insert(id,origin,HAND_DURATION,puffs,elapsed,"hand")
	if is_instance_valid(smoke_audio): smoke_audio.play_start(id,origin,"hand",elapsed)

func add_vehicle(id: String,origin: Vector3,forward: Vector3,elapsed:=0.0,kind: String="abrams") -> void:
	if id.is_empty() or not origin.is_finite() or clouds.has(id): return
	var front:=Vector3(forward.x,0,forward.z).normalized()
	if front.length_squared()<.5: front=Vector3.FORWARD
	var right:=Vector3.UP.cross(front).normalized()
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(id)
	var puffs: Array[Dictionary]=[]
	# Launch tubes form an outward fan; the overlapping plumes close into
	# a broad protective ring around the hull as they spread.
	var size_scale:=.85 if kind in ["guarani","bmp2"] else 1.0
	var cartridge_count:=6 if kind in ["guarani","bmp2"] else 12
	for canister in cartridge_count:
		var angle:=TAU*(float(canister)+.5)/float(cartridge_count)
		var direction:=front*cos(angle)+right*sin(angle)
		var radius: float=(12.0 if cos(angle)>.2 else 8.0)*size_scale
		var landing:=origin+direction*radius
		for puff in 3:
			var offset:=Vector3(rng.randf_range(-2.0,2.0),rng.randf_range(.9,3.9)*size_scale,rng.randf_range(-2.0,2.0))
			puffs.append({"index":canister*3+puff,"launch_at":.08+float(canister%3)*.045,"point":landing+offset,"size":rng.randf_range(3.0,4.1)*size_scale,"drift":Vector3(rng.randf_range(-.10,.10),rng.randf_range(.06,.16),rng.randf_range(-.10,.10))})
	_insert(id,origin,VEHICLE_DURATION,puffs,elapsed,"vehicle")
	if is_instance_valid(smoke_audio): smoke_audio.play_start(id,origin,"vehicle",elapsed)

func _insert(id: String,origin: Vector3,duration: float,puffs: Array[Dictionary],elapsed: float,kind: String) -> void:
	if clouds.has(id) or elapsed>=duration: return
	while cloud_order.size()>=MAX_EVENTS:
		clouds.erase(cloud_order.pop_front())
	cloud_order.append(id)
	clouds[id]={"origin":origin,"age":clampf(elapsed,0.,duration),"duration":duration,"puffs":puffs,"kind":kind}

func clear_clouds() -> void:
	clouds.clear()
	cloud_order.clear()
	overlay_alpha=0.
	if is_instance_valid(overlay): overlay.color.a=0.
	if pool!=null: pool.visible_instance_count=0
	if is_instance_valid(smoke_audio): smoke_audio.stop_all()

func _process(delta: float) -> void:
	for id in clouds.keys():
		var data: Dictionary=clouds[id]
		data.age=float(data.age)+delta
		if float(data.age)>=float(data.duration):
			clouds.erase(id)
			cloud_order.erase(id)
	if pool==null: return
	draw_clock+=delta
	if draw_clock<UPDATE_INTERVAL: return
	var step:=draw_clock
	draw_clock=0.
	_draw_clouds(step)

func _draw_clouds(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		pool.visible_instance_count=0
		return
	var origin:=camera.global_position
	var distance_order:=cloud_order.duplicate()
	distance_order.sort_custom(func(a,b): return origin.distance_squared_to(clouds[a].origin)<origin.distance_squared_to(clouds[b].origin))
	var drawn:=0
	var coverage:=0.
	for id in distance_order:
		var cloud: Dictionary=clouds[id]
		var age: float=cloud.age
		var duration: float=cloud.duration
		var grow:=smoothstep(0.,5.5,age-(1.1 if cloud.puffs[0].has("launch_at") else 0.))
		var fade:=1.-smoothstep(duration-14.,duration,age)
		if fade<=.001: continue
		if origin.distance_squared_to(cloud.origin)>pow(DRAW_DISTANCE+38.,2): continue
		for puff: Dictionary in cloud.puffs:
			var position: Vector3=puff.point+Vector3(puff.drift)*minf(age,18.)
			var size: float=float(puff.size)*lerpf(.3,1.0,grow)
			var tracer:=false
			if puff.has("launch_at") and age<float(puff.launch_at)+1.0:
				if age<float(puff.launch_at) or int(puff.index)%3!=0: continue
				# Visual arc from the launcher to the ring, with no rigidbodies.
				var t:=clampf((age-float(puff.launch_at)),0.,1.)
				position=cloud.origin.lerp(puff.point,t)+Vector3.UP*(1.8+4.*sin(PI*t))
				size=.11
				tracer=true
			var distance:=origin.distance_to(position)
			var cover_radius:=size*1.5
			if not tracer and distance<cover_radius:
				coverage=maxf(coverage,(1.-smoothstep(.0,cover_radius,distance))*.82*grow*fade)
			if distance>DRAW_DISTANCE: continue
			if Vector3(position-origin).dot(-camera.global_basis.z)<-size: continue
			var stride:=3 if distance>170. else (2 if distance>85. else 1)
			if not tracer and int(puff.get("index",0))%stride!=0: continue
			if drawn>=MAX_SPRITES: break
			var alpha:=.9 if tracer else .87*grow*fade
			if not tracer: alpha*=smoothstep(.12,maxf(.7,size*.55),distance)
			var draw_size:=size if tracer else minf(size,maxf(.25,distance*.5))
			pool.set_instance_transform(drawn,Transform3D(Basis.from_scale(Vector3.ONE*draw_size),position))
			pool.set_instance_color(drawn,Color(.27,.30,.26,alpha) if tracer else Color(.63,.65,.61,alpha))
			drawn+=1
		if drawn>=MAX_SPRITES: break
	pool.visible_instance_count=drawn
	overlay_alpha=lerpf(overlay_alpha,coverage,1.-exp(-delta*6.))
	if is_instance_valid(overlay):
		var tint:=overlay.color
		tint.a=overlay_alpha
		overlay.color=tint
