extends SceneTree
## Minimal native smoke test: can run without the full game on Windows or Linux.
func _initialize() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_POSE_PLATFORM_QA ",JSON.stringify({"ok":false,"reason":"native class not registered"}))
		quit(2)
		return
	var native: Object=ClassDB.instantiate("WarNativePoseMath")
	if native==null:
		print("GDE_POSE_PLATFORM_QA ",JSON.stringify({"ok":false,"reason":"failed to instantiate class"}))
		quit(2)
		return
	var torso: Transform3D=native.upper_transform(0.3,-0.2)
	var weapon: Transform3D=native.weapon_transform(0.3,-0.2,0.5,Transform3D.IDENTITY,Vector3(0.05,0.06,-0.3))
	var pitches:=PackedFloat32Array([0.3,-0.1])
	var leans:=PackedFloat32Array([-0.2,0.4])
	var batch: Array=native.upper_batch(pitches,leans)
	var ok:=batch.size()==2 and torso.origin.is_finite() and weapon.origin.is_finite()
	ok=ok and batch[0] is Transform3D and (batch[0] as Transform3D).origin.distance_to(torso.origin)<0.0002
	var arm_results: Array=native.arm_batch(PackedVector3Array([Vector3(.3,1.15,0),Vector3(-.3,1.15,0)]),PackedVector3Array([Vector3(.19,.9,-.45),Vector3(-.19,.9,-.45)]),[Basis.IDENTITY,Basis.IDENTITY],[Basis.IDENTITY,Basis.IDENTITY],PackedInt32Array([0,1]),PackedFloat32Array([1.,1.]),PackedVector3Array([Vector3(.023,-.025,.085),Vector3(-.035,-.029,.075)]))
	ok=ok and arm_results.size()==2
	for result: Array in arm_results:
		ok=ok and result.size()==4 and (result[2] as Transform3D).origin.is_finite()
	var inputs: Array[Dictionary]=[]
	var owned: Array[Node3D]=[]
	for side in ["R","L"]:
		var arm:=Node3D.new()
		var upper:=Node3D.new()
		var lower:=Node3D.new()
		var hand:=Node3D.new()
		owned.append_array([arm,upper,lower,hand])
		inputs.append({"arm":arm,"upper":upper,"lower":lower,"hand":hand,
			"shoulder":Vector3(.3,1.1,0) if side=="R" else Vector3(-.3,1.1,0),
			"grip":Vector3(.22,.9,-.4) if side=="R" else Vector3(-.22,.9,-.4),
			"hand_basis":Basis.IDENTITY,"upper_basis":Basis.IDENTITY,
			"side":side,"proportion":1.,"cuff":Vector3(.023,-.025,.085)})
	var direct_count: int=native.apply_arms_direct(inputs)
	ok=ok and direct_count==2
	for data: Dictionary in inputs:
		var hand: Node3D=data.hand
		ok=ok and hand.position.is_finite() and hand.position.length()>.001
	for node: Node3D in owned:node.free()
	print("GDE_POSE_PLATFORM_QA ",JSON.stringify({"ok":ok,"platform":OS.get_name(),"class_exists":true,"batch_count":batch.size(),"arm_batch_count":arm_results.size(),"direct_arm_writes":direct_count}))
	quit(0 if ok else 1)
