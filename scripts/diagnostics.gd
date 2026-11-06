extends Node

# Never record credentials, command-line arguments, voice samples or RPC bodies.
const LIMIT := 8 * 1024 * 1024
var path := ""
var file: FileAccess
var pending: Array[Dictionary] = []
var lock := Mutex.new()
var sink: Logger
var clock := 0.
var session := ""
var peer_files: Dictionary={}
var writer:=Thread.new()
var wake:=Semaphore.new()
var file_lock:=Mutex.new()
var stopping:=false
var repeated: Dictionary={}

class ErrorSink extends Logger:
	var owner: Node
	func _log_message(_message: String, _error: bool) -> void: pass
	func _log_error(function: String, source: String, line: int, code: String, rationale: String, _notify: bool, kind: int, _traces: Array[ScriptBacktrace]) -> void:
		if is_instance_valid(owner): owner.record("engine_error", {"function":function,"source":source.get_file(),"line":line,"code":code,"reason":rationale,"kind":kind})

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var folder := NavalStorage.folder().path_join("diagnostics")
	DirAccess.make_dir_recursive_absolute(folder)
	var old := DirAccess.get_files_at(folder);var sessions: Array[String]=[]
	for name_text in old:
		if name_text.ends_with(".jsonl"):
			var group:=name_text.trim_suffix(".jsonl").split("-peer-")[0]
			if group not in sessions:sessions.append(group)
	sessions.sort()
	while sessions.size()>=8:
		var group: String=sessions.pop_front()
		for name_text in old:
			if name_text==str(group)+".jsonl" or name_text.begins_with(str(group)+"-peer-"):DirAccess.remove_absolute(folder.path_join(name_text))
	session = "%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	path = folder.path_join(session+".jsonl")
	file = FileAccess.open(path, FileAccess.WRITE)
	sink = ErrorSink.new(); sink.owner = self; OS.add_logger(sink)
	record("boot", {"engine":Engine.get_version_info().string,"platform":OS.get_name(),"headless":DisplayServer.get_name()=="headless","gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"build":ProjectSettings.get_setting("application/config/version","development")})
	flush()
	writer.start(_write_loop)

func clean(value: Variant, depth := 0) -> Variant:
	if depth > 4: return "[limited]"
	if value is Dictionary:
		var result := {}; var count := 0
		for key in value:
			var text_key := str(key).to_lower()
			if text_key.contains("token") or text_key.contains("password") or text_key.contains("secret") or text_key.contains("proof") or text_key.contains("pem") or text_key.contains("reservation"): continue
			result[str(key).left(64)] = clean(value[key],depth+1); count+=1
			# Keep frame pacing context after its timing counters, while
			# retaining the tighter cap for nested dictionaries.
			if count >= (48 if depth == 0 else 32): break
		return result
	if value is Array:
		var result := []
		for entry in value.slice(0,48): result.append(clean(entry,depth+1))
		return result
	if value is String:
		var result: String = value.left(2000)
		var pattern := RegEx.new(); pattern.compile("(?i)(bearer\\s+|token[=:\\s]+|password[=:\\s]+)[^\\s,;]+")
		return pattern.sub(result,"[redacted]",true)
	if value is bool or value is int or value is float: return value
	return str(value).left(128)

func record(event: String, details: Dictionary = {}) -> void:
	# An error loop must not turn diagnostics into an additional frame hitch.
	lock.lock()
	if pending.size()>=256:lock.unlock();return
	if event=="engine_error":
		var key:=hash([details.get("source"),details.get("line"),details.get("code")])
		var now:=Time.get_ticks_msec()
		if now-int(repeated.get(key,-5000))<5000:lock.unlock();return
		repeated[key]=now
		if repeated.size()>128:repeated.erase(repeated.keys()[0])
	lock.unlock()
	var row := {"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"session":session,"event":event.left(80),"details":clean(details)}
	lock.lock()
	if pending.size()<256: pending.append(row)
	lock.unlock()
	if event=="engine_error" or event.contains("disconnected"):wake.post()

func _write_loop() -> void:
	while true:
		wake.wait();flush()
		if stopping:return

func flush() -> void:
	lock.lock(); var rows := pending; pending=[]; lock.unlock()
	file_lock.lock()
	if not file:file_lock.unlock();return
	for row in rows:
		if file.get_position() < LIMIT: file.store_line(JSON.stringify(row))
		var id:=int(row.details.get("peer",0))
		if id>0 and DisplayServer.get_name()=="headless":
			if not peer_files.has(id) and peer_files.size()<64:peer_files[id]=FileAccess.open(path.get_base_dir().path_join(session+"-peer-%d.jsonl"%id),FileAccess.WRITE)
			var peer_file: FileAccess=peer_files.get(id)
			if peer_file and peer_file.get_position()<128*1024:peer_file.store_line(JSON.stringify(row));peer_file.flush()
	file.flush()
	file_lock.unlock()

func _process(delta: float) -> void:
	clock+=delta
	if clock>=1.: clock=0.;wake.post()

func export_report() -> String:
	record("report_export"); flush()
	var output := NavalStorage.folder().path_join("diagnostics-"+session+".zip")
	var zip := ZIPPacker.new()
	if zip.open(output)!=OK: return ""
	for name_text in DirAccess.get_files_at(path.get_base_dir()):
		if not name_text.ends_with(".jsonl"): continue
		zip.start_file(name_text); zip.write_file(FileAccess.get_file_as_bytes(path.get_base_dir().path_join(name_text))); zip.close_file()
	zip.close()
	return output

func _exit_tree() -> void:
	record("clean_shutdown");stopping=true;wake.post()
	if writer.is_started():writer.wait_to_finish()
	flush()
	if sink: OS.remove_logger(sink)
	file=null
	peer_files.clear()
