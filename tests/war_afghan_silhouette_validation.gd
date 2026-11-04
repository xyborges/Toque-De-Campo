extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var arm := Node3D.new()
	var cloth := StandardMaterial3D.new()
	WarAfghanUniform.add_sleeve(arm, cloth)
	var sleeve := arm.get_node_or_null("AfghanTaperedSleeve") as MeshInstance3D
	check(sleeve != null, "Afghan sleeve is built on existing arm pivot")
	if sleeve != null:
		var bounds := sleeve.get_aabb()
		check(bounds.size.x < .26 and bounds.size.z < .27, "Sleeve width remains close to articulated upper arm")
		check(sleeve.position.y + bounds.end.y <= .06, "Sleeve never extends far above shoulder")
		check(sleeve.position.y + bounds.position.y >= -.40, "Sleeve terminates near elbow")
		check(bool(sleeve.get_meta("uniform_attachment",false)), "Sleeve remains batchable")
		check(sleeve.material_override == cloth, "Sleeve reuses cloth material")
	var body_source := FileAccess.get_file_as_string("res://modes/war/scripts/body_mesh.gd")
	check(body_source.contains("sleeve.mesh=null") and not body_source.contains("uniform-sleeve\""), "No long upward placeholder arm mesh")
	check(body_source.contains("WarHumanRig.build(actor)"), "Final articulated WarHumanRig still built")
	var afghan_source := FileAccess.get_file_as_string("res://modes/war/scripts/afghan_uniform.gd")
	check(not afghan_source.contains("LooseSleeve"), "Bulky capsule sleeve removed")
	var uniform_source := FileAccess.get_file_as_string("res://modes/war/scripts/uniform.gd")
	check(uniform_source.contains("team==1 and WarRules.CURRENT_OPERATION==WarOperation.AFGHAN"), "Afghan visual remains isolated from Ukraine")
	print("WAR_AFGHAN_SILHOUETTE_VALIDATION ", JSON.stringify({"checks":checks,"ok":failures.is_empty(),"failures":failures}))
	arm.free()
	quit(0 if failures.is_empty() else 1)
