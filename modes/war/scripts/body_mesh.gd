extends RefCounted
class_name WarBodyMesh

static var cache: Dictionary={}

# Rings describe an authored silhouette: height, half-width, half-depth,
# depth offset. Superellipse sections give cloth volume without box corners.
static func loft(id: String,rings: Array,segments:=16,roundness:=.72) -> ArrayMesh:
	if cache.has(id): return cache[id]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for level in rings.size()-1:
		for side in segments:
			var points: Array[Vector3]=[]
			for corner: Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,0)]:
				var row: Array=rings[level+corner.x]
				var angle:=float(side+corner.y)/segments*TAU
				var sx:=sin(angle);var cz:=cos(angle)
				points.append(Vector3(signf(sx)*pow(absf(sx),roundness)*float(row[1]),float(row[0]),signf(cz)*pow(absf(cz),roundness)*float(row[2])+float(row[3])))
			for index in [0,2,1]:
				surface.set_uv(Vector2(float(side)/segments,float(level)/rings.size()))
				surface.add_vertex(points[index])
			for index in [3,5,4]:
				surface.set_uv(Vector2(float(side+1)/segments,float(level+1)/rings.size()))
				surface.add_vertex(points[index])
	# A sleeve/forearm may end on a nonzero ring. Leaving that ring open
	# exposed the far side as a hollow cuff when looking at raised shoulders.
	# Close both ends in the original surface, without extra shoulder nodes.
	for end in [0,rings.size()-1]:
		var row: Array=rings[end]
		if float(row[1])<=.00001 or float(row[2])<=.00001:continue
		var centre:=Vector3(0,float(row[0]),float(row[3]))
		for side in segments:
			var edge: Array[Vector3]=[]
			for step in [side,side+1]:
				var angle:=float(step)/segments*TAU;var sx:=sin(angle);var cz:=cos(angle)
				edge.append(Vector3(signf(sx)*pow(absf(sx),roundness)*float(row[1]),float(row[0]),signf(cz)*pow(absf(cz),roundness)*float(row[2])+float(row[3])))
			for point in [centre,edge[1] if end==0 else edge[0],edge[0] if end==0 else edge[1]]:
				surface.set_uv(Vector2(.5,.5));surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	var mesh:=surface.commit()
	cache[id]=mesh
	return mesh

static func cushion(size: Vector3) -> Mesh:
	var id: String="cushion:"+str(size)
	return loft(id,[[-size.y*.5,0,0,0],[-size.y*.46,size.x*.40,size.z*.38,0],[-size.y*.32,size.x*.50,size.z*.50,0],[size.y*.32,size.x*.50,size.z*.50,0],[size.y*.46,size.x*.40,size.z*.38,0],[size.y*.5,0,0,0]],12,.55)

static func apply(actor: GamePlayer) -> void:
	var head: MeshInstance3D=actor.avatar_parts.head
	head.mesh=loft("human-head188",[[-.218,.043,.057,-.014],[-.187,.083,.090,-.013],[-.128,.118,.119,-.008],[-.052,.140,.137,.004],[.025,.148,.147,.008],[.116,.145,.143,.013],[.188,.103,.109,.017],[.223,0,0,.018]],28,1.0)
	head.position=Vector3(0,1.70,0)
	for face in head.get_children():
		if face is MeshInstance3D and not face.has_meta("uniform_attachment"):
			head.remove_child(face);face.queue_free()
	for side in [-1,1]:
		var ear:=MeshInstance3D.new()
		ear.mesh=cushion(Vector3(.055,.105,.055))
		ear.position=Vector3(side*.154,-.015,.005)
		ear.material_override=head.material_override
		head.add_child(ear)
		var eye:=MeshInstance3D.new()
		eye.mesh=cushion(Vector3(.032,.010,.006))
		eye.position=Vector3(side*.060,.004,-.134)
		eye.material_override=EnvironmentKit.material("fabric:51483e")
		head.add_child(eye)
		var brow:=MeshInstance3D.new()
		brow.mesh=cushion(Vector3(.041,.006,.006));brow.position=Vector3(side*.060,.030,-.135)
		brow.material_override=EnvironmentKit.material("fabric:685343");head.add_child(brow)
	var nose:=MeshInstance3D.new()
	nose.mesh=loft("human-nose",[[-.052,.018,.009,0],[-.025,.027,.025,0],[.035,.012,.012,0],[.05,0,0,0]],10)
	nose.position=Vector3(0,-.032,-.153);nose.material_override=head.material_override;head.add_child(nose)
	var lips:=MeshInstance3D.new()
	lips.mesh=cushion(Vector3(.057,.008,.007));lips.position=Vector3(0,-.108,-.126)
	lips.material_override=EnvironmentKit.material("fabric:a47a61");head.add_child(lips)
	var torso: MeshInstance3D=actor.avatar_parts.torso
	torso.mesh=loft("uniform-torso",[[-.34,.19,.14,0],[-.27,.225,.145,0],[-.05,.25,.16,0],[.15,.285,.175,0],[.26,.28,.16,0],[.34,.16,.12,0],[.37,.08,.085,0]],20,.8)
	torso.position=Vector3(0,1.15,0)
	var pelvis:=actor.body_root.get_node("Pelvis") as MeshInstance3D
	pelvis.mesh=loft("uniform-pelvis",[[-.14,.20,.13,0],[-.09,.235,.15,0],[.08,.23,.15,0],[.15,.205,.135,0]],16,.8)
	pelvis.position.y=.84
	for side in ["l","r"]:
		var arm: Node3D=actor.avatar_parts["arm_"+side]
		arm.position=Vector3(-.30 if side=="l" else .30,1.42,0)
		var sleeve:=arm.get_node(str(arm.name)+"Mesh") as MeshInstance3D
		# No upward-pointing placeholder arms. WarHumanRig.build() below
		# installs the single definitive articulated upper-arm mesh/pose.
		sleeve.mesh=null
		var hand:=arm.get_node("Hand"+("L" if side=="l" else "R")) as MeshInstance3D
		hand.mesh=cushion(Vector3(.13,.17,.095))
		hand.material_override=EnvironmentKit.material("fabric:32392e")
		var leg: Node3D=actor.avatar_parts["leg_"+side]
		leg.position=Vector3(-.145 if side=="l" else .145,.85,0)
		var pants:=leg.get_node(str(leg.name)+"Mesh") as MeshInstance3D
		pants.mesh=loft("uniform-trousers",[[-.39,.07,.08,0],[-.31,.085,.095,0],[-.17,.095,.10,.01],[-.05,.105,.115,-.012],[.03,.11,.13,0],[.20,.13,.14,0],[.34,.135,.14,0],[.39,.10,.10,0]],16,.9)
		var boot:=leg.get_node("Shoe"+("L" if side=="l" else "R")) as MeshInstance3D
		boot.mesh=loft("combat-boot",[[-.08,.095,.17,-.025],[-.04,.105,.18,-.025],[.04,.10,.17,-.022],[.09,.085,.11,.025],[.22,.075,.09,.03],[.24,.07,.08,.03]],14,.68)
		boot.material_override=EnvironmentKit.material("fabric:383b32")
		var sole:=MeshInstance3D.new()
		sole.mesh=cushion(Vector3(.22,.045,.37));sole.position=Vector3(0,-.07,-.025)
		sole.material_override=EnvironmentKit.material("steel:232825");boot.add_child(sole)
	_update_region(actor,"head",Vector3(.32,.45,.31))
	_update_region(actor,"chest",Vector3(.55,.34,.35),Vector3(0,.15,0))
	_update_region(actor,"abdomen",Vector3(.46,.32,.31),Vector3(0,-.17,0))
	_update_region(actor,"abdomenPelvis",Vector3(.46,.27,.30))
	for side in ["L","R"]:
		_update_region(actor,"arm"+side,Vector3(.21,.38,.23),Vector3(0,.19,0))
		_update_region(actor,"forearm"+side,Vector3(.17,.38,.19),Vector3(0,-.19,0))
		_update_region(actor,"hand"+side,Vector3(.13,.17,.10))
		_update_region(actor,"leg"+side,Vector3(.25,.78,.28))
		_update_region(actor,"foot"+side,Vector3(.22,.28,.37),Vector3(0,.07,-.02))
	WarHumanRig.build(actor)
	actor.set_meta("human_war_mesh",true)

static func _update_region(actor: GamePlayer,id: String,size: Vector3,offset:=Vector3.ZERO) -> void:
	if not actor.hit_regions.has(id): return
	var area: Area3D=actor.hit_regions[id]
	var collider: CollisionShape3D
	for child in area.get_children():
		if child is CollisionShape3D: collider=child;break
	if collider==null: return
	var box:=BoxShape3D.new();box.size=size;collider.shape=box;collider.position=Vector3.ZERO
	area.position=offset
