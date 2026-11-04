extends "res://tests/afghan_composition_benchmark.gd"
func diagnose() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var plants: Array[GeometryInstance3D]=[]
	for child in map.get_children():
		if child is GeometryInstance3D and (str(child.name).begins_with("poplar_") or str(child.name).begins_with("willow_") or str(child.name).begins_with("garden_shrub_")):plants.append(child)
	var rows: Array=[]
	for variant in ["normal","no_shadows","normal","no_plants","normal","no_physics","normal"]:
		lights.sun.shadow_enabled=variant!="no_shadows"
		for plant in plants:plant.visible=variant!="no_plants"
		PhysicsServer3D.set_active(variant!="no_physics")
		await create_timer(2.).timeout
		var times: Array[float]=[];var gpu:=0.;var cpu:=0.;var physics:=0.;var hitches: Array=[]
		var start:=Time.get_ticks_usec();var previous:=start
		while Time.get_ticks_usec()-start<8000000:
			await process_frame
			var now:=Time.get_ticks_usec();var ms: float=(now-previous)*.001;previous=now;times.append(ms)
			var gpu_ms:=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			var render_ms:=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			var physics_ms: float=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
			gpu+=gpu_ms;cpu+=render_ms;physics+=physics_ms
			if ms>20.:hitches.append({"ms":ms,"gpu":gpu_ms,"render_cpu":render_ms,"physics":physics_ms,"process":Performance.get_monitor(Performance.TIME_PROCESS)*1000.})
			var elapsed: float=(now-start)*.000001
			for i in actors.size():
				actors[i].rotation.y=sin(elapsed*.3+i)*.5
				actors[i].avatar_parts.leg_l.rotation.x=sin(elapsed*8.+i)*.25
				actors[i].avatar_parts.leg_r.rotation.x=-sin(elapsed*8.+i)*.25
		var total: float=times.reduce(func(a,b):return a+b,0.);times.sort();var count:=maxi(1,ceili(times.size()*.01));var slow:=0.
		for i in range(times.size()-count,times.size()):slow+=times[i]
		var row:={"variant":variant,"fps":times.size()*1000./total,"low":count*1000./slow,"worst_ms":times[-1],"gpu_ms":gpu/times.size(),"render_cpu_ms":cpu/times.size(),"physics_ms":physics/times.size(),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"hitches":hitches}
		rows.append(row);print("AFGHAN_COST ",variant," FPS=",row.fps," LOW=",row.low," GPU=",row.gpu_ms," CPU=",row.render_cpu_ms," PHYSICS=",row.physics_ms)
	PhysicsServer3D.set_active(true)
	NavalStorage.write_json("res://work/"+label+"-cost.json",{"samples":rows,"scope":"Render feature ceilings and inactive physics ceiling; not changes applied to gameplay. Same camera, 18 actors."})
