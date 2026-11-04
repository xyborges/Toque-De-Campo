extends Node
class_name GameAccountPreferences

const FILES:={"game":"game-options.json","aim":"aim-sensitivity.json","audio":"audio-settings.json","war_camera":"war-camera.json","naval":"settings.json"}
var accounts: NavalAccounts
var account_id:=""
var pending: Dictionary={}
var serial:=0
var applying:=false
var ready_to_send:=false
var sending:=false
var retry_after:=0.0
var legacy_owner:=""

func setup(owner_accounts: NavalAccounts) -> void:
	accounts=owner_accounts
	legacy_owner=str(accounts.profile.get("id",""))

func activate(id: String,generation: int) -> void:
	if id.length()!=32 or not id.is_valid_hex_number(false): return
	if account_id!=id:
		GameOptions.flush();GameAimSensitivity.flush();GameAudioSettings.flush()
		account_id=id;NavalStorage.preference_account=id
		DirAccess.make_dir_recursive_absolute(NavalStorage.settings_folder())
		NavalStorage.preference_changed=_changed
		var marker:=NavalStorage.folder().path_join("preferences-owner.json")
		var previous:=str(NavalStorage.read_json(marker).get("id",""))
		if (previous==id or (previous.is_empty() and legacy_owner==id)) and not FileAccess.file_exists(NavalStorage.settings_folder().path_join("migration-done.json")):
			applying=true
			for file: String in FILES.values():
				var old:=NavalStorage.folder().path_join(file);var destination:=NavalStorage.settings_folder().path_join(file)
				if FileAccess.file_exists(old) and not FileAccess.file_exists(destination): NavalStorage.write_json(destination,NavalStorage.read_json(old))
			var legacy_audio:=NavalStorage.folder().path_join("war-audio.json")
			if FileAccess.file_exists(legacy_audio): NavalStorage.write_json(NavalStorage.settings_folder().path_join("war-audio.json"),NavalStorage.read_json(legacy_audio))
			NavalStorage.write_json(NavalStorage.settings_folder().path_join("migration-done.json"),{"done":true});applying=false
		NavalStorage.write_json(marker,{"id":id})
		pending=NavalStorage.read_json(NavalStorage.settings_folder().path_join("pending.json"));serial=int(Time.get_unix_time_from_system()*1000)
		ready_to_send=false;_reload_local()
	await _pull(id,generation)

func _pull(id: String,generation: int) -> void:
	var response: Dictionary=await accounts.call_api("preferences_get")
	if not is_instance_valid(accounts) or generation!=accounts.session_generation or id!=account_id: return
	if not response.get("ok",false) or not response.get("settings") is Dictionary:
		ready_to_send=false;retry_after=5.;return
	var remote: Dictionary=response.settings
	applying=true
	for key: String in FILES:
		var local_path:=NavalStorage.settings_folder().path_join(FILES[key])
		if remote.has(key) and remote[key] is Dictionary and not pending.has(key):
			NavalStorage.write_json(local_path,remote[key])
		elif not remote.has(key) and FileAccess.file_exists(local_path) and not pending.has(key):
			serial+=1;pending[key]=serial
	applying=false;_save_pending();_reload_local();ready_to_send=true;retry_after=.5

func _reload_local() -> void:
	GameOptions.path="";GameAimSensitivity.cache_path="";GameAudioSettings.loaded_path=""
	GameOptions.ensure();GameOptions.apply_controls();GameAudioSettings.ensure()
	if get_viewport(): GameOptions.startup(get_viewport())

func _changed(path: String) -> void:
	if applying or account_id.is_empty() or path.get_base_dir()!=NavalStorage.settings_folder(): return
	for key: String in FILES:
		if path.get_file()==FILES[key]:
			serial+=1;pending[key]=serial;_save_pending();retry_after=.5;return

func _save_pending() -> void:
	if account_id.is_empty(): return
	NavalStorage.write_json(NavalStorage.settings_folder().path_join("pending.json"),pending)

func _process(delta: float) -> void:
	if account_id.is_empty() or not is_instance_valid(accounts) or not accounts.validated_session or accounts.token.is_empty() or sending: return
	retry_after-=delta
	if retry_after>0: return
	if not ready_to_send:
		retry_after=5.;_pull(account_id,accounts.session_generation);return
	if pending.is_empty(): retry_after=2.;return
	_upload(account_id,accounts.session_generation)

func _upload(id: String,generation: int) -> void:
	sending=true
	var versions:=pending.duplicate();var sections: Dictionary={}
	for key: String in versions:
		if not FILES.has(key): continue
		var data:=NavalStorage.read_json(NavalStorage.settings_folder().path_join(FILES[key]))
		if key=="naval":
			var filtered: Dictionary={}
			for field in ["sensitivity","music_db"]:
				if data.has(field): filtered[field]=data[field]
			data=filtered
		sections[key]=data
	if sections.is_empty(): sending=false;retry_after=5.;return
	var response: Dictionary=await accounts.call_api("preferences_set",{"sections":sections})
	if generation==accounts.session_generation and id==account_id:
		if response.get("ok",false):
			for key in versions:
				if pending.get(key)!=null and pending[key]==versions[key]: pending.erase(key)
			_save_pending();retry_after=.5
		else: retry_after=5.
	sending=false

func deactivate() -> void:
	GameOptions.flush();GameAimSensitivity.flush();GameAudioSettings.flush()
	account_id="";ready_to_send=false;NavalStorage.preference_account="";NavalStorage.preference_changed=Callable()
	_reload_local()

func _exit_tree() -> void:
	if NavalStorage.preference_changed==Callable(self,"_changed"): deactivate()
