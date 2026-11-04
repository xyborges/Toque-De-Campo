extends SceneTree

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)

func find_mesh(parent: Node,prefix: String) -> MeshInstance3D:
	for child in parent.get_children():
		if child is MeshInstance3D and str(child.name).begins_with(prefix):
			return child
	return null

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result

func parent_aabb(node: MeshInstance3D) -> AABB:
	return node.transform*node.mesh.get_aabb()

func signed_volume(node: MeshInstance3D) -> float:
	var result:=0.0
	for surface in node.mesh.get_surface_count():
		var arrays:=node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty(): continue
		for triangle in indices.size()/3:
			var a:=vertices[indices[triangle*3]]
			var b:=vertices[indices[triangle*3+1]]
			var c:=vertices[indices[triangle*3+2]]
			result+=a.dot(b.cross(c))/6.0
	return result

func build_raw(kind: String) -> WarVehicle:
	var actor:=WarVehicle.new()
	actor.kind=kind
	actor.vehicle_id="model_integrity_"+kind
	root.add_child(actor)
	actor.set_physics_process(false)
	var builder:=WarVehicleModels.new()
	builder.v=actor
	builder.paint="657052" if actor.team==0 else "4c6047"
	match kind:
		"guarani": builder.guarani()
		"bmp2": builder.bmp()
		"abrams": builder.abrams()
		"t90": builder.t90()
	builder.common()
	if kind in ["guarani","bmp2"]: builder.tv_launcher()
	actor.set_meta("qa_piece_count",builder.pieces)
	return actor

func check_tank_neck(actor: WarVehicle,hull_roof: float,shell_bottom: float,prefix: String) -> void:
	var race:=find_mesh(actor.turret,prefix+"TurretRace")
	var collar:=find_mesh(actor.turret,prefix+"TurretCollar")
	check(race!=null and collar!=null,actor.kind+" has turret race and collar")
	if race==null: return
	var bounds:=parent_aabb(race)
	var local_roof:=hull_roof-actor.turret.position.y
	check(bounds.position.y<=local_roof+.005,actor.kind+" turret race reaches hull roof")
	check(bounds.end.y>=shell_bottom-.005,actor.kind+" turret race reaches turret shell")

func check_tv_mount(actor: WarVehicle) -> void:
	var bridge:=find_mesh(actor.elevation,"TVLauncherPivotBridge")
	var riser:=find_mesh(actor.elevation,"TVLauncherRiser")
	var cradle:=find_mesh(actor.elevation,"TVLauncherCradle")
	var trunnion:=find_mesh(actor.elevation,"TVLauncherTrunnion")
	check(bridge!=null and riser!=null and cradle!=null and trunnion!=null,actor.kind+" TV launcher has articulated support")
	if bridge==null or riser==null or cradle==null: return
	check(parent_aabb(bridge).grow(.01).intersects(parent_aabb(riser)),actor.kind+" TV bridge touches riser")
	check(parent_aabb(riser).grow(.01).intersects(parent_aabb(cradle)),actor.kind+" TV riser touches cradle")

func check_tank_gun(actor: WarVehicle) -> void:
	var shield:=find_mesh(actor.elevation,"GunMantletShield")
	var trunnion:=find_mesh(actor.elevation,"GunTrunnion")
	var barrel_mesh:=find_mesh(actor.elevation,"GunM256" if actor.kind=="abrams" else "Gun2A46")
	check(shield!=null and trunnion!=null,actor.kind+" main gun has mantlet shield and trunnion")
	if shield!=null and trunnion!=null:
		check(parent_aabb(shield).grow(.01).intersects(parent_aabb(trunnion)),actor.kind+" trunnion connects to mantlet")
	check(barrel_mesh!=null,actor.kind+" main gun barrel exists")

func shell_name(kind: String) -> String:
	return {"guarani":"Guarani30Turret","bmp2":"BMPFacetedConicalTurret","abrams":"AbramsWeldedAngularTurret","t90":"T90LowWeldedTurret"}[kind]

func run() -> void:
	for kind in ["guarani","bmp2","abrams","t90"]:
		var actor:=build_raw(kind)
		var shell:=find_mesh(actor.turret,shell_name(kind))
		check(shell!=null,kind+" turret shell exists")
		if shell!=null: check(signed_volume(shell)<-.01,kind+" turret shell faces point outward")
		var material_ok:=true
		for mesh in meshes(actor):
			if mesh.mesh==null or mesh.get_active_material(0)==null:
				material_ok=false
				break
		check(material_ok,kind+" visual pieces have explicit materials")
		check(int(actor.get_meta("qa_piece_count",0))>100,kind+" keeps detailed model density")
		if kind=="abrams":
			check_tank_neck(actor,1.71,-.24,"Abrams")
			check_tank_gun(actor)
		elif kind=="t90":
			check_tank_neck(actor,1.57,-.13,"T90")
			check_tank_gun(actor)
		else:
			check_tv_mount(actor)
		actor.queue_free()
		await process_frame
	print("VEHICLE_MODEL_INTEGRITY %d checks / %d failures"%[checks,failures.size()])
	if not failures.is_empty(): print(JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
