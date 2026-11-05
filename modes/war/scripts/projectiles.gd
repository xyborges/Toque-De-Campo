extends Node3D
class_name WarProjectiles
const LIMIT := 512
const TRAIL_SEGMENTS := 4
const COLORS := {"glock":Color("f8df86"),"ak":Color("ffb457"),"fal":Color("36b6cf"),"g3":Color("f6c080"),"sniper":Color("fff3ce"),"hmg":Color("ff863f"),"autocannon":Color("ff6941"),"tank":Color("ff7926"),"rpg":Color("ed995b"),"stinger":Color("ffdda3"),"grenade":Color("c7c28d"),"tv":Color("ff6e35")}
var game: Node3D
var rounds: Array[Dictionary] = []
var available: Array[int] = []
var active_slots: Array[int]=[]
var cores: MultiMesh
var rocket_bodies: Dictionary={}
var trails: MultiMesh
var flashes: MultiMesh
var flash_ages := PackedFloat32Array()
var flash_points := PackedVector3Array()
var flash_cursor := 0
var by_id: Dictionary={}
var counter := 0
var thermal := false
var tv_colliders: Dictionary={}

func _ready() -> void:
	name = "WarProjectiles"
	for i in LIMIT:
		rounds.append({})
		available.append(LIMIT-1-i)
	flash_ages.resize(48)
	flash_points.resize(48)
	if DisplayServer.get_name()=="headless": return
	var core_mesh := SphereMesh.new()
	core_mesh.radius = .025;core_mesh.height = .05
	core_mesh.radial_segments = 6;core_mesh.rings = 3
	cores = _pool(core_mesh,LIMIT,false)
	for launcher in ["rpg","stinger"]:
		rocket_bodies[launcher]=_pool(_rocket_mesh(launcher),LIMIT,false,true)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	trails = _pool(quad,LIMIT*TRAIL_SEGMENTS,true)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius=.13;flash_mesh.height=.26;flash_mesh.radial_segments=8;flash_mesh.rings=4
	flashes = _pool(flash_mesh,48,false)

func _pool(mesh: Mesh,count: int,ribbon: bool,rocket_body:=false) -> MultiMesh:
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_colors = true
	pool.mesh = mesh
	pool.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = pool
	var extent:=WarTerrain.HALF+1200.
	node.custom_aabb = AABB(Vector3(-extent,-1000,-extent),Vector3(extent*2,3000,extent*2))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ribbon:
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://modes/war/shaders/tracer.gdshader")
		node.material_override = shader
	elif not rocket_body:
		var mat := ShaderMaterial.new()
		mat.shader=preload("res://modes/war/shaders/projectile_core.gdshader")
		node.material_override = mat
	add_child(node)
	for i in count: pool.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	pool.visible_instance_count=0
	return pool

func spawn(owner_id: int,origin: Vector3,direction: Vector3,weapon: String,authoritative: bool,shot_id: String,extra: Dictionary = {}) -> bool:
	if available.is_empty(): return false
	var item: Dictionary = CombatRules.weapon(weapon) if GameWeapons.ITEMS.has(weapon) else {}
	var speed := float(extra.get("speed",item.get("speed",100)))
	var distance := float(extra.get("range",item.get("range",1000)))
	var slot: int = available.pop_back()
	var excluded: Array[RID]=game._collision_excludes(owner_id,false)
	if game.vehicle_system: excluded.append_array(game.vehicle_system.owner_excludes(owner_id))
	var query:=PhysicsRayQueryParameters3D.create(origin,origin,CombatRules.SHOT_MASK,excluded)
	query.collide_with_areas=true
	active_slots.append(slot)
	rounds[slot] = {"owner":owner_id,"position":origin,"velocity":direction.normalized()*speed+extra.get("inherited",Vector3.ZERO),"gravity":float(extra.get("gravity",item.get("gravity",9.81))),"range":distance,"distance":0.0,"life":float(extra.get("life",distance/maxf(speed,1)*1.4+.1)),"weapon":weapon,"damage":float(extra.get("damage",item.get("damage",20))),"radius":float(extra.get("radius",0)),"server":authoritative,"shot_id":shot_id,"target":str(extra.get("target","")),"history":[origin],"active":true,"fade":.075,"query":query,"drag":float(extra.get("drag",item.get("drag",0)))}
	var shot: Dictionary=rounds[slot]
	shot.infantry_damage=float(extra.get("infantry_damage",shot.damage))
	if float(shot.drag)<=0: shot.drag=float({"rpg":.016,"stinger":.008,"tv":.006,"hmg":.02}.get(weapon,0))
	shot.waterborne=bool(extra.get("waterborne",false))
	shot.tracer=GameTracerStyle.visible_for(weapon,shot_id)
	shot.exhaust_clock=0.0
	shot.guided=bool(extra.get("guided",false));shot.tv_vehicle=str(extra.get("tv_vehicle",""));shot.tv_life=int(extra.get("tv_life",-1));shot.tv_epoch=int(extra.get("tv_epoch",-1));shot.correction=Vector3.ZERO;shot.visual_wait=false;shot.tv_linked=bool(extra.get("tv_linked",true))
	by_id[shot_id]=slot
	if shot.guided and authoritative:
		var collider:=tv_colliders.get(slot) as Area3D
		if not is_instance_valid(collider):
			collider=Area3D.new();collider.monitoring=false;collider.monitorable=false;collider.collision_mask=0
			var volume:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=.38;volume.shape=shape
			collider.add_child(volume);add_child(collider);tv_colliders[slot]=collider
		collider.set_meta("tv_shot_id",shot_id);collider.set_meta("surface","metal")
		collider.global_position=origin;collider.collision_layer=2
		shot.hp=25.
		# The missile must not collide with its own physical hit volume.
		var self_excluded:=query.exclude;self_excluded.append(collider.get_rid());query.exclude=self_excluded
	if shot.guided and game.vehicle_system: game.vehicle_system.tv.register(shot)
	counter += 1
	return true

func flash(point: Vector3) -> void:
	flash_points[flash_cursor] = point
	flash_ages[flash_cursor] = .055
	flash_cursor = (flash_cursor+1)%48

func cancel_shot(id: String) -> void:
	for index in active_slots:
		var round: Dictionary=rounds[index]
		if str(round.shot_id)==id:
			round.active=false
			if tv_colliders.has(index): tv_colliders[index].collision_layer=0

func intercept_tv(id: String,attacker: int,damage: float) -> void:
	var shot:=find_round(id)
	if shot.is_empty() or not bool(shot.active) or not bool(shot.server) or not bool(shot.guided): return
	shot.hp=maxf(0,float(shot.get("hp",25))-damage)
	if float(shot.hp)>0: return
	cancel_shot(id)
	game.vehicle_system.tv.finish(id)
	game.vehicle_system._broadcast("explosion_event",[id,shot.position,1.5,"metal"])

func discard_owner(id: int) -> void:
	for index in active_slots:
		var round: Dictionary=rounds[index]
		if int(round.owner)==id and round.server: round.active=false

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var highest:=-1
	for cursor_index in range(active_slots.size()-1,-1,-1):
		var index: int=active_slots[cursor_index]
		var shot: Dictionary = rounds[index]
		if shot.active:
			var remaining := minf(delta,float(shot.life))
			while remaining>.000001 and shot.active:
				# Swept rays cover the complete segment. At 60 Hz the gravity
				# chord error is below 0.5 mm; homing keeps 120 Hz steering.
				var step := minf(remaining,1.0/(120.0 if not str(shot.target).is_empty() or shot.guided else 60.0))
				remaining -= step
				_step(shot,step)
			shot.life = float(shot.life)-delta
			if float(shot.life)<=0: shot.active=false
		else: shot.fade = float(shot.fade)-delta
		if tv_colliders.has(index):
			var collider: Area3D=tv_colliders[index]
			collider.collision_layer=2 if shot.active else 0
			collider.global_position=shot.position
		if not shot.active and float(shot.fade)<=0:
			_hide(index)
			by_id.erase(str(shot.shot_id))
			rounds[index] = {}
			available.append(index)
			active_slots.remove_at(cursor_index)
			continue
		highest=maxi(highest,index)
		if cores!=null: _draw_round(index,shot,camera)
	if cores!=null:
		for rocket_pool in rocket_bodies.values():
			var pool: MultiMesh=rocket_pool
			pool.visible_instance_count=highest+1
		cores.visible_instance_count=highest+1
		trails.visible_instance_count=(highest+1)*TRAIL_SEGMENTS
	if flashes!=null:
		flashes.visible_instance_count=48
		for i in 48:
			flash_ages[i] = maxf(0,flash_ages[i]-delta)
			flashes.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*flash_ages[i]/.055),flash_points[i]))
			flashes.set_instance_color(i,Color("ffcf86"))

func _step(shot: Dictionary,delta: float) -> void:
	if bool(shot.visual_wait): return
	if bool(shot.guided) and game.vehicle_system: game.vehicle_system.tv.steer(shot,delta)
	var old: Vector3 = shot.position
	if not str(shot.target).is_empty() and game.vehicle_system:
		var target: Node3D = game.vehicle_system.find_target(str(shot.target))
		if is_instance_valid(target):
			var velocity: Vector3 = shot.velocity
			var aim_point: Vector3=target.global_position+(Vector3.UP*1.2 if target is WarVehicle else Vector3.ZERO)
			var desired := (aim_point-old).normalized()
			var axis := velocity.normalized().cross(desired)
			if axis.length_squared()>.00001:
				shot.velocity = velocity.rotated(axis.normalized(),minf(velocity.normalized().angle_to(desired),2.2*delta))
	var acceleration := Vector3(0,-float(shot.gravity),0)
	var drag:=WarArmorBallistics.drag_for(str(shot.weapon),float(shot.drag),float(shot.distance),Vector3(shot.velocity).length())
	var coefficients:=GameBulletPhysics.coefficients(drag,delta)
	var next: Vector3=old+Vector3(shot.velocity)*coefficients.y+acceleration*coefficients.z
	if bool(shot.get("waterborne",false)): next.y=WarCoast.wave(next,game.war_clock)-.15
	if not shot.server and Vector3(shot.correction).length_squared()>.000001:
		var correction: Vector3=Vector3(shot.correction)*minf(1,delta*12)
		next+=correction;shot.correction=Vector3(shot.correction)-correction
	var remaining_distance:=maxf(0,float(shot.range)-float(shot.distance))
	if old.distance_to(next)>remaining_distance: next=old+(next-old).normalized()*remaining_distance
	shot.velocity=Vector3(shot.velocity)*coefficients.x+acceleration*coefficients.y
	var query: PhysicsRayQueryParameters3D=shot.query
	query.from=old;query.to=next
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() and not bool(shot.get("waterborne",false)) and next.y<=WarCoast.wave(next,game.war_clock) and WarCoast.wet(next.x,next.z):
		var amount:=clampf((old.y-WarCoast.wave(old,game.war_clock))/maxf(.001,old.y-next.y),0,1)
		hit={"position":old.lerp(next,amount),"normal":Vector3.UP,"collider":null,"water":true}
	if not hit.is_empty():
		next = hit.position
		if bool(shot.guided) and not shot.server: shot.visual_wait=true
		else: shot.active=false
		if shot.server:
			if float(shot.radius)>0:
				game.vehicle_system.explode(int(shot.owner),next,float(shot.damage),float(shot.radius),str(shot.weapon),str(shot.shot_id),hit,float(shot.infantry_damage))
			else:
				var item := {"id":shot.weapon,"damage":shot.damage}
				game._confirm_impact(int(shot.owner),hit,item,str(shot.shot_id),(next-old).normalized())
	shot.distance = float(shot.distance)+old.distance_to(next)
	if not shot.get("near_played",false) and is_instance_valid(game.combat_feedback) and is_instance_valid(game.local_player):
		if game.combat_feedback.near_miss(old,next,game.local_player,int(shot.owner),shot.velocity,str(shot.weapon)): shot.near_played=true
	shot.position = next
	if str(shot.weapon) in ["rpg","stinger"] and shot.active and DisplayServer.get_name()!="headless":
		shot.exhaust_clock=float(shot.exhaust_clock)+delta
		if float(shot.exhaust_clock)>=.075:
			shot.exhaust_clock=0.0
			var camera:=get_viewport().get_camera_3d()
			if is_instance_valid(camera) and camera.global_position.distance_squared_to(next)<62500. and is_instance_valid(game.combat_effects):
				var wake: Vector3=-Vector3(shot.velocity).normalized()*.50+Vector3.UP*.28
				game.combat_effects.spawn(next,wake,.10,.48,Color(.70,.70,.64,.31),.30)
	if float(shot.distance)>=float(shot.range): shot.active=false
	var history: Array = shot.history
	if history.is_empty() or history.back().distance_squared_to(next)>.01:
		history.append(next)
		if history.size()>TRAIL_SEGMENTS+1: history.pop_front()

static func projectile_width(camera: Camera3D,point: Vector3,pixels: float,minimum: float,maximum: float) -> float:
	if not is_instance_valid(camera): return minimum
	var size:=camera.get_viewport().get_visible_rect().size
	var tangent:=tan(deg_to_rad(camera.fov)*.5)
	if camera.keep_aspect==Camera3D.KEEP_WIDTH: tangent/=maxf(1,size.x/maxf(1,size.y))
	var units_per_pixel:=2*camera.global_position.distance_to(point)*tangent/maxf(1,size.y)
	return clampf(units_per_pixel*pixels,minimum,maximum)

func _draw_round(index: int,shot: Dictionary,camera: Camera3D) -> void:
	_draw_rocket(index,shot)
	if not bool(shot.get("tracer",true)):
		cores.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		for i in TRAIL_SEGMENTS: trails.set_instance_transform(index*TRAIL_SEGMENTS+i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		return
	var color: Color = GameTracerStyle.color_for(str(shot.weapon)) if GameTracerStyle.COLORS.has(str(shot.weapon)) else COLORS.get(str(shot.weapon),Color("ffb457"))
	if NavalCatalog.WEAPONS.has(str(shot.weapon)): color=NavalCatalog.WEAPONS[str(shot.weapon)].color
	var radius := 1.0 if str(shot.weapon) in ["glock","ak","fal","g3","sniper"] else 2.0
	if str(shot.weapon) in ["glock","ak","fal","g3"]: radius=GameTracerStyle.infantry_radius(camera,shot.position)/.025
	if str(shot.weapon)=="sniper": radius=GameTracerStyle.sniper_radius(camera,shot.position)/.025
	var heavy: bool=str(shot.weapon) in ["tank","autocannon","rpg","stinger","tv","missile","torpedo"]
	if heavy: radius=projectile_width(camera,shot.position,3.2,.10,4.0)/.05
	var camera_inside: bool=bool(shot.guided) and game.vehicle_system and game.vehicle_system.tv.view_id==str(shot.shot_id)
	cores.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ONE*(radius if shot.active and not camera_inside else 0)),shot.position))
	cores.set_instance_color(index,color)
	var history: Array = shot.history
	for segment in TRAIL_SEGMENTS:
		var slot := index*TRAIL_SEGMENTS+segment
		if segment+1>=history.size() or camera==null:
			trails.set_instance_transform(slot,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
			continue
		var a: Vector3 = history[segment]
		var b: Vector3 = history[segment+1]
		var tail_length: float=Vector3(shot.velocity).length()*(.012 if camera.global_position.distance_to(shot.position)<80 else .05)
		if Vector3(shot.position).distance_to(b)>tail_length:
			trails.set_instance_transform(slot,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO));continue
		a=b-(b-a).limit_length(maxf(.01,tail_length-Vector3(shot.position).distance_to(b)))
		var direction := (b-a).normalized()
		var centre := (a+b)*.5
		var across := direction.cross(camera.global_position-centre).normalized()
		if across.length_squared()<.01: across = Vector3.RIGHT
		var width:=projectile_width(camera,centre,2.0,.16,2.8) if heavy else (GameTracerStyle.infantry_radius(camera,centre)*2. if str(shot.weapon) in ["glock","ak","fal","g3"] else .075*radius)
		var basis := Basis(across*width,direction*a.distance_to(b),across.cross(direction))
		trails.set_instance_transform(slot,Transform3D(basis,centre))
		var tint := color
		tint.a = float(segment+1)/TRAIL_SEGMENTS*(.9 if heavy or str(shot.weapon)=="sniper" else .65)*clampf(float(shot.fade)/.075,0,1)
		trails.set_instance_color(slot,tint)

# Shared low-poly missile silhouettes; one MultiMesh per type, no per-shot nodes.
static func _rocket_mesh(kind: String) -> Mesh:
	var profile: Array[Vector2]=[]
	if kind=="rpg":
		profile=[Vector2(-.38,.006),Vector2(-.33,.025),Vector2(-.21,.068),Vector2(-.09,.079),Vector2(.04,.071),Vector2(.11,.027),Vector2(.34,.019),Vector2(.39,.008)]
	else:
		profile=[Vector2(-.61,.007),Vector2(-.55,.030),Vector2(-.43,.040),Vector2(.34,.040),Vector2(.48,.033),Vector2(.58,.010)]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(profile.size()-1):
		var front: Vector2=profile[ring_index]
		var back: Vector2=profile[ring_index+1]
		for side in 12:
			var a:=TAU*float(side)/12.0
			var b:=TAU*float(side+1)/12.0
			var p0:=Vector3(cos(a)*front.y,sin(a)*front.y,front.x)
			var p1:=Vector3(cos(b)*front.y,sin(b)*front.y,front.x)
			var p2:=Vector3(cos(b)*back.y,sin(b)*back.y,back.x)
			var p3:=Vector3(cos(a)*back.y,sin(a)*back.y,back.x)
			for corner in [p0,p1,p2,p0,p2,p3]: surface.add_vertex(corner)
	for fin in 4:
		var theta:=TAU*float(fin)/4.0
		var radial:=Vector3(cos(theta),sin(theta),0)
		var base_radius:=.020 if kind=="rpg" else .039
		var fin_radius:=.126 if kind=="rpg" else .105
		var fin_z:=.27 if kind=="rpg" else .42
		var a:=radial*base_radius+Vector3(0,0,fin_z-.105)
		var b:=radial*fin_radius+Vector3(0,0,fin_z+.025)
		var c:=radial*base_radius+Vector3(0,0,fin_z+.125)
		for corner in [a,b,c,c,b,a]: surface.add_vertex(corner)
	surface.generate_normals()
	var mesh:=surface.commit() as ArrayMesh
	var matte:=StandardMaterial3D.new()
	matte.albedo_color=Color("5e6753") if kind=="rpg" else Color("62665c")
	matte.metallic=.28
	matte.roughness=.75
	matte.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,matte)
	return mesh

func _draw_rocket(index: int,shot: Dictionary) -> void:
	var weapon:=str(shot.weapon)
	for id in rocket_bodies:
		var pool: MultiMesh=rocket_bodies[id]
		if id!=weapon or not bool(shot.active) or Vector3(shot.velocity).length_squared()<.001:
			pool.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
			continue
		var forward: Vector3=Vector3(shot.velocity).normalized()
		var up:=Vector3.UP if absf(forward.y)<.98 else Vector3.FORWARD
		var basis:=Basis.looking_at(forward,up)
		pool.set_instance_transform(index,Transform3D(basis,shot.position))

func _hide(index: int) -> void:
	if cores==null: return
	for rocket_pool in rocket_bodies.values():
		var pool: MultiMesh=rocket_pool
		pool.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	cores.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	for i in TRAIL_SEGMENTS: trails.set_instance_transform(index*TRAIL_SEGMENTS+i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))

func find_round(id: String) -> Dictionary:
	return rounds[int(by_id[id])] if by_id.has(id) else {}
