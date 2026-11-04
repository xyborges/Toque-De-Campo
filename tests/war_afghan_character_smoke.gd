extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	WarRules.configure(WarOperation.AFGHAN)
	for team in [0,1]:
		var actor := WarPlayer.new()
		actor.name = "SilhouetteTest"+str(team)
		actor.is_local = false
		actor.is_npc = true
		actor.peer_id = 11+team
		actor.war_team = team
		actor.set_physics_process(false)
		root.add_child(actor)
		var upper := actor.avatar_parts.arm_l.get_node_or_null("ArmLMesh") as MeshInstance3D
		var forearm := actor.avatar_parts.arm_l.get_node_or_null("ForearmLMesh") as MeshInstance3D
		check(bool(actor.get_meta("human_war_mesh",false)), "Final War mesh built for team "+str(team))
		check(upper != null and upper.mesh != null and forearm != null and forearm.mesh != null, "Articulated arms visible team "+str(team))
		check(bool(actor.get_meta("articulated_arms",false)), "IK enabled team "+str(team))
		check(int(actor.get_meta("afghan_uniform_variant",-1)) >= 0 if team==1 else not actor.has_meta("afghan_uniform_variant"), "Afghan variants isolated team "+str(team))
		actor.queue_free()
		await process_frame
	print("WAR_AFGHAN_CHARACTER_SMOKE ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
