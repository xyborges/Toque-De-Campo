extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=WarGame.new();game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_visual_preview",true);root.add_child(game)
	game.online=false;game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.set_process(false);game.set_physics_process(false)
	await physics_frame;await physics_frame
	for base: Vector3 in WarRules.BASES:
		var sign_value:=1. if base.x<0 else -1.
		for z in [35.,41.,47.]:
			var at:=base+Vector3(sign_value*81,0,sign_value*z)
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*8,at-Vector3.UP*8,1)
			var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
			print("TRENCH_CONTACT ",{"at":str(at),"terrain":WarTerrain.height_at(at.x,at.z),"hit":str(hit.get("position",Vector3.INF)),"collider":str(hit.collider.get_path()) if not hit.is_empty() else "none"})
	game.queue_free();await create_timer(.3).timeout;quit()
