extends SceneTree

# Functional equivalence, NOT an FPS benchmark: production flags default OFF.
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	Engine.max_fps=60
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_meta("ia2_allow_headless_queue_test",true)
	await process_frame
	var actor: WarPlayer=game.players.get(2)
	check(is_instance_valid(actor) and not actor.is_local,"remote soldier exists")
	if not is_instance_valid(actor):
		quit(2);return
	check(not GameWeapons.is_launcher(actor.weapon_id) and is_instance_valid(actor.muzzle_marker),"remote starts with full rifle and muzzle")
	var original:=actor.muzzle_marker
	var existing_builds:=actor.ia2_weapon_full_builds
	actor.ia2_respawn_weapon_reuse=true
	actor._refresh_weapon()
	check(actor.muzzle_marker==original,"same weapon retains authoritative muzzle")
	check(actor.ia2_weapon_full_builds==existing_builds and actor.ia2_weapon_reuse_hits==1,"same weapon skips only redundant geometry")
	actor.weapon_id="glock"
	actor._refresh_weapon()
	check(actor.muzzle_marker!=original and actor.ia2_weapon_full_builds==existing_builds+1,"different weapon still rebuilds model and muzzle")
	var glock:=actor.muzzle_marker
	actor._refresh_weapon()
	check(actor.muzzle_marker==glock and actor.ia2_weapon_reuse_hits==2,"repeated pistol also uses valid model")
	actor.weapon_id="rpg"
	actor._refresh_weapon()
	var launcher:=actor.launcher_model
	actor._refresh_weapon()
	check(actor.launcher_model!=launcher,"launcher refresh remains original behavior")
	# Ragdoll scheduling applies only to remote presentation, never death data.
	game.ia2_remote_ragdoll_queue_enabled=true
	var victims: Array[GamePlayer]=[actor]
	for i in 2:
		var victim: WarPlayer=game.make_actor(3+i,false,1,"soldier",Vector3(23+i*4,0,-23))
		victims.append(victim)
	for victim in victims:
		victim.death_presented=victim.life_id-1
		game.spawn_ragdoll(victim.global_position,1,victim)
	check(game.ia2_remote_ragdoll_jobs.size()==3,"three deaths queued instead of building synchronously")
	check(get_nodes_in_group("death_ragdolls").is_empty(),"no remote physics bodies created in death callback")
	await process_frame
	await process_frame
	check(game.ia2_remote_ragdoll_created==1,"at most one remote corpse in the first process frame")
	await process_frame
	check(game.ia2_remote_ragdoll_created==2,"second corpse created on another frame")
	await process_frame
	check(game.ia2_remote_ragdoll_created==3,"third corpse created on another frame")
	for victim in victims:
		check(victim.death_presented==victim.life_id,"death dedup retained across deferred presentations")
	# Projectile simulation: compare impact positions at the same static wall.
	game.ia2_remote_ragdoll_queue_enabled=false
	var wall:=StaticBody3D.new()
	wall.collision_layer=1;wall.collision_mask=0
	var box:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(8,8,1)
	box.shape=shape;wall.add_child(box)
	wall.position=Vector3(0,2,-25)
	game.world_root.add_child(wall)
	var bullet: WarProjectiles=game.war_fx
	var collisions: Array[Vector3]=[]
	for mode in [false,true]:
		bullet.ia2_visual_sweep_30hz=mode
		var key:="ia2-sweep-"+str(mode)
		check(bullet.spawn(2,Vector3(0,2,0),Vector3.FORWARD,"glock",false,key),"remote visual round spawned")
		var stopped:=false
		for tick in 30:
			await physics_frame
			bullet._physics_process(1.0/60.0)
			var shot: Dictionary=bullet.find_round(key)
			if not shot.is_empty() and not bool(shot.active):
				collisions.append(shot.position)
				stopped=true
				break
		check(stopped,"remote visual ray hits obstacle in "+str(mode)+" mode")
	check(collisions.size()==2 and collisions[0].distance_to(collisions[1])<.12,"full sweep and batched sweep hit same world wall")
	check(bullet.ia2_visual_ray_skipped>0 and bullet.ia2_visual_ray_queries>0,"visual-only path actually reduces ray queries")
	var before_authority:=bullet.ia2_authority_ray_queries
	var key_auth:="ia2-server-ray"
	check(bullet.spawn(2,Vector3(0,2,0),Vector3.FORWARD,"glock",true,key_auth),"authoritative round spawned")
	for tick in 15:
		await physics_frame
		bullet._physics_process(1.0/60.0)
		var shot: Dictionary=bullet.find_round(key_auth)
		if not shot.is_empty() and not bool(shot.active): break
	check(bullet.ia2_authority_ray_queries>before_authority,"server retains swept ray queries with visual flag on")
	var report={"checks":checks,"failures":failures,
		"weapon_reuses":actor.ia2_weapon_reuse_hits,
		"deferred_ragdolls":game.ia2_remote_ragdoll_created,
		"visual_ray_skipped":bullet.ia2_visual_ray_skipped,
		"visual_ray_queries":bullet.ia2_visual_ray_queries,
		"authority_ray_queries":bullet.ia2_authority_ray_queries,
		"visual_hit_positions":collisions}
	print("IA2_ENTRY_COMBAT_QA ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
