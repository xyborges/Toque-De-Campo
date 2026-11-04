extends Node3D
class_name GameGrenades

const LIMIT:=24
const FUSE:=5.0
const THROW_SPEED:=18.9
const RADIUS:=6.0
const DAMAGE:=160.0
var game: Node
var rounds: Dictionary={}
var events: Dictionary={}
var explosion_audio: GameExplosionAudio
var bursts: Array[Dictionary]=[]
var effects_available: Array[MeshInstance3D]=[]
var shape:=SphereShape3D.new()
var sweep_query:=PhysicsShapeQueryParameters3D.new()
var preview_full: Dictionary={}
var preview_remaining:=-1.0
var mesh: SphereMesh
var guide: MeshInstance3D
var guide_mesh: ImmediateMesh
var marker: MeshInstance3D
var preview_clock:=0.0
var preview_launch: Dictionary={}
var preview_points:=PackedVector3Array()
var preview_end:=Vector3.ZERO
var server_clock_offset:=0.0
var server_clock_ready:=false
static var prop_mesh: SphereMesh
static var prop_material: StandardMaterial3D
static var lever_mesh: BoxMesh
static var lever_material: StandardMaterial3D

static func make_prop() -> MeshInstance3D:
	# One model for FPP, TPP, remote preparation and the airborne grenade.
	if prop_mesh==null:
		prop_mesh=SphereMesh.new();prop_mesh.radius=.09;prop_mesh.height=.18;prop_mesh.radial_segments=10;prop_mesh.rings=5
		prop_material=StandardMaterial3D.new();prop_material.albedo_color=Color("43513a");prop_material.roughness=.85
		lever_mesh=BoxMesh.new();lever_mesh.size=Vector3(.025,.11,.025)
		lever_material=StandardMaterial3D.new();lever_material.albedo_color=Color("6d7569")
	var result:=MeshInstance3D.new();result.mesh=prop_mesh;result.material_override=prop_material;result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lever:=MeshInstance3D.new();lever.mesh=lever_mesh;lever.material_override=lever_material
	lever.position=Vector3(.06,.06,0);lever.rotation.z=-.4;lever.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;result.add_child(lever)
	return result

func _ready() -> void:
	shape.radius=.09
	sweep_query.shape=shape;sweep_query.collision_mask=1;sweep_query.margin=.002
	mesh=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=10;mesh.rings=5
	if DisplayServer.get_name()!="headless":
		explosion_audio=GameExplosionAudio.new();add_child(explosion_audio)
		guide_mesh=ImmediateMesh.new();guide=MeshInstance3D.new();guide.mesh=guide_mesh
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("155e6b");material.cull_mode=BaseMaterial3D.CULL_DISABLED
		guide.material_override=material;guide.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(guide);guide.hide()
		marker=MeshInstance3D.new();marker.mesh=mesh;marker.material_override=material;marker.scale=Vector3.ONE*.17;add_child(marker);marker.hide()

func prime(actor: GamePlayer,life: int,sequence: int) -> bool:
	if game.online and not multiplayer.is_server(): return false
	if not is_instance_valid(actor) or actor.hp<=0 or actor.life_id!=life or actor.grenades<=0 or not actor.grenades_enabled: return false
	if not game.grenade_allowed(actor): return false
	if not actor.grenade_held_id.is_empty() or rounds.size()>=LIMIT or sequence<=int(actor.get_meta("grenade_sequence",0)): return false
	var now:=Time.get_ticks_msec()*.001
	if now-float(actor.get_meta("grenade_at",-100))<.8: return false
	actor.pause_reload()
	actor.grenade_selected=true;actor._animate_walk()
	actor.set_meta("grenade_sequence",sequence);actor.set_meta("grenade_at",now);actor.grenades-=1
	var id:="grenade:%s:%d:%d:%d"%[str(game.match_generation),actor.peer_id,life,sequence]
	var packet: Dictionary={"id":id,"owner":actor.peer_id,"life":life,"sequence":sequence,"origin":_hand(actor),"velocity":Vector3.ZERO,"fuse":FUSE,"held":true,"revision":0,"server_stamp":Time.get_ticks_usec()*.000001,"deadline":Time.get_ticks_usec()*.000001+FUSE}
	spawn(packet)
	if game.online: game._broadcast("remote_grenade_spawn",[packet])
	game.sync_inventory(actor)
	return true

func _hand(actor: GamePlayer) -> Vector3:
	return actor.grenade_hand_position()

func accept(actor: GamePlayer,life: int,sequence: int,origin: Vector3,direction: Vector3) -> bool:
	if game.online and not multiplayer.is_server(): return false
	if not is_instance_valid(actor) or actor.hp<=0 or actor.life_id!=life or not origin.is_finite() or not direction.is_finite() or absf(direction.length()-1)>.01: return false
	if not game.grenade_allowed(actor): return false
	if origin.distance_to(actor.camera_pivot.global_position)>3.8: return false
	var expected:=actor.global_basis*(Basis(Vector3.RIGHT,actor.pitch)*Vector3.FORWARD)
	if expected.dot(direction)<.88: return false
	# The legacy direct command still primes on the authority. It cannot
	# reset an existing fuse, bypass inventory, or throw the same sequence twice.
	if actor.grenade_held_id.is_empty() and not prime(actor,life,sequence): return false
	var id:=actor.grenade_held_id
	if not rounds.has(id): return false
	var round: Dictionary=rounds[id]
	if not round.held or int(round.sequence)!=sequence or int(round.life)!=life: return false
	var launch:=launch_state(actor,direction)
	round.position=launch.origin;round.velocity=launch.velocity;round.held=false;round.revision=1
	var packet:=_packet(round)
	spawn(packet)
	if game.online: game._broadcast("remote_grenade_spawn",[packet])
	return true

func _packet(round: Dictionary) -> Dictionary:
	return {"id":round.id,"owner":round.owner,"life":round.life,"sequence":round.sequence,"origin":round.position,"velocity":round.velocity,"fuse":round.left,"held":round.held,"revision":round.revision,"drop":round.get("drop",false),"resting":round.get("resting",false),"server_stamp":Time.get_ticks_usec()*.000001,"deadline":Time.get_ticks_usec()*.000001+float(round.left)}

func spawn(packet: Dictionary) -> void:
	var id:=str(packet.id)
	if events.has(id) or (not rounds.has(id) and rounds.size()>=LIMIT): return
	var revision:=int(packet.get("revision",1))
	var stamp:=float(packet.get("server_stamp",0))
	if rounds.has(id) and stamp>0 and stamp<float(rounds[id].get("server_stamp",0)): return
	var remaining:=float(packet.fuse)
	if game.online and not multiplayer.is_server() and stamp>0:
		var now:=Time.get_ticks_usec()*.000001
		var sample: float=now-stamp-game._melee_network_delay(1)
		server_clock_offset=minf(server_clock_offset,sample) if server_clock_ready else sample
		server_clock_ready=true
		remaining=clampf(float(packet.get("deadline",stamp+remaining))-(now-server_clock_offset),0,FUSE)

	if rounds.has(id) and revision<int(rounds[id].revision): return
	var node: MeshInstance3D
	var existed:=rounds.has(id)
	var was_held: bool=existed and bool(rounds[id].held)
	var changed: bool=not existed or revision>int(rounds[id].revision)
	if existed: node=rounds[id].node
	elif DisplayServer.get_name()!="headless":
		node=make_prop()
		add_child(node)
	var held:=bool(packet.get("held",false))
	rounds[id]={"id":id,"owner":int(packet.owner),"life":int(packet.get("life",1)),"sequence":int(packet.get("sequence",1)),"position":Vector3(packet.origin),"velocity":Vector3(packet.velocity),"left":remaining,"server_stamp":stamp,"node":node,"held":held,"revision":revision,"drop":bool(packet.get("drop",false)),"resting":bool(packet.get("resting",false))}
	if is_instance_valid(node): node.global_position=packet.origin
	var actor:=game.players.get(int(packet.owner)) as GamePlayer
	if is_instance_valid(actor):
		if held or changed: actor.trigger_held=false
		if held:
			if changed: actor.pause_reload()
			actor.grenade_prime_pending=false;actor.grenade_selected=true
			actor.grenade_held_id=id;actor.grenade_fuse_left=remaining;actor.clear_weapon_aim()
		elif actor.grenade_held_id==id or was_held:
			actor.grenade_held_id="";actor.grenade_selected=false;actor.grenade_fuse_left=0;actor.grenade_aiming=false;actor.grenade_prime_pending=false
			if not packet.get("drop",false): actor.grenade_throw_left=.75

func drop_owner(owner: int) -> void:
	if game.online and not multiplayer.is_server(): return
	for round: Dictionary in rounds.values():
		if int(round.owner)==owner and round.held: _drop(round)

func _drop(round: Dictionary) -> void:
	round.held=false;round.revision=1;round.drop=true
	var actor:=game.players.get(int(round.owner)) as GamePlayer
	if is_instance_valid(actor):
		round.position=_hand(actor);round.velocity=actor.velocity.limit_length(8)*.35
		round.position.y=maxf(round.position.y,actor.global_position.y+.25)
	spawn(_packet(round))
	if game.online: game._broadcast("remote_grenade_spawn",[_packet(round)])

func _physics_process(delta: float) -> void:
	for id in rounds.keys():
		var round: Dictionary=rounds[id]
		var actor:=game.players.get(int(round.owner)) as GamePlayer
		var authority: bool=not game.online or multiplayer.is_server()
		if round.held:
			if is_instance_valid(actor) and actor.hp>0 and actor.life_id==int(round.life):
				round.position=_hand(actor);actor.grenade_held_id=id;actor.grenade_fuse_left=maxf(0,float(round.left)-delta)
			elif authority: _drop(round);round=rounds[id]
		if not round.held: advance(round,minf(delta,maxf(0,round.left)))
		round.left=maxf(0,float(round.left)-delta)
		var destination: Vector3=round.position
		if is_instance_valid(round.node):
			round.node.global_position=destination
			round.node.visible=not (round.held and is_instance_valid(actor) and actor.is_local and (not game.third_person or actor.iron_sights))
			if not round.held: round.node.rotate_x(delta*4)
		if round.left<=0 and authority:
			_damage(round);present_explosion(id,destination)
			if game.online: game._broadcast("remote_grenade_explosion",[id,destination])

func time_left(actor: GamePlayer) -> float:
	return maxf(0,float(rounds[actor.grenade_held_id].left)) if rounds.has(actor.grenade_held_id) else actor.grenade_fuse_left

func _damage(round: Dictionary) -> void:
	var before:=int(game.multi_kill_count(int(round.owner)))
	if game.has_method("environment_blast"): game.environment_blast(round.position,DAMAGE,RADIUS)
	for target: GamePlayer in game.players.values().duplicate():
		if not is_instance_valid(target) or target.hp<=0: continue
		var point: Vector3=target.global_position+Vector3.UP
		var distance_to: float=point.distance_to(round.position)
		if distance_to>=RADIUS: continue
		var visible_points:=0
		for height in [.5,1.1,1.65]:
			var ray:=PhysicsRayQueryParameters3D.create(round.position+Vector3.UP*.12,target.global_position+Vector3.UP*height,1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): visible_points+=1
		if visible_points==0 and not (target.peer_id==int(round.owner) and bool(round.get("held",false))): continue
		var region: Area3D=target.hit_regions.get("chest")
		if not is_instance_valid(region): continue
		var damage:=DAMAGE if target.peer_id==int(round.owner) and bool(round.get("held",false)) else DAMAGE*(1-distance_to/RADIUS)*visible_points/3.0
		game._apply_hit(int(round.owner),{"collider":region,"position":point},damage,"chest","grenade",(point-Vector3(round.position)).normalized())
	game.notify_multi_kill(int(round.owner),before,str(round.get("id",round.get("shot_id","grenade:"+str(round.position)))))

func present_explosion(id: String,point: Vector3) -> void:
	if events.has(id): return
	events[id]=true
	if events.size()>256: events.erase(events.keys()[0])
	if rounds.has(id):
		var round: Dictionary=rounds[id]
		var actor:=game.players.get(int(round.owner)) as GamePlayer
		if is_instance_valid(actor) and actor.grenade_held_id==id: actor.grenade_held_id="";actor.grenade_selected=false;actor.grenade_fuse_left=0;actor.grenade_aiming=false;actor.grenade_prime_pending=false
		if is_instance_valid(round.node): round.node.queue_free()
		rounds.erase(id)
	if explosion_audio: explosion_audio.play_event(id,point,"grenade")
	if DisplayServer.get_name()=="headless": return
	var camera:=get_viewport().get_camera_3d()
	var distant:=is_instance_valid(camera) and camera.global_position.distance_squared_to(point)>250.*250.
	# Same bounded mesh pool, but each puff has a purpose: flash,
	# expanding dust, then a dark lingering cloud. No new physics bodies.
	for index in (4 if distant else 10):
		if bursts.size()>=64: break
		var node: MeshInstance3D=effects_available.pop_back() if not effects_available.is_empty() else MeshInstance3D.new()
		if node.get_parent()==null:
			node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
			node.material_override=mat;add_child(node)
		var flash:=index==0
		var dust:=index>=1 and index<=4
		var direction:=Vector3(sin(index*2.39996),0,cos(index*2.39996))
		var lifetime:=.14 if flash else (1.45 if dust else 5.4)
		var size:=2.8 if flash else (1.0 if dust else 1.6)
		var growth:=5.0 if flash else (2.5 if dust else 1.25)
		var velocity:=Vector3.UP*.7 if flash else (direction*(5.0 if dust else 1.0)+Vector3.UP*(1.2 if dust else .65))
		var color:=Color(1.,.86,.54,.92) if flash else (Color(.46,.38,.30,.48) if dust else Color(.19,.20,.19,.57))
		node.material_override.albedo_color=color
		node.global_position=point+direction*.45+Vector3.UP*(.6 if flash else .35+index*.10)
		node.show()
		bursts.append({"node":node,"left":lifetime,"total":lifetime,"size":size,"growth":growth,"velocity":velocity,"alpha":color.a,"attack":.004 if flash else (.06 if dust else .32),"release":.09 if flash else (1.0 if dust else 2.3)})

func _process(delta: float) -> void:
	_preview(delta)
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary=bursts[i];burst.left-=delta
		if burst.left<=0:
			burst.node.hide();effects_available.append(burst.node);bursts.remove_at(i)
		else:
			var elapsed: float=float(burst.total)-float(burst.left)
			burst.node.global_position+=Vector3(burst.velocity)*delta
			burst.node.scale=Vector3.ONE*(float(burst.size)+float(burst.growth)*elapsed)
			burst.node.material_override.albedo_color.a=float(burst.alpha)*GameEffectEnvelope.opacity(elapsed,float(burst.total),float(burst.attack),float(burst.release))

func snapshots() -> Array:
	var result: Array=[]
	for round: Dictionary in rounds.values(): result.append(_packet(round))
	return result

func reset_round() -> void:
	for id in rounds:
		# Keep tombstones so a delayed unreliable snapshot cannot resurrect an
		# armed grenade after the new-round reliable message.
		events[id]=true
		var node: Node=rounds[id].node
		if is_instance_valid(node): node.queue_free()
	rounds.clear()
	while events.size()>512: events.erase(events.keys()[0])
	for actor: GamePlayer in game.players.values():
		actor.grenade_selected=false;actor.grenade_prime_pending=false;actor.grenade_aiming=false
		actor.grenade_held_id="";actor.grenade_fuse_left=0;actor.grenade_throw_left=0
	for burst in bursts:
		burst.node.hide();effects_available.append(burst.node)
	bursts.clear();preview_full.clear();preview_points.clear();preview_remaining=-1
	if is_instance_valid(guide): guide.hide()
	if is_instance_valid(marker): marker.hide()

func receive_snapshots(states: Array) -> void:
	for state: Dictionary in states: spawn(state)

func launch_state(actor: GamePlayer,direction: Vector3) -> Dictionary:
	var hand:=actor.avatar_parts.arm_r.get_node("HandR") as Node3D
	var start:=hand.global_position+direction*.25
	var ray:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,start,1)
	var obstacle:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty(): start=obstacle.position+obstacle.normal*.12
	return {"origin":start,"velocity":direction*THROW_SPEED+actor.velocity.limit_length(8)*.35}

func advance(round: Dictionary,delta: float) -> void:
	if round.get("resting",false) or delta<=0: return
	var old: Vector3=round.position
	var space:=get_world_3d().direct_space_state
	var query:=sweep_query
	query.motion=Vector3.ZERO
	query.transform=Transform3D(Basis.IDENTITY,old)
	# cast_motion ignores colliders overlapping the starting shape. Resolve
	# resting contact first, so a stopped grenade cannot sink through a floor.
	var overlap:=space.get_rest_info(query)
	if not overlap.is_empty():
		var surface_normal: Vector3=overlap.normal
		var penetration:=shape.radius+.006-(old-Vector3(overlap.point)).dot(surface_normal)
		if penetration>0: old+=surface_normal*penetration
		if Vector3(round.velocity).dot(surface_normal)<0: round.velocity=Vector3(round.velocity).bounce(surface_normal)*.43
	var destination: Vector3=old+round.velocity*delta+Vector3.DOWN*4.905*delta*delta
	round.velocity+=Vector3.DOWN*9.81*delta
	query.transform=Transform3D(Basis.IDENTITY,old);query.motion=destination-old
	var fractions:=space.cast_motion(query)
	if fractions[0]<1:
		destination=old+(destination-old)*maxf(0,fractions[0]-.005)
		query.transform.origin=old+query.motion*minf(1,fractions[1]+.002)
		query.motion=Vector3.ZERO
		var rest:=space.get_rest_info(query)
		var normal: Vector3=rest.get("normal",Vector3.UP)
		destination+=normal*.006
		round.velocity=Vector3(round.velocity).bounce(normal)*.43
		if round.velocity.length()<.45 and normal.y>.6: round.velocity=Vector3.ZERO;round.resting=true
	round.position=destination

func predict(launch: Dictionary,remaining:=FUSE) -> Dictionary:
	var state: Dictionary={"position":Vector3(launch.origin),"velocity":Vector3(launch.velocity)}
	var points:=PackedVector3Array([state.position])
	var elapsed:=0.0
	var index:=0
	while elapsed<remaining-.000001:
		var step:=minf(1.0/60.0,remaining-elapsed)
		advance(state,step);elapsed+=step;index+=1
		if index%2==0 or elapsed>=remaining-.000001: points.append(state.position)
	return {"points":points,"position":state.position}

func guide_prediction(launch: Dictionary,remaining: float) -> Dictionary:
	# A short PUBG-style arc to first contact only. No simulation of later
	# bounces or the complete fuse path in the per-frame aiming UI.
	var points:=PackedVector3Array([Vector3(launch.origin)])
	var duration:=minf(5.0,maxf(.02,remaining))
	var query:=PhysicsRayQueryParameters3D.new();query.collision_mask=1
	var contact:=false
	for index in range(1,33):
		var time:=duration*index/32.0
		var point: Vector3=Vector3(launch.origin)+Vector3(launch.velocity)*time+Vector3.DOWN*4.905*time*time
		query.from=points[points.size()-1];query.to=point
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): points.append(hit.position);contact=true;break
		points.append(point)
	return {"points":points,"position":points[points.size()-1],"contact":contact}

func _preview(delta: float) -> void:
	if not is_instance_valid(guide): return
	var actor:=game.local_player as GamePlayer
	var enabled: bool=is_instance_valid(actor) and actor.hp>0 and actor.grenade_aiming and (actor.grenade_selected or not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending) and game.gameplay_input_allowed()
	guide.visible=enabled;marker.visible=enabled
	if not enabled: preview_launch.clear();return
	preview_clock+=delta
	if preview_clock<.1: return
	preview_clock=0
	var camera:=actor.camera
	var launch:=launch_state(actor,-camera.global_basis.z.normalized())
	var remaining:=minf(FUSE,time_left(actor)) if not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending else FUSE
	if not preview_launch.is_empty() and Vector3(preview_launch.origin).distance_squared_to(launch.origin)<.0004 and Vector3(preview_launch.velocity).distance_squared_to(launch.velocity)<.0004 and absf(remaining-preview_remaining)<.1: return
	preview_launch=launch;preview_remaining=remaining
	var prediction:=guide_prediction(launch,remaining)
	preview_points=prediction.points;preview_end=prediction.position
	guide_mesh.clear_surfaces()
	if preview_points.size()>1:
		guide_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in preview_points.size()-1:
			var a:=preview_points[index];var b:=preview_points[index+1];var middle:=a.lerp(b,.5)
			var side: Vector3=(b-a).cross(camera.global_position-middle).normalized()*clampf(camera.global_position.distance_to(middle)*.0028,.004,.065)
			for point in [a-side,a+side,b-side,a+side,b+side,b-side]: guide_mesh.surface_add_vertex(point)
		guide_mesh.surface_end()
	marker.global_position=preview_end
