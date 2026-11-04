extends SceneTree

const Lab=preload("res://tests/pole_fracture_visual_lab.gd")
var errors: Array[String]=[]

func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab=Lab.new();root.add_child(lab)
	var a:=Vector2i(0,0);var b:=Vector2i(1,0)
	var points: Array=[Vector3(2,1,2),Vector3(8,1,2),Vector3(95,1,2)]
	check(lab.setup(points,[[a,0,a,1],[a,1,b,0]]),"create grouped poles and wires")
	var shape: CollisionShape3D=lab.entries["0:0:0"].shape
	var owner_before: int=(shape.get_parent() as CollisionObject3D).shape_find_owner(0)
	var initial: Vector3=lab.wires[0].from
	var event: Dictionary={"cell":a,"index":0,"direction":Vector3.RIGHT,"height_cm":150}
	check(lab.present(event),"falling event accepted")
	check(not lab.present(event),"duplicate event ignored")
	check(lab.active_count()==1 and lab.entries["0:0:0"].height==1.5,"correct fall height and pool count")
	lab._process(.8)
	check(lab.wires[0].from.distance_to(initial)>.1,"wire follows moving upper end")
	lab._process(.8)
	check(lab.active_count()==0 and not lab.is_processing(),"finished fall returns pool slot")
	var endpoint: Vector3=lab.entries["0:0:0"].tip
	check(lab.wires[0].from.distance_to(endpoint)<.001,"wire follows settled end")
	check(float(lab.wires[0].min_y)>=1.04-.001,"wire does not pass below flat test ground")
	check(lab.present({"cell":b,"index":0,"direction":Vector3.LEFT,"height_cm":620},false),"late snapshot settles immediately")
	check(lab.active_count()==0 and lab.entries["1:0:0"].height==6.2,"late state keeps distinct break height")
	await process_frame;await physics_frame
	check(shape.disabled,"broken pole shape disabled")
	var stump_shape: CollisionShape3D=lab.entries["0:0:0"].stump_shape
	check(not stump_shape.disabled and is_equal_approx((stump_shape.shape as CylinderShape3D).height,1.5),"stump collision follows break height")
	await physics_frame
	var space:=lab.get_world_3d().direct_space_state
	var low_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.7,2),Vector3(4,1.7,2),1))
	var high_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,3.,2),Vector3(4,3.,2),1))
	check(not low_hit.is_empty() and high_hit.is_empty(),"collision retains the stump and clears the broken upper section")
	if not low_hit.is_empty():
		var hit_body:=low_hit.collider as CollisionObject3D
		var hit_owner:=hit_body.shape_find_owner(int(low_hit.shape))
		var hit_shape:=hit_body.shape_owner_get_owner(hit_owner) as CollisionShape3D
		check(is_instance_valid(hit_shape) and hit_shape.get_meta("pole_cell")==a and hit_shape.get_meta("pole_index")==0,"shared collider identifies the exact pole shape")
	check((shape.get_parent() as CollisionObject3D).shape_find_owner(0)==owner_before,"shape index remains stable")
	check(not (lab.entries["0:0:1"].shape as CollisionShape3D).disabled,"neighbour stays solid")
	var busy=Lab.new();root.add_child(busy);var many: Array=[]
	for i in 13: many.append(Vector3(2.+float(i),1,4))
	check(busy.setup(many,[]),"create pool-overflow test")
	for i in 13:
		check(busy.present({"cell":a,"index":i,"direction":Vector3.RIGHT,"height_cm":100+i*20}),"each simultaneous break accepted")
	check(busy.active_count()==12 and busy.max_active==12,"pool remains bounded and overflow settles")
	check(busy.entries["0:0:12"].tip.distance_to(many[12]+Vector3.UP*3.4)>1.,"overflow has a settled wire endpoint")
	busy._process(2.)
	check(busy.active_count()==0,"all pooled falls return to idle")
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"peak_pool":busy.max_active,"cells":lab.cells.size(),"wires":lab.wires.size()}))
	quit(0 if errors.is_empty() else 1)
