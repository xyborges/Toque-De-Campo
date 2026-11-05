extends SceneTree

var passed:=0
var errors: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func verify(condition: bool,label: String) -> void:
	if condition:
		passed+=1
		print("PASS ",label)
	else:
		errors.append(label)
		push_error("FAIL "+label)

func run() -> void:
	var source:=FileAccess.get_file_as_string("res://modes/war/scripts/launcher_details.gd")
	for weapon in ["rpg","stinger"]:
		var model:=WarLauncherModels.build(weapon)
		verify(model.has_node("LauncherMuzzle"),weapon+" muzzle anchor exists")
		verify(model.has_node("GripRight") and model.has_node("GripLeft"),weapon+" grip markers remain available")
		verify(model.get_meta("model_details").version==4,weapon+" detailed model version")
		verify(int(model.get_meta("model_details").parts)>48,weapon+" receives the extra manufactured details")
		verify(GameOpticCatalog.ids_for_weapon(weapon).is_empty(),weapon+" excludes add-on sights")
		verify(GameAttachmentState.from_legacy(weapon,"scope4x").is_empty(),weapon+" rejects legacy scope4x")
		if weapon=="rpg":
			verify(source.contains("PGO7ElevationTurret"),"RPG permanently carries PGO-7 adjustment drum")
			verify(source.contains("PGO7EyepieceRubber"),"RPG has PGO-7 eyecup")
		else:
			verify(source.contains("CheekboneToneIndicator"),"Stinger has seeker feedback housing")
			verify(source.contains("IFFAntennaRaised"),"Stinger has IFF sight support")
		model.free()
	for weapon in ["rpg","stinger"]:
		var missile:=WarProjectiles._rocket_mesh(weapon)
		verify(missile!=null and missile.get_surface_count()==1,weapon+" rocket mesh contains a finned projectile")
		verify(missile.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>100,weapon+" rocket is detailed beyond a tracer sphere")
	var tone:=WarStingerLockAudio._tone(500.,900.,.12)
	verify(tone.format==AudioStreamWAV.FORMAT_16_BITS and tone.mix_rate==22050,"local seeker tone has 16-bit PCM")
	verify(tone.data.size()==5292,"seeker PCM duration is generated deterministically")
	var reticle:=load("res://shaders/scope_reticle.gdshader") as Shader
	verify(reticle!=null and reticle.code.contains("launcher_mode"),"standard reticle shader provides two exclusive launcher modes")
	# Exercise the actual authoritative firing path with elapsed simulation time.
	var fixture:=load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(fixture)
	await process_frame
	var actor:=fixture.local_player as WarPlayer
	var manager:=fixture.vehicle_system as WarVehicles
	for weapon in ["rpg","stinger"]:
		var team:=1 if weapon=="rpg" else 0
		actor.apply_identity(team,"antitank")
		fixture.members[1].team=team
		fixture.members[2].team=1-team
		fixture.players[2].apply_identity(1-team,"soldier")
		actor.set_gadget(true,weapon)
		actor._update_weapon_pose()
		fixture.war_clock+=10.0
		fixture.members[1].last_gadget=-100.0
		if weapon=="stinger":
			var drone:=WarDrone.new()
			drone.drone_id="realism_qa_drone"
			drone.team=1
			fixture.world_root.add_child(drone)
			drone.set_physics_process(false)
			drone.set_process(false)
			drone.global_position=actor.camera_pivot.global_position+Vector3(0,0,-80.0)
			manager.drones[drone.drone_id]=drone
			manager._update_gadgets(.016)
			for i in 6:
				fixture.war_clock+=.25
				manager._update_gadgets(.25)
			verify(float(manager.locks.get(1,{}).get("progress",0.0))>=1.0,"Stinger authority completes a tracked lock")
		var muzzle: Vector3=actor.launcher_muzzle.global_position
		var count: int=fixture.war_fx.counter
		var charges: int=int(fixture.members[1].charges)
		manager.use_gadget(1)
		verify(fixture.war_fx.counter==count+1,weapon+" authority spawns one rocket")
		verify(int(fixture.members[1].charges)==charges-1,weapon+" authority consumes one charge")
		if fixture.war_fx.counter>count:
			var shot: Dictionary=fixture.war_fx.rounds[fixture.war_fx.active_slots[-1]]
			verify(Vector3(shot.position).distance_to(muzzle)<.002,weapon+" flight begins precisely at barrel marker")
			verify(Vector3(shot.velocity).length()>10.0,weapon+" has a valid travelling velocity")
	fixture.queue_free()
	await process_frame
	print("RPG_STINGER_QA ",passed," passed; ",errors.size()," failed")
	quit(0 if errors.is_empty() else 1)
