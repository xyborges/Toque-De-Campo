extends RefCounted
class_name DeathRagdoll

static func create(parent: Node3D, source: Node3D, _position: Vector3, persistent:=false) -> Node3D:
	# Experimental A/B switch. Default is the original, fully physical ragdoll.
	var faster_physics: bool = OS.get_environment("TDC_R01_RAGDOLL_OPT") == "1" and not source.is_local and not persistent
	var root := preload("res://scripts/ragdoll_lifetime.gd").new()
	root.name = "DeathRagdoll"
	root.add_to_group("death_ragdolls")
	parent.add_child(root)
	var definitions := {
		"Torso":[source.avatar_parts.torso,25.0], "Head":[source.avatar_parts.head,5.0],
		"Pelvis":[source.body_root.get_node("Pelvis"),10.0],
		"ArmL":[source.avatar_parts.arm_l.get_node("ArmLMesh"),3.5], "ArmR":[source.avatar_parts.arm_r.get_node("ArmRMesh"),3.5],
		"HandL":[source.avatar_parts.arm_l.get_node("HandL"),0.7], "HandR":[source.avatar_parts.arm_r.get_node("HandR"),0.7],
		"LegL":[source.avatar_parts.leg_l.get_node("LegLMesh"),8.0], "LegR":[source.avatar_parts.leg_r.get_node("LegRMesh"),8.0],
		"ShoeL":[source.avatar_parts.leg_l.find_child("ShoeL",true,false),1.0], "ShoeR":[source.avatar_parts.leg_r.find_child("ShoeR",true,false),1.0]}
	for side in ["L","R"]:
		var forearm:=source.avatar_parts["arm_"+side.to_lower()].get_node_or_null("Forearm"+side+"Mesh") as MeshInstance3D
		if forearm: definitions["Forearm"+side]=[forearm,1.8];definitions["Arm"+side][1]=1.7
		var shin:=source.avatar_parts["leg_"+side.to_lower()].find_child("Shin"+side,true,false) as MeshInstance3D
		if shin: definitions["Shin"+side]=[shin,3.2];definitions["Leg"+side][1]=4.8
	var bodies: Dictionary = {}
	var materials: Array[StandardMaterial3D] = []
	var displacement:=_clearance(parent,definitions)
	for key in definitions:
		var original: MeshInstance3D = definitions[key][0]
		var body := preload("res://scripts/ragdoll_body.gd").new()
		body.name = key
		body.mass = float(definitions[key][1])
		body.linear_damp = 1.0
		body.angular_damp = 3.5
		body.linear_velocity = Vector3(source.get_meta("death_velocity",Vector3.ZERO)).limit_length(8.0)
		# Large trunk/head parts retain CCD; smaller connected limbs use discrete contacts.
		body.continuous_cd = not faster_physics or key in ["Torso", "Head", "Pelvis"]
		body.collision_layer = 8
		body.collision_mask = 1
		root.add_child(body)
		body.global_transform = Transform3D(original.global_basis.orthonormalized(),original.global_position+displacement)
		var visual := MeshInstance3D.new()
		visual.mesh = original.mesh
		visual.scale = original.global_basis.get_scale().abs()
		var source_material:=original_material(original)
		var material := source_material.duplicate() as StandardMaterial3D if source_material is StandardMaterial3D else StandardMaterial3D.new()
		visual.material_override = material
		materials.append(material)
		body.add_child(visual)
		# Clothing and equipment stay on their physical body section, including
		# attachments parented to an animated arm/leg pivot rather than its mesh.
		var attachments: Array[Node] = original.find_children("*","MeshInstance3D",true,false)
		if key in ["ArmL","ArmR","LegL","LegR","ShinL","ShinR"]:
			for child in original.get_parent().get_children():
				if child.has_meta("uniform_attachment"):
					if child is MeshInstance3D: attachments.append(child)
					attachments.append_array(child.find_children("*","MeshInstance3D",true,false))
		for attachment: MeshInstance3D in attachments:
			var piece := MeshInstance3D.new()
			piece.mesh = attachment.mesh
			var attachment_material:=original_material(attachment)
			if attachment_material:
				piece.material_override = attachment_material.duplicate()
				if piece.material_override is StandardMaterial3D: materials.append(piece.material_override)
			body.add_child(piece)
			piece.global_transform = attachment.global_transform
			piece.global_position+=displacement
			var equipment_kind:=_equipment_kind(attachment,source.body_root)
			if not equipment_kind.is_empty():piece.set_meta("br_equipment_kind",equipment_kind)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = original.mesh.get_aabb().size * visual.scale * 0.96
		shape.shape = box
		shape.position=original.mesh.get_aabb().get_center()*visual.scale
		body.add_child(shape)
		bodies[key] = body
	# In optimized mode, layer 8 / mask 1 already excludes every body in this
	# ragdoll from every other body. Avoid the quadratic exception registration.
	if not faster_physics:
		for body in bodies.values():
			for other in bodies.values():
				if body != other: body.add_collision_exception_with(other)
	var links := [["Torso","Head"],["Torso","Pelvis"],["Torso","ArmL"],["Torso","ArmR"],["ArmL","HandL"],["ArmR","HandR"],["Pelvis","LegL"],["Pelvis","LegR"],["LegL","ShoeL"],["LegR","ShoeR"]]
	for side in ["L","R"]:
		if bodies.has("Forearm"+side):
			links.erase(["Arm"+side,"Hand"+side]);links.append(["Arm"+side,"Forearm"+side]);links.append(["Forearm"+side,"Hand"+side])
		if bodies.has("Shin"+side):
			links.erase(["Leg"+side,"Shoe"+side]);links.append(["Leg"+side,"Shin"+side]);links.append(["Shin"+side,"Shoe"+side])
	var detached: String = {"head":"Head","armL":"ArmL","armR":"ArmR","legL":"LegL","legR":"LegR"}.get(source.detached_region,"")
	for link in links:
		if link[1] == detached: continue
		var joint := ConeTwistJoint3D.new()
		root.add_child(joint)
		joint.global_position = bodies[link[0]].global_position.lerp(bodies[link[1]].global_position,0.5)
		joint.swing_span = 0.65 if link[1] != "Head" else 0.3
		joint.twist_span = 0.3
		if ProjectSettings.get_setting("physics/3d/physics_engine","")!="Jolt Physics": joint.bias = 0.25
		joint.node_a = joint.get_path_to(bodies[link[0]])
		joint.node_b = joint.get_path_to(bodies[link[1]])
	apply_fatal_impact(bodies,source.last_hit_region,source.last_impact_direction,source.last_impact_weapon)
	root.begin(bodies,materials,persistent,faster_physics)
	return bodies.Torso

static func _equipment_kind(piece: Node,boundary: Node) -> String:
	var ancestor:=piece
	while is_instance_valid(ancestor) and ancestor!=boundary:
		var kind:=str(ancestor.get_meta("equipment_kind",""))
		if kind in ["vest","helmet","pack"]:return kind
		if str(ancestor.name).begins_with("BRProtection"):
			kind=str(ancestor.name).trim_prefix("BRProtection")
			if kind in ["vest","helmet","pack"]:return kind
		ancestor=ancestor.get_parent()
	return ""

static func apply_fatal_impact(bodies: Dictionary,region: String,direction: Vector3,weapon: String) -> void:
	if not direction.is_finite() or direction.length_squared()<.01: return
	var name: String={"head":"Head","chest":"Torso","torso":"Torso","abdomen":"Pelvis","armL":"ArmL","armR":"ArmR","forearmL":"ForearmL","forearmR":"ForearmR","handL":"HandL","handR":"HandR","legL":"LegL","legR":"LegR","footL":"ShoeL","footR":"ShoeR"}.get(region,"Torso")
	if not bodies.has(name): name="Arm"+name.right(1) if name.begins_with("Forearm") else "Torso"
	var heavy:=weapon in ["rpg","stinger","tv","grenade","tank","autocannon","missile","runover"]
	var impulse:=direction.normalized()*(8.0 if heavy else 3.5)
	# Share most of the impulse with the trunk; a small bounded local impulse
	# moves the struck segment without tearing joints apart or launching limbs.
	var torso: RigidBody3D=bodies.get("Torso")
	if not is_instance_valid(torso): return
	if name=="Torso": torso.apply_central_impulse(impulse)
	else:
		torso.apply_central_impulse(impulse*.70)
		var part: RigidBody3D=bodies.get(name)
		if is_instance_valid(part): part.apply_central_impulse(impulse*.30)

static func original_material(mesh: MeshInstance3D) -> Material:
	# Thermal is a temporary local rendering pass, never a corpse's skin.
	if mesh.has_meta("thermal_source"): return mesh.get_meta("thermal_source").get("material") as Material
	return mesh.material_override if mesh.material_override else mesh.get_active_material(0)

static func _clearance(parent: Node3D, definitions: Dictionary) -> Vector3:
	# Animated arms can extend beyond the living movement capsule and into
	# scenery. Move the whole initial pose together before enabling joints,
	# rather than allowing the solver to eject individual limbs from a wall.
	var queries: Array[PhysicsShapeQueryParameters3D]=[]
	for definition in definitions.values():
		var original: MeshInstance3D=definition[0]
		var box:=BoxShape3D.new()
		box.size=original.mesh.get_aabb().size*original.global_basis.get_scale().abs()*.96
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=box
		query.collision_mask=1
		query.transform=Transform3D(original.global_basis.orthonormalized(),original.global_transform*original.mesh.get_aabb().get_center())
		queries.append(query)
	var offsets: Array[Vector3]=[Vector3(0,.08,0),Vector3(0,.2,0)]
	for radius in [.35,.7,1.05]:
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]: offsets.append(direction*radius+Vector3.UP*.2)
	offsets.append(Vector3.UP*.8)
	var space:=parent.get_world_3d().direct_space_state
	for offset in offsets:
		var clear:=true
		for query in queries:
			var moved:=query.transform
			moved.origin+=offset
			var base:=query.transform
			query.transform=moved
			var overlap:=space.intersect_shape(query,1)
			query.transform=base
			if not overlap.is_empty(): clear=false;break
		if clear: return offset
	return Vector3.UP*.2
