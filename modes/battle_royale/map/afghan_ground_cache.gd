extends RefCounted
const ROOT:="res://modes/battle_royale/map/"
const FILES:=["afghan_ground_source.gdshader","afghan_landform.gd","afghan_biomes.png"]
static func signature() -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for file in FILES: hash.update(FileAccess.get_file_as_bytes(ROOT+file))
	for file in ["sand-albedo","concrete-albedo","rock-albedo"]:
		hash.update(FileAccess.get_file_as_bytes("res://assets/environment/materials/"+file+".png"))
	return hash.finish().hex_encode()
static func valid() -> bool:
	if not ResourceLoader.exists(ROOT+"afghan_ground_baked.png") or not FileAccess.file_exists(ROOT+"afghan_ground_baked.json"): return false
	# Editor changes invalidate automatically; the exported package contains
	# the last validated bake, since original source files may be remapped.
	if OS.has_feature("editor"):
		var data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"afghan_ground_baked.json"))
		return data is Dictionary and str(data.get("signature",""))==signature()
	return true
