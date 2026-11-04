extends RefCounted
class_name BRProtectionAppearance
const DIR:="res://modes/battle_royale/ui/equipment/"
static var fabrics: Dictionary={}
static func fabric(color: String) -> StandardMaterial3D:
	if fabrics.has(color):return fabrics[color]
	var material:=StandardMaterial3D.new();material.albedo_color=Color(color);material.roughness=.92
	fabrics[color]=material;return material
static func apply(actor: GamePlayer,vest: int,helmet: int,backpack:=0) -> void:
	var key:=Vector3i(clampi(vest,0,3),clampi(helmet,0,3),clampi(backpack,0,3))
	if actor.get_meta("br_protection_visual",Vector3i(-1,-1,-1))==key:return
	# Keep the War human rig, with plain clothes and no permanent military kit.
	var shirt:=fabric("998e72")
	var trousers:=fabric("4c5149")
	actor.avatar_parts.torso.material_override=shirt
	actor.body_root.get_node("Pelvis").material_override=trousers
	for side in ["L","R"]:
		var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
		(arm.get_node("Arm"+side+"Mesh") as MeshInstance3D).material_override=shirt
		(arm.get_node("Forearm"+side+"Mesh") as MeshInstance3D).material_override=shirt
		var leg: Node3D=actor.avatar_parts["leg_"+side.to_lower()]
		(leg.get_node("Leg"+side+"Mesh") as MeshInstance3D).material_override=trousers
		var shin:=leg.get_node_or_null("Knee"+side+"/Shin"+side) as MeshInstance3D
		if shin:shin.material_override=trousers
	for pair in [["vest",actor.avatar_parts.torso,key.x],["helmet",actor.avatar_parts.head,key.y],["pack",actor.avatar_parts.torso,key.z]]:
		var anchor: Node3D=pair[1];var previous:=anchor.get_node_or_null("BRProtection"+str(pair[0]))
		if previous:anchor.remove_child(previous);previous.queue_free()
		if int(pair[2])>0:
			var piece: Node3D=load(DIR+str(pair[0])+"_%d.tscn"%int(pair[2])).instantiate()
			piece.name="BRProtection"+str(pair[0]);anchor.add_child(piece)
	actor.apply_body_colors(actor.get_meta("body_colors",GameCharacterColors.DEFAULTS))
	actor.set_meta("br_protection_visual",key)

static func make(kind: String,level: int) -> Node3D:
	var root:=Node3D.new();root.name=kind+"_%d"%level;root.set_meta("equipment_kind",kind);root.set_meta("level",level)
	var cloth:=fabric(["8b8065","57634b","353f45"][level-1])
	var belt:=fabric("34372f")
	if kind=="vest":
		var width:=.42+.015*level;var height:=.43+.04*level
		_box(root,Vector3(0,.03,-.19),Vector3(width,height,.08+.015*level),cloth)
		_box(root,Vector3(0,.03,.18),Vector3(width,height,.085),cloth)
		for side in [-1,1]:
			_box(root,Vector3(side*.19,.27,0),Vector3(.065,.06,.38),belt)
			_box(root,Vector3(side*.24,-.09,0),Vector3(.06,.12,.33),cloth)
		if level>1:
			for x in [-.13,0.,.13]:_box(root,Vector3(x,-.04,-.26),Vector3(.10,.16,.05),cloth)
		if level==3:_box(root,Vector3(0,-.28,-.18),Vector3(.26,.18,.075),cloth)
	elif kind=="pack":
		var size:=Vector3(.33+.035*level,.32+.075*level,.15+.025*level)
		_box(root,Vector3(0,-.025,.27+size.z*.5),size,cloth)
		for side in [-1,1]:
			_box(root,Vector3(side*.155,.08,.1),Vector3(.045,.4,.035),belt)
			if level>1:_box(root,Vector3(side*(size.x*.5+.035),-.07,.34),Vector3(.075,.19,.13),cloth)
		_box(root,Vector3(0,-.09,.29+size.z),Vector3(size.x*.7,size.y*.45,.04),belt)
	else:
		var shell:=MeshInstance3D.new();shell.mesh=WarBodyMesh.loft("br-helmet-%d"%level,[[.07,.18,.175,.01],[.13,.19,.18,.012],[.22,.14,.14,.015],[.29,.035,.035,.015],[.30,0,0,.015]],20,1.)
		shell.material_override=cloth;root.add_child(shell)
		for side in [-1,1]:_box(root,Vector3(side*.145,-.025,.015),Vector3(.02,.21,.025),belt)
		if level>1:
			for side in [-1,1]:_box(root,Vector3(side*.172,.04,.015),Vector3(.035,.105,.11),cloth)
		if level==3:_box(root,Vector3(0,-.02,-.16),Vector3(.29,.16,.025),EnvironmentKit.material("steel:646d6b"))
	var pieces: Array[Node]=[]
	for child in root.get_children():
		if child is MeshInstance3D:pieces.append(child)
	WarRenderBatch.merge(root,"br-equipment-v2-%s-%d"%[kind,level],pieces)
	return root

static func _box(root: Node3D,p: Vector3,size: Vector3,material: Material) -> void:
	var mesh:=MeshInstance3D.new();mesh.mesh=WarBodyMesh.cushion(size);mesh.position=p;mesh.material_override=material;root.add_child(mesh)
