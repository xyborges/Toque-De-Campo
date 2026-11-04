extends RefCounted
class_name NavalStorage
static var _folder_path := ""
static var preference_account := ""
static var preference_changed: Callable

static func folder() -> String:
	# The command line and installation directory are fixed for this process.
	# Resolve/probe once: hot settings getters must not touch the filesystem.
	if _folder_path.is_empty(): _folder_path = _resolve_folder()
	return _folder_path

static func settings_folder() -> String:
	if preference_account.is_empty(): return folder()
	return folder().path_join("preferences").path_join(preference_account)

static func mark_setting(file: String) -> void:
	if preference_changed.is_valid(): preference_changed.call(settings_folder().path_join(file))

static func _resolve_folder() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--naval-data="):
			var custom := arg.trim_prefix("--naval-data=")
			DirAccess.make_dir_recursive_absolute(custom)
			return custom
	var base := OS.get_user_data_dir()
	if base.is_empty() or not base.is_absolute_path():
		base = OS.get_environment("APPDATA").path_join("Godot/app_userdata/Toque de Campo — Godot")
	base = base.path_join("naval")
	DirAccess.make_dir_recursive_absolute(base)
	var probe := FileAccess.open(base.path_join(".write-probe"),FileAccess.WRITE)
	if probe:
		probe.close()
		DirAccess.remove_absolute(base.path_join(".write-probe"))
		return base
	base = (ProjectSettings.globalize_path("res://user_data") if OS.has_feature("editor") else portable_profiles(OS.get_executable_path())).path_join("naval")
	DirAccess.make_dir_recursive_absolute(base)
	return base

# The updater installs binaries in releases/<hash>. Keep identity outside that
# version directory so a signed update cannot accidentally create a new account.
static func portable_profiles(executable: String) -> String:
	var directory := executable.get_base_dir()
	var releases := directory.get_base_dir()
	var installation := releases.get_base_dir()
	if releases.get_file() == "releases" and FileAccess.file_exists(installation.path_join("installed.json")):
		return installation.path_join("profiles")
	return directory.path_join("ToqueDeCampo-data/profiles")

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	return parser.data if parser.data is Dictionary else {}

static func write_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data))
	file.close()
	var ok:=DirAccess.rename_absolute(path+".tmp",path) == OK
	if ok and preference_changed.is_valid(): preference_changed.call(path)
	return ok

static func client_key() -> CryptoKey:
	var path := folder().path_join("device-private.pem")
	var key := CryptoKey.new()
	if FileAccess.file_exists(path):
		if key.load(path) != OK: return null
	else:
		key = Crypto.new().generate_rsa(2048)
		if key.save(path) != OK: return null
	return key

static func load_account(id: String) -> Dictionary:
	var path := folder().path_join("accounts").path_join(id+".json")
	var account := read_json(path)
	if account.is_empty():
		account = {"id":id,"coins":0,"owned":["light"],"selected":"light","transactions":{}}
	return account

static func save_account(account: Dictionary) -> bool:
	return write_json(folder().path_join("accounts").path_join(str(account.id)+".json"),account)
