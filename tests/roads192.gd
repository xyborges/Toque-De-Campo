extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var results: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+65000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: quit(1);return
	Engine.max_fps=0
	game.set_physics_process(false);game.local_player.set_physics_process(false);game.vehicle_system.set_physics_process(false);game.vehicle_system.set_process(false);game.war_fx.set_physics_process(false)
	if game.bot_director: game.bot_director.stop()
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values(): vehicle.collision_layer=0
	for index in [2,3]:
		if "--road-east" in OS.get_cmdline_user_args() and index!=3: continue
		var path:=WarRoads.rounded(WarRoads.ROUTES[index])
		var max_grade:=0.;var max_cross:=0.
		for part in path.size()-1:
			var a: Vector2=path[part];var b: Vector2=path[part+1];var side:=Vector2(-(b-a).y,(b-a).x).normalized()*3.5
			var count:=maxi(1,ceili(a.distance_to(b)))
			for step in count:
				var p:=a.lerp(b,float(step)/count);var q:=a.lerp(b,float(step+1)/count)
				max_grade=maxf(max_grade,absf(WarTerrain.height_at(p.x,p.y)-WarTerrain.height_at(q.x,q.y))/maxf(.001,p.distance_to(q)))
				max_cross=maxf(max_cross,absf(WarTerrain.height_at(p.x+side.x,p.y+side.y)-WarTerrain.height_at(p.x-side.x,p.y-side.y))/7.)
		check(max_grade<.16,"port %d continuous longitudinal grade below 16 percent"%index)
		check(max_cross<.15,"port %d carriageway crossfall below 15 percent"%index)
		results.append({"road":index,"max_longitudinal_percent":max_grade*100,"max_cross_percent":max_cross*100})
		for kind in (["guarani"] if "--road-quick" in OS.get_cmdline_user_args() else ["guarani","bmp2","abrams","t90"]):
			for reverse_path in [false,true]:
				var route:=path.duplicate()
				if reverse_path: route.reverse()
				var vehicle:=game.vehicle_system.vehicles["v_"+kind] as WarVehicle
				game.vehicle_system._respawn_vehicle(vehicle);vehicle.collision_layer=17;vehicle.speed=0;vehicle.velocity=Vector3.ZERO;vehicle.ground_support=WarVehicleGround.new()
				var p: Vector2=route[0];vehicle.position=WarTerrain.point(p.x,p.y)+Vector3.UP*.08
				var direction: Vector2=(Vector2(route[1])-p).normalized();vehicle.heading=atan2(-direction.x,-direction.y);vehicle.rotation=Vector3(0,vehicle.heading,0);vehicle.driver=999
				var goal:=1;var last:=vehicle.position;var stuck:=0;var worst_stuck:=0;var largest_up:=0.;var peak_velocity_y:=0.;var min_up:=1.;var reached:=false
				for frame in 12500:
					var at:=Vector2(vehicle.position.x,vehicle.position.z)
					if at.distance_to(route[goal])<5.:
						goal+=1
						if goal>=route.size(): reached=true;break
					var offset: Vector2=Vector2(route[goal])-at
					var wanted:=atan2(-offset.x,-offset.y);var error:=angle_difference(vehicle.heading,wanted)
					var throttle:=.20 if absf(error)>.6 else .35
					var before:=vehicle.position
					vehicle.simulate(1./60.,{"throttle":throttle,"steer":clampf(-error*2.5,-1,1),"aim":vehicle.position+Vector3.FORWARD*1000})
					largest_up=maxf(largest_up,vehicle.position.y-before.y);peak_velocity_y=maxf(peak_velocity_y,vehicle.velocity.y);min_up=minf(min_up,vehicle.basis.y.y)
					if vehicle.position.distance_squared_to(last)<.000001: stuck+=1
					else: stuck=0
					worst_stuck=maxi(worst_stuck,stuck);last=vehicle.position
					await physics_frame
					if stuck>300: break
				var contact_rows: Array=[]
				for c in vehicle.get_slide_collision_count():
					var hit:=vehicle.get_slide_collision(c)
					for n in hit.get_collision_count():
						var body:=hit.get_collider(n) as CollisionObject3D
						if is_instance_valid(body):
							var shape_node:=body.shape_owner_get_owner(body.shape_find_owner(hit.get_collider_shape_index(n))) as Node3D
							contact_rows.append({"body":str(body.get_path()),"shape":str(shape_node.get_path()) if shape_node else "", "normal":str(hit.get_normal(n)),"position":str(hit.get_position(n))})
				print("CONTACTS ",JSON.stringify(contact_rows))
				var label:="%s / %s / %s"%[kind,"E" if index==3 else "D","uphill" if reverse_path else "downhill"]
				check(reached,label+": completes the actual full access with all original world collisions")
				check(largest_up<.52 and peak_velocity_y<.15 and min_up>.80,label+": no launch, rollover or abrupt climb")
				results.append({"vehicle":label,"reached":reached,"waypoint":goal,"last":str(vehicle.position),"max_up_tick":largest_up,"max_vertical_velocity":peak_velocity_y,"minimum_up_normal":min_up,"stuck_ticks":worst_stuck})
				print("ROAD_SCENARIO ",JSON.stringify(results.back()));NavalStorage.write_json("res://work/roads192-checkpoint.json",{"records":results,"failures":failures})
				vehicle.driver=0;vehicle.collision_layer=0;vehicle.position=Vector3(1500,30,1500)
				await physics_frame
	var report:={"checks":checks,"failures":failures,"records":results,"note":"Actual full-world collision, deterministic 60 Hz simulation, not a performance benchmark."}
	NavalStorage.write_json("res://work/roads192-results.json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
