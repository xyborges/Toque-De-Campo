extends RefCounted
class_name BRCorpseAppearance

static func create(parent: Node3D,source: GamePlayer,position: Vector3) -> Node3D:
	var torso:=DeathRagdoll.create(parent,source,position,true)
	if not is_instance_valid(torso):return null
	var corpse:=torso.get_parent() as Node3D
	corpse.set_meta("br_corpse",true);corpse.set_meta("br_owner",source.peer_id);corpse.set_meta("br_life",source.life_id)
	return torso

static func bind_loot(corpse: Node3D,container_id: int,gear_parts: Dictionary) -> void:
	if not is_instance_valid(corpse):return
	corpse.set_meta("br_loot_id",container_id);corpse.set_meta("br_gear_parts",gear_parts.duplicate(true))
	for visual: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
		var kind:=str(visual.get_meta("br_equipment_kind",""))
		if gear_parts.has(kind):visual.set_meta("br_loot_part",int(gear_parts[kind]))
		elif not kind.is_empty():
			# A fatal hit can exhaust armor before the live appearance refresh.
			# Only equipment actually left on this corpse may remain visible.
			visual.hide();visual.set_meta("br_looted",true)

static func present(corpse: Node3D,remaining_ids: Array) -> void:
	if not is_instance_valid(corpse):return
	for visual: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
		if not visual.has_meta("br_loot_part"):continue
		# Equipment removal is monotonic for this corpse. A delayed older
		# contents packet cannot put a looted helmet back on the head.
		if visual.get_meta("br_looted",false):continue
		if int(visual.get_meta("br_loot_part")) not in remaining_ids:
			visual.hide();visual.set_meta("br_looted",true)

static func equipment_pieces(corpse: Node3D,kind: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if not is_instance_valid(corpse):return result
	for visual: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
		if str(visual.get_meta("br_equipment_kind",""))==kind:result.append(visual)
	return result
