extends SceneTree
## Run externally with --main-pack, so this script is never shipped.
var files: Array[String]=[]
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func scan(path: String) -> void:
	var directory:=DirAccess.open(path)
	if not directory:return
	for name in directory.get_files():files.append(path.path_join(name))
	for name in directory.get_directories():scan(path.path_join(name))
func run() -> void:
	scan("res://")
	var data_path:="res://modes/battle_royale/navigation/prepared/manifest.json"
	check(FileAccess.file_exists(data_path),"navigation manifest included")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(data_path))
	check(data is Dictionary and bool(data.get("complete",false)),"production manifest complete")
	var mesh_count:=0;var polygons:=0
	if data is Dictionary:
		for record: Dictionary in data.get("tiles",[]):
			var mesh: NavigationMesh=load(str(record.path)) as NavigationMesh
			check(mesh!=null,"navigation resource loads: "+str(record.path))
			if mesh:mesh_count+=1;polygons+=mesh.get_polygon_count()
	check(data is Dictionary and mesh_count>0 and mesh_count==data.get("tiles",[]).size(),"all navigation resources declared by the prepared manifest are packaged")
	var unwanted: Array[String]=[];var secret_files: Array[String]=[];var native_files: Array[String]=[]
	for path in files:
		if path.begins_with("res://work/") or path.begins_with("res://tests/") or path.begins_with("res://distribution/") or path.get_file().begins_with("tile_") and path.contains("/navigation/"):unwanted.append(path)
		if path.begins_with("res://native/voice/"):native_files.append(path)
		if path.get_extension().to_lower() in ["key","pem","crt"]:
			var text:=FileAccess.get_file_as_string(path)
			if text.contains("PRIVATE KEY"):secret_files.append(path)
	check(unwanted.is_empty(),"no tests, work files, private distribution or dense source tiles")
	check(secret_files.is_empty(),"no packaged private key")
	check(native_files.is_empty(),"server pack excludes voice extension and native binaries")
	var extension_path:="res://.godot/extension_list.cfg"
	var extensions:="" if not FileAccess.file_exists(extension_path) else FileAccess.get_file_as_string(extension_path)
	check(not extensions.contains("native/voice/"),"no dangling voice extension registration")
	check(not ClassDB.class_exists("GodotOpusEncoder") and not ClassDB.class_exists("GodotOpusDecoder"),"headless server did not load voice codec")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"pack_files":files.size(),"navigation_resources":mesh_count,"navigation_polygons":polygons,"unwanted_files":unwanted,"private_key_files":secret_files,"native_voice_files":native_files,"extension_list":extensions,"engine":Engine.get_version_info(),"os":OS.get_name(),"scope":"Windows Godot editor loading locally exported Linux Server PCK; validates packaging/resource resolution, not a Linux executable runtime."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pack-report="):
			var file:=FileAccess.open(arg.trim_prefix("--pack-report="),FileAccess.WRITE)
			if file:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_SERVER_PACK_PROBE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
