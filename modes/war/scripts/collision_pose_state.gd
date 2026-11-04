extends RefCounted
class_name WarCollisionPoseState
## Pure collision-pose snapshot contract. Never manipulates visual rigs,
## physics shapes, weapon origins, authoritative state, or scene hierarchy.
## P1b will use this to prove an independent collision rig equals the
## existing articulated rig under identical gameplay state.
const REGIONS: Array[String]=[
	"head","chest","abdomen","abdomenPelvis",
	"armL","armR","forearmL","forearmR","handL","handR",
	"legL","legR","shinL","shinR","footL","footR"
]
static func capture(actor: GamePlayer) -> Dictionary:
	var transforms: Dictionary={}
	var basis: Transform3D=actor.global_transform.affine_inverse()
	for id: String in REGIONS:
		var region: Area3D=actor.hit_regions.get(id)
		if is_instance_valid(region):
			transforms[id]=basis*region.global_transform
	var muzzle: Transform3D=Transform3D.IDENTITY
	var has_muzzle:=is_instance_valid(actor.muzzle_marker)
	if has_muzzle: muzzle=basis*actor.muzzle_marker.global_transform
	return {
		"life":actor.life_id,
		"weapon":actor.weapon_id,
		"physics_frame":Engine.get_physics_frames(),
		"posture":2 if actor.prone else (1 if actor.crouched else 0),
		"crouch_weight":actor.stance.crouch_weight,
		"prone_weight":actor.stance.prone_weight,
		"pitch":actor.pitch,
		"lean":actor.lean,
		"regions":transforms,
		"has_muzzle":has_muzzle,
		"muzzle":muzzle
	}

static func compare(a: Dictionary,b: Dictionary) -> Dictionary:
	var left: Dictionary=a.get("regions",{})
	var right: Dictionary=b.get("regions",{})
	var missing: Array[String]=[]
	var per: Dictionary={}
	var max_origin:=0.
	var max_basis:=0.
	for name: String in left:
		if not right.has(name):
			missing.append(name)
			continue
		var l: Transform3D=left[name]
		var r: Transform3D=right[name]
		var offset:=l.origin.distance_to(r.origin)
		var rotation_error:=0.
		for index in 3:
			rotation_error=maxf(rotation_error,l.basis[index].distance_to(r.basis[index]))
		per[name]={"origin_m":offset,"basis_delta":rotation_error}
		max_origin=maxf(max_origin,offset)
		max_basis=maxf(max_basis,rotation_error)
	for name: String in right:
		if not left.has(name):missing.append(name)
	var muzzle_offset: float=-1.
	var muzzle_basis: float=-1.
	if a.get("has_muzzle",false) and b.get("has_muzzle",false):
		var m1: Transform3D=a.muzzle
		var m2: Transform3D=b.muzzle
		muzzle_offset=m1.origin.distance_to(m2.origin)
		muzzle_basis=0.
		for index in 3:
			muzzle_basis=maxf(muzzle_basis,m1.basis[index].distance_to(m2.basis[index]))
	return {
		"regions_a":left.size(),"regions_b":right.size(),
		"missing":missing,"per_region":per,
		"max_origin_m":max_origin,"max_basis_delta":max_basis,
		"muzzle_origin_m":muzzle_offset,"muzzle_basis_delta":muzzle_basis
	}
