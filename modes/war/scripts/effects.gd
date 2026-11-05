extends Node3D
class_name WarEffects
const LIMIT := 256
var pool: MultiMesh
var slots: Array[Dictionary]=[]
var cursor:=0
var clock:=0.0
var persistent:=0.0
var emitted_at: Dictionary={}
# Client-only cinematic sequence: never spawns physics, collision or extra audio.
const MAX_CINEMATIC := 8
# Huge wreck plumes are drawn separately from the 900m close-up particle pool.
# 8 wrecks x 3 cards = 24 pooled billboards in ONE MultiMesh draw.
const WRECK_PLUME_LIMIT := 8
const WRECK_PLUME_CARDS := 3
const WRECK_PLUME_LIFETIME := 75.0
const WRECK_PLUME_MAX_RANGE := 6500.0
var wreck_plumes: Array[Dictionary]=[]
var wreck_plume_pool: MultiMesh
var wreck_plume_visible:=0
var wreck_plume_tick:=0.0
var cinematic: Array[Dictionary]=[]
var rings: Array[MeshInstance3D]=[]
var ring_events: Array[Dictionary]=[]
var ring_cursor:=0
var shock_camera: Camera3D
var shock_base:=Vector2.ZERO
var shock_left:=0.0
var shock_total:=0.0
var shock_power:=0.0
var shock_clock:=0.0
func _ready() -> void:
	for i in LIMIT: slots.append({})
	if DisplayServer.get_name()=="headless": set_process(false);return
	var mesh:=QuadMesh.new();mesh.size=Vector2(2,2)
	pool=MultiMesh.new();pool.transform_format=MultiMesh.TRANSFORM_3D;pool.use_colors=true;pool.mesh=mesh;pool.instance_count=LIMIT
	var instance:=MultiMeshInstance3D.new();instance.multimesh=pool;instance.custom_aabb=AABB(Vector3(-1800,-100,-1800),Vector3(3600,500,3600));instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=preload("res://modes/war/shaders/smoke.gdshader")
	instance.material_override=material
	add_child(instance)
	for i in LIMIT: pool.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	pool.visible_instance_count=0
	var plume_mesh:=QuadMesh.new()
	plume_mesh.size=Vector2(2.,2.)
	wreck_plume_pool=MultiMesh.new()
	wreck_plume_pool.transform_format=MultiMesh.TRANSFORM_3D
	wreck_plume_pool.use_colors=true
	wreck_plume_pool.use_custom_data=true
	wreck_plume_pool.mesh=plume_mesh
	wreck_plume_pool.instance_count=WRECK_PLUME_LIMIT*WRECK_PLUME_CARDS
	var plume_instance:=MultiMeshInstance3D.new()
	plume_instance.name="DistantTankWreckPlumes"
	plume_instance.multimesh=wreck_plume_pool
	plume_instance.custom_aabb=AABB(Vector3(-8500.,-800.,-8500.),Vector3(17000.,2500.,17000.))
	plume_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plume_material:=ShaderMaterial.new()
	plume_material.shader=preload("res://modes/war/shaders/wreck_smoke_far.gdshader")
	plume_instance.material_override=plume_material
	add_child(plume_instance)
	wreck_plume_pool.visible_instance_count=0
	var ring_shader:=Shader.new()
	ring_shader.code="shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled; uniform vec4 tint : source_color = vec4(0.78,0.69,0.49,0.40); void fragment(){ vec2 uv=UV*2.0-1.0; float r=length(uv); float outer=smoothstep(0.64,0.81,r)*(1.0-smoothstep(0.89,0.99,r)); float inner=smoothstep(0.34,0.52,r)*(1.0-smoothstep(0.56,0.74,r)); ALBEDO=tint.rgb; ALPHA=tint.a*(outer+inner*0.27); }"
	for index in MAX_CINEMATIC:
		var ring:=MeshInstance3D.new()
		var quad:=QuadMesh.new();quad.size=Vector2(2,2);ring.mesh=quad
		var ring_material:=ShaderMaterial.new();ring_material.shader=ring_shader
		ring.material_override=ring_material
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible=false;add_child(ring);rings.append(ring)

func spawn(point: Vector3,velocity: Vector3,size: float,life: float,color: Color,growth:=.4,muzzle:=false,attack:=.035,release:=.5,delay:=0.0) -> void:
	if pool==null: return
	slots[cursor]={"position":point,"velocity":velocity,"size":size,"life":life,"total":life,"color":color,"growth":growth,"muzzle":muzzle,"age":0.0,"attack":attack,"release":release,"delay":delay}
	cursor=(cursor+1)%LIMIT

func explosion(point: Vector3,radius: float,seed_value: int,kind:="") -> void:
	var random:=RandomNumberGenerator.new();random.seed=seed_value
	var camera:=get_viewport().get_camera_3d()
	var distance:=camera.global_position.distance_to(point) if is_instance_valid(camera) else 1000.0
	var distant:=distance>450.0
	var near:=distance<190.0
	var heavy:=kind in ["tank","tv","drone","destroy","tank_wreck","armor_wreck"]
	if heavy: radius=maxf(6.,radius)*1.18
	# The distant wreck exists even when every short-range explosion particle
	# is culled. Keep this BEFORE the 900m early return.
	if kind=="tank_wreck":
		_register_wreck_plume(point,seed_value)
	if is_instance_valid(camera) and camera.global_position.distance_squared_to(point)>900.*900.: return
	if kind in ["tank_wreck","armor_wreck"]:
		# Scheduled muzzle-like ammunition flashes are visual only: the original
		# destruction WAV already contains the secondary booms.
		if cinematic.size()>=MAX_CINEMATIC: cinematic.pop_front()
		cinematic.append({"point":point,"radius":radius,"age":0.0,"next":0,"heavy":kind=="tank_wreck","seed":seed_value,"smoke_time":0.0})
	if distance<520.0 and (heavy or distance<240.0):
		_start_ring(point,maxf(3.0,radius),heavy)
	if near:
		# One short white-hot core and a dusty orange fringe; no dynamic lights.
		spawn(point+Vector3.UP*.65,Vector3.UP*2.8,maxf(1.6,radius*.34),.19,Color(1.0,.92,.67,.92),3.4,false,.005,.11)
		spawn(point+Vector3.UP*.85,Vector3.UP*1.8,maxf(2.2,radius*.54),.33,Color(1.0,.43,.09,.56),3.7,false,.018,.18,.025)
		if heavy:
			# The previous blast disappeared into grey smoke after just a
			# fraction of a second. Keep a bright, growing fireball visible
			# for the first 1–2 seconds of vehicle destruction.
			for index in 9:
				var angle:=TAU*float(index)/9.0+random.randf_range(-.18,.18)
				var spread:=Vector3(cos(angle),random.randf_range(.12,.9),sin(angle))
				var warm:=Color(1.0,.84,.34,.88) if index%3==0 else Color(.98,.38,.09,.70)
				var size:=maxf(2.5,radius*random.randf_range(.34,.52))
				var velocity:=spread*random.randf_range(1.4,4.2)+Vector3.UP*random.randf_range(1.0,2.8)
				var slot:=cursor
				spawn(point+spread*radius*.15+Vector3.UP*.9,velocity,size,random.randf_range(1.05,1.80),warm,random.randf_range(2.3,4.2),false,.025,.65,index*.025)
				if not slots[slot].is_empty():
					slots[slot].cloud=str(seed_value)+":fireball"
					slots[slot].large_limit=4
		_push_shock(camera,distance,heavy)
	# Dust thrown radially outward provides a readable footprint.
	var dust_count:=3 if distant else (8 if heavy else 5)
	for i in dust_count:
		var theta:=TAU*(float(i)+random.randf_range(-.15,.15))/float(dust_count)
		var outward:=Vector3(cos(theta),0.0,sin(theta))
		var speed:=random.randf_range(5.0,10.0) if heavy else random.randf_range(2.5,5.0)
		spawn(point+outward*radius*.20+Vector3.UP*.32,outward*speed+Vector3.UP*.95,maxf(.9,radius*.27),1.65 if heavy else 1.12,Color(.43,.39,.34,.50),3.1 if heavy else 1.8,false,.045,.85,i*.012)
	# Cheap bright fragments sell force without spawning rigidbodies.
	if distance<260.0:
		for i in (8 if heavy else 4):
			var velocity:=Vector3(random.randf_range(-1.,1.),random.randf_range(.25,1.2),random.randf_range(-1.,1.)).normalized()*random.randf_range(7.,15.)
			spawn(point+Vector3.UP*.5,velocity,.10 if heavy else .06,.45,Color(1.0,.60,.20,.80),.015,false,.004,.20)
	for i in (3 if distant else (14 if heavy else 9)):
		var vector:=Vector3(random.randf_range(-1,1),random.randf_range(.1,1),random.randf_range(-1,1)).normalized()
		var slot:=cursor
		spawn(point+vector*radius*.12,vector*radius*.7,radius*.2,random.randf_range(.3,.7),Color(1,.46,.12,.9),.7)
		if not slots[slot].is_empty(): slots[slot].cloud=str(seed_value)+":fire";slots[slot].large_limit=3
	# Larger clouds use fewer pooled cards, keeping their overdraw bounded.
	for i in (3 if distant else (11 if heavy else 7)):
		var vector:=Vector3(random.randf_range(-1,1),random.randf_range(.4,1.3),random.randf_range(-1,1))
		var slot:=cursor
		var wreck:=kind in ["tank_wreck","armor_wreck"]
		spawn(point+vector*radius*.22,vector*(4.0 if wreck else 2.1),maxf(.65,radius*.33 if wreck else (radius*.28 if heavy else radius*.22)),random.randf_range(16,23) if wreck else (random.randf_range(10,14) if heavy else random.randf_range(6,9)),Color(.13,.14,.14,.67) if wreck else (Color(.17,.18,.17,.58) if heavy else Color(.29,.28,.25,.54)),2.0 if wreck else (1.9 if heavy else 1.3),false,.20 if heavy else .34,4.5 if wreck else (3.8 if heavy else 2.5),i*.035)
		if not slots[slot].is_empty(): slots[slot].cloud=str(seed_value)+":smoke";slots[slot].large_limit=2

# Short client-side visual impulse. Affected camera offsets are restored,
# so physics, aiming rays, camera rotation and network state remain unchanged.
func _restore_shock() -> void:
	if is_instance_valid(shock_camera):
		shock_camera.h_offset=shock_base.x
		shock_camera.v_offset=shock_base.y
	shock_camera=null
	shock_left=0.0
	shock_power=0.0

func _push_shock(camera: Camera3D,distance: float,heavy: bool) -> void:
	if not is_instance_valid(camera) or distance>95.0: return
	var intensity: float=(.125 if heavy else .060)*pow(1.0-clampf(distance/95.0,0,1),1.4)
	if intensity<.001: return
	if shock_camera!=camera:
		_restore_shock()
		shock_camera=camera
		shock_base=Vector2(camera.h_offset,camera.v_offset)
	shock_power=maxf(shock_power,intensity)
	shock_total=.52 if heavy else .34
	shock_left=shock_total

func _shock_step(delta: float) -> void:
	if shock_left<=0: return
	if not is_instance_valid(shock_camera) or get_viewport().get_camera_3d()!=shock_camera:
		_restore_shock()
		return
	shock_left=maxf(0.0,shock_left-delta)
	shock_clock+=delta
	var fade:=pow(shock_left/maxf(.001,shock_total),2)
	shock_camera.h_offset=shock_base.x+sin(shock_clock*TAU*12.0)*shock_power*fade
	shock_camera.v_offset=shock_base.y+sin(shock_clock*TAU*17.0)*shock_power*.65*fade
	if shock_left<=0: _restore_shock()

func _exit_tree() -> void:
	_restore_shock()

func impact(point: Vector3,blood: bool) -> void:
	for i in (4 if blood else 3):
		var vector:=Vector3(sin(i*2.4),.4+i*.2,cos(i*2.4))
		spawn(point,vector*.7,.06 if blood else .12,.32,Color(.55,.04,.025,.85) if blood else Color(.85,.64,.37,.75),.12)

func muzzle_smoke(origin: Vector3,direction: Vector3,weapon: String,seed_value: int,emitter:=0) -> void:
	if pool==null: return
	var camera:=get_viewport().get_camera_3d()
	if is_instance_valid(camera) and camera.global_position.distance_to(origin)>280: return
	var key:=str(emitter)+":"+weapon
	var interval:=.18 if weapon in ["hmg","ak","fal","g3"] else .10
	if clock-float(emitted_at.get(key,-100))<interval: return
	if emitted_at.size()>128: emitted_at.clear()
	emitted_at[key]=clock
	var heavy:=weapon in ["tank","rpg","stinger","autocannon","tv"]
	var random:=RandomNumberGenerator.new();random.seed=seed_value
	for index in (6 if weapon in ["rpg","stinger"] else (3 if heavy else 1)):
		var drift:=Vector3(random.randf_range(-.45,.45),random.randf_range(.2,.7),random.randf_range(-.45,.45))
		spawn(origin+direction*index*.10,direction*random.randf_range(1.2,2.8)+drift,.18 if heavy else .06,.85 if heavy else .30,Color(.40,.42,.40,.42 if heavy else .25),.42 if heavy else .12,true)
	if weapon in ["rpg","stinger"]:
		var rear:=origin-direction*(1.75 if weapon=="rpg" else 1.6)
		for index in 5:
			var exhaust_speed:=2.5+float(index)*1.15
			spawn(rear-direction*index*.10,-direction*exhaust_speed+Vector3.UP*.45,.22,1.05,Color(.43,.40,.34,.44),.50,true)

func smoke_screen(point: Vector3,seed_value: int) -> void:
	if pool==null: return
	var random:=RandomNumberGenerator.new();random.seed=seed_value
	for i in 18:
		var angle:=TAU*float(i)/18.;var radius:=random.randf_range(2.,8.)
		var offset:=Vector3(cos(angle)*radius,random.randf_range(.6,2.5),sin(angle)*radius)
		spawn(point+offset,Vector3(random.randf_range(-.2,.2),.3,random.randf_range(-.2,.2)),2.4,12.,Color(.36,.37,.35,.72),.35,false,.8,2.0,i*.04)

func _start_ring(point: Vector3,radius: float,major: bool) -> void:
	if rings.is_empty(): return
	var ring:=rings[ring_cursor]
	ring_cursor=(ring_cursor+1)%rings.size()
	ring.global_position=point+Vector3.UP*.18
	ring.rotation=Vector3(-PI*.5,0,0)
	ring.scale=Vector3.ONE*.2
	ring.show()
	# Reusing the oldest ring avoids creating meshes during combat.
	for i in range(ring_events.size()-1,-1,-1):
		if ring_events[i].node==ring: ring_events.remove_at(i)
	ring_events.append({"node":ring,"age":0.0,"duration":.75 if major else .48,"radius":radius*(5.5 if major else 3.5)})

func _cinematic_step(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	for i in range(cinematic.size()-1,-1,-1):
		var event: Dictionary=cinematic[i]
		event.age+=delta
		var age: float=event.age
		if age>21.0:
			cinematic.remove_at(i);continue
		var dist:=camera.global_position.distance_to(event.point) if is_instance_valid(camera) else 100.0
		if dist>900.0: continue
		var random:=RandomNumberGenerator.new()
		random.seed=int(event.seed)+int(event.next)*7919
		var times: Array=[1.45,2.72,3.08,4.25,6.10] # All destroyed armored vehicles currently use the V3 tank recording.
		if int(event.next)<times.size() and age>=float(times[int(event.next)]):
			var count:=(3 if bool(event.heavy) else 2) if dist<300.0 else 1
			for j in count:
				var offset:=Vector3(random.randf_range(-2,2),random.randf_range(1.0,3.5),random.randf_range(-2,2))
				var size: float=float(event.radius)*random.randf_range(.18,.32)
				spawn(event.point+offset,Vector3(random.randf_range(-1,1),random.randf_range(2,5),random.randf_range(-1,1)),size,.30,Color(1.,.45,.12,.9),2.8)
				spawn(event.point+offset,Vector3(random.randf_range(-1,1),random.randf_range(2,4),random.randf_range(-1,1)),size*.8,7.0,Color(.14,.15,.14,.38),1.3,false,.20,2.5)
			event.next=int(event.next)+1
		# A tiny budgeted trickle keeps the wreck smoking without a particle emitter.
		if age<16.0 and dist<600.0:
			event.smoke_time=float(event.smoke_time)+delta
			if float(event.smoke_time)>.9:
				event.smoke_time=0.0
				var drift:=Vector3(random.randf_range(-1.2,1.2),1.0,random.randf_range(-1.2,1.2))
				spawn(event.point+Vector3.UP*2.,drift*2.0,maxf(1.0,float(event.radius)*.24),random.randf_range(7,11),Color(.13,.14,.13,.34),1.15,false,.6,3.0)
	for i in range(ring_events.size()-1,-1,-1):
		var r: Dictionary=ring_events[i]
		r.age+=delta
		var t: float=float(r.age)/float(r.duration)
		if t>=1.0:
			r.node.hide();ring_events.remove_at(i);continue
		r.node.scale=Vector3.ONE*(.3+float(r.radius)*t)
		r.node.material_override.set_shader_parameter("tint",Color(.78,.67,.49,(1.0-t)*(1.0-t)*.42))

# Keep the apparent angle of a plume even beyond the camera far plane.
# Render at <=72% of camera.far instead of raising far clipping and terrain cost.
static func wreck_plume_profile(distance: float, far_clip: float, age: float) -> Dictionary:
	if not is_finite(distance) or not is_finite(far_clip) or not is_finite(age): return {}
	if distance<220.0 or distance>WRECK_PLUME_MAX_RANGE or far_clip<=10.0 or age<0.0 or age>=WRECK_PLUME_LIFETIME: return {}
	var opacity:=smoothstep(220.0,470.0,distance)*(1.0-smoothstep(5750.0,WRECK_PLUME_MAX_RANGE,distance))
	opacity*=smoothstep(.55,4.0,age)*(1.0-smoothstep(54.0,WRECK_PLUME_LIFETIME,age))
	if opacity<.008: return {}
	var mapped_distance:=minf(distance,far_clip*.72)
	var growth:=smoothstep(.5,12.0,age)
	return {"mapped_distance":mapped_distance,"scale":mapped_distance/distance,
		"height":lerpf(16.0,145.0,growth),"width":lerpf(14.0,64.0,growth),
		"opacity":opacity}

func _register_wreck_plume(point: Vector3,seed_value: int) -> void:
	if wreck_plume_pool==null or not point.is_finite(): return
	if wreck_plumes.size()>=WRECK_PLUME_LIMIT: wreck_plumes.pop_front()
	wreck_plumes.append({"point":point,"age":0.0,"seed":seed_value})

func _wreck_plume_step(delta: float,camera: Camera3D) -> void:
	if wreck_plume_pool==null: return
	# Fixed-size pool: never allocate geometry, collisions, lights, audio or particles.
	for i in range(wreck_plumes.size()-1,-1,-1):
		var record: Dictionary=wreck_plumes[i]
		record.age=float(record.age)+delta
		if float(record.age)>=WRECK_PLUME_LIFETIME: wreck_plumes.remove_at(i)
	var drawn:=0
	if is_instance_valid(camera):
		var eye:=camera.global_position
		var forward: Vector3=-camera.global_basis.z
		for record in wreck_plumes:
			var offset: Vector3=record.point-eye
			var distance:=offset.length()
			var params:=wreck_plume_profile(distance,camera.far,float(record.age))
			if params.is_empty() or offset.dot(forward)<-25.0: continue
			var proxy_origin:=eye+offset*(float(params.mapped_distance)/distance)
			var projected_height:=float(params.height)*float(params.scale)
			var projected_width:=float(params.width)*float(params.scale)
			var alpha:=float(params.opacity)
			var seed_fraction:=float(posmod(int(record.seed),997))/997.0
			for layer in WRECK_PLUME_CARDS:
				# Avoid allocating per-layer arrays in the render loop.
				var y:=.30 if layer==0 else (.57 if layer==1 else .82)
				var w:=.72 if layer==0 else (1.0 if layer==1 else 1.28)
				var h:=.70 if layer==0 else (.86 if layer==1 else .39)
				var center:=proxy_origin+Vector3.UP*(projected_height*y)
				wreck_plume_pool.set_instance_transform(drawn,Transform3D(Basis.from_scale(Vector3(projected_width*w*.5,projected_height*h*.5,1.0)),center))
				var shade:=Color(.11,.11,.11,.55) if layer==0 else (Color(.16,.16,.16,.58) if layer==1 else Color(.21,.21,.20,.49))
				shade.a*=alpha
				wreck_plume_pool.set_instance_color(drawn,shade)
				wreck_plume_pool.set_instance_custom_data(drawn,Color(fposmod(seed_fraction+layer*.257,1.0),0.0,0.0,0.0))
				drawn+=1
	wreck_plume_pool.visible_instance_count=drawn
	wreck_plume_visible=drawn

func _process(delta: float) -> void:
	# Far smoke geometry only needs ~12.5 updates/s; shader animation is smooth.
	wreck_plume_tick+=delta
	if wreck_plume_tick>=.08:
		_wreck_plume_step(wreck_plume_tick,get_viewport().get_camera_3d())
		wreck_plume_tick=0.0
	_shock_step(delta)
	_cinematic_step(delta)
	clock+=delta;persistent+=delta
	if persistent>.6:
		persistent=0
		for x in [-450,-350,350,450]:
			var point:=WarTerrain.point(x,-220)
			spawn(point+Vector3(0,2,0),Vector3(.5,1.1,.1),.9,4,Color(.15,.16,.15,.38),.5)
	var drawn:=0
	var camera:=get_viewport().get_camera_3d()
	var large_clouds: Dictionary={}
	var tangent:=tan(deg_to_rad(camera.fov)*.5) if is_instance_valid(camera) else 1.
	if is_instance_valid(camera) and camera.keep_aspect==Camera3D.KEEP_WIDTH:
		var size:=get_viewport().get_visible_rect().size;tangent/=maxf(1,size.x/maxf(1,size.y))
	for i in LIMIT:
		var data: Dictionary=slots[i]
		if data.is_empty(): continue
		data.age=float(data.age)+delta
		if data.age<float(data.delay): continue
		data.life=float(data.life)-delta
		if float(data.life)<=0:
			slots[i]={};continue
		data.position+=data.velocity*delta
		data.size=float(data.size)+float(data.growth)*delta
		if is_instance_valid(camera):
			var offset: Vector3=data.position-camera.global_position
			if offset.length_squared()>900.*900. or offset.dot(-camera.global_basis.z)<-float(data.size)*2.: continue
		var color: Color=data.color
		color.a*=GameEffectEnvelope.opacity(float(data.total)-float(data.life),float(data.total),float(data.attack),float(data.release))
		var draw_size:=float(data.size)
		if bool(data.get("muzzle",false)) and is_instance_valid(camera):
			draw_size=minf(draw_size,maxf(.08,camera.global_position.distance_to(data.position)*.09))
		elif is_instance_valid(camera):
			var distance:=camera.global_position.distance_to(data.position)
			if data.has("cloud") and draw_size>distance*tangent*.7:
				var count: int=large_clouds.get(data.cloud,0)
				if count>=int(data.large_limit): continue
				large_clouds[data.cloud]=count+1
			# Avoid full-screen transparent quads when the camera is inside smoke.
			color.a*=smoothstep(.15,maxf(.3,draw_size*.35),distance)
			draw_size=minf(draw_size,maxf(.25,distance*.45))
		pool.set_instance_transform(drawn,Transform3D(Basis.from_scale(Vector3.ONE*draw_size),data.position))
		pool.set_instance_color(drawn,color);drawn+=1
	pool.visible_instance_count=drawn
