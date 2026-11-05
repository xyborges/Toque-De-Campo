extends Node3D
class_name WarCollisionRigProxy
## P1g collision hierarchy. It can become the authoritative hit-region tree
## under an explicit QA pilot while preserving the legacy visual regions for
## fallback states and clean restoration.
const SNAPSHOT=preload("res://modes/war/scripts/collision_pose_state.gd")

var regions: Dictionary={}
var legacy_regions: Dictionary={}
var muzzle: Marker3D
var collision_source: GamePlayer
var using_authority:=false

func build_from(actor: GamePlayer) -> int:
	collision_source=actor
	name="CollisionRigProxy"
	legacy_regions=actor.hit_regions.duplicate()
	var count:=0
	for region_id: String in SNAPSHOT.REGIONS:
		var original: Area3D=legacy_regions.get(region_id)
		if not is_instance_valid(original): continue
		var replica:=Area3D.new()
		replica.name="Collision_"+region_id
		replica.collision_layer=0
		replica.collision_mask=0
		replica.monitoring=false
		replica.monitorable=false
		replica.set_meta("hit_region",original.get_meta("hit_region",region_id))
		for child in original.get_children():
			if child is CollisionShape3D:
				var source:=child as CollisionShape3D
				var shape:=CollisionShape3D.new()
				shape.name="CollisionShape3D"
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
	sync_legacy(actor)
	return count

func _shape(area: Area3D) -> CollisionShape3D:
	if not is_instance_valid(area): return null
	for child in area.get_children():
		if child is CollisionShape3D: return child as CollisionShape3D
	return null

func _region_states(source: Dictionary) -> Dictionary:
	var states: Dictionary={}
	for id: String in source:
		var area:=source[id] as Area3D
		if not is_instance_valid(area): continue
		var shape:=_shape(area)
		states[id]={
			"layer":area.collision_layer,
			"disabled":bool(shape.disabled) if is_instance_valid(shape) else true
		}
	return states

func _disable(source: Dictionary) -> void:
	for area: Area3D in source.values():
		if not is_instance_valid(area): continue
		area.collision_layer=0
		var shape:=_shape(area)
		if is_instance_valid(shape): shape.disabled=true

func _apply_states(target: Dictionary,states: Dictionary) -> void:
	for id: String in target:
		var area:=target[id] as Area3D
		if not is_instance_valid(area): continue
		var state: Dictionary=states.get(id,{"layer":0,"disabled":true})
		var layer:=int(state.layer)
		var shape:=_shape(area)
		# Collision layer is changed immediately by GamePlayer while shape
		# disabling is deferred. Treat layer 0 as disabled during a swap so a
		# same-frame restore cannot accidentally revive a collider.
		if is_instance_valid(shape): shape.disabled=bool(state.disabled) or layer==0
		area.collision_layer=layer

func activate(actor: GamePlayer) -> bool:
	if using_authority: return actor.hit_regions==regions
	if legacy_regions.is_empty() or regions.is_empty(): return false
	var states:=_region_states(legacy_regions)
	# Disable the old collision source before making the new one visible to
	# gameplay queries. The proxy is already synchronized by the caller.
	_disable(legacy_regions)
	_apply_states(regions,states)
	actor.hit_regions=regions
	using_authority=true
	return true

func restore(actor: GamePlayer) -> bool:
	if not using_authority:
		if not legacy_regions.is_empty(): actor.hit_regions=legacy_regions
		return true
	var states:=_region_states(regions)
	_disable(regions)
	_apply_states(legacy_regions,states)
	actor.hit_regions=legacy_regions
	using_authority=false
	return true

func sync(frame: Dictionary) -> bool:
	var transforms: Dictionary=frame.get("regions",{})
	for id: String in regions:
		if not transforms.has(id): return false
		(regions[id] as Area3D).transform=transforms[id]
	if bool(frame.get("has_muzzle",false)): muzzle.transform=frame.muzzle
	return true

func legacy_snapshot(actor: GamePlayer) -> Dictionary:
	var transforms: Dictionary={}
	var inverse:=actor.global_transform.affine_inverse()
	for id: String in legacy_regions:
		var region:=legacy_regions[id] as Area3D
		if is_instance_valid(region): transforms[id]=inverse*region.global_transform
	var has_muzzle:=is_instance_valid(actor.muzzle_marker)
	var muzzle_transform:=inverse*actor.muzzle_marker.global_transform if has_muzzle else Transform3D.IDENTITY
	return {"regions":transforms,"has_muzzle":has_muzzle,"muzzle":muzzle_transform}

func sync_legacy(actor: GamePlayer) -> bool:
	var inverse:=actor.global_transform.affine_inverse()
	for id: String in regions:
		var source:=legacy_regions.get(id) as Area3D
		if not is_instance_valid(source): return false
		(regions[id] as Area3D).transform=inverse*source.global_transform
	if is_instance_valid(actor.muzzle_marker):
		muzzle.transform=inverse*actor.muzzle_marker.global_transform
	return true

func snapshot() -> Dictionary:
	var out: Dictionary={}
	for id: String in regions:
		out[id]=(regions[id] as Area3D).transform
	return {"regions":out,"has_muzzle":is_instance_valid(muzzle),"muzzle":muzzle.transform if muzzle else Transform3D.IDENTITY}
