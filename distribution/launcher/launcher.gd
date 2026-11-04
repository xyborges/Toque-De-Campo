extends Control

const SERVER := "https://192.168.101.24"
const MAX_PACKAGE := 536870912
const CORE_FILES := ["ToqueDeCampo.exe", "ToqueDeCampo.pck"]
const VOICE_LIBRARY := "libgodotopus.windows.template_release.x86_64.dll"
var base_url := SERVER
var storage := ""
var http: HTTPRequest
var status: Label
var detail: Label
var progress: ProgressBar
var play: Button
var retry: Button
var notes_version: Label
var notes_title: Label
var notes_summary: Label
var notes_list: VBoxContainer
var busy := false
var current: Dictionary = {}
var check_only := false
var lock := TCPServer.new()

func _ready() -> void:
	if OS.has_feature("xampp"):
		base_url = SERVER
	storage = OS.get_user_data_dir()
	# Some Windows environments do not resolve Godot's user-data location.
	# Use the same per-user location explicitly; never install beside the EXE.
	if storage.is_empty() or not storage.is_absolute_path():
		storage = OS.get_environment("APPDATA").path_join("Godot/app_userdata/Toque de Campo Launcher")
	var args := OS.get_cmdline_user_args()
	check_only = "--check-only" in args
	var custom_storage := false
	# Overrides support isolated validation of the actual exported launcher.
	for i in range(args.size() - 1):
		if args[i] == "--data-root":
			storage = args[i + 1]
			custom_storage = true
		if args[i] == "--update-server": base_url = args[i + 1].trim_suffix("/")
	_build_ui()
	var portable := OS.get_executable_path().get_base_dir().path_join("ToqueDeCampo-data")
	# Once portable data exists, keep using it even if user-folder permissions change.
	if not custom_storage and FileAccess.file_exists(portable.path_join("installed.json")):
		storage = portable
	if not _writable(storage) and not custom_storage:
		storage = portable
	if not _writable(storage):
		status.text = "Não foi possível criar a pasta de instalação do usuário."
		detail.text = "Coloque o executável em uma pasta onde você possa salvar arquivos."
		if check_only: get_tree().quit(1)
		return
	if not check_only and lock.listen(39221, "127.0.0.1") != OK:
		status.text = "O atualizador já está aberto."
		return
	http = HTTPRequest.new()
	http.max_redirects = 0
	var certificate:=X509Certificate.new()
	if certificate.load("res://accounts-ca.crt")!=OK:
		status.text="Certificado de atualização indisponível."
		if check_only: get_tree().quit(1)
		return
	http.set_tls_options(TLSOptions.client(certificate))
	add_child(http)
	current = _load_current()
	_show_release(current)
	_check.call_deferred()

func _writable(path: String) -> bool:
	if not path.is_absolute_path() or DirAccess.make_dir_recursive_absolute(path) != OK: return false
	var probe := path.path_join(".write-probe")
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null: return false
	file.store_8(1)
	file.close()
	DirAccess.remove_absolute(probe)
	return true

func _build_ui() -> void:
	var palette := Theme.new()
	palette.default_font_size = 15
	palette.set_color("font_color","Label",Color("e2e9e4"))
	palette.set_color("font_color","Button",Color("e2e9e4"))
	palette.set_color("font_hover_color","Button",Color("101b18"))
	palette.set_color("font_pressed_color","Button",Color("101b18"))
	palette.set_color("font_focus_color","Button",Color("e2e9e4"))
	palette.set_color("font_disabled_color","Button",Color("687975"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("b7cca1") if state in ["hover","pressed"] else Color("18282b")
		style.border_color = Color("b7cca1") if state in ["hover","pressed","focus"] else Color("35494a")
		style.set_border_width_all(2 if state=="focus" else 1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 16
		style.content_margin_right = 16
		palette.set_stylebox(state,"Button",style)
	theme = palette
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = preload("res://game-icon.png")
	icon.custom_minimum_size = Vector2(48,48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var title := Label.new()
	title.text = "TOQUE DE CAMPO"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color("b7cca1")
	header.add_child(title)
	box.add_child(HSeparator.new())
	status = Label.new()
	status.text = "Verificando atualizações..."
	status.add_theme_font_size_override("font_size", 20)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = Color("9dadae")
	box.add_child(detail)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("243336")
	progress.add_theme_stylebox_override("background",track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b7cca1")
	progress.add_theme_stylebox_override("fill",fill)
	box.add_child(progress)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := StyleBoxFlat.new()
	card.bg_color = Color("132226")
	card.border_color = Color("304145")
	card.set_border_width_all(1)
	card.set_corner_radius_all(5)
	for side in ["left","right","top","bottom"]: card.set("content_margin_"+side,20.0)
	panel.add_theme_stylebox_override("panel",card)
	box.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	notes_version = Label.new()
	notes_version.text = "NOVIDADES DA VERSÃO"
	notes_version.modulate = Color("b7cca1")
	notes_version.add_theme_font_size_override("font_size",12)
	content.add_child(notes_version)
	notes_title = _note_label("Conferindo o que chegou...",24)
	content.add_child(notes_title)
	notes_summary = _note_label("As novidades aparecem aqui após a verificação da versão.",15)
	notes_summary.modulate = Color("9dadae")
	content.add_child(notes_summary)
	notes_list = VBoxContainer.new()
	notes_list.add_theme_constant_override("separation",16)
	content.add_child(notes_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	play = Button.new()
	play.text = "JOGAR"
	play.custom_minimum_size.y = 48
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.disabled = true
	play.pressed.connect(_launch)
	row.add_child(play)
	retry = Button.new()
	retry.text = "VERIFICAR NOVAMENTE"
	retry.custom_minimum_size.y = 48
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(_check)
	row.add_child(retry)
	var footnote := _note_label("A atualização é automática. Leia as novidades e clique em Jogar quando estiver pronto.",13)
	footnote.modulate = Color("9dadae")
	box.add_child(footnote)

func _note_label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _show_release(manifest: Dictionary) -> void:
	if manifest.is_empty(): return
	var version := str(manifest.get("version_name",manifest.get("version",""))).left(40)
	notes_version.text = "NOVIDADES · VERSÃO %s · BUILD %d" % [version,int(manifest.get("version",0))]
	for node in notes_list.get_children():
		notes_list.remove_child(node)
		node.queue_free()
	var notes: Variant = manifest.get("release_notes",{})
	if not notes is Dictionary or not notes.get("changes") is Array:
		notes_title.text = "Toque de Campo " + version
		notes_summary.text = "Esta versão não inclui uma lista de novidades."
		return
	notes_title.text = str(notes.get("title","Novidades da atualização")).left(120)
	notes_summary.text = str(notes.get("summary","")).left(600)
	for change: Variant in notes.changes.slice(0,12):
		if not change is Dictionary: continue
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation",4)
		item.add_child(_note_label(str(change.get("title","")).left(100),17))
		var description := _note_label(str(change.get("text","")).left(600),14)
		description.modulate = Color("9dadae")
		item.add_child(description)
		notes_list.add_child(item)

func _process(_delta: float) -> void:
	if busy and http != null and not http.download_file.is_empty():
		var total := http.get_body_size()
		if total > 0:
			progress.value = 100.0 * http.get_downloaded_bytes() / total

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _verify(envelope: Dictionary) -> Dictionary:
	if not envelope.get("payload") is String or not envelope.get("signature") is String: return {}
	var bytes := Marshalls.base64_to_raw(envelope.payload)
	var key := CryptoKey.new()
	if key.load("res://release-public.pem", true) != OK: return {}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, digest.finish(), Marshalls.base64_to_raw(envelope.signature), key): return {}
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary or data.get("schema") != 1: return {}
	if not data.get("version") is float and not data.get("version") is int: return {}
	if int(data.version) < 1 or float(data.version) != float(int(data.version)): return {}
	if not data.get("sha256") is String or data.sha256.length() != 64 or not data.sha256.is_valid_hex_number(): return {}
	if data.get("archive") != "releases/game-%d-%s.zip" % [int(data.version), data.sha256.left(12)]: return {}
	if int(data.get("size", 0)) < 1 or int(data.size) > MAX_PACKAGE: return {}
	if not _file_manifest_valid(data.get("files")): return {}
	return data

func _file_manifest_valid(files: Variant) -> bool:
	# Two-file releases remain readable; new releases include exactly one approved
	# native library. Never turn the signed manifest into an arbitrary DLL allowlist.
	if not files is Dictionary or files.size() not in [2, 3]: return false
	for name: String in CORE_FILES:
		if not files.has(name): return false
	for name: Variant in files:
		if not name is String or (name not in CORE_FILES and name != VOICE_LIBRARY): return false
		var entry: Variant = files[name]
		if not entry is Dictionary: return false
		var digest: Variant = entry.get("sha256")
		if not digest is String or digest.length() != 64 or not digest.is_valid_hex_number(): return false
		var size: Variant = entry.get("size")
		if typeof(size) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(size)) or float(size) < 1.0 or float(size) > float(MAX_PACKAGE): return false
		if float(size) != float(int(size)): return false
	return true

func _folder(manifest: Dictionary) -> String:
	return storage.path_join("releases").path_join(manifest.sha256)

func _files_valid(manifest: Dictionary) -> bool:
	if manifest.is_empty() or not _file_manifest_valid(manifest.get("files")): return false
	for name: String in manifest.files:
		var path := _folder(manifest).path_join(name)
		if not FileAccess.file_exists(path): return false
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(manifest.files[name].size): return false
		file.close()
		if FileAccess.get_sha256(path) != manifest.files[name].sha256: return false
	return true

func _load_current() -> Dictionary:
	var envelope := _read_json(storage.path_join("installed.json"))
	var manifest := _verify(envelope)
	return manifest if _files_valid(manifest) else {}

func _request(url: String, destination: String = "") -> Array:
	if not url.begins_with("https://"): return [HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray()]
	http.download_file = destination
	http.body_size_limit = MAX_PACKAGE if not destination.is_empty() else 65536
	http.timeout = 180.0 if not destination.is_empty() else 6.0
	var error := http.request(url, ["Cache-Control: no-cache", "Accept-Encoding: identity"])
	if error != OK: return [error, 0, PackedStringArray(), PackedByteArray()]
	return await http.request_completed

func _check() -> void:
	if busy: return
	busy = true
	retry.disabled = true
	play.disabled = true
	status.text = "Verificando atualizações..."
	detail.text = base_url
	progress.value = 0
	var response := await _request(base_url + "/manifest.json?t=" + str(Time.get_unix_time_from_system()))
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		_finish("Servidor indisponível. A versão instalada foi mantida.", false)
		return
	var envelope: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not envelope is Dictionary:
		_finish("O servidor enviou uma atualização inválida.", false)
		return
	var manifest := _verify(envelope)
	if manifest.is_empty():
		_finish("Assinatura da atualização inválida. Nada foi instalado.", false)
		return
	_show_release(manifest)
	if not current.is_empty():
		if int(manifest.version) < int(current.version):
			_finish("A versão instalada é mais recente que a do servidor.", true)
			return
		if int(manifest.version) == int(current.version):
			if manifest.sha256 != current.sha256:
				_finish("Versão repetida com conteúdo diferente. Atualização recusada.", false)
			else:
				_finish("Jogo atualizado. Nenhum download necessário.", true)
			return
	status.text = "Baixando versão " + str(manifest.get("version_name", manifest.version))
	detail.text = "A versão atual permanece disponível até a instalação terminar."
	var archive_path := storage.path_join("download.zip.part")
	response = await _request(base_url + "/" + manifest.archive, archive_path)
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		print("DOWNLOAD_FAILURE result=", response[0], " http=", response[1], " path=", archive_path)
		_finish("Download interrompido. Tente novamente; a versão anterior foi mantida.", false)
		return
	var file := FileAccess.open(archive_path, FileAccess.READ)
	if file == null:
		_finish("Não foi possível abrir o download.", false)
		return
	var size := file.get_length()
	file.close()
	if size != int(manifest.size) or FileAccess.get_sha256(archive_path) != manifest.sha256:
		_finish("Download incompleto ou alterado. Nada foi instalado.", false)
		return
	status.text = "Conferindo e instalando..."
	if not _extract(archive_path, manifest):
		_finish("Falha ao instalar. A versão anterior foi mantida.", false)
		return
	var state_path := storage.path_join("installed.json")
	var output := FileAccess.open(state_path + ".tmp", FileAccess.WRITE)
	if output == null:
		_finish("Sem permissão para salvar a instalação.", false)
		return
	output.store_string(JSON.stringify(envelope))
	output.close()
	if DirAccess.rename_absolute(state_path + ".tmp", state_path) != OK:
		_finish("Não foi possível ativar a nova versão.", false)
		return
	current = manifest
	DirAccess.remove_absolute(archive_path)
	progress.value = 100
	_finish("Atualização instalada.", true)

func _extract(path: String, manifest: Dictionary) -> bool:
	if not _file_manifest_valid(manifest.get("files")): return false
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return false
	var names := zip.get_files()
	if names.size() != manifest.files.size():
		zip.close()
		return false
	# Flat, exact allowlist, including the one approved release codec DLL.
	var seen := {}
	for name in names:
		if not manifest.files.has(name) or seen.has(name):
			zip.close()
			return false
		seen[name] = true
	var folder := _folder(manifest)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		zip.close()
		return false
	for name in names:
		var bytes := zip.read_file(name)
		if bytes.size() != int(manifest.files[name].size):
			zip.close()
			return false
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		if context.finish().hex_encode() != manifest.files[name].sha256:
			zip.close()
			return false
		var output := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
		if output == null:
			zip.close()
			return false
		output.store_buffer(bytes)
		output.close()
	zip.close()
	return _files_valid(manifest)

func _finish(message: String, auto_play: bool) -> void:
	busy = false
	retry.disabled = false
	play.disabled = current.is_empty()
	status.text = message
	detail.text = "Versão instalada: " + str(current.get("version_name", "nenhuma"))
	print("UPDATER: ", message, " | ", detail.text)
	if check_only:
		get_tree().quit(0 if not current.is_empty() else 1)
	# Keep the release notes visible after installing/checking. The player
	# explicitly presses Play; do not close this screen before it can be read.

func _launch() -> void:
	if busy or current.is_empty(): return
	if not _files_valid(current):
		current = {}
		_finish("Arquivos locais alterados ou incompletos. Verifique novamente.", false)
		return
	var executable := _folder(current).path_join("ToqueDeCampo.exe")
	var pid := OS.create_process(executable, [])
	if pid <= 0:
		_finish("Não foi possível iniciar o jogo.", false)
	else:
		get_tree().quit()
