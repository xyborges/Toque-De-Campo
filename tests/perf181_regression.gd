extends SceneTree

var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var thermal:=WarThermal.new();root.add_child(thermal)
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();root.add_child(mesh)
	var original:=StandardMaterial3D.new();original.albedo_color=Color.RED
	var external:=StandardMaterial3D.new();external.albedo_color=Color.BLUE
	var overlay:=StandardMaterial3D.new();mesh.material_overlay=overlay
	mesh.material_override=original
	thermal.enabled=true;thermal._register_mesh(mesh,.86)
	mesh.get_meta("thermal_source")["unchanged_scan"]=true
	thermal._register_mesh(mesh,.86)
	check(mesh.get_meta("thermal_source").has("unchanged_scan"),"unchanged thermal scan reuses metadata")
	thermal._register_mesh(mesh,.7)
	check(mesh.material_override==thermal.heat_materials[70],"heat changes still update thermal material")
	thermal.set_enabled(false)
	check(mesh.material_override==original,"heat change preserves original material")
	for i in 3:
		thermal.enabled=true;thermal._register_mesh(mesh,.86)
		check(mesh.material_override is ShaderMaterial,"thermal replaces the main pass")
		check(mesh.material_overlay==overlay,"unrelated overlays remain untouched")
		thermal.set_enabled(false)
		check(mesh.material_override==original,"toggle restores original override")
	mesh.material_override=null;thermal.enabled=true;thermal._register_mesh(mesh,.5)
	thermal.set_enabled(false);check(mesh.material_override==null,"surface material restored with null override")
	thermal.enabled=true;thermal._register_mesh(mesh,.5);mesh.material_override=external
	thermal._register_mesh(mesh,.7);thermal.set_enabled(false)
	check(mesh.material_override==external,"appearance change during thermal survives rescan and disable")
	thermal.enabled=true;thermal._register_mesh(mesh,.5);mesh.material_override=original;thermal.set_enabled(false)
	check(mesh.material_override==original,"external change immediately before disable is retained")
	thermal.enabled=true;thermal._register_mesh(mesh,.5);mesh.free();thermal.set_enabled(false)
	check(thermal.registered.is_empty(),"destroyed objects cleared safely")
	thermal.free()
	var world:=Node3D.new();world.set_meta("sector_colliders",true);root.add_child(world)
	var kit:=EnvironmentKit.new(world)
	kit.box("Red",Vector3.ZERO,Vector3.ONE,"wood:aa4444",true)
	kit.box("Blue",Vector3(3,0,0),Vector3.ONE,"wood:4444aa",true)
	check(kit.batches.size()==1,"tints share the same geometry/material batch")
	check(kit.collision_count==2,"both collision shapes retained")
	var batch: Dictionary=kit.batches.values()[0]
	check(batch.transforms.size()==2 and batch.colors.size()==2,"all transforms and instance colors preserved")
	check(batch.colors[0]!=batch.colors[1],"distinct tints not lost when merging")
	kit.flush()
	var draws:=world.find_children("*","MultiMeshInstance3D",true,false)
	check(draws.size()==1 and draws[0].multimesh.instance_count==2,"one batch contains both visible objects")
	check(draws[0].material_override.vertex_color_use_as_albedo,"instance color drives albedo")
	world.free()
	var result:={"checks":checks,"failures":failures}
	var file:=FileAccess.open("res://work/perf181/regression.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("PERF181_REGRESSION "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
