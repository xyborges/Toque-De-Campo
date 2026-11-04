extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: errors.append(label)
func populate(views: BRLootVisuals,records: Array) -> void:
	views.update_visible(records,Vector3.ZERO)
	for tick in 180: views._process(0.0)
func run() -> void:
	var scene:=Node3D.new()
	root.add_child(scene)
	var views:=BRLootVisuals.new()
	views.set_meta("test_visuals",true)
	scene.add_child(views)
	views.set_process(false)
	views.prepare()
	verify(views.models.has("fal") and views.models.has("glock"),"loot model cache initializes")
	var near: Array=[]
	var far: Array=[]
	for i in 140:
		near.append({"id":i+100,"kind":"heal","position":Vector3(float(i%10)*.15,0,float(i/10)*.15)})
		far.append({"id":i+500,"kind":"heal","position":Vector3(10.+float(i%10)*.2,0,float(i/10)*.2)})
	views.update_visible(near,Vector3.ZERO)
	views._process(0.)
	verify(views.active.size()<=BRLootVisuals.CREATIONS_PER_FRAME,"instantiation respects per-frame budget")
	for tick in 180: views._process(0.)
	verify(views.active.size()==near.size(),"all items within pickup range remain visible")
	verify(views.pending.is_empty(),"near loot eventually finishes incremental creation")
	views.update_visible(far,Vector3.ZERO)
	for tick in 180: views._process(0.)
	verify(views.active.size()==BRLootVisuals.LIMIT,"loot beyond pickup range follows fixed visual budget")
	verify(views.pending.is_empty(),"distant loot eventually finishes incremental creation")
	var corpse: Array=[{"id":9999,"kind":"container","corpse_key":"round:1:victim:7","position":Vector3.ZERO,"contents":[]}]
	views.update_visible(corpse,Vector3.ZERO)
	views._process(0.)
	verify(views.active.is_empty() and views.pending.is_empty(),"corpse loot never spawns duplicate proxy")
	views.update_visible([],Vector3.ZERO)
	views.clear()
	views._process(0.)
	verify(views.active.is_empty() and views.pending.is_empty(),"leaving match clears both active and queued loot")
	scene.queue_free()
	await process_frame
	print("BR_VISUAL_BUDGET_QA ",JSON.stringify({"checks":checks,"failures":errors,"scope":"visible near loot exception versus distant fixed cap; no FPS claim"}))
	quit(0 if errors.is_empty() else 1)
