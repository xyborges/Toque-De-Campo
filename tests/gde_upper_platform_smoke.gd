extends SceneTree
## Standalone GDExtension QA: runs in minimal project Windows/Linux,
## independent from WarGame scenes, textures or imported resources.
var checks:=0
var failures: Array[String]=[]
var worst:=0.0

func verify(ok: bool,context: String) -> void:
	checks+=1
	if not ok:failures.append(context)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("UPPER_PLATFORM_SMOKE ",JSON.stringify({"error":"missing native class"}))
		quit(2);return
	var native: Object=ClassDB.instantiate("WarNativePoseMath")
	if not native.has_method("apply_upper_direct"):
		print("UPPER_PLATFORM_SMOKE ",JSON.stringify({"error":"missing upper scene method"}))
		quit(2);return
	var parent:=Node3D.new()
	root.add_child(parent)
	var parts: Dictionary={}
	for key in ["torso","head","arm_l","arm_r","leg_l","leg_r"]:
		var node:=Node3D.new()
		node.name=key
		parent.add_child(node)
		parts[key]=node
	var pelvis:=Node3D.new()
	parent.add_child(pelvis)
	var rest: Dictionary={
		"torso":Vector3(0,1.13,0),
		"head":Vector3(0,1.70,0),
		"left":Vector3(-.24,1.32,0),
		"right":Vector3(.24,1.32,0),
		"pelvis":Vector3(0,.85,0),
		"leg_l":Vector3(-.20,.42,0),
		"leg_r":Vector3(.20,.42,0)
	}
	for pitch in [-1.,0.,.7]:
		for lean in [-.8,0.,.8]:
			var ok: bool=native.apply_upper_direct(parts,pelvis,rest,pitch,lean,1.1,.9,true)
			verify(ok,"direct returned false")
			if not ok:continue
			var upper: Transform3D=native.upper_transform(pitch,lean)
			var offset:=Vector3(lean*.04,0,0)
			var torso:=parts.torso as Node3D
			var head:=parts.head as Node3D
			var neck:=Vector3(0,rest.head.y-.21,0)
			var head_basis:=Basis(Vector3.RIGHT,clampf(pitch*.92,-1.12,1.12))*Basis(Vector3.BACK,-lean*.18)
			for t in [
				[pelvis.position,rest.pelvis+offset],
				[parts.leg_l.position,rest.leg_l+offset],
				[parts.leg_r.position,rest.leg_r+offset],
				[torso.position,upper*Vector3(rest.torso)],
				[head.position,upper*neck+head_basis*(Vector3(rest.head)-neck)],
				[parts.arm_l.position,upper*Vector3(-(.325*1.1+.025),1.32,0)],
				[parts.arm_r.position,upper*Vector3(.325*1.1+.025,1.32,0)]
			]:
				var error: float=Vector3(t[0]).distance_to(Vector3(t[1]))
				worst=maxf(error,worst)
				verify(error<.00001,"position difference %.9f"%error)
	print("UPPER_PLATFORM_SMOKE ",JSON.stringify({"platform":OS.get_name(),
		"checks":checks,"failures":failures,"max_error":worst}))
	parent.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
