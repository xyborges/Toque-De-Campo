extends RefCounted
class_name WarFavelaUniform
## Policiais: equipamento grafite/preto. Adversarios: roupas casuais
## vermelhas e escuras, variantes estaveis pelo ID de rede.
## Usa os ossos existentes; nao muda hitbox, IK nem proporcoes anatomicas.
const REDS := ["922f36","a34142","87313a","7d2836","ad4c42","983944"]
const DARKS := ["202429","303138","38373a","29292d","454144","24292e"]
const POLICE := ["20262b","262b32","292c31","1e2328"]

static func variant(actor: GamePlayer) -> int:
	return posmod(int(actor.peer_id),6)

static func outfit(actor: GamePlayer,team: int) -> Material:
	var tone: String=POLICE[posmod(variant(actor),POLICE.size())] if team==0 else REDS[variant(actor)]
	return EnvironmentKit.material("fabric:"+tone)

static func trousers(actor: GamePlayer,team: int) -> Material:
	var tone: String="24282b" if team==0 else DARKS[variant(actor)]
	return EnvironmentKit.material("fabric:"+tone)

static func apply(actor: GamePlayer,team: int,role: String) -> void:
	var shirt:=outfit(actor,team)
	var pants:=trousers(actor,team)
	var gear:=EnvironmentKit.material("fabric:161b20" if team==0 else "fabric:29272a")
	var vest:=EnvironmentKit.material("fabric:333b43" if team==0 else "fabric:5a3030")
	actor.avatar_parts.torso.material_override=shirt
	(actor.body_root.get_node("Pelvis") as MeshInstance3D).material_override=pants
	for key in ["arm_l","arm_r","leg_l","leg_r"]:
		var part: Node3D=actor.avatar_parts[key]
		var material: Material=shirt if key.begins_with("arm") else pants
		(part.get_node(str(part.name)+"Mesh") as MeshInstance3D).material_override=material
		var side: String="L" if key.ends_with("_l") else "R"
		var endpoint: String=("Forearm"+side+"Mesh") if key.begins_with("arm") else ("Knee"+side+"/Shin"+side)
		var node:=part.get_node_or_null(endpoint) as MeshInstance3D
		if node:node.material_override=material
	var torso: MeshInstance3D=actor.avatar_parts.torso
	var head: MeshInstance3D=actor.avatar_parts.head
	if team==0:
		WarUniform.box(torso,"PoliceFrontVest",Vector3(0,.025,-.19),Vector3(.47,.55,.10),vest)
		WarUniform.box(torso,"PoliceBackVest",Vector3(0,.02,.20),Vector3(.45,.52,.09),vest)
		for x in [-.17,0.0,.17]:
			WarUniform.box(torso,"PoliceMagazine",Vector3(x,-.17,-.265),Vector3(.12,.18,.07),gear)
		WarUniform.box(head,"PoliceHelmet",Vector3(0,.24,0),Vector3(.39,.16,.36),gear)
		WarUniform.box(head,"PoliceVisor",Vector3(0,.12,-.23),Vector3(.32,.14,.035),
			EnvironmentKit.material("steel:232c34"))
		WarUniform.box(torso,"PoliceRadio",Vector3(.29,.14,.07),Vector3(.09,.18,.12),gear)
		if role=="medic":
			WarUniform.box(torso,"MedicKit",Vector3(-.32,-.15,.16),Vector3(.20,.26,.20),vest)
		elif role=="marksman":
			WarUniform.box(torso,"ReconBag",Vector3(0,.02,.31),Vector3(.36,.42,.16),vest)
		else:
			WarUniform.box(torso,"AssaultBag",Vector3(0,.02,.30),Vector3(.31,.36,.15),gear)
	else:
		# Camiseta/jaqueta casual: nada de mangas extras que flutuem ao animar.
		var cap:=EnvironmentKit.material("fabric:"+DARKS[variant(actor)])
		if variant(actor)%2==0:
			WarUniform.box(head,"CasualBoné",Vector3(0,.27,0),Vector3(.34,.09,.34),cap)
			WarUniform.box(head,"AbaBoné",Vector3(0,.24,-.21),Vector3(.29,.045,.18),cap)
		if variant(actor)%3==0:
			WarUniform.box(torso,"JaquetaAberta",Vector3(0,.05,.22),Vector3(.41,.44,.09),cap)
		for x in [-.18,.18]:
			WarUniform.box(torso,"AlçaMochila",Vector3(x,.16,-.09),Vector3(.045,.34,.25),gear)
		WarUniform.box(torso,"Mochila",Vector3(0,.03,.30),Vector3(.34,.38,.14),cap)
		if role=="antitank":
			WarUniform.box(torso,"BolsaRPG",Vector3(-.31,-.14,.13),Vector3(.23,.30,.19),gear)
		elif role=="medic":
			WarUniform.box(torso,"BolsaMedico",Vector3(.31,-.13,.08),Vector3(.21,.26,.17),gear)
	actor.set_meta("war_team",team)
	actor.set_meta("war_class",role)
	actor.set_meta("favela_uniform_variant",variant(actor))
	WarRenderBatch.uniform(actor,team,role+"-favela-"+str(variant(actor)))
	actor.infantry_protection.refresh_visuals(actor)
	refresh_materials(actor,team)

static func refresh_materials(actor: GamePlayer,team: int) -> void:
	# Preserva a personalizacao de pele e recolore somente os tecidos.
	actor.apply_body_colors(actor.get_meta("body_colors",GameCharacterColors.DEFAULTS))
	var shirt:=outfit(actor,team)
	var pants:=trousers(actor,team)
	actor.avatar_parts.torso.material_override=shirt
	(actor.body_root.get_node("Pelvis") as MeshInstance3D).material_override=pants
	for key in ["arm_l","arm_r","leg_l","leg_r"]:
		var part: Node3D=actor.avatar_parts[key]
		var material: Material=shirt if key.begins_with("arm") else pants
		(part.get_node(str(part.name)+"Mesh") as MeshInstance3D).material_override=material
		var side: String="L" if key.ends_with("_l") else "R"
		var endpoint: String=("Forearm"+side+"Mesh") if key.begins_with("arm") else ("Knee"+side+"/Shin"+side)
		var node:=part.get_node_or_null(endpoint) as MeshInstance3D
		if node:node.material_override=material
