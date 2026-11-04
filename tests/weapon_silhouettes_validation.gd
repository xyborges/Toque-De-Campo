extends SceneTree
const ICONS=preload("res://scripts/ui/weapon_silhouette.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:
	for id in ICONS.IDS:
		var image:=Image.load_from_file(ICONS.PATH+id+".png")
		check(image!=null and image.get_size()==Vector2i(1024,320),id+" baked asset size")
		if not image:continue
		check(image.get_format()==Image.FORMAT_RGBA8,id+" alpha channel")
		var used:=image.get_used_rect()
		check(used.position.x>4 and used.position.y>4 and used.end.x<1020 and used.end.y<316,id+" silhouette has no cropped geometry")
		check(image.get_pixel(0,0).a==0. and used.get_area()>60000,id+" transparent background and nonempty recognizable mesh")
		var profile: Dictionary=ICONS.profile(id)
		check(profile.get("anchors",{}).size()==6,id+" six generic mount coordinates")
		for point: Array in profile.get("anchors",{}).values():check(float(point[0])>0. and float(point[0])<1. and float(point[1])>0. and float(point[1])<1.,id+" normalized mount inside canvas")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Offline PNGs derived from actual gameplay meshes, RGBA transparency, framing and normalized mount coordinates. Runtime only loads static textures; no gameplay viewport."}
	var file:=FileAccess.open("res://work/weapon-silhouettes-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WEAPON_SILHOUETTES_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
