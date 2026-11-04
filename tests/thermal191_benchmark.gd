extends SceneTree

# Isolated CPU scan benchmark: 1,000 already registered meshes, no GPU/map.
# The initial scan and all allocation/warmup are outside the timed section.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var thermal:=WarThermal.new();root.add_child(thermal);thermal.enabled=true
	var meshes: Array[MeshInstance3D]=[]
	for i in 1000:
		var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();root.add_child(mesh)
		meshes.append(mesh);thermal._register_mesh(mesh,.86)
	for pass_index in 20:
		for mesh in meshes: thermal._register_mesh(mesh,.86)
	var timings: Array[float]=[]
	for pass_index in 200:
		var start:=Time.get_ticks_usec()
		for mesh in meshes: thermal._register_mesh(mesh,.86)
		timings.append((Time.get_ticks_usec()-start)/1000.)
	timings.sort()
	var total:=0.;for value in timings: total+=value
	print("THERMAL191 "+JSON.stringify({"meshes":meshes.size(),"scans":timings.size(),"scan_mean_ms":total/timings.size(),"scan_p95_ms":timings[int(timings.size()*.95)-1],"gpu_rendered":false}))
	thermal.set_enabled(false);thermal.free()
	for mesh in meshes: mesh.free()
	quit()
