extends SceneTree
## QA independente dos módulos complementares de referência da Favela.
## --capture renderiza uma prancha visual sem depender do mapa completo.
const IDS := [
	"favela_canaleta_drenagem",
	"favela_muro_contencao",
	"favela_corrimao_beco",
	"favela_tubulacao_externa",
	"favela_antena_parabolica",
	"favela_portao_grade",
	"favela_tanque_lavanderia",
	"favela_barraca_rua",
]
var failures: Array[String] = []
var meshes := 0
var collisions := 0

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _run() -> void:
	var gallery := Node3D.new()
	gallery.name = "FavelaReferenceGallery"
	root.add_child(gallery)
	for i in IDS.size():
		var id: String = IDS[i]
		var path := "res://modes/war/library/" + id + ".tscn"
		require(ResourceLoader.exists(path), id + " ausente")
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		require(scene != null, id + " não carregou como PackedScene")
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		require(node != null, id + " não instanciou")
		if node == null:
			continue
		require(str(node.get_meta("library_id", "")) == id, id + " library_id divergente")
		require(node.has_meta("footprint"), id + " sem footprint")
		require(int(node.get_meta("asset_revision", 0)) >= 1, id + " sem revisão")
		var forma := node.get_node_or_null("Forma") as MeshInstance3D
		require(is_instance_valid(forma) and forma.mesh != null, id + " sem Forma principal")
		var local_meshes := node.find_children("*", "MeshInstance3D", true, false)
		require(local_meshes.size() >= 2, id + " detalhamento visual insuficiente")
		for model: MeshInstance3D in local_meshes:
			meshes += 1
			require(model.mesh != null, id + " contém MeshInstance3D sem malha")
			require(model.visibility_range_end > 0.0, id + " contém peça sem LOD")
		var local_collisions := node.find_children("*", "CollisionShape3D", true, false)
		collisions += local_collisions.size()
		if id == "favela_muro_contencao":
			require(local_collisions.size() == 1, "muro de contenção precisa de colisão simples única")
		else:
			require(local_collisions.is_empty(), id + " microdetalhe não deve adicionar colisão")
		var column := i % 4
		var row := i / 4
		node.position = Vector3((column - 1.5) * 5.0, 0, (row - .5) * 6.0)
		gallery.add_child(node)

	require(meshes >= 34, "conjunto visual simplificado demais")
	require(collisions == 1, "orçamento de colisões do conjunto deve permanecer em um")
	print("FAVELA_REFERENCE_MODULES ", JSON.stringify({
		"modules": IDS.size(), "mesh_parts": meshes, "collisions": collisions, "failures": failures
	}))
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capture(gallery)
	if failures.is_empty():
		print("FAVELA_REFERENCE_MODULES PASS")
		quit(0)
	else:
		for issue in failures:
			printerr("FAVELA_REFERENCE_MODULES FAIL: " + issue)
		quit(1)

func _capture(gallery: Node3D) -> void:
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(23, 15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("77756b")
	mat.roughness = 1.0
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = mat
	gallery.add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -32, 0)
	light.shadow_enabled = true
	gallery.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(10, 10, 17)
	camera.look_at_from_position(camera.position, Vector3(0, 1, 0))
	camera.fov = 62.0
	gallery.add_child(camera)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	var target := OS.get_environment("FAVELA_REFERENCE_CAPTURE")
	if target.is_empty():
		target = "user://favela-reference-modules.png"
	var error := root.get_texture().get_image().save_png(target)
	require(error == OK, "falha ao salvar prancha visual")
	print("FAVELA_REFERENCE_CAPTURE ", target)
