extends RefCounted
class_name WarAfghanUniform

# Deterministic appearance based on replicated actor identity.
const COLORS := ["85765a", "766a53", "6b725e", "9b8b6f", "686057", "8e8066"]
const PANTS := ["77715d", "656052", "686b56", "817762", "58594e", "736b5c"]
const WRAPS := ["c9b99a", "aa9f85", "5a554d", "d0c4ad", "777263", "918472"]

static func appearance_index(actor: GamePlayer) -> int:
	return posmod(int(actor.peer_id), COLORS.size())

static func fabric_for(actor: GamePlayer) -> Material:
	return EnvironmentKit.material("fabric:" + COLORS[appearance_index(actor)])

static func add_sleeve(arm: Node3D, fabric: Material) -> void:
	# Tapered cloth follows the articulated shoulder, unlike a bulky capsule.
	# No changes to IK, limb lengths or hitboxes; batcher merges this detail.
	var sleeve := MeshInstance3D.new()
	sleeve.name = "AfghanTaperedSleeve"
	sleeve.mesh = WarBodyMesh.loft("afghan-tapered-upper-sleeve-v2", [
		[-.172,.068,.075,0],[-.150,.083,.086,0],[-.090,.098,.105,0],
		[-.030,.106,.112,0],[.040,.113,.119,0],[.115,.118,.123,0],
		[.175,.104,.108,0],[.215,.071,.080,0],[.235,0,0,0]
	],12,.92)
	sleeve.position = Vector3(0,-WarHumanRig.UPPER*.5,0)
	sleeve.material_override = fabric
	sleeve.visibility_range_end = 110
	sleeve.set_meta("uniform_attachment",true)
	arm.add_child(sleeve)

static func apply(actor: GamePlayer, role: String) -> void:
	var variant := appearance_index(actor)
	var fabric := fabric_for(actor)
	var trousers := EnvironmentKit.material("fabric:" + PANTS[variant])
	var wrap := EnvironmentKit.material("fabric:" + WRAPS[variant])
	var leather := EnvironmentKit.material("fabric:574a37")
	var olive := EnvironmentKit.material("fabric:62654b")
	var torso: MeshInstance3D = actor.avatar_parts.torso
	var head: MeshInstance3D = actor.avatar_parts.head
	torso.material_override = fabric
	(actor.body_root.get_node("Pelvis") as MeshInstance3D).material_override = trousers
	for key in ["arm_l", "arm_r", "leg_l", "leg_r"]:
		var part: Node3D = actor.avatar_parts[key]
		var mat: Material = fabric if key.begins_with("arm") else trousers
		(part.get_node(str(part.name)+"Mesh") as MeshInstance3D).material_override = mat
		if key.begins_with("arm"):
			var side := "L" if key=="arm_l" else "R"
			var lower := part.get_node_or_null("Forearm"+side+"Mesh") as MeshInstance3D
			if lower: lower.material_override = mat
		else:
			var side := "L" if key=="leg_l" else "R"
			var shin := part.get_node_or_null("Knee"+side+"/Shin"+side) as MeshInstance3D
			if shin: shin.material_override = mat
	# Tunic hem, shawl and loose sleeves are parented to the existing animated rig.
	WarUniform.box(torso,"LongTunicHem",Vector3(0,-.32,0),Vector3(.51,.18,.36),fabric)
	for key in ["arm_l","arm_r"]:
		add_sleeve(actor.avatar_parts[key],fabric)
	if variant in [0,2,4]:
		var pakol := MeshInstance3D.new()
		pakol.name = "PakolWoolCap"
		pakol.mesh = WarBodyMesh.loft("afghan-pakol",[[.125,.15,.15,0],[.17,.19,.19,0],[.20,.19,.19,0],[.25,.145,.145,0],[.31,.10,.10,0],[.33,0,0,0]],18,1.0)
		pakol.material_override = wrap
		pakol.set_meta("uniform_attachment",true)
		head.add_child(pakol)
		var band := WarUniform.box(head,"PakolRolledBand",Vector3(0,.165,0),Vector3(.37,.065,.37),wrap)
		band.set_meta("protection_slot","")
	else:
		var turban := MeshInstance3D.new()
		turban.name = "ClothTurban"
		turban.mesh = WarBodyMesh.loft("afghan-turban",[[.105,.155,.16,0],[.17,.21,.20,0],[.24,.19,.19,0],[.31,.135,.14,0],[.36,0,0,0]],20,1.0)
		turban.material_override = wrap
		turban.set_meta("uniform_attachment",true)
		head.add_child(turban)
		WarUniform.box(head,"TurbanTail",Vector3(.12,-.045,.15),Vector3(.085,.37,.065),wrap)
	# Small layered fabric folds break up the silhouette without extra textures.
	if variant in [1,3,5]:
		for side in [-1.0,1.0]:
			WarUniform.box(head,"TurbanFold",Vector3(side*.115,.192,-.085),Vector3(.09,.064,.20),wrap)
	else:
		WarUniform.box(head,"PakolCrownFold",Vector3(0,.272,0),Vector3(.235,.055,.22),wrap)
	# Facial hair is geometry, not a painted expression.
	if variant != 1:
		var beard := MeshInstance3D.new()
		beard.name = "AfghanBeard"
		beard.mesh = WarBodyMesh.loft("afghan-beard", [[-.28,.055,.07,-.06],[-.22,.10,.105,-.045],[-.14,.13,.105,-.045],[-.08,.13,.07,-.045],[-.045,0,0,-.045]],14,1.0)
		beard.material_override = EnvironmentKit.material("fabric:302b26" if variant%2==0 else "fabric:504337")
		beard.set_meta("uniform_attachment",true)
		head.add_child(beard)
	# Mixed civilian/military field gear; no modern plate carrier or NVG helmet.
	if variant in [0,3,5]:
		WarUniform.box(torso,"WoolShawl",Vector3(-.23,.075,-.02),Vector3(.14,.58,.30),wrap)
	if variant in [1,2,4]:
		WarUniform.box(torso,"OpenWaistcoat",Vector3(0,.025,-.175),Vector3(.43,.49,.075),olive)
	for x in [-.16,.0,.16]:
		WarUniform.box(torso,"AmmunitionPouch",Vector3(x,-.13,-.255),Vector3(.125,.15,.085),leather)
	for x in [-.21,.21]:
		WarUniform.box(torso,"WornShoulderStrap",Vector3(x,.22,-.08),Vector3(.065,.065,.34),leather)
	WarUniform.box(torso,"ClothWaistSash",Vector3(0,-.245,0),Vector3(.49,.075,.36),wrap)
	if role=="medic":
		WarUniform.box(torso,"MedicSatchel",Vector3(-.30,-.18,.02),Vector3(.23,.29,.20),olive)
	elif role=="antitank":
		WarUniform.box(torso,"LauncherAmmunitionBag",Vector3(0,-.02,.26),Vector3(.37,.40,.17),leather)
	elif role=="marksman":
		WarUniform.box(torso,"ScoutFieldBag",Vector3(.29,-.14,.10),Vector3(.20,.30,.21),leather)
	else:
		WarUniform.box(torso,"FieldBackpack",Vector3(0,.01,.25),Vector3(.35,.37,.16),olive)
	actor.set_meta("war_team",1)
	actor.set_meta("war_class",role)
	actor.set_meta("afghan_uniform_variant",variant)
	WarRenderBatch.uniform(actor,1,role+"-afghan-"+str(variant))
	actor.infantry_protection.refresh_visuals(actor)
	refresh_materials(actor)

static func refresh_materials(actor: GamePlayer) -> void:
	# Skin colors remain customizable, but Afghan uniforms override shirt/pants.
	actor.apply_body_colors(actor.get_meta("body_colors",GameCharacterColors.DEFAULTS))
	var fabric := fabric_for(actor)
	var trousers := EnvironmentKit.material("fabric:" + PANTS[appearance_index(actor)])
	actor.avatar_parts.torso.material_override = fabric
	(actor.body_root.get_node("Pelvis") as MeshInstance3D).material_override = trousers
	for key in ["arm_l","arm_r","leg_l","leg_r"]:
		var part: Node3D = actor.avatar_parts[key]
		var mat: Material = fabric if key.begins_with("arm") else trousers
		(part.get_node(str(part.name)+"Mesh") as MeshInstance3D).material_override = mat
		var side := "L" if key.ends_with("_l") else "R"
		var path := ("Forearm"+side+"Mesh") if key.begins_with("arm") else ("Knee"+side+"/Shin"+side)
		var lower := part.get_node_or_null(path) as MeshInstance3D
		if lower: lower.material_override = mat
