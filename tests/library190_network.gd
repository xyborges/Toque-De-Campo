extends "res://tests/pose189_network.gd"
var impact_injected:=false
var peak_hull_shock:=0.

func _process(delta: float) -> bool:
	super._process(delta)
	if is_instance_valid(game) and is_instance_valid(game.vehicle_system):
		peak_hull_shock=maxf(peak_hull_shock,float(game.vehicle_system.hull_shock))
		if role=="server" and game.phase=="apc" and not impact_injected:
			var vehicle:=game.vehicle_system.vehicles.v_bmp2 as WarVehicle
			if vehicle.shot_sequence>=2:
				impact_injected=true
				game.vehicle_system.damage_from_hit(0,vehicle,75,"rpg",Vector3.FORWARD)
	return false

func library_checks() -> String:
	WarTerrainEdits.prepare()
	var samples:=PackedFloat64Array()
	for base: Vector3 in WarRules.BASES:
		var sign_value:=1. if base.x<0 else -1.
		for z in [35.,41.,47.]:
			var at:=base+Vector3(sign_value*81,0,sign_value*z)
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*8,at-Vector3.UP*8,1)
			var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
			# The authored wooden walking boards sit 11 cm above the excavated soil.
			var soil:=WarTerrain.height_at(at.x,at.z)
			check(not hit.is_empty() and absf(float(hit.position.y)-(soil+.11))<.015,"saved trench floor has real physics in this network instance")
			samples.append(WarTerrain.height_at(at.x,at.z))
			if not hit.is_empty(): samples.append(float(hit.position.y))
			check(not WarVegetation.clear_site(Vector2(at.x,at.z)),"generated trees respect the editable trench")
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(samples.to_byte_array())
	return hasher.finish().hex_encode()

func server() -> void:
	if not await wait_for(func():return game.members.size()==2 and game.members.values().all(func(s):return s.deployed),"deploy terrain clients",75): return
	var signature:=library_checks()
	check(await wait_for(func():return game.reports.has("alpha:terrain-"+signature) and game.reports.has("bravo:terrain-"+signature),"same saved terrain/collision on both clients",75),"two DTLS clients agree with authoritative trench floor samples")
	await super.server()
	check(impact_injected,"authority injected a nonfatal missile impact during APC combat")

func client() -> void:
	var signature:=library_checks();report("terrain-"+signature)
	await super.client()
	if role=="alpha": check(peak_hull_shock>.1,"operator receives authoritative missile camera shock through DTLS")
	check(not game.vehicle_system.impact_events.is_empty(),"observer receives the authoritative metallic hull impact event")
