extends SceneTree

var checks := 0
var failures: Array[String] = []
var options := {}
var launcher: Control

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var split := arg.find("=")
			options[arg.substr(2, split - 2)] = arg.substr(split + 1)
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func run() -> void:
	launcher = load("res://launcher.gd").new()
	launcher.storage = str(options.get("install", ""))
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(options.get("manifest", ""))))
	check(envelope is Dictionary, "published envelope parses")
	if not envelope is Dictionary: finish({}); return
	var manifest: Dictionary = launcher._verify(envelope)
	check(not manifest.is_empty(), "real public key accepts actual published signature")
	if manifest.is_empty(): finish({}); return
	check(int(manifest.version) == int(options.get("build", "0")), "approved build number")
	check(manifest.files.size() == 3 and manifest.files.has(launcher.VOICE_LIBRARY), "three-file signed native client package")
	var path := str(options.get("archive", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	check(file != null and file.get_length() == int(manifest.size), "local ZIP has signed archive size")
	if file: file.close()
	check(FileAccess.get_sha256(path) == manifest.sha256, "local ZIP has signed archive SHA256")
	if not failures.is_empty(): finish({}); return
	check(launcher._extract(path, manifest), "actual launcher extracts approved real game ZIP")
	check(launcher._files_valid(manifest), "actual launcher verifies all installed game files")
	var folder: String = launcher._folder(manifest)
	for name: String in manifest.files:
		check(FileAccess.get_sha256(folder.path_join(name)) == manifest.files[name].sha256, "installed bytes match signed file: " + name)
	var installed := FileAccess.open(launcher.storage.path_join("installed.json"), FileAccess.WRITE)
	check(installed != null, "QA installation pointer opens")
	if installed:
		installed.store_string(JSON.stringify(envelope))
		installed.close()
	var current: Dictionary = launcher._load_current()
	check(not current.is_empty() and int(current.get("version", 0)) == int(manifest.version), "persisted installation re-verifies with real public key")
	finish({"version": manifest.version, "version_name": manifest.get("version_name", ""), "archive_sha256": manifest.sha256,
		"archive_size": manifest.size, "files": manifest.files, "installed_folder": folder})

func finish(metrics: Dictionary) -> void:
	launcher.free()
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures, "metrics": metrics,
		"scope": "Actual launcher verifier/extractor source clone, real public key and signed local game package; no private key, download, export or activation"}
	var file := FileAccess.open(str(options.get("report", "res://results.json")), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("SIGNED_INSTALL_VALIDATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
