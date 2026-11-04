extends SceneTree

# Invoked externally by the approved protected client EXE. This script is not
# included in game exports; every res:// dependency below comes from its PCK.
const CODEC = preload("res://scripts/voice/codec.gd")
const SILHOUETTES = preload("res://scripts/ui/weapon_silhouette.gd")
const ATTACHMENTS = preload("res://scripts/attachments/registry.gd")
const ATTACHMENT_STATE = preload("res://scripts/attachments/state.gd")
const NAVIGATION_MANIFEST := "res://modes/battle_royale/navigation/prepared/manifest.json"
const EXPECTED_WEAPONS := ["fal", "ak", "sniper", "glock", "rpg", "stinger"]
var checks := 0
var failures: Array[String] = []
var metrics := {}
var report_path := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func run() -> void:
	check(not OS.has_feature("editor") and OS.has_feature("release"), "actual exported release runtime")
	check(OS.has_feature("windows") and OS.has_feature("x86_64"), "Windows x86-64 client")
	check(OS.get_executable_path().get_file() == "ToqueDeCampo.exe", "production client executable")
	check(Engine.get_version_info().major == 4 and Engine.get_version_info().minor == 7 and Engine.get_version_info().patch == 2, "Godot 4.7.2 runtime")
	check(FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("libgodotopus.windows.template_release.x86_64.dll")), "external release DLL beside executable")
	check(CODEC.available(), "native Opus encoder and decoder available from protected package")
	if CODEC.available():
		var encoder: Object = CODEC.encoder()
		var decoder: Object = CODEC.decoder()
		check(encoder != null and decoder != null, "native codec instances created")
		if encoder != null and decoder != null:
			encoder.call("set_dtx", false)
			var encoded := 0
			var decoded := 0
			var payload_bytes := 0
			var nonzero := 0
			for frame in 100:
				var pcm := PackedFloat32Array()
				pcm.resize(CODEC.SAMPLES)
				for index in pcm.size():
					var time := float(frame * CODEC.SAMPLES + index) / float(CODEC.SAMPLE_RATE)
					pcm[index] = .17 * sin(TAU * 173. * time) + .07 * sin(TAU * 346. * time)
				var packet: PackedByteArray = encoder.call("encode", pcm)
				if CODEC.valid_packet(packet): encoded += 1
				payload_bytes += packet.size()
				var output: PackedFloat32Array = decoder.call("decode", packet)
				if output.size() == CODEC.SAMPLES: decoded += 1
				var valid_audio := true
				var energy := 0.
				for sample: float in output:
					valid_audio = valid_audio and is_finite(sample)
					energy += sample * sample
				if valid_audio and energy > .01: nonzero += 1
			check(encoded == 100 and decoded == 100, "100 real native Opus frames encode and decode at 24k mono20ms")
			check(nonzero >= 99, "decoded audio is finite and non-silent")
			var kbps := payload_bytes * 8. / 2. / 1000.
			check(kbps >= 16. and kbps <= 24., "codec payload within 16-24kbps")
			metrics.codec = {"encoded_frames": encoded, "decoded_frames": decoded, "nonzero_frames": nonzero,
				"payload_bytes": payload_bytes, "payload_kbps": kbps, "microphone_activated": false}
		CODEC.release(encoder)
		CODEC.release(decoder)
	for license_name: String in ["godotopus-MIT.txt", "opus-BSD.txt", "speexdsp-BSD.txt", "godot-cpp-MIT.txt"]:
		check(FileAccess.file_exists("res://native/voice/licenses/" + license_name), "codec license included: " + license_name)

	for weapon: String in EXPECTED_WEAPONS:
		var texture: Texture2D = SILHOUETTES.texture(weapon)
		check(texture != null and texture.get_width() == 1024 and texture.get_height() == 320, "static silhouette texture: " + weapon)
		var profile: Dictionary = SILHOUETTES.profile(weapon)
		var anchors: Variant = profile.get("anchors")
		check(anchors is Dictionary and anchors.size() == 6, "silhouette JSON anchors: " + weapon)
		if anchors is Dictionary:
			for point: Variant in anchors.values():
				check(point is Array and point.size() == 2 and float(point[0]) > 0. and float(point[0]) < 1.
					and float(point[1]) > 0. and float(point[1]) < 1., "normalized silhouette mount: " + weapon)
		var weapon_profile = ATTACHMENTS.profile(weapon)
		check(weapon_profile != null and weapon_profile.weapon_id == weapon, "weapon socket profile included: " + weapon)
	check(ATTACHMENTS.ids() == ["prism4x", "pso4x"], "two real optic definitions included")
	for id: String in ATTACHMENTS.ids():
		var definition = ATTACHMENTS.definition(id)
		check(definition != null and definition.scene_reference != null and definition.behavior_type == "optical", "module resource and optic behavior: " + id)
		if definition and definition.scene_reference:
			var node: Node = definition.scene_reference.instantiate()
			check(node.get_node_or_null(definition.mount_reference) is Marker3D
				and node.get_node_or_null(definition.eye_reference) is Marker3D
				and node.get_node_or_null(definition.reticle_reference) is MeshInstance3D, "real optic scene markers/lens: " + id)
			node.free()
		for weapon: String in ["fal", "ak"]:
			var state: Dictionary = ATTACHMENT_STATE.from_legacy(weapon, id)
			check(not state.is_empty() and bool(ATTACHMENT_STATE.validate(weapon, state).get("ok", false)), "shared mount compatibility: " + weapon + "/" + id)
	metrics.silhouettes = EXPECTED_WEAPONS.size()
	metrics.production_modules = ATTACHMENTS.ids()

	check(FileAccess.file_exists(NAVIGATION_MANIFEST), "BR prepared navigation JSON included")
	if FileAccess.file_exists(NAVIGATION_MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAVIGATION_MANIFEST))
		check(parsed is Dictionary and bool(parsed.get("complete", false)), "BR navigation prepared manifest complete")
		if parsed is Dictionary:
			var tile_count := 0
			var polygons := 0
			for tile: Dictionary in parsed.get("tiles", []):
				var path := str(tile.get("path", ""))
				check(ResourceLoader.exists(path), "prepared navigation tile included: " + path.get_file())
				if not ResourceLoader.exists(path): continue
				var mesh := load(path) as NavigationMesh
				check(mesh != null, "prepared navigation mesh loads: " + path.get_file())
				if mesh:
					tile_count += 1
					polygons += mesh.get_polygon_count()
			check(tile_count > 0 and polygons > 0, "prepared navigation has native polygons")
			check(not parsed.get("spawns", []).is_empty() and not parsed.get("zones", []).is_empty(), "prepared spawn and zone candidates included")
			metrics.navigation = {"tiles": tile_count, "polygons": polygons, "spawns": parsed.get("spawns", []).size(),
				"zones": parsed.get("zones", []).size(), "loot_points": parsed.get("loot", []).size()}
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures, "metrics": metrics,
		"engine": Engine.get_version_info().string, "executable": OS.get_executable_path(), "editor": OS.has_feature("editor"),
		"release": OS.has_feature("release"), "scope": "Real protected exported client/PCK/native DLL; codec and included runtime resources only. No microphone, network, full match, GPU performance or subjective audio claim."}
	if report_path.is_empty():
		push_error("Smoke requires an explicit report path")
		quit(2)
		return
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write smoke report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("EXPORTED_CLIENT_SMOKE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
