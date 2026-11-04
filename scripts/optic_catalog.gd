extends RefCounted
class_name GameOpticCatalog

# Compatibility façade for old loadouts. Authoritative definitions, fitting,
# interfaces and models now belong to the universal attachment registry.
static func valid(id: String) -> bool:
	if id=="scope4x":return true
	var definition:=GameAttachmentRegistry.definition(id)
	return definition!=null and definition.behavior_type=="optical"
static func resolve(id: String,weapon: String) -> String:
	var resolved:=GameAttachmentRegistry.resolve_legacy(id,weapon)
	return resolved if valid(resolved) else ""
static func compatible(id: String,weapon: String) -> bool:
	return not GameAttachmentState.from_legacy(weapon,id).is_empty()
static func item_name(id: String,weapon:="") -> String:
	var definition:=GameAttachmentRegistry.definition(resolve(id,weapon))
	return definition.display_name if definition else ("4×" if id=="scope4x" else "")
static func title(id: String,weapon:="") -> String:return item_name(id,weapon)
static func magnification(id: String,weapon:="") -> float:
	var definition:=GameAttachmentRegistry.definition(resolve(id,weapon))
	return float(definition.behavior_parameters.get("magnification",1.)) if definition else (4. if id=="scope4x" else 1.)
static func model_id(id: String,weapon:="") -> String:return resolve(id,weapon)
static func model(id: String,weapon:="") -> PackedScene:
	var definition:=GameAttachmentRegistry.definition(resolve(id,weapon))
	return definition.scene_reference if definition and (weapon.is_empty() or compatible(id,weapon)) else null
static func ids_for_weapon(weapon: String) -> Array[String]:
	var result: Array[String]=[]
	for id: String in GameAttachmentRegistry.ids("optic"):
		if compatible(id,weapon):result.append(id)
	return result
