extends RefCounted
## Shared, export-safe identity. Generated files are never hashed at connection time.
const IDS:=["ukraine","afghan","desert","office","naval"]
const ROOT:="res://maps/prepared/"
static var cache: Dictionary={}
static var checked: Dictionary={}

static func get_definition(id: String) -> Dictionary:
	if id not in IDS:return {}
	if not cache.has(id):
		var path:=ROOT+id+"/manifest.json"
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		cache[id]=data if data is Dictionary else {}
	return cache[id]

static func identity(id: String) -> Dictionary:
	var data:=get_definition(id)
	return {"id":id,"version":int(data.get("version",0)),"hash":str(data.get("content_hash",""))}

static func compatible(id: String,remote: Variant) -> bool:
	var local:=identity(id)
	return current(id) and remote is Dictionary and local.version>0 and local.hash.length()==64 and remote.get("id","")==id and remote.get("version",-1)==local.version and remote.get("hash","")==local.hash

static func source_hash(paths: Array) -> String:
	var ordered:=paths.duplicate();ordered.sort()
	var signature:=""
	for path: String in ordered:
		if not FileAccess.file_exists(path):return ""
		signature+=path+":"+FileAccess.get_sha256(path)+";"
	return signature.sha256_text()

static func current(id: String) -> bool:
	var data:=get_definition(id)
	if data.is_empty():return false
	if not checked.has(id):checked[id]=not OS.has_feature("editor") or source_hash(data.get("sources",[]))==data.get("source_hash","")
	return checked[id]

static func grass_enabled(id: String) -> bool:
	# Explicit QA bypass still requires matching prepared content.
	return current(id) and (bool(get_definition(id).get("grass_enabled",false)) or bool(get_definition(id).get("grass_approved",false)) or "--nova-grama-preview" in OS.get_cmdline_user_args())

static func cartography(id: String,variant:=0) -> Texture2D:
	if DisplayServer.get_name()=="headless":return null
	var file:=ROOT+id+"/cartography"+("_"+str(variant) if id=="naval" else "")+".res"
	return load(file) as Texture2D if ResourceLoader.exists(file) and current(id) else null
