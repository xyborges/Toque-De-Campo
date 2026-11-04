extends SceneTree

# Runs in a disposable project copied by validate_native_package.py. The public
# key created here is only for QA; production signing material is never read.
const DLL := "libgodotopus.windows.template_release.x86_64.dll"
var checks := 0
var failures: Array[String] = []
var private_key: CryptoKey
var launcher: Control
var serial := 0
var originals := {
	"ToqueDeCampo.exe": PackedByteArray([77, 90, 1, 2, 3, 4]),
	"ToqueDeCampo.pck": PackedByteArray([71, 68, 80, 67, 5, 6]),
	DLL: PackedByteArray([77, 90, 7, 8, 9, 10]),
}

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func file_records(names: Array) -> Dictionary:
	var records := {}
	for name: String in names:
		var bytes: PackedByteArray = originals[name]
		records[name] = {"size": bytes.size(), "sha256": digest(bytes)}
	return records

func sign_payload(payload: Dictionary) -> Dictionary:
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	var signature := Crypto.new().sign(HashingContext.HASH_SHA256, context.finish(), private_key)
	return {"payload": Marshalls.raw_to_base64(bytes), "signature": Marshalls.raw_to_base64(signature)}

func fixture(entries: Array, records: Dictionary) -> Dictionary:
	serial += 1
	var path := ProjectSettings.globalize_path("res://fixture-%d.zip" % serial)
	var zip := ZIPPacker.new()
	check(zip.open(path) == OK, "QA archive opens")
	for entry: Dictionary in entries:
		check(zip.start_file(entry.name) == OK, "QA entry opens")
		zip.write_file(entry.bytes)
		zip.close_file()
	zip.close()
	var archive_digest := FileAccess.get_sha256(path)
	var payload := {"schema": 1, "version": serial, "version_name": "QA only",
		"sha256": archive_digest, "size": FileAccess.get_file_as_bytes(path).size(),
		"archive": "releases/game-%d-%s.zip" % [serial, archive_digest.left(12)], "files": records}
	return {"path": path, "payload": payload, "envelope": sign_payload(payload)}

func entries_for(names: Array) -> Array:
	var entries := []
	for name: String in names:
		entries.append({"name": name, "bytes": originals[name]})
	return entries

func run() -> void:
	private_key = Crypto.new().generate_rsa(3072)
	check(private_key != null and private_key.save("res://release-public.pem", true) == OK, "isolated QA trust key")
	launcher = load("res://launcher.gd").new()
	launcher.storage = ProjectSettings.globalize_path("res://installed")
	var core := ["ToqueDeCampo.exe", "ToqueDeCampo.pck"]
	var names := core + [DLL]
	var current := fixture(entries_for(names), file_records(names))
	var verified: Dictionary = launcher._verify(current.envelope)
	check(not verified.is_empty(), "signed three-file release accepted")
	check(launcher._extract(current.path, verified), "three-file release extracts")
	check(launcher._files_valid(verified), "all three installed hashes verified")
	var installed_dll: String = launcher._folder(verified).path_join(DLL)
	check(FileAccess.get_file_as_bytes(installed_dll) == originals[DLL], "DLL remains beside executable")
	var old := fixture(entries_for(core), file_records(core))
	var old_verified: Dictionary = launcher._verify(old.envelope)
	check(not old_verified.is_empty(), "legacy signed two-file release remains accepted")
	check(launcher._extract(old.path, old_verified) and launcher._files_valid(old_verified), "legacy extraction and validation")

	var changed: Dictionary = current.envelope.duplicate(true)
	var changed_payload: Dictionary = current.payload.duplicate(true)
	changed_payload.files[DLL].sha256 = "0".repeat(64)
	changed.payload = Marshalls.raw_to_base64(JSON.stringify(changed_payload).to_utf8_buffer())
	check(launcher._verify(changed).is_empty(), "modified DLL manifest without new signature rejected")

	for invalid_name: String in ["extra.dll", "libgodotopus.windows.template_debug.x86_64.dll", "../" + DLL,
		"native/" + DLL, "native\\" + DLL, "/" + DLL, "C:\\" + DLL]:
		var payload: Dictionary = current.payload.duplicate(true)
		payload.files[invalid_name] = payload.files[DLL]
		payload.files.erase(DLL)
		check(launcher._verify(sign_payload(payload)).is_empty(), "signed disallowed filename rejected: " + invalid_name)
		check(not launcher._extract(current.path, payload), "extract independently rejects disallowed filename: " + invalid_name)
	var extra_payload: Dictionary = current.payload.duplicate(true)
	extra_payload.files["extra.dll"] = extra_payload.files[DLL]
	check(launcher._verify(sign_payload(extra_payload)).is_empty(), "four-file signed manifest rejected")
	var missing_payload: Dictionary = current.payload.duplicate(true)
	missing_payload.files.erase("ToqueDeCampo.pck")
	check(launcher._verify(sign_payload(missing_payload)).is_empty(), "DLL cannot replace required PCK")

	for invalid_digest: Variant in ["", "x".repeat(64), "a".repeat(63), 123, null]:
		var records: Dictionary = current.payload.files.duplicate(true)
		records[DLL].sha256 = invalid_digest
		check(not launcher._file_manifest_valid(records), "malformed per-DLL SHA256 rejected")
	for invalid_size: Variant in [0, -1, 1.5, "6", null, 536870913, INF, NAN]:
		var records: Dictionary = current.payload.files.duplicate(true)
		records[DLL].size = invalid_size
		check(not launcher._file_manifest_valid(records), "malformed per-DLL size rejected")

	var corrupt_entries := entries_for(names)
	corrupt_entries[2].bytes = PackedByteArray([77, 90, 7, 8, 9, 11])
	var corrupt := fixture(corrupt_entries, file_records(names))
	var corrupt_verified: Dictionary = launcher._verify(corrupt.envelope)
	check(not corrupt_verified.is_empty(), "QA tampered ZIP has valid outer signature and archive hash")
	check(not launcher._extract(corrupt.path, corrupt_verified), "inner DLL hash rejects equal-size tampering")
	check(not launcher._files_valid(corrupt_verified), "tampered DLL cannot become valid installation")

	var extra_entries := entries_for(names)
	extra_entries.append({"name": "extra.dll", "bytes": PackedByteArray([1])})
	var extra := fixture(extra_entries, file_records(names))
	check(not launcher._extract(extra.path, launcher._verify(extra.envelope)), "ZIP extra DLL rejected")
	var missing := fixture(entries_for(core), file_records(names))
	check(not launcher._extract(missing.path, launcher._verify(missing.envelope)), "ZIP missing DLL rejected")
	var traversal_entries := entries_for(core)
	traversal_entries.append({"name": "../" + DLL, "bytes": originals[DLL]})
	var traversal := fixture(traversal_entries, file_records(names))
	check(not launcher._extract(traversal.path, launcher._verify(traversal.envelope)), "ZIP traversal rejected with same entry count")
	var duplicate := fixture([{"name": "ToqueDeCampo.exe", "bytes": originals["ToqueDeCampo.exe"]},
		{"name": DLL, "bytes": originals[DLL]}, {"name": DLL, "bytes": originals[DLL]}], file_records(names))
	check(not launcher._extract(duplicate.path, launcher._verify(duplicate.envelope)), "ZIP duplicate entry rejected with same entry count")
	check(not FileAccess.file_exists(ProjectSettings.globalize_path("res://installed/" + DLL)), "no file escaped its release directory")

	var output := FileAccess.open(installed_dll, FileAccess.WRITE)
	output.store_buffer(corrupt_entries[2].bytes)
	output.close()
	check(not launcher._files_valid(verified), "installed equal-size DLL tampering detected before play")
	check(launcher._extract(current.path, verified) and launcher._files_valid(verified), "trusted re-extraction repairs DLL")
	output = FileAccess.open(installed_dll, FileAccess.WRITE)
	output.store_8(1)
	output.close()
	check(not launcher._files_valid(verified), "installed truncated DLL detected before play")
	check(launcher._extract(current.path, verified), "final trusted fixture restored")
	launcher.free()
	var report := {"checks": checks, "failures": failures, "scope": "Real launcher verifier/extractor with isolated signing key; no export, install or publication"}
	var report_file := FileAccess.open("res://results.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
