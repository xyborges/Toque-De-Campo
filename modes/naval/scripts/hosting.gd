extends RefCounted
class_name NavalHosting
var process_id := -1
var info: Dictionary = {}
var ready_file := ""
var token := ""
var started := 0.0
var firewall_pid := -1
var firewall_result := ""
func start() -> Error:
	var directory := NavalStorage.folder().path_join("hosting")
	DirAccess.make_dir_recursive_absolute(directory)
	var previous := NavalStorage.read_json(directory.path_join("active.json"))
	if int(previous.get("protocol",-1)) == NavalCatalog.PROTOCOL and Time.get_unix_time_from_system()-float(previous.get("heartbeat",0.0))<6.0 and OS.is_process_running(int(previous.get("pid",-1))):
		info = previous
		process_id = int(previous.pid)
		return OK
	token = NavalCatalog.uid()
	ready_file = directory.path_join("ready-"+token+".json")
	var arguments := PackedStringArray(["--headless","--max-fps","60","--log-file",directory.path_join("server-"+token+".log")])
	if OS.has_feature("editor"): arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--","--naval-server","--naval-auto-host","--naval-port=0","--naval-ready="+ready_file,"--naval-token="+token,"--naval-parent="+str(OS.get_process_id()),"--naval-data="+NavalStorage.folder()])
	for arg in OS.get_cmdline_user_args():
		if arg == "--naval-test-accounts" or arg.begins_with("--naval-discovery-port=") or arg.begins_with("--naval-idle-seconds="): arguments.append(arg)
	process_id = OS.create_instance(arguments)
	started = Time.get_ticks_msec()*0.001
	return OK if process_id>0 else ERR_CANT_CREATE
func poll() -> Error:
	if not info.is_empty(): return OK
	if process_id<1 or not OS.is_process_running(process_id): return ERR_CANT_CREATE
	var data := NavalStorage.read_json(ready_file)
	if data.get("token") == token and int(data.get("pid",-1)) == process_id and int(data.get("port",0))>0 and int(data.get("protocol",-1)) == NavalCatalog.PROTOCOL:
		info = data
		NavalStorage.write_json(NavalStorage.folder().path_join("hosting/active.json"),data)
		return OK
	if Time.get_ticks_msec()*0.001-started>18.0:
		OS.kill(process_id)
		return ERR_TIMEOUT
	return ERR_BUSY
func request_firewall() -> void:
	if OS.get_name() != "Windows" or "--naval-skip-firewall" in OS.get_cmdline_user_args(): return
	if firewall_pid>0 and OS.is_process_running(firewall_pid): return
	var directory := NavalStorage.folder().path_join("hosting")
	var script := directory.path_join("allow-lan.ps1")
	var content := FileAccess.get_file_as_string("res://modes/naval/tools/allow-lan.ps1")
	var file := FileAccess.open(script,FileAccess.WRITE)
	if file == null or content.is_empty(): return
	file.store_string(content)
	file.close()
	firewall_result = directory.path_join("firewall-"+NavalCatalog.uid()+".json")
	firewall_pid = OS.create_process("powershell.exe",["-NoProfile","-ExecutionPolicy","Bypass","-File",script,"-Executable",OS.get_executable_path(),"-ResultPath",firewall_result])
func firewall_status() -> Dictionary:
	return NavalStorage.read_json(firewall_result) if not firewall_result.is_empty() else {}
