extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
	if "--ticks40" in OS.get_cmdline_user_args(): Engine.physics_ticks_per_second=40
	run.call_deferred()
func run() -> void:
	var game=load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode="training";game.map_kind="sandbox";game._enter_match_world()
	game._static_box(game.world_root,"Floor",Vector3(0,-.25,0),Vector3(80,.4,80),Color.GRAY)
	var sources: Array[GamePlayer]=[]
	for i in 12:
		var pos:=Vector3((i%4)*4,0,(i/4)*4)
		game._static_box(game.world_root,"Wall%d"%i,pos+Vector3(.5,1.5,0),Vector3(.3,3,2),Color.GRAY)
		var actor: GamePlayer=game._spawn_player(100+i,false,true,pos)
		actor.set_physics_process(false)
		actor.apply_body_proportions({"head":1.5 if i%2 else .65,"torso":1.5 if i%3==0 else 1,"arms":1.5,"legs":1.0})
		actor.yaw=i*.6;actor.rotation.y=actor.yaw
		actor.avatar_parts.arm_l.rotation.x=-1.5
		actor.avatar_parts.arm_r.rotation.z=-1.0
		actor.set_meta("death_velocity",Vector3(4,0,-2))
		sources.append(actor)
	await physics_frame
	for actor in sources:
		actor.detached_region=""
		DeathRagdoll.create(game.world_root,actor,actor.global_position)
	var max_speed:=0.0
	var max_height:=0.0
	var max_separation:=0.0
	for tick in 180:
		await physics_frame
		for corpse in get_nodes_in_group("death_ragdolls"):
			var torso: RigidBody3D=corpse.get_node("Torso")
			for body in corpse.get_children():
				if not body is RigidBody3D: continue
				if not CombatRules.finite_vector(body.global_position): failures.append("invalid corpse transform")
				max_speed=maxf(max_speed,body.linear_velocity.length())
				max_height=maxf(max_height,body.global_position.y)
				max_separation=maxf(max_separation,body.global_position.distance_to(torso.global_position))
	if max_speed>11: failures.append("solver launched a body")
	if max_height>4: failures.append("corpse flew above its initial pose")
	if max_separation>2.7: failures.append("attached parts separated from torso")
	var report: Dictionary={"failures":failures,"corpses":get_nodes_in_group("death_ragdolls").size(),"maximum_speed":max_speed,"maximum_height":max_height,"maximum_separation":max_separation}
	NavalStorage.write_json("res://work/ragdoll-contact-40-results.json" if "--ticks40" in OS.get_cmdline_user_args() else "res://tests/ragdoll-contact-stress.json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
