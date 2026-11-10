extends SceneTree
## Actual player step physics on 8 hillside alleys and western mountain.
const W=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const DT:=1.0/60.0
var failures:Array[String]=[]
func _initialize()->void:
	_run.call_deferred()
func _player(parent:Node3D)->CharacterBody3D:
	var actor:=CharacterBody3D.new()
	actor.name="FavelaV2CapsuleQA"
	actor.collision_layer=1
	actor.collision_mask=1
	actor.floor_snap_length=.5
	var shape:=CapsuleShape3D.new()
	shape.radius=.3
	shape.height=1.78
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	collider.position=Vector3.UP*.89
	actor.add_child(collider)
	parent.add_child(actor)
	return actor

func _walk(actor:CharacterBody3D,start:Vector2,heading:Vector2,
		speed:float,frames:int)->Dictionary:
	actor.global_position=Vector3(start.x,T.height_at(start.x,start.y)+.28,start.y)
	actor.velocity=Vector3.ZERO
	for i in 12:
		await physics_frame
		actor.velocity=Vector3(0,-.30,0)
		actor.move_and_slide()
	var begun:Vector3=actor.global_position
	var last:=begun
	var backwards:=0
	var peak_vertical:=0.0
	var grounded:=0
	for tick in frames:
		await physics_frame
		actor.velocity.x=heading.x*speed
		actor.velocity.z=heading.y*speed
		if actor.is_on_floor():
			actor.velocity.y=-.1
		else:
			actor.velocity.y-=9.81*DT
		GameStepMotion.move(actor,DT)
		var pos:Vector3=actor.global_position
		var diff:=pos-last
		if Vector2(diff.x,diff.z).dot(heading)<-.02:backwards+=1
		peak_vertical=maxf(peak_vertical,absf(diff.y))
		if actor.is_on_floor():grounded+=1
		last=pos
	return {"meters":snappedf(Vector2(last.x-begun.x,
			last.z-begun.z).dot(heading),.01),
		"backwards":backwards,"max_vertical":snappedf(peak_vertical,.003),
		"grounded_frames":grounded,
		"end":Vector2(last.x,last.z),"start":start}

func _run()->void:
	var scene:=Node3D.new()
	root.add_child(scene)
	var data:=W.build(scene,false)
	await physics_frame
	var actor:=_player(scene)
	var alleys:=W.plan_alleys()
	var results:Array[Dictionary]=[]
	var tested:=0
	for alley:Dictionary in alleys:
		if tested>=10:break
		var start:Vector2=alley["a"]
		var end:Vector2=alley["to"]
		var dir:Vector2=(end-start).normalized()
		var test=await _walk(actor,start+dir*1.4,dir,3.3,120)
		var passable:bool=float(test["meters"])>=5.2 and int(test["backwards"])<=3
		if not passable:failures.append("alley_"+str(tested)+"_"+str(alley["edge"]))
		results.append({"id":str(alley["edge"]),"meters":test["meters"],
			"backwards":test["backwards"],"pass":passable})
		tested+=1
	# Terrain and physical rock crest test: the player must NOT gain a
	# traversable shortcut from the dead-end western roofs to the high base.
	# Walk north from the southern shoulder directly toward the ridge.
	var climb=await _walk(actor,Vector2(-205.0,-203.0),
		Vector2(0,-1),6.0,550)
	var final_pos:Vector2=climb["end"]
	var ridge_blocked:bool=final_pos.y> -241.0
	if not ridge_blocked:failures.append("northern_crest_was_walkable")
	print("FAVELA_V2_DENSITY_WALK_QA ",JSON.stringify({
		"pass":failures.is_empty(),"alleys_walked":tested,
		"rock_crest_bodies":data["alleys_and_details"]["rock_crest_colliders"],
		"ridge_blocked":ridge_blocked,"ridge_final_z":snappedf(final_pos.y,.02),
		"ridge_progress_m":climb["meters"],
		"alley_results":results,"failures":failures}))
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)
