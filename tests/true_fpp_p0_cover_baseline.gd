extends SceneTree
## P0b controlled geometry: reports historical FPP/TPP shot differences.
## Does not modify player physics, anti-cheat or combat implementation.
class ShotFixture extends "res://tests/war_optics_fixture.gd":
	var accepted: Dictionary={}
	func _present_shot(packet: Dictionary) -> bool:
		accepted=packet.duplicate(true)
		return super._present_shot(packet)

var game: WarGame
var sequence:=77000

func _initialize() -> void:
	run.call_deferred()

func cover(name_text: String, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=name_text
	body.collision_layer=1
	body.collision_mask=0
	body.set_meta("cover_test",name_text)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	body.add_child(visual)
	body.position=centre
	game.world_root.add_child(body)
	return body

func record(actor: WarPlayer, preference: bool) -> Dictionary:
	game.third_person=preference
	actor.aiming=false
	actor.iron_sights=false
	actor.pitch=0.0
	actor.yaw=0.0
	actor.rotation=Vector3.ZERO
	actor.camera_pivot.rotation=Vector3.ZERO
	actor.recoil=0.0
	actor.attack_anim=0.0
	actor.velocity=Vector3.ZERO
	actor._update_view()
	actor._animate_walk()
	actor._update_weapon_pose()
	actor._update_camera_collision(1.0/60.0)
	var camera_origin: Vector3=actor.camera.global_position
	var camera_direction: Vector3=-actor.camera.global_basis.z.normalized()
	var eye: Vector3=actor.camera_pivot.global_position
	var muzzle: Vector3=actor.get_muzzle_position()
	var excludes: Array[RID]=[actor.get_rid()]
	var space:=game.get_world_3d().direct_space_state
	var aiming:=PhysicsRayQueryParameters3D.create(camera_origin,camera_origin+camera_direction*110.0,1,excludes)
	var aimed: Dictionary=space.intersect_ray(aiming)
	var crossing:=PhysicsRayQueryParameters3D.create(eye,muzzle,1,excludes)
	crossing.hit_from_inside=true
	var obstruction: Dictionary=space.intersect_ray(crossing)
	game.shot_clocks.clear()
	game.accepted.clear()
	sequence+=1
	actor.ammo["g3"]=30
	game._server_accept_shot(1,sequence,actor.life_id,camera_origin,camera_direction,"g3",0)
	var packet: Dictionary=game.accepted
	var fired: bool=str(packet.get("weapon",""))=="g3"
	var direction: Vector3=packet.get("direction",Vector3.ZERO)
	var shot_origin: Vector3=packet.get("origin",Vector3.INF)
	var projectile_query:=PhysicsRayQueryParameters3D.create(shot_origin,shot_origin+direction*110.0,1,excludes)
	var projectile_hit: Dictionary=space.intersect_ray(projectile_query) if fired else {}
	var output: Dictionary={
		"camera_preference":"TPP" if preference else "FPP",
		"effective_view":"TPP" if actor.camera.get_parent()==actor.shoulder_arm else "FPP",
		"camera_origin":str(camera_origin),
		"camera_eye_distance_m":camera_origin.distance_to(eye),
		"muzzle":str(muzzle),
		"shot_accepted":fired,
		"shot_origin":str(shot_origin),
		"shot_direction":str(direction),
		"shot_blocked":packet.get("blocked",false),
		"camera_ray_hit":str(aimed.collider.name) if not aimed.is_empty() else "",
		"eye_to_muzzle_hit":str(obstruction.collider.name) if not obstruction.is_empty() else "",
		"straight_line_hit":str(projectile_hit.collider.name) if not projectile_hit.is_empty() else "",
		"straight_line_hit_pos":str(projectile_hit.position) if not projectile_hit.is_empty() else ""
	}
	return output

func run() -> void:
	game=ShotFixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	actor.weapon_id="g3"
	actor.owned=["g3","glock"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor._refresh_weapon()
	actor.set_process(false)
	actor.set_physics_process(false)
	var cases: Array[Dictionary]=[
		{"name":"open","parts":[]},
		{"name":"eye_muzzle_wall","parts":[[Vector3(0.0,1.12,-0.62),Vector3(1.6,2.24,.20)]]},
		{"name":"right_corner","parts":[[Vector3(.85,1.22,-2.7),Vector3(1.25,2.44,.45)]]},
		{"name":"left_corner","parts":[[Vector3(-.85,1.22,-2.7),Vector3(1.25,2.44,.45)]]},
		{"name":"window","parts":[[Vector3(-1.3,1.35,-3.0),Vector3(1.45,2.7,.30)],[Vector3(1.3,1.35,-3.0),Vector3(1.45,2.7,.30)],[Vector3(0,2.35,-3),Vector3(1.3,.65,.3)],[Vector3(0,.42,-3),Vector3(1.3,.84,.3)]]},
		{"name":"low_wall","parts":[[Vector3(0,.53,-2.6),Vector3(2.4,1.06,.40)]]}
	]
	var results: Array[Dictionary]=[]
	var rejected:=0
	for scenario: Dictionary in cases:
		var blocks: Array[StaticBody3D]=[]
		var index:=0
		for part: Array in scenario.parts:
			var body:=cover(str(scenario.name)+"_"+str(index),part[0],part[1])
			blocks.append(body)
			index+=1
		await physics_frame
		var fpp: Dictionary=record(actor,false)
		var tpp: Dictionary=record(actor,true)
		if not fpp.shot_accepted or not tpp.shot_accepted: rejected+=1
		results.append({"case":scenario.name,"fpp":fpp,"tpp":tpp})
		for obj: StaticBody3D in blocks: obj.free()
		await physics_frame
	var report: Dictionary={"cases":results,"case_count":results.size(),"rejected_perspective_pairs":rejected}
	report["fixture_ok"]=results.size()==cases.size() and rejected==0
	var log:=FileAccess.open("res://work/fpp-tpp-p0-20261104/g3-cover-baseline.json",FileAccess.WRITE)
	if log:log.store_string(JSON.stringify(report,"\t"));log.close()
	print("TRUE_FPP_P0_COVER ",JSON.stringify({"cases":report.case_count,"rejected":rejected,"fixture_ok":report.fixture_ok}))
	for item: Dictionary in results:
		print("P0_COVER_PAIR ",JSON.stringify({"case":item.case,"fpp_blocked":item.fpp.shot_blocked,"tpp_blocked":item.tpp.shot_blocked,"fpp_hit":item.fpp.straight_line_hit,"tpp_hit":item.tpp.straight_line_hit,"fpp_aim":item.fpp.camera_ray_hit,"tpp_aim":item.tpp.camera_ray_hit}))
	game.queue_free()
	await process_frame
	quit(0 if bool(report.fixture_ok) else 1)
