extends RefCounted
class_name GameAttachmentRegistry

const ROOT:="res://scripts/attachments/data/"
static var definitions: Dictionary={}
static var weapon_profiles: Dictionary={}
static var initialized:=false

static func ensure() -> void:
	if initialized:return
	initialized=true
	for id in ["prism4x","pso4x","hensoldt4x","precision8x"]:
		var value:=load(ROOT+id+".tres") as GameAttachmentDefinition
		if value:definitions[value.id]=value
	for weapon in ["fal","ak","g3","glock","sniper","rpg","stinger"]:
		var value:=load(ROOT+"profiles/"+weapon+".tres") as GameAttachmentProfile
		if value:weapon_profiles[weapon]=value

static func definition(id: String) -> GameAttachmentDefinition:
	ensure();return definitions.get(id) as GameAttachmentDefinition
static func profile(weapon: String) -> GameAttachmentProfile:
	ensure();return weapon_profiles.get(GameWeapons.canonical(weapon)) as GameAttachmentProfile
static func ids(category:="",production_only:=true) -> Array[String]:
	ensure();var result: Array[String]=[]
	for id: String in definitions:
		var value: GameAttachmentDefinition=definitions[id]
		if (category.is_empty() or value.category==category) and (not production_only or value.production):result.append(id)
	result.sort();return result
static func register_definition(value: GameAttachmentDefinition) -> bool:
	ensure()
	if not value or value.id.is_empty() or value.id.length()>64 or value.category.is_empty() or value.required_interfaces.is_empty() or not value.required_space.is_finite() or not is_finite(value.weight) or value.weight<0:return false
	definitions[value.id]=value;return true
static func register_profile(value: GameAttachmentProfile) -> bool:
	ensure()
	if not value or value.weapon_id.is_empty():return false
	weapon_profiles[value.weapon_id]=value;return true
static func unregister_definition(id: String) -> void:ensure();definitions.erase(id)
static func unregister_profile(id: String) -> void:ensure();weapon_profiles.erase(id)
static func resolve_legacy(id: String,weapon: String) -> String:
	if id!="scope4x":return id if definition(id)!=null else ""
	var value:=profile(weapon);return value.legacy_optic if value else ""
static func fitting(definition_value: GameAttachmentDefinition,socket: GameAttachmentSocket) -> Dictionary:
	var result: Dictionary={}
	if not definition_value or not socket:return result
	for tag: String in socket.fitting_tags:
		if definition_value.fittings.get(tag) is Dictionary:result.merge(definition_value.fittings[tag],true)
	return result
