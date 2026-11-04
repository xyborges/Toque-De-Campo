extends RefCounted
class_name GameWeaponSilhouette
## PNGs baked from gameplay meshes; no live 3D viewport in inventory screens.
const PATH:="res://assets/ui/weapons/"
const IDS:=["fal","ak","sniper","glock","rpg","stinger"]
static var textures: Dictionary={}
static var profiles: Dictionary={}

static func texture(id: String) -> Texture2D:
	id=GameWeapons.canonical(id)
	if not id in IDS:return null
	if not textures.has(id):textures[id]=load(PATH+id+".png")
	return textures[id]

static func profile(id: String) -> Dictionary:
	id=GameWeapons.canonical(id)
	if profiles.is_empty():
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH+"silhouettes.json"))
		if data is Dictionary:profiles=data
	return profiles.get(id,{}).duplicate(true)
