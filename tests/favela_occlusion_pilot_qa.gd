extends SceneTree
## Render-only whitelist contract. Does not require building the full Favela.
var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func _occluders(scene: Node3D) -> Array[Node]:
	return scene.find_children("*","OccluderInstance3D",true,false)

func _run() -> void:
	var strict:=Node3D.new()
	strict.set_meta("use_occluders",true)
	strict.set_meta("occluder_labels",PackedStringArray(["CasaFavela","Puxadinho"]))
	strict.set_meta("occluder_cell_size",32.0)
	root.add_child(strict)
	var kit:=EnvironmentKit.new(strict,true,48.)
	kit.box("CasaFavela",Vector3.ZERO,Vector3(8,5.7,9),"concrete",true)
	kit.box("Puxadinho",Vector3(64,6,0),Vector3(5,2.85,5),"brick",true)
	kit.box("CasaFavela",Vector3(74,0,0),Vector3(7,5.7,8),"concrete",true)
	kit.box("CasaParedeLateral",Vector3(0,2,12),Vector3(.28,4,14),"concrete",true)
	kit.box("LajeAcessivel",Vector3(0,5,0),Vector3(10,.3,10),"concrete",true)
	kit.box("SalaOperacional",Vector3(48,3,0),Vector3(14,6,12),"concrete",true)
	var occluders:=_occluders(strict)
	check(kit.collision_count==6,"pilot must preserve all six colliders")
	check(occluders.size()==2,"only closed and solid houses qualify")
	var labels: Array[String]=[]
	for occluder: Node in occluders:
		labels.append(str(occluder.get_meta("source_collider","")))
		var size: Vector3=(occluder as OccluderInstance3D).occluder.size
		check(size.x>0.0 and size.y>0.0 and size.z>0.0,"occluder box dimensions remain positive")
	check(labels.has("CasaFavela") and labels.has("Puxadinho"),"whitelist excludes walkable/open geometry")
	var closed: OccluderInstance3D=occluders[0] as OccluderInstance3D if not occluders.is_empty() else null
	if closed!=null:
		check(closed.occluder.size==Vector3(7.76,5.46,8.76),"pilot occluder stays inset within real solid collision")

	var normal:=Node3D.new()
	normal.set_meta("use_occluders",false)
	root.add_child(normal)
	var normal_kit:=EnvironmentKit.new(normal,true)
	normal_kit.box("CasaFavela",Vector3.ZERO,Vector3(8,5,8),"concrete",true)
	check(_occluders(normal).is_empty(),"default keeps occlusion disabled")
	check(normal_kit.collision_count==1,"normal gameplay collision unchanged")

	var server:=Node3D.new()
	server.set_meta("use_occluders",true)
	server.set_meta("occluder_labels",PackedStringArray(["CasaFavela"]))
	root.add_child(server)
	var server_kit:=EnvironmentKit.new(server,false)
	server_kit.box("CasaFavela",Vector3.ZERO,Vector3(8,5,8),"concrete",true)
	check(_occluders(server).is_empty(),"dedicated server never builds occluders")
	check(server_kit.collision_count==1,"dedicated server retains collisions")

	var office:=Node3D.new()
	office.set_meta("use_occluders",true)
	root.add_child(office)
	var office_kit:=EnvironmentKit.new(office,true)
	office_kit.box("OfficeSolid",Vector3.ZERO,Vector3(10,5,10),"concrete",true)
	check(_occluders(office).size()==1,"existing office behavior preserved")
	print("FAVELA_OCCLUSION_QA ",JSON.stringify({"checks":checks,"failures":failures,"occluders":labels}))
	quit(0 if failures.is_empty() else 1)
