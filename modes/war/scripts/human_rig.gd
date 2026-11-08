extends RefCounted
class_name WarHumanRig
const UPPER:=.37
const LOWER:=.35
static var gloves: Dictionary={}
# R01 A/B pilot: keep the original path unless explicitly enabled.
static var r01_fast_ik_lookup: bool=OS.get_environment("TDC_R01_IK_NODE_CACHE")=="1"

static func grip_glove(support: bool,pistol:=false) -> Mesh:
	var key: String="grip:%s:%s"%[support,pistol]
	if gloves.has(key): return gloves[key]
	var parts:=Node3D.new()
	if support and not pistol:
		# Palm under the handguard; curled fingers rise around its sides.
		WarArtStyle.mesh(parts,"Palm",WarBodyMesh.cushion(Vector3(.083,.040,.092)),"rubber",Vector3(0,-.004,0))
		for i in 4:
			var z: float=-.033+i*.022
			WarArtStyle.mesh(parts,"Finger",WarBodyMesh.cushion(Vector3(.020,.065,.018)),"rubber",Vector3(.037,.016,z),Basis(Vector3.FORWARD,.24))
			WarArtStyle.mesh(parts,"Tip",WarBodyMesh.cushion(Vector3(.027,.020,.017)),"rubber",Vector3(.025,.047,z))
		WarArtStyle.mesh(parts,"Thumb",WarBodyMesh.cushion(Vector3(.024,.069,.026)),"rubber",Vector3(-.037,.020,.020),Basis(Vector3.RIGHT,.42))
		WarArtStyle.mesh(parts,"Cuff",WarBodyMesh.cushion(Vector3(.066,.052,.065)),"rubber",Vector3(-.035,-.029,.055),Basis(Vector3.UP,-.40))
	else:
		var flip: float=-1. if support else 1.
		WarArtStyle.mesh(parts,"Palm",WarBodyMesh.cushion(Vector3(.037,.085,.074)),"rubber",Vector3(flip*.026,-.014,.016))
		for i in 4:
			var y: float=.014-i*.020
			WarArtStyle.mesh(parts,"Finger",WarBodyMesh.cushion(Vector3(.068,.017,.023)),"rubber",Vector3(0,y,-.030))
			WarArtStyle.mesh(parts,"Tip",WarBodyMesh.cushion(Vector3(.018,.017,.040)),"rubber",Vector3(-flip*.030,y,-.009))
		WarArtStyle.mesh(parts,"Thumb",WarBodyMesh.cushion(Vector3(.022,.071,.024)),"rubber",Vector3(-flip*.025,.018,.020),Basis(Vector3.FORWARD,flip*-.50))
		WarArtStyle.mesh(parts,"Cuff",WarBodyMesh.cushion(Vector3(.065,.056,.065)),"rubber",Vector3(flip*.023,-.025,.066))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: MeshInstance3D in parts.get_children(): st.append_from(part.mesh,0,part.transform)
	st.index();gloves[key]=st.commit();parts.free();return gloves[key]

static func glove(side: int) -> Mesh:
	if gloves.has(side): return gloves[side]
	var parts:=Node3D.new()
	WarArtStyle.mesh(parts,"Palm",WarBodyMesh.cushion(Vector3(.091,.107,.052)),"rubber")
	WarArtStyle.mesh(parts,"KnuckleGuard",WarBodyMesh.cushion(Vector3(.087,.037,.018)),"rubber",Vector3(0,-.025,.027))
	# Four distinct bent fingers, with a recessed space between each finger.
	for i in 4:
		var x: float=(i-1.5)*.021
		WarArtStyle.mesh(parts,"Finger",WarBodyMesh.cushion(Vector3(.018,.048,.025)),"rubber",Vector3(x,-.064,.005),Basis(Vector3.RIGHT,-.48))
		WarArtStyle.mesh(parts,"Fingertip",WarBodyMesh.cushion(Vector3(.017,.029,.024)),"rubber",Vector3(x,-.084,-.020),Basis(Vector3.RIGHT,-1.1))
	WarArtStyle.mesh(parts,"Thumb",WarBodyMesh.cushion(Vector3(.026,.068,.027)),"rubber",Vector3(side*.050,-.019,-.018),Basis(Vector3.FORWARD,side*-.55))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: MeshInstance3D in parts.get_children(): st.append_from(part.mesh,0,part.transform)
	st.index();gloves[side]=st.commit();parts.free();return gloves[side]

static func build(actor: GamePlayer) -> void:
	for side in ["L","R"]:
		var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
		var upper:=arm.get_node("Arm"+side+"Mesh") as MeshInstance3D
		upper.mesh=WarBodyMesh.loft("upper-arm-closed-2026",[[-UPPER*.5,.065,.073,0],[-.12,.077,.082,0],[.02,.09,.098,0],[.12,.107,.108,0],[.17,.103,.110,0],[.225,.066,.070,0],[.26,0,0,0]],16,.95)
		upper.position=Vector3(0,-UPPER*.5,0)
		var lower:=arm.get_node_or_null("Forearm"+side+"Mesh") as MeshInstance3D
		if lower==null:
			lower=MeshInstance3D.new();lower.name="Forearm"+side+"Mesh";arm.add_child(lower)
		lower.mesh=WarBodyMesh.loft("forearm-188",[[-LOWER*.5,.049,.052,0],[-.11,.055,.060,0],[.02,.073,.075,0],[.12,.075,.080,0],[LOWER*.5,.060,.067,0]],16,.96)
		lower.position=Vector3(0,-UPPER-LOWER*.5,0)
		lower.material_override=upper.material_override
		var hand:=arm.get_node("Hand"+side) as MeshInstance3D
		hand.mesh=glove(-1 if side=="L" else 1);hand.material_override=WarArtStyle.material("rubber")
		hand.position=Vector3(0,-UPPER-LOWER-.053,0)
		if r01_fast_ik_lookup:
			# Arm nodes belong to this pivot; the cache dies with it and is
			# rebuilt alongside the geometry on each avatar reconstruction.
			arm.set_meta("r01_ik_nodes",[lower,hand,upper])
		# Keep named hit regions attached to the physical segment they depict.
		var forearm: Area3D=actor.hit_regions["forearm"+side]
		if forearm.get_parent()!=lower: forearm.reparent(lower,false)
		WarBodyMesh._update_region(actor,"arm"+side,Vector3(.20,UPPER,.21))
		WarBodyMesh._update_region(actor,"forearm"+side,Vector3(.16,LOWER,.17))
		WarBodyMesh._update_region(actor,"hand"+side,Vector3(.13,.16,.09),Vector3(0,-.02,0))
	actor.set_meta("articulated_arms",true)

static func pose(actor: GamePlayer,arm: Node3D,target: Vector3,group: String,held_object: Node3D=null) -> void:
	var side: String=group.right(1)
	var cached: Array=arm.get_meta("r01_ik_nodes",[]) if r01_fast_ik_lookup else []
	var cache_valid: bool=cached.size()==3 and is_instance_valid(cached[0]) and is_instance_valid(cached[1]) and is_instance_valid(cached[2])
	var lower: MeshInstance3D=cached[0] if cache_valid else arm.get_node_or_null("Forearm"+side+"Mesh") as MeshInstance3D
	if lower==null: return
	var hand: MeshInstance3D=cached[1] if cache_valid else arm.get_node("Hand"+side) as MeshInstance3D
	var proportion:=clampf(float(actor.body_proportions.get("arms",1.)),.65,1.5)
	var shoulder: Vector3=arm.position
	var grip:=actor.body_root.to_local(target)
	var hand_basis: Basis=actor.body_root.global_basis.inverse()*actor.weapon_root.global_basis
	if is_instance_valid(held_object): hand_basis=actor.body_root.global_basis.inverse()*held_object.global_basis
	var firearm: bool=not is_instance_valid(held_object) and GameWeapons.ITEMS[actor.weapon_id].kind=="firearm" and not actor._grenade_active()
	if firearm and GameWeapons.canonical(actor.weapon_id) in ["fal","glock","g3"]:
		var model:=actor.weapon_root.get_node_or_null("Imported_"+GameWeapons.canonical(actor.weapon_id)) as Node3D
		if model: hand_basis=actor.body_root.global_basis.inverse()*model.global_basis
	elif firearm and GameWeapons.canonical(actor.weapon_id)=="ak":
		var model:=actor.weapon_root.get_node_or_null("Imported_ak") as Node3D
		if model:hand_basis=actor.body_root.global_basis.inverse()*GameAKReload.hand_basis(model)
	var grabbing: bool=side=="L" and actor.reload_weapon==actor.weapon_id and actor.reload_left>0
	if grabbing and GameWeapons.canonical(actor.weapon_id) in ["ak","fal","glock","sniper","g3"]:
		grabbing=bool(actor.reload_pose_state(GameWeapons.canonical(actor.weapon_id),actor.reload_left,actor.reload_total).hand_grabbing)
	var previous: Dictionary=arm.get_meta("human_pose_cache",{})
	if not previous.is_empty() and bool(previous.grabbing)==grabbing and previous.weapon==actor.weapon_id and Vector3(previous.grip).distance_squared_to(grip)<.00000001 and Basis(previous.basis).is_equal_approx(hand_basis) and float(previous.proportion)==proportion and bool(previous.firearm)==firearm and arm.transform.is_equal_approx(previous.arm): return
	var hand_mesh:=grip_glove(side=="L",GameWeapons.canonical(actor.weapon_id)=="glock" or grabbing) if firearm else glove(-1 if side=="L" else 1)
	if hand.mesh!=hand_mesh: hand.mesh=hand_mesh
	var cuff:=Vector3(-.035,-.029,.075) if side=="L" and GameWeapons.canonical(actor.weapon_id)!="glock" and not grabbing else Vector3(.023,-.025,.085)
	var wrist:=grip+hand_basis*(cuff if firearm else Vector3(0,.067,0))
	var direction:=wrist-shoulder
	var distance:=direction.length()
	if distance<.01: return
	var a:=UPPER*proportion;var b:=LOWER*proportion
	# Small stretch is reserved for extreme saved proportions. Normal poses
	# retain constant upper/lower bone lengths and bend at the elbow.
	var stretch:=maxf(1.,distance/(a+b-.003));a*=stretch;b*=stretch
	var along:=direction/distance
	# The bend plane follows the chest and keeps the elbow outside the vest.
	# A down/back pole folded both elbows through the plate carrier.
	var pole:=GameInfantryPose.upper_transform(actor).basis*Vector3(-.75 if side=="L" else .75,-.70,-.25)
	var perpendicular: Vector3=(pole-along*pole.dot(along)).normalized()
	var projection:=clampf((a*a-b*b+distance*distance)/(2*distance),0,a)
	var elbow:=shoulder+along*projection+perpendicular*sqrt(maxf(0,a*a-projection*projection))
	arm.basis=Basis(Quaternion(Vector3.DOWN,(elbow-shoulder).normalized()))
	var upper: MeshInstance3D=cached[2] if cache_valid else arm.get_node("Arm"+side+"Mesh") as MeshInstance3D
	upper.position=Vector3(0,-a*.5,0);upper.scale=Vector3(proportion,a/UPPER,proportion)
	var inverse:=arm.transform.affine_inverse()
	var elbow_local:=inverse*elbow
	var wrist_local:=inverse*wrist
	lower.position=(elbow_local+wrist_local)*.5
	lower.basis=Basis(Quaternion(Vector3.DOWN,(wrist_local-elbow_local).normalized()))*Basis.from_scale(Vector3(proportion,b/LOWER,proportion))
	hand.transform=Transform3D(inverse.basis*hand_basis*Basis.from_scale(Vector3.ONE*proportion),inverse*grip)
	arm.set_meta("grip_error",actor.body_root.to_global(arm.transform*hand.position).distance_to(target))
	arm.set_meta("human_pose_cache",{"weapon":actor.weapon_id,"grip":grip,"basis":hand_basis,"proportion":proportion,"firearm":firearm,"grabbing":grabbing,"arm":arm.transform})
