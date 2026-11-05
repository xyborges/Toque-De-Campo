extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var failures: Array[String]=[]
var checks:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	var owned: Array=GameWeapons.INFANTRY_IDS
	for mode in ["war","desert","offline_training","offline_desert"]:
		var options:=GameLoadouts.allowed(mode,owned,"soldier",0)
		check(options.get("grenade",[])==["grenade","smoke"],"Two infantry grenade choices in "+mode)
		for kind in ["grenade","smoke"]:
			var selected:=GameLoadouts.defaults(mode,owned,"soldier",0)
			selected.grenade=kind
			check(GameLoadouts.validate(selected,mode,owned,"soldier",0).ok,mode+" accepts "+kind)
	check(not GameLoadouts.allowed("war",owned,"medic",0).has("grenade"),"War medic rules preserved")
	check(not GameLoadouts.validate({"primary":"ak","grenade":"unknown"},"desert",owned).ok,"Unknown grenade rejected")
	check(GameGrenades.SMOKE_FUSE==GameGrenades.FUSE-1.0,"M18 fuse one second shorter")
	var visual:=GameGrenades.make_prop("smoke")
	check(visual.mesh is CylinderMesh,"M18 uses proper cylindrical body")
	check(visual.get_node("SmokeCap").visible and visual.get_node("SmokeBand").visible,"M18 cap and identification band exist")
	GameGrenades.tune_prop(visual,"grenade")
	check(visual.mesh is SphereMesh and not visual.get_node("SmokeCap").visible,"Existing fragmentation grenade kept")
	visual.free()
	var smoke:=GameSmokeClouds.new()
	root.add_child(smoke)
	smoke.add_hand("hand",Vector3(0,0,0))
	check(smoke.clouds.has("hand") and smoke.clouds.hand.puffs.size()==14,"Hand grenade builds dense smoke from shared pooled system")
	smoke.add_hand("hand",Vector3.ZERO)
	check(smoke.clouds.size()==1,"Duplicate smoke events idempotent")
	for kind in ["abrams","t90","bmp2","guarani"]:
		var id: String="armor-"+kind
		smoke.add_vehicle(id,Vector3(15,0,0),Vector3.FORWARD,0.,kind)
		var data: Dictionary=smoke.clouds[id]
		var count: int=data.puffs.size()
		var radius: float=Vector3(data.puffs[0].point).distance_to(data.origin)
		var expected:=18 if kind in ["guarani","bmp2"] else 36
		check(count==expected,"Realistic launcher capacity and pooled cloud cards: "+kind)
		check(radius>5 and radius<20,"Armored smoke projects outward: "+kind)
	check(GameSmokeClouds.HAND_DURATION>=60 and GameSmokeClouds.VEHICLE_DURATION>=65,"Smoke lasts at least a minute")
	check(GameSmokeClouds.MAX_SPRITES<=192 and GameSmokeClouds.MAX_EVENTS<=40,"GPU sprite and smoke event budgets bounded")
	smoke.clear_clouds()
	check(smoke.clouds.is_empty(),"Smoke reset clears lingering event data")
	smoke.queue_free()
	var game:=FIXTURE.new() as WarGame
	root.add_child(game)
	await process_frame
	# Lightweight optics fixture does not construct the shared grenade system.
	game.grenades_system=GameGrenades.new();game.grenades_system.game=game;game.world_root.add_child(game.grenades_system)
	var manager:=game.vehicle_system as WarVehicles
	var actor:=game.local_player as WarPlayer
	check(is_instance_valid(game.grenades_system.smoke_clouds),"Shared visual system is initialized")
	for kind in ["abrams","t90","bmp2","guarani"]:
		var tank:=manager.vehicles["v_"+kind] as WarVehicle
		tank.global_position=actor.global_position
		tank.allocate_seat(actor.peer_id)
		actor.vehicle_id=tank.vehicle_id
		game.members[actor.peer_id].vehicle=tank.vehicle_id
		manager.deploy_smoke(actor.peer_id)
		check(manager.smoke_screens.size()==1,"Server deploys smoke for "+kind)
		var event: Dictionary=manager.smoke_screens.values()[0]
		check(absf(float(event.until)-game.war_clock-GameSmokeClouds.VEHICLE_DURATION)<.01,"Correct duration for "+kind)
		check(game.grenades_system.smoke_clouds.clouds.size()==1,"Smoke visual registered for "+kind)
		manager.deploy_smoke(actor.peer_id)
		check(manager.smoke_screens.size()==1,"Cooldown prevents duplicate for "+kind)
		tank.vacate_seat(actor.peer_id)
		manager.smoke_screens.clear()
		game.grenades_system.smoke_clouds.clear_clouds()
	manager.reset_occupancy()
	check(manager.smoke_screens.is_empty(),"Match reset clears armored smoke")
	# Throw one M18 through the real server-authoritative grenade fuse path.
	actor.apply_identity(0,"soldier");game.members[actor.peer_id].role="soldier"
	var selection:=GameLoadouts.defaults("war",owned,"soldier",0)
	selection.grenade="smoke"
	var approved:=GameLoadouts.validate(selection,"war",owned,"soldier",0)
	GameLoadouts.apply(actor,approved,true)
	actor.grenades=2;actor.deployed=true;actor.vehicle_id=""
	game.members[actor.peer_id].vehicle=""
	check(str(actor.get_meta("grenade_kind",""))=="smoke","Server loadout sets grenade kind")
	var sequence:=actor.grenade_sequence+1
	check(game.grenades_system.prime(actor,actor.life_id,sequence),"M18 can be primed on authority")
	if not game.grenades_system.rounds.is_empty():
		var round_id: String=game.grenades_system.rounds.keys()[0]
		var grenade: Dictionary=game.grenades_system.rounds[round_id]
		check(grenade.kind=="smoke" and absf(float(grenade.left)-GameGrenades.SMOKE_FUSE)<.03,"M18 packet carries 4 second fuse")
		var target:=game.players[2] as WarPlayer
		target.global_position=actor.global_position+Vector3.RIGHT*1.5
		var health:=target.hp
		grenade.held=false;grenade.position=target.global_position;grenade.left=.0001
		game.grenades_system._physics_process(.02)
		check(is_equal_approx(target.hp,health),"M18 activation never causes explosive damage")
		check(game.grenades_system.smoke_clouds.clouds.has(round_id),"M18 activation creates persistent smoke")
	game.queue_free()
	await process_frame
	print("SMOKE_GRENADE_QA ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
