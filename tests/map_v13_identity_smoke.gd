extends SceneTree
const DEFINITIONS=preload("res://scripts/maps/definition.gd")
const NAV=preload("res://modes/battle_royale/navigation/navigation.gd")
func _initialize() -> void:
	var ok:=true
	for id in ["afghan","ukraine"]:
		var identity:=DEFINITIONS.identity(id)
		var present:=DEFINITIONS.compatible(id,identity)
		var invalid:=identity.duplicate()
		invalid.hash="invalid-prepared-map-content"
		var rejects_old:=not DEFINITIONS.compatible(id,invalid)
		print("MAP_IDENTITY_QA ",id," v=",identity.version," compatible=",present," rejects_changed=",rejects_old)
		ok=ok and present and rejects_old
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NAV.DATA))
	var nav_ok:=bool(manifest.get("complete",false)) and str(manifest.get("source_hash",""))==NAV.source_hash()
	var shelters:=0
	for region: Dictionary in manifest.get("tiles",[]):
		if "/shed_" in str(region.get("path","")):shelters+=1
	print("MAP_IDENTITY_QA nav_complete=",nav_ok," v13_shed_regions=",shelters)
	ok=ok and nav_ok and shelters==12
	print("MAP_IDENTITY_RESULT ",JSON.stringify({"ok":ok}))
	quit(0 if ok else 1)
