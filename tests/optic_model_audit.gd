extends SceneTree
const FIXTURE = preload("res://tests/war_optics_fixture.gd")
var game: WarGame
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func settle() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func signature(node: Node3D) -> Dictionary:
	var shapes: Array[String] = []
	var names: Array[String] = []
	var triangles := 0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible: continue
		names.append(str(mesh.name))
		var count := 0
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			count += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		triangles += count
		shapes.append("%s:%s:%s:%s" % [mesh.name, mesh.mesh.get_class(), mesh.mesh.get_aabb(), mesh.transform])
	shapes.sort(); names.sort()
	return {"sha256": "\n".join(shapes).sha256_text(), "visible_meshes": names, "triangles": triangles}

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Requires graphical Compatibility rendering"); quit(2); return
	root.title = "Toque de Campo — auditoria das duas ópticas"
	root.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game = FIXTURE.new(); root.add_child(game); await settle()
	game.hud_layer.hide()
	var actor := game.local_player as WarPlayer
	actor.set_process(false); actor.set_physics_process(false); actor.set_process_unhandled_input(false)
	var camera := Camera3D.new(); camera.fov = 36.; camera.near = .01; game.world_root.add_child(camera)
	for weapon: String in ["fal", "ak"]:
		var signatures := {}
		for optic: String in ["prism4x", "pso4x"]:
			var canonical := GameAttachmentState.from_legacy(weapon, optic)
			actor.set_meta("weapon_attachments", {weapon: canonical})
			actor.set_meta("weapon_optics", {weapon: optic})
			actor.weapon_id = weapon; actor.hp = 100.; actor.deployed = true
			actor.aiming = false; actor.iron_sights = false; actor.reload_left = 0.
			game.third_person = false; actor.yaw = 0.; actor.rotation = Vector3.ZERO; actor.pitch = 0.
			actor._refresh_weapon(); actor._update_view(); actor._update_weapon_pose(); actor.weapon_optics.update(actor)
			await settle()
			var world := actor.weapon_optics.world_scope as Node3D
			var copy := actor.view_root.find_child("Scope4x", true, false) as Node3D
			check(world != null and copy != null, "world and FPP modules exist: " + weapon + "/" + optic)
			if not world or not copy: continue
			check(world.get_meta("attachment_id", "") == optic and copy.get_meta("attachment_id", "") == optic, "canonical chosen ID reaches world and FPP: " + weapon + "/" + optic)
			var physical := signature(world); var presentation := signature(copy)
			check(physical.sha256 == presentation.sha256, "prepare_copy preserves actual chosen geometry: " + weapon + "/" + optic)
			check(actor.weapon_root.find_children("Scope4x", "Node3D", true, false).size() == 1 and actor.view_root.find_children("Scope4x", "Node3D", true, false).size() == 1, "one selected module, no hidden alternatives: " + weapon + "/" + optic)
			signatures[optic] = physical.sha256
			var row := {"weapon": weapon, "optic": optic, "scene": GameAttachmentRegistry.definition(optic).scene_reference.resource_path,
				"physical": physical, "presentation": presentation, "canonical": canonical}
			actor.camera.make_current(); await settle()
			var hip_path := "res://work/optic-model-" + weapon + "-" + optic + "-fpp.png"
			root.get_texture().get_image().save_png(hip_path); row.fpp_capture = hip_path
			# Inspect the actual mounted world module close up, not an unrelated
			# standalone catalog scene. Original hands/receiver stay in the view.
			actor.view_root.hide(); actor.weapon_root.show()
			var target := world.global_position
			camera.global_position = target + Vector3(.75, .18, .32)
			camera.look_at(target + Vector3(0., -.02, -.03), Vector3.UP); camera.make_current()
			await settle()
			var tpp_path := "res://work/optic-model-" + weapon + "-" + optic + "-mounted.png"
			root.get_texture().get_image().save_png(tpp_path); row.world_capture = tpp_path
			actor.camera.make_current(); actor.aiming = true; actor.iron_sights = true
			actor._update_view(); actor._update_weapon_pose(); actor.weapon_optics.update(actor); await settle()
			var ads_path := "res://work/optic-model-" + weapon + "-" + optic + "-ads.png"
			root.get_texture().get_image().save_png(ads_path); row.ads_capture = ads_path
			check(actor.weapon_optics.active, "selected optic uses live rendered view: " + weapon + "/" + optic)
			records.append(row)
		check(signatures.get("prism4x", "") != signatures.get("pso4x", ""), "both models have genuinely different mounted geometry on " + weapon)
		actor.remove_meta("weapon_attachments"); actor.set_meta("weapon_optics", {weapon: "scope4x"})
		actor.refresh_weapon_optics(); actor._update_view(); actor._update_weapon_pose(); actor.weapon_optics.update(actor); await settle()
		var expected := "prism4x" if weapon == "fal" else "pso4x"
		check(actor.weapon_optics.selected_optic == expected, "old scope4x alias preserves model: " + weapon + "/" + expected)
		# A deliberately selected iron sight must beat old legacy metadata.
		actor.set_meta("weapon_attachments", {weapon: {}}); actor.refresh_weapon_optics()
		check(not actor.weapon_optics.enabled(actor), "explicit canonical iron sight beats stale legacy model: " + weapon)
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures, "records": records,
		"scope": "Actual shared player/world/FPP attachment manager, canonical state and legacy alias; four physical mounted combinations and live ADS captures. Static geometry audit, not multiplayer test or subjective quality approval."}
	NavalStorage.write_json("res://work/optic-model-audit.json", report)
	print("OPTIC_MODEL_AUDIT ", checks, " ", failures)
	game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
