extends RefCounted
class_name BRPunchHistory

# Authority keeps a short geometric history, never rewinds physics objects.
# A delayed punch still needs contact with an actual hit region and a clear
# wall ray now. Life IDs prevent an old punch from crossing a respawn.
const WINDOW:=.24
const INTERVAL:=1./30.
const MAX_REWIND:=.12
var frames: Array[Dictionary]=[]
var next_at:=-1.

func clear() -> void:
	frames.clear();next_at=-1.

func record(actors: Dictionary,now: float) -> void:
	if now<next_at:return
	next_at=now+INTERVAL
	var poses: Dictionary={}
	for actor: GamePlayer in actors.values():
		if actor.hp<=0:continue
		var regions: Dictionary={}
		for key in actor.hit_regions:
			var area:=actor.hit_regions[key] as Area3D
			if not is_instance_valid(area) or area.collision_layer==0:continue
			var shape: CollisionShape3D
			for child in area.get_children():
				if child is CollisionShape3D:shape=child;break
			if shape and shape.shape is BoxShape3D:
				regions[key]={"transform":shape.global_transform,"size":(shape.shape as BoxShape3D).size}
		poses[actor.peer_id]={"life":actor.life_id,"position":actor.global_position,"regions":regions}
	frames.append({"at":now,"poses":poses})
	while not frames.is_empty() and now-float(frames[0].at)>WINDOW:frames.pop_front()

func contact(actors: Dictionary,owner: int,start: Vector3,end: Vector3,now: float,rewind: float,radius:=.12) -> Dictionary:
	if not start.is_finite() or not end.is_finite() or start.distance_to(end)>1.46:return {}
	record(actors,now)
	if frames.is_empty():return {}
	var at:=now-clampf(rewind,0.,MAX_REWIND)
	var frame: Dictionary=frames.back()
	for old: Dictionary in frames:
		if float(old.at)<=at:frame=old
		else:break
	var nearest:=INF;var result: Dictionary={}
	for id in frame.poses:
		if int(id)==owner:continue
		var actor:=actors.get(id) as GamePlayer;var pose: Dictionary=frame.poses[id]
		if not actor or actor.hp<=0 or actor.life_id!=int(pose.life):continue
		if Vector3(pose.position).distance_to(start)>2.3:continue
		for key in pose.regions:
			var area:=actor.hit_regions.get(key) as Area3D
			if not is_instance_valid(area):continue
			var region: Dictionary=pose.regions[key];var transform: Transform3D=region.transform
			var inverse:=transform.affine_inverse()
			var padding:=Vector3(radius/maxf(.1,transform.basis.x.length()),radius/maxf(.1,transform.basis.y.length()),radius/maxf(.1,transform.basis.z.length()))
			var half:=Vector3(region.size)*.5+padding
			var local_hit: Variant=AABB(-half,half*2).intersects_segment(inverse*start,inverse*end)
			if local_hit==null:continue
			var point: Vector3=transform*Vector3(local_hit);var distance:=start.distance_squared_to(point)
			if distance<nearest:
				nearest=distance;result={"collider":area,"position":point,"normal":(start-end).normalized(),"history_at":float(frame.at)}
	return result
