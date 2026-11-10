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
	print("GDE_POSE_PLATFORM_QA ",JSON.stringify({"ok":ok,"platform":OS.get_name(),"class_exists":true,"batch_count":batch.size()}))
	quit(0 if ok else 1)
