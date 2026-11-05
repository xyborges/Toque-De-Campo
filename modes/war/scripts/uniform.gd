extends RefCounted
class_name WarUniform
static var cloth: Dictionary = {}
static var equipment: Dictionary = {}

static func material(team: int) -> StandardMaterial3D:
	if cloth.has(team): return cloth[team]
	var value := StandardMaterial3D.new()
	value.albedo_texture = load("res://assets/war/%s-camo.png" % ("ukraine" if team==0 else "russia"))
	value.normal_enabled = true
	value.normal_texture = load("res://assets/environment/materials/fabric-normal.png")
	value.normal_scale = .25
	value.roughness = .94
	value.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	value.uv1_triplanar = true
	value.uv1_scale = Vector3.ONE*1.8
	cloth[team] = value
	return value

static func gear(team: int) -> StandardMaterial3D:
	if not equipment.has(team):
		var mat := EnvironmentKit.material("fabric").duplicate() as StandardMaterial3D
		mat.albedo_color = Color("7f7759") if team==0 else Color("485b3d")
		equipment[team] = mat
	return equipment[team]

static func box(parent: Node3D,label: String,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = WarBodyMesh.cushion(size)
	node.material_override = mat
	node.position = pos
	node.visibility_range_end = 110
	parent.add_child(node)
	node.set_meta("uniform_attachment",true)
	if label in ["FrontPlateCarrier","RearPlateCarrier","MagazinePouch","PouchFlap","MolleWebbing","ShoulderStrap"]:node.set_meta("protection_slot","vest")
	if label in ["ChinStrap","HelmetRail","NVGMount","HelmetScrim"]:node.set_meta("protection_slot","helmet")
	return node

static func apply(actor: GamePlayer,team: int,role: String) -> void:
	team = clampi(team,0,1)
	if not actor.get_meta("human_war_mesh",false): WarBodyMesh.apply(actor)
	for part: Node3D in actor.avatar_parts.values():
		for child in part.get_children():
			if child.has_meta("uniform_attachment"):
				part.remove_child(child)
				child.queue_free()
		for knee: Node3D in part.find_children("Knee?","Node3D",false,false):
			for child in knee.get_children():
				if child.has_meta("uniform_attachment"): knee.remove_child(child);child.queue_free()
	if WarRules.CURRENT_OPERATION==WarOperation.FAVELA:
		WarFavelaUniform.apply(actor,team,role)
		return
	if team==1 and WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
		WarAfghanUniform.apply(actor,role)
		return
	var fabric := material(team)
	var harness := gear(team)
	var torso: MeshInstance3D = actor.avatar_parts.torso
	torso.material_override = fabric
	actor.body_root.get_node("Pelvis").material_override = fabric
	for key in ["arm_l","arm_r","leg_l","leg_r"]:
		var part: Node3D = actor.avatar_parts[key]
		var mesh := part.get_node(str(part.name)+"Mesh") as MeshInstance3D
		mesh.material_override = fabric
		if key.begins_with("arm"):
			var lower:=part.get_node_or_null("Forearm"+("L" if key=="arm_l" else "R")+"Mesh") as MeshInstance3D
			if lower: lower.material_override=fabric
		else:
			var shin:=part.get_node_or_null("Knee"+("L" if key=="leg_l" else "R")+"/Shin"+("L" if key=="leg_l" else "R")) as MeshInstance3D
			if shin: shin.material_override=fabric
		if key.begins_with("arm"):
			box(part,"ShoulderSeam",Vector3(0,-.12,0),Vector3(.235,.15,.25),fabric)
			box(part,"ElbowReinforcement",Vector3(0,-.32,.07),Vector3(.17,.13,.035),harness)
		else:
			var knee:=part.get_node_or_null("Knee"+("L" if key=="leg_l" else "R")) as Node3D
			box(knee if knee else part,"KneePad",Vector3(0,0,-.12) if knee else Vector3(0,-.42,-.12),Vector3(.19,.20,.055),harness)
	box(torso,"FrontPlateCarrier",Vector3(0,.04,-.18),Vector3(.47,.51,.10),harness)
	box(torso,"RearPlateCarrier",Vector3(0,.04,.17),Vector3(.46,.50,.09),harness)
	for x in [-.155,.0,.155]:
		box(torso,"MagazinePouch",Vector3(x,-.04,-.265),Vector3(.13,.22,.09),harness)
		box(torso,"PouchFlap",Vector3(x,.075,-.275),Vector3(.14,.04,.09),harness)
		for y in [-.10,.04,.17]: box(torso,"MolleWebbing",Vector3(x,y,.224),Vector3(.13,.018,.012),harness)
	for x in [-.19,.19]: box(torso,"ShoulderStrap",Vector3(x,.27,0),Vector3(.075,.075,.39),harness)
	box(torso,"WebBelt",Vector3(0,-.29,0),Vector3(.49,.065,.36),harness)
	var head: MeshInstance3D = actor.avatar_parts.head
	var helmet := MeshInstance3D.new()
	helmet.name = "CombatHelmet"
	helmet.mesh=WarBodyMesh.loft("military-helmet",[[.07,.175,.17,.01],[.10,.185,.18,.01],[.17,.173,.17,.012],[.23,.135,.13,.015],[.28,.065,.065,.015],[.29,0,0,.015]],24,1)
	helmet.material_override = fabric
	helmet.set_meta("uniform_attachment",true)
	helmet.set_meta("protection_slot","helmet")
	head.add_child(helmet)
	var rim:=MeshInstance3D.new()
	rim.mesh=WarBodyMesh.loft("helmet-rim",[[.065,.178,.174,.01],[.075,.19,.183,.01],[.088,.185,.177,.01]],24,1)
	rim.material_override=harness;rim.set_meta("uniform_attachment",true);head.add_child(rim)
	rim.set_meta("protection_slot","helmet")
	for side in [-1,1]:
		box(head,"ChinStrap",Vector3(side*.146,-.08,-.01),Vector3(.015,.25,.025),harness)
		box(head,"HelmetRail",Vector3(side*.18,.10,.02),Vector3(.025,.045,.17),EnvironmentKit.material("steel:3f453c"))
		box(actor.avatar_parts.arm_l if side<0 else actor.avatar_parts.arm_r,"TeamBand",Vector3(0,-.22,0),Vector3(.21,.085,.22),EnvironmentKit.material("fabric:5986a1" if team==0 else "fabric:b8b4a6"))
	box(head,"NVGMount",Vector3(0,.15,-.175),Vector3(.06,.075,.025),EnvironmentKit.material("steel:3c4039"))
	if role=="medic":
		box(torso,"MedicalBackpack",Vector3(0,.0,.29),Vector3(.40,.53,.22),harness)
		var patch := box(torso,"MedicalPatch",Vector3(0,.02,.41),Vector3(.19,.19,.015),EnvironmentKit.material("fabric:386c50"))
		box(patch,"MedicalHorizontal",Vector3(0,0,.012),Vector3(.15,.045,.015),EnvironmentKit.material("plaster:e2e7db"))
		box(patch,"MedicalVertical",Vector3(0,0,.014),Vector3(.045,.15,.015),EnvironmentKit.material("plaster:e2e7db"))
		var front_patch := box(torso,"FrontMedicalPatch",Vector3(-.19,.23,-.32),Vector3(.12,.12,.02),EnvironmentKit.material("fabric:386c50"))
		box(front_patch,"MedicalMark",Vector3(0,0,-.02),Vector3(.025,.08,.01),EnvironmentKit.material("plaster:e2e7db"))
		box(front_patch,"MedicalMark",Vector3(0,0,-.02),Vector3(.08,.025,.01),EnvironmentKit.material("plaster:e2e7db"))
		for x in [-.33,.33]: box(torso,"TraumaPouch",Vector3(x,-.22,.0),Vector3(.17,.23,.24),harness)
	elif role=="antitank":
		box(torso,"AmmunitionPack",Vector3(0,.0,.30),Vector3(.42,.52,.22),harness)
		for x in [-.16,.16]:
			var tube := MeshInstance3D.new()
			var shape := CylinderMesh.new()
			shape.top_radius = .05
			shape.bottom_radius = .05
			shape.height = .65
			shape.radial_segments = 10
			tube.mesh = shape
			tube.material_override = harness
			tube.position = Vector3(x,.08,.37)
			tube.set_meta("uniform_attachment",true)
			torso.add_child(tube)
	elif role=="marksman":
		box(torso,"ReconPack",Vector3(0,.05,.27),Vector3(.36,.40,.16),harness)
		for x in [-.22,.22]:
			box(torso,"ReconPouch",Vector3(x,-.24,-.32),Vector3(.14,.14,.08),harness)
		for x in [-.12,.12]: box(head,"HelmetScrim",Vector3(x,.22,.02),Vector3(.10,.07,.22),fabric)
	else:
		box(torso,"AssaultPack",Vector3(0,.02,.28),Vector3(.38,.46,.18),harness)
		box(torso,"Radio",Vector3(.32,.2,.08),Vector3(.12,.22,.09),EnvironmentKit.material("steel:39433c"))
	for x in [-.16,.16]:
		box(torso,"PackRetention",Vector3(x,.0,.39),Vector3(.018,.39,.02),harness)
	box(torso,"PackTopFlap",Vector3(0,.255,.29),Vector3(.36,.065,.22),harness)
	actor.set_meta("war_team",team)
	actor.set_meta("war_class",role)
	WarRenderBatch.uniform(actor,team,role)
	actor.infantry_protection.refresh_visuals(actor)

	actor.apply_body_colors(actor.get_meta("body_colors",GameCharacterColors.DEFAULTS))

static func refresh_materials(actor: GamePlayer,team: int) -> void:
	if WarRules.CURRENT_OPERATION==WarOperation.FAVELA:
		WarFavelaUniform.refresh_materials(actor,team)
		return
	if team==1 and WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
		WarAfghanUniform.refresh_materials(actor)
		return
	var fabric:=material(clampi(team,0,1))
	actor.avatar_parts.torso.material_override=fabric
	actor.body_root.get_node("Pelvis").material_override=fabric
	for key in ["arm_l","arm_r","leg_l","leg_r"]:
		var part: Node3D=actor.avatar_parts[key]
		(part.get_node(str(part.name)+"Mesh") as MeshInstance3D).material_override=fabric
		if key.begins_with("arm"):
			var lower:=part.get_node_or_null("Forearm"+("L" if key=="arm_l" else "R")+"Mesh") as MeshInstance3D
			if lower: lower.material_override=fabric
		else:
			var side: String="L" if key=="leg_l" else "R"
			var shin:=part.get_node_or_null("Knee"+side+"/Shin"+side) as MeshInstance3D
			if shin: shin.material_override=fabric

	actor.apply_body_colors(actor.get_meta("body_colors",GameCharacterColors.DEFAULTS))
