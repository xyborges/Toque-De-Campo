extends RefCounted

# R2C's first shared result: actor-local transforms, composed from a fresh
# physical base. Reuse the object, never integrate deltas from its last output.
# Tick/life identify a result; they are NOT a cache key for gameplay state.
var physics_tick: int = -1
var life: int = -1
var pelvis_base := Transform3D.IDENTITY
var torso_base := Transform3D.IDENTITY
var pelvis := Transform3D.IDENTITY
var torso := Transform3D.IDENTITY

func compose(base_pelvis: Transform3D,base_torso: Transform3D,hip_offset: Vector3,hip_angles: Vector3,torso_angles: Vector3,tick: int,life_id: int) -> void:
	pelvis_base=base_pelvis
	torso_base=base_torso
	pelvis=Transform3D(base_pelvis.basis*Basis.from_euler(hip_angles),base_pelvis.origin+hip_offset)
	torso=Transform3D(base_torso.basis*Basis.from_euler(torso_angles),base_torso.origin)
	physics_tick=tick
	life=life_id

func valid_for(tick: int,life_id: int) -> bool:
	return physics_tick>=0 and life>=0 and physics_tick==tick and life==life_id

func invalidate() -> void:
	physics_tick=-1
	life=-1
