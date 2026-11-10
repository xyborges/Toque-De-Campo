extends RefCounted
class_name WarHumanRig
const UPPER:=.37
const LOWER:=.35
static var gloves: Dictionary={}
# QA/diagnostics: number of native crossings vs arms solved (opt-in only).
static var native_batch_calls:=0
static var native_solved_arms:=0
static var native_direct_arms:=0

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
		# Keep named hit regions attached to the physical segment they depict.
		var forearm: Area3D=actor.hit_regions["forearm"+side]
		if forearm.get_parent()!=lower: forearm.reparent(lower,false)
		WarBodyMesh._update_region(actor,"arm"+side,Vector3(.20,UPPER,.21))
		WarBodyMesh._update_region(actor,"forearm"+side,Vector3(.16,LOWER,.17))
		WarBodyMesh._update_region(actor,"hand"+side,Vector3(.13,.16,.09),Vector3(0,-.02,0))
	actor.set_meta("articulated_arms",true)

static func _prepare_arm(actor: GamePlayer,arm: Node3D,target: Vector3,group: String,held_object: Node3D=null) -> Dictionary:
	var side: String=group.right(1)
	var lower:=arm.get_node_or_null("Forearm"+side+"Mesh") as MeshInstance3D
	if lower==null: return {}
	var hand:=arm.get_node("Hand"+side) as MeshInstance3D
	var upper:=arm.get_node("Arm"+side+"Mesh") as MeshInstance3D
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
	if not previous.is_empty() and bool(previous.grabbing)==grabbing and previous.weapon==actor.weapon_id and Vector3(previous.grip).distance_squared_to(grip)<.00000001 and Basis(previous.basis).is_equal_approx(hand_basis) and float(previous.proportion)==proportion and bool(previous.firearm)==firearm and arm.transform.is_equal_approx(previous.arm): return {}
	var cuff:=Vector3(-.035,-.029,.075) if side=="L" and GameWeapons.canonical(actor.weapon_id)!="glock" and not grabbing else Vector3(.023,-.025,.085)
	var wrist:=grip+hand_basis*(cuff if firearm else Vector3(0,.067,0))
	if wrist.distance_to(shoulder)<.01:return {}
	return {"actor":actor,"arm":arm,"target":target,"side":side,"upper":upper,"lower":lower,"hand":hand,
		"proportion":proportion,"shoulder":shoulder,"grip":grip,"hand_basis":hand_basis,
		"upper_basis":GameInfantryPose.upper_transform(actor).basis,
		"cuff":cuff if firearm else Vector3(0,.067,0),
		"firearm":firearm,"grabbing":grabbing}

static func _solve_arm_gd(data: Dictionary) -> Array:
	# Original two-bone equation, kept as authoritative numerical reference.
	var shoulder: Vector3=data.shoulder
	var grip: Vector3=data.grip
	var hand_basis: Basis=data.hand_basis
	var proportion: float=data.proportion
	var wrist: Vector3=grip+hand_basis*Vector3(data.cuff)
	var direction:=wrist-shoulder
	var distance:=direction.length()
	if distance<.01:return []
	var a:=UPPER*proportion;var b:=LOWER*proportion
	var stretch:=maxf(1.,distance/(a+b-.003));a*=stretch;b*=stretch
	var along:=direction/distance
	var pole:=Basis(data.upper_basis)*Vector3(-.75 if data.side=="L" else .75,-.70,-.25)
	var perpendicular: Vector3=(pole-along*pole.dot(along)).normalized()
	var projection:=clampf((a*a-b*b+distance*distance)/(2*distance),0,a)
	var elbow:=shoulder+along*projection+perpendicular*sqrt(maxf(0,a*a-projection*projection))
	var arm:=Transform3D(Basis(Quaternion(Vector3.DOWN,(elbow-shoulder).normalized())),shoulder)
	var inverse:=arm.affine_inverse()
	var elbow_local:=inverse*elbow
	var wrist_local:=inverse*wrist
	var lower:=Transform3D(Basis(Quaternion(Vector3.DOWN,(wrist_local-elbow_local).normalized()))*Basis.from_scale(Vector3(proportion,b/LOWER,proportion)),(elbow_local+wrist_local)*.5)
	var upper:=Transform3D(Basis.from_scale(Vector3(proportion,a/UPPER,proportion)),Vector3(0,-a*.5,0))
	var hand:=Transform3D(inverse.basis*hand_basis*Basis.from_scale(Vector3.ONE*proportion),inverse*grip)
	return [arm,upper,lower,hand]

static func _native_arm_batch(data_list: Array[Dictionary]) -> Array:
	var native: Object=GameInfantryPose._native_math()
	if native==null:return []
	# Reuse dictionaries prepared by the existing visual rig: avoid seven
	# temporary packed-array allocations per actor per pose update.
	var results: Array=native.arm_batch_dicts(data_list)
	if results.size()==data_list.size():
		native_batch_calls+=1
		native_solved_arms+=data_list.size()
	return results

static func _finish_arm(data: Dictionary) -> void:
	# Gameplay-owned visual material, grip error and animation cache.
	var actor: GamePlayer=data.actor
	var arm: Node3D=data.arm
	var hand: MeshInstance3D=data.hand
	var side: String=data.side
	var proportion: float=data.proportion
	var firearm: bool=data.firearm
	var grabbing: bool=data.grabbing
	var hand_mesh:=grip_glove(side=="L",GameWeapons.canonical(actor.weapon_id)=="glock" or grabbing) if firearm else glove(-1 if side=="L" else 1)
	if hand.mesh!=hand_mesh:hand.mesh=hand_mesh
	var target: Vector3=data.target
	arm.set_meta("grip_error",actor.body_root.to_global(arm.transform*hand.position).distance_to(target))
	arm.set_meta("human_pose_cache",{"weapon":actor.weapon_id,"grip":data.grip,"basis":data.hand_basis,"proportion":proportion,"firearm":firearm,"grabbing":grabbing,"arm":arm.transform})

static func _apply_arm(data: Dictionary,solved: Array) -> void:
	if solved.size()!=4:return
	var arm: Node3D=data.arm
	var upper: MeshInstance3D=data.upper
	var lower: MeshInstance3D=data.lower
	var hand: MeshInstance3D=data.hand
	var arm_result: Transform3D=solved[0]
	var upper_result: Transform3D=solved[1]
	arm.basis=arm_result.basis
	upper.position=upper_result.origin
	upper.scale=upper_result.basis.get_scale()
	lower.transform=solved[2]
	hand.transform=solved[3]
	_finish_arm(data)

static func _native_apply_direct(data_list: Array[Dictionary]) -> bool:
	var native: Object=GameInfantryPose._native_math()
	if native==null:return false
	if native.apply_arms_direct(data_list)!=data_list.size():return false
	native_batch_calls+=1
	native_solved_arms+=data_list.size()
	native_direct_arms+=data_list.size()
	for data: Dictionary in data_list:_finish_arm(data)
	return true

static func pose(actor: GamePlayer,arm: Node3D,target: Vector3,group: String,held_object: Node3D=null) -> void:
	var data: Dictionary=_prepare_arm(actor,arm,target,group,held_object)
	if data.is_empty():return
	if GameInfantryPose.native_pose_enabled:
		var input: Array[Dictionary]=[data]
		if _native_apply_direct(input):return
	_apply_arm(data,_solve_arm_gd(data))

static func pose_pair(actor: GamePlayer,right_target: Vector3,left_target: Vector3) -> void:
	# Explicit, synchronous batching: one native call for BOTH arms of this
	# actor. Do not defer physical poses to the next frame or skip one arm.
	if not GameInfantryPose.native_pose_enabled:
		pose(actor,actor.avatar_parts.arm_r,right_target,"armR")
		pose(actor,actor.avatar_parts.arm_l,left_target,"armL")
		return
	var pending: Array[Dictionary]=[]
	for entry in [[actor.avatar_parts.arm_r,right_target,"armR"],[actor.avatar_parts.arm_l,left_target,"armL"]]:
		var data: Dictionary=_prepare_arm(actor,entry[0],entry[1],entry[2])
		if not data.is_empty():pending.append(data)
	if pending.is_empty():return
	if _native_apply_direct(pending):return
	for data: Dictionary in pending:_apply_arm(data,_solve_arm_gd(data))
