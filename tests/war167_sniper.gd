extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures.append(text)
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	var data:=CombatRules.weapon("sniper")
	check(float(data.range)>=2000 and float(data.speed)>=500,"sniper ballistics cover the 2km War battlefield")
	check(float(data.gravity)>float(CombatRules.weapon("fal").gravity) and float(data.drag)>0,"gravity and progressive drag remain active")
	for distance_value in [300.,800.,1200.,1800.,2000.]:
		var lower:=0.;var upper:=deg_to_rad(3.4);var flight:=0.
		for iteration in 50:
			var angle: float=(lower+upper)*.5
			flight=-log(1-float(data.drag)*distance_value/(float(data.speed)*cos(angle)))/float(data.drag)
			var state:=GameBulletPhysics.advance(Vector3(0,1.7,0),Vector3(cos(angle),sin(angle),0)*float(data.speed),float(data.gravity),float(data.drag),flight)
			if Vector3(state.position).y>1.3: upper=angle
			else: lower=angle
		var angle: float=(lower+upper)*.5
		var target:=StaticBody3D.new();target.collision_layer=1
		var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.4,1,.8);collider.shape=box;target.add_child(collider);game.world_root.add_child(target);target.position=Vector3(distance_value,1.3,0)
		await physics_frame;await physics_frame
		check(game.war_fx.spawn(1,Vector3(0,1.7,0),Vector3(cos(angle),sin(angle),0),"sniper",false,"long:"+str(distance_value)),"physical sniper round created for "+str(distance_value)+"m")
		var shot: Dictionary=game.war_fx.rounds[game.war_fx.active_slots[-1]]
		var time:=0.;var lifetime:=float(shot.life)
		while shot.active and time<lifetime:
			game.war_fx._step(shot,1./120.);time+=1./120.
		check(not shot.active and absf(Vector3(shot.position).x-(distance_value-.2))<.02 and absf(Vector3(shot.position).y-1.3)<.05,"swept collision hits a real body-sized target at "+str(distance_value)+"m")
		check(angle<deg_to_rad(float(data.optic_fovs[-1])*.5),"drop compensation remains inside the deepest scope field at "+str(distance_value)+"m")
		measurements.append({"distance":distance_value,"elevation_degrees":rad_to_deg(angle),"flight_seconds":time,"lifetime":lifetime,"impact":var_to_str(shot.position)})
		target.queue_free();await physics_frame;await physics_frame
	var velocity:=Vector3(1,1,0).normalized()*float(data.speed)
	var predicted:=GameBulletPhysics.advance(Vector3(0,1.7,0),velocity,float(data.gravity),float(data.drag),2)
	game.war_fx.spawn(1,Vector3(0,1.7,0),velocity.normalized(),"sniper",false,"elevated")
	var elevated: Dictionary=game.war_fx.rounds[game.war_fx.active_slots[-1]]
	for tick in 240: game.war_fx._step(elevated,1./120.)
	print("ELEVATED_ERROR ",Vector3(elevated.position).distance_to(predicted.position))
	check(Vector3(elevated.position).distance_to(predicted.position)<.025,"45degree shot matches shared ballistic integration without extra vertical impulse")
	var report: Dictionary={"checks":checks,"failures":failures,"measurements":measurements,"speed":data.speed,"range":data.range,"gravity":data.gravity,"drag":data.drag};NavalStorage.write_json("res://tests/war167-sniper-results.json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await process_frame;await create_timer(.4).timeout;quit(0 if failures.is_empty() else 1)
