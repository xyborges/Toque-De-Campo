extends Node3D
class_name WarCollisionRigProxy
## P1b isolated prototype. Physics hierarchy is NOT the live hit detector yet.
## It intentionally stays on layer 0 and has disabled shapes: no double hits.
## Next step: replace source snapshot with a pure, independent pose solver.
const SNAPSHOT=preload("res://modes/war/scripts/collision_pose_state.gd")
var regions: Dictionary={}
var muzzle: Marker3D
var collision_source: GamePlayer
func build_from(actor: GamePlayer) -> int:
	collision_source=actor
	name="CollisionRigProxy"
	var count:=0
	for region_id: String in SNAPSHOT.REGIONS:
		var original: Area3D=actor.hit_regions.get(region_id)
		if not is_instance_valid(original):continue
		var replica:=Area3D.new()
		replica.name="Collision_"+region_id
		replica.collision_layer=0
		replica.collision_mask=0
		replica.monitoring=false
		replica.monitorable=false
		replica.set_meta("hit_region",original.get_meta("hit_region",region_id))
		for child in original.get_children():
			if child is CollisionShape3D:
				var source: CollisionShape3D=child as CollisionShape3D
				var shape:=CollisionShape3D.new()
				shape.name="RegionShape"
				shape.transform=source.transform
				shape.shape=source.shape.duplicate(true) if source.shape else null
				shape.disabled=true
				replica.add_child(shape)
		add_child(replica)
		regions[region_id]=replica
		count+=1
	muzzle=Marker3D.new()
	muzzle.name="CollisionMuzzle"
	add_child(muzzle)
	sync(SNAPSHOT.capture(actor))
	return count
func sync(frame: Dictionary) -> bool:
	var transforms: Dictionary=frame.get("regions",{})
	for id: String in regions:
		if not transforms.has(id):return false
		(regions[id] as Area3D).transform=transforms[id]
	if bool(frame.get("has_muzzle",false)):muzzle.transform=frame.muzzle
	return true
func snapshot() -> Dictionary:
	var out: Dictionary={}
	for id: String in regions:
		out[id]=(regions[id] as Area3D).transform
	return {"regions":out,"has_muzzle":is_instance_valid(muzzle),"muzzle":muzzle.transform if muzzle else Transform3D.IDENTITY}
