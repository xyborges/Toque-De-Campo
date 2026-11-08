extends SceneTree
## Real physics scan for V25 rooftops, plus native capsule walking tests.
## Godot --headless --path . --script res://tests/favela_roof_stability_v26_qa.gd
const RADIUS := .30
const HEIGHT := 1.75
const SPEED := 3.5
const STEP_DT := 1.0 / 60.0
const PHYS_STEPS := 22
var errors: Array[String] = []
var owner_labels: Dictionary = {}
var spots: Array[Dictionary] = []
var moves := 0
var reversals := 0
var failed_moves := 0
var grounded_spots := 0
var penetrated_spots := 0
var transition_failures := 0
var transition_reversals := 0
var transition_routes := 0
var world: Node3D
var map: WarFavelaMap
var walker: CharacterBody3D
var capsule := CapsuleShape3D.new()

func _initialize() -> void:
	_run.call_deferred()

func _shape_label(hit: Dictionary) -> String:
	var collider := hit.get("collider") as CollisionObject3D
	if not is_instance_valid(collider): return "none"
	var shape_id: int = int(hit.get("shape", -1))
	if shape_id < 0: return str(collider.name)
	var owner := collider.shape_find_owner(shape_id)
	var shape_node := collider.shape_owner_get_owner(owner)
	return str(shape_node.name) if shape_node is Node else str(collider.name)

func _sample(origin: Vector3) -> Dictionary:
	var space := root.world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * .45,
		origin - Vector3.UP * .65,1)
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return {"floor": false}
	var floor_y := float((hit.position as Vector3).y)
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape=capsule
	clearance.transform.origin=Vector3(origin.x,floor_y + HEIGHT * .5 + .032,origin.z)
	clearance.collision_mask=1
	var intrusions := space.intersect_shape(clearance,5)
	return {"floor":true,"height":floor_y,"normal":hit.normal,
		"shape":_shape_label(hit),"intrusions":intrusions.size()}

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	world = Node3D.new()
	world.name="FavelaRoofPhysicsQA"
	root.add_child(world)
	WarWorld.build(world,false)
	map=world.get_node("FavelaWar") as WarFavelaMap
	capsule.radius=RADIUS
	capsule.height=HEIGHT
	await physics_frame
	await physics_frame
	# V25 landing and roof both had the same upper face over 0.62m.
	# Duplicate coplanar contacts can make the capsule oscillate between
	# supports; inspect all generated colliders, not a selected building.
	# Godot auto-renames duplicate CollisionShape3D siblings inside the
	# EnvironmentSector body. Classify by unique physical dimensions instead
	# of scene node name to include EVERY house, not one per sector.
	var physical_landings: Array[CollisionShape3D] = []
	var physical_roofs: Array[CollisionShape3D] = []
	for node: Node in map.find_children("*","CollisionShape3D",true,false):
		var shape_node := node as CollisionShape3D
		if shape_node == null or not shape_node.shape is BoxShape3D:continue
		var physical_size: Vector3 = (shape_node.shape as BoxShape3D).size
		if absf(physical_size.y-.24)<.002 and absf(physical_size.z-1.0)<.002 and physical_size.x>.78 and physical_size.x<.88:
			physical_landings.append(shape_node)
		elif absf(physical_size.y-.28)<.002 and physical_size.x>8.0 and physical_size.z>8.0:
			physical_roofs.append(shape_node)
	var seam_checked := 0
	var worst_overlap_m := 0.0
	var unmatched_landings: Array[String] = []
	for item: Node in physical_landings:
		var landing_shape := item as CollisionShape3D
		if landing_shape == null or not landing_shape.shape is BoxShape3D: continue
		var p := landing_shape.global_position
		var sz: Vector3=(landing_shape.shape as BoxShape3D).size
		var landing_left:=p.x-sz.x*.5
		var landing_right:=p.x+sz.x*.5
		var best_overlap := 0.0
		for other: Node in physical_roofs:
			var slab := other as CollisionShape3D
			if slab == null or not slab.shape is BoxShape3D: continue
			var r:=slab.global_position
			var rz: Vector3=(slab.shape as BoxShape3D).size
			if absf((p.y+sz.y*.5)-(r.y+rz.y*.5))>.035:continue
			if p.z+sz.z*.5<r.z-rz.z*.5 or p.z-sz.z*.5>r.z+rz.z*.5:continue
			var overlap:=maxf(0.,minf(landing_right,r.x+rz.x*.5)-maxf(landing_left,r.x-rz.x*.5))
			best_overlap=maxf(best_overlap,overlap)
		if best_overlap>0:
			seam_checked+=1
			worst_overlap_m=maxf(worst_overlap_m,best_overlap)
		elif unmatched_landings.size()<12:
			unmatched_landings.append(str(p))
	if seam_checked < physical_landings.size() or worst_overlap_m>.035:
		errors.append("Coplanar roof landing overlap: "+str(worst_overlap_m)+", matched="+str(seam_checked))
	var all_roofs := 0
	var indexed := 0
	for path: PackedVector3Array in map.roof_paths:
		if path.size()!=9:continue
		all_roofs+=1
		if all_roofs % 4 != 1:continue
		indexed+=1
		var origin := path[-1] as Vector3
		for lateral in [Vector2.ZERO,Vector2(1.6,0),Vector2(-1.6,0),
			Vector2(0,1.6),Vector2(0,-1.6)]:
			var point := origin+Vector3(lateral.x,0,lateral.y)
			var result := _sample(point)
			if not bool(result.floor):
				spots.append({"site":str(point),"problem":"no_ground"})
				continue
			if float(result.normal.y)<.85:
				spots.append({"site":str(point),"problem":"inclined_ground","shape":result.shape})
			if int(result.intrusions)>0:
				penetrated_spots+=1
				if spots.size()<30:
					spots.append({"site":str(point),"problem":"body_overlap",
						"shape":result.shape,"intrusions":result.intrusions})
			else:
				grounded_spots+=1
			owner_labels[result.shape]=int(owner_labels.get(result.shape,0))+1
			if indexed>=30:break
		if indexed>=30:break
	walker=CharacterBody3D.new()
	walker.name="QAPlayerCapsule"
	walker.floor_snap_length=.45
	walker.collision_layer=1
	walker.collision_mask=1
	var collider:=CollisionShape3D.new()
	collider.shape=capsule
	collider.position.y=HEIGHT*.5
	walker.add_child(collider)
	root.add_child(walker)
	await physics_frame
	# Walk at least 10 representative roofs in both directions. A capped
	# step count keeps this inexpensive when used as a release gate.
	var tested:=0
	for path: PackedVector3Array in map.roof_paths:
		if path.size()!=9:continue
		if tested%3==2:
			tested+=1
			continue
		tested+=1
		var origin := path[-1] as Vector3
		for axis in [Vector3.RIGHT,Vector3.FORWARD]:
			walker.global_position=origin+Vector3.UP*.12
			walker.velocity=Vector3.ZERO
			await physics_frame
			for settle in 3:
				walker.velocity=Vector3.DOWN*.15
				walker.move_and_slide()
				await physics_frame
			var start := walker.global_position
			var previous := start
			for frame in PHYS_STEPS:
				walker.velocity.x=axis.x*SPEED
				walker.velocity.z=axis.z*SPEED
				if not walker.is_on_floor():walker.velocity.y-=9.81*STEP_DT
				GameStepMotion.move(walker,STEP_DT)
				var step_delta:=walker.global_position-previous
				if step_delta.dot(axis)<-.014:reversals+=1
				previous=walker.global_position
				await physics_frame
			moves+=1
			var advanced:=(walker.global_position-start).dot(axis)
			if advanced<.40:
				failed_moves+=1
				if spots.size()<30:
					spots.append({"site":str(origin),"problem":"failed_walk",
						"axis":str(axis),"advance":advanced})
		if tested>=12:break
	# A V25 bug report specifically concerns walking *onto* the slab.
	# Test the landing/door threshold/roof center, not only roof interiors.
	var ordinal:=0
	for path: PackedVector3Array in map.roof_paths:
		if path.size()!=9:continue
		ordinal+=1
		if ordinal%5!=1:continue
		transition_routes+=1
		walker.global_position=path[6]+Vector3.UP*.08
		walker.velocity=Vector3.ZERO
		await physics_frame
		for settle in 4:
			walker.velocity=Vector3.DOWN*.18
			walker.move_and_slide()
			await physics_frame
		for target_index in [7,8]:
			var target: Vector3=path[target_index]
			var arrived:=false
			var max_stuck:=0
			var stalled:=0
			for frame in 145:
				var toward:=Vector3(target.x-walker.global_position.x,
					0,target.z-walker.global_position.z)
				if toward.length()<.36:
					arrived=true
					break
				var heading:=toward.normalized()
				var previous_position:=walker.global_position
				walker.velocity.x=heading.x*SPEED
				walker.velocity.z=heading.z*SPEED
				if not walker.is_on_floor():walker.velocity.y-=9.81*STEP_DT
				GameStepMotion.move(walker,STEP_DT)
				var displacement:=walker.global_position-previous_position
				if displacement.dot(heading)<-.014:transition_reversals+=1
				if displacement.dot(heading)<.008:
					stalled+=1
					max_stuck=maxi(max_stuck,stalled)
				else:
					stalled=0
				await physics_frame
			if not arrived:
				transition_failures+=1
				if spots.size()<40:
					spots.append({"site":str(path[6]),"problem":"land_to_roof_blocked",
						"leg":target_index,"distance":walker.global_position.distance_to(target),
						"max_stalled_frames":max_stuck})
				break
		if transition_routes>=12:break
	print("FAVELA_ROOF_V26_QA ",JSON.stringify({
		"roofs_available":all_roofs,"roofs_scanned":indexed,
		"supported_clear":grounded_spots,"capsule_overlaps":penetrated_spots,
		"floor_shapes":owner_labels,"motions":moves,"reverse_ticks":reversals,
		"blocked_walks":failed_moves,"roof_landing_seams":seam_checked,
		"roof_landings_total":physical_landings.size(),
		"roof_slabs_total":physical_roofs.size(),
		"unmatched_landings":unmatched_landings,
		"max_coplanar_overlap_m":worst_overlap_m,"transition_routes":transition_routes,
		"transition_failures":transition_failures,"transition_reverse_ticks":transition_reversals,
		"geometry_errors":errors,"problem_sites":spots
	}))
	if not errors.is_empty() or penetrated_spots>0 or failed_moves>0 or transition_failures>0 or transition_reversals>3:
		print("FAVELA_ROOF_V26_QA REGRESSION_FOUND")
	else:
		print("FAVELA_ROOF_V26_QA PASS")
	walker.queue_free()
	world.queue_free()
	quit(0 if errors.is_empty() and penetrated_spots==0 and failed_moves==0 and transition_failures==0 and transition_reversals<=3 else 1)
