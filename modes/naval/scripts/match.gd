extends Node
class_name NavalMatch

var network: NavalNetwork
var room: Dictionary
var space: SubViewport
var world: NavalWorld
var ships: Dictionary = {}
var projectiles: Dictionary = {}
var next_fire: Dictionary = {}
var time := 0.0
var tick := 0
var counter := 0
var tracer_sequences: Dictionary={}
var match_stats:=GameMatchStats.new()
var stats_ping_at:=0.0
var accumulator := 0.0
var snapshot_clock := 0.0
var random := RandomNumberGenerator.new()

func build(service: NavalNetwork, data: Dictionary) -> void:
	network = service
	room = data
	random.randomize()
	space = SubViewport.new()
	space.name = "RoomSpace"
	space.own_world_3d = true
	space.size = Vector2i(16,16)
	space.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(space)
	world = NavalWorld.new()
	space.add_child(world)
	world.build(false,int(data.get("map_seed",0)))
	if network.require_accounts: _register_accounts.call_deferred()

func add_player(peer: int, user: Dictionary) -> void:
	if ships.has(peer): return
	var account: Dictionary = network.accounts[user.identity]
	var kind := str(user.ship)
	if kind not in account.owned: kind = "light"
	var ship := NavalShip.new()
	world.add_child(ship)
	ship.build(kind,peer,str(user.identity),str(user.name))
	ships[peer] = ship
	match_stats.register(peer,ship.display_name)
	if not room.stats.has(ship.identity): room.stats[ship.identity] = {"name":ship.display_name,"kills":0,"deaths":0}
	_place(ship)

func _place(ship: NavalShip) -> void:
	var best := Vector3(800,0,800)
	var best_score := -INF
	for attempt in range(100):
		var candidate := Vector3(random.randf_range(-850,850),0,random.randf_range(-850,850))
		if not NavalCatalog.safe_point(candidate,NavalCatalog.ship_radius(ship.kind)): continue
		var nearest := 1800.0
		var exposed:=false
		for other in ships.values():
			if other == ship or other.dead: continue
			nearest = minf(nearest,candidate.distance_to(other.global_position))
			var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*3.,other.global_position+Vector3.UP*3.,1)
			if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():exposed=true
		if nearest < 160.0: continue
		if exposed and nearest<350.:continue
		if not exposed:nearest+=350.
		for shot in projectiles.values():
			var pos := NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,shot.age,shot.weapon,shot.time)
			if candidate.distance_to(pos) < 45.0: nearest -= 500.0
		if nearest > best_score:
			best_score = nearest
			best = candidate
	ship.global_position = best
	ship.global_position.y = NavalCatalog.wave(best,time)
	ship.heading = atan2(best.x,best.z)
	ship.rotation = Vector3(0,ship.heading,0)
	ship.aim = Vector3.ZERO
	ship.latest_input = time

func remove_player(peer: int) -> void:
	match_stats.remove(peer)
	if ships.has(peer): room.stats.erase(ships[peer].identity)
	if ships.has(peer):
		ships[peer].queue_free()
		ships.erase(peer)
	for id in projectiles.keys():
		if int(projectiles[id].owner) == peer: projectiles.erase(id)
	for id in next_fire.keys():
		if str(id).begins_with(str(peer)+":"): next_fire.erase(id)

func set_control(peer: int, throttle: float, steer: float, aim: Vector3, weapon: String, firing: bool) -> void:
	var ship: NavalShip = ships.get(peer)
	if not is_instance_valid(ship) or ship.dead: return
	ship.throttle = throttle
	ship.steering = steer
	ship.aim = aim
	ship.latest_input = time
	if weapon in ship.spec.weapons and ship.selected != weapon:
		ship.selected = weapon
		ship.firing = false
		ship.reload_left = 0.0
		ship.reload_weapon = ""
	ship.firing = firing

func cease_fire(peer: int) -> void:
	var ship: NavalShip = ships.get(peer)
	if is_instance_valid(ship): ship.firing = false

func reload(peer: int) -> void:
	var ship: NavalShip = ships.get(peer)
	if is_instance_valid(ship): ship.start_reload()

func _physics_process(delta: float) -> void:
	if room.get("state","") != "IN_PROGRESS": return
	accumulator += minf(delta,0.25)
	while accumulator >= NavalCatalog.STEP:
		accumulator -= NavalCatalog.STEP
		advance(NavalCatalog.STEP)
	snapshot_clock += delta
	if snapshot_clock >= 0.10:
		snapshot_clock = 0.0
		var data := snapshot()
		network.send_state(room.members,data)

func advance(delta: float) -> void:
	time += delta
	tick += 1
	world.update_time(time)
	for ship: NavalShip in ships.values():
		if ship.dead:
			if time >= ship.respawn_at and bool(network.users.get(ship.peer,{}).get("ready",false)): _respawn(ship)
			continue
		ship.simulate(delta,time)
		if ship.firing: try_fire(ship)
	for id in projectiles.keys():
		var shot: Dictionary = projectiles[id]
		var end := NavalBallistics.duration(shot.velocity.length(),float(shot.range),float(shot.life),str(shot.weapon))
		var next := minf(float(shot.age)+delta,end)
		var hit := NavalBallistics.segment(world.get_world_3d(),shot,next,_excludes(shot))
		shot.age = next
		if not hit.is_empty():
			projectiles.erase(id)
			_impact(shot,hit)
		elif next >= end:
			projectiles.erase(id)
			_event("impact",{"id":id,"position":NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,next,shot.weapon,shot.time),"water":false,"hit_ship":false,"weapon":shot.weapon})

func try_fire(ship: NavalShip) -> bool:
	if ship.dead or ship.reload_left > 0.0 or int(ship.ammo[ship.selected]) <= 0 or projectiles.size() >= 192: return false
	var turret: NavalTurret = ship.turrets[ship.selected]
	if turret.blocked or not turret.reachable: return false
	var key := str(ship.peer)+":"+ship.selected
	var next := float(next_fire.get(key,-100.0))
	if time+0.00001 < next: return false
	if time-next > NavalCatalog.STEP*1.5: next = time
	next_fire[key] = next+float(NavalCatalog.WEAPONS[ship.selected].cadence)
	ship.waits[ship.selected] = maxf(0.0,float(next_fire[key])-time)
	ship.ammo[ship.selected] = int(ship.ammo[ship.selected])-1
	counter += 1
	tracer_sequences[key]=int(tracer_sequences.get(key,0))+1
	var shot := turret.launch(ship.velocity,time)
	shot.merge({"id":str(room.match)+":"+str(counter),"owner":ship.peer,"owner_ship":ship.ship_id,"life_id":ship.life,"tracer":ship.selected not in ["lightMG","heavyMG"] or int(tracer_sequences[key])%2==0})
	projectiles[shot.id] = shot
	_event("shot",shot.duplicate())
	turret.show_recoil()
	return true

func _excludes(shot: Dictionary) -> Array[RID]:
	var result: Array[RID] = []
	var owner: NavalShip = ships.get(int(shot.owner))
	if is_instance_valid(owner) and owner.ship_id == str(shot.owner_ship): result.append(owner.get_rid())
	return result

func _impact(shot: Dictionary, hit: Dictionary) -> void:
	var target := hit.get("collider") as NavalShip
	if is_instance_valid(target) and not target.dead:
		var before:=target.hp
		target.last_damage_at = time
		target.hp = maxf(0.0,target.hp-float(NavalCatalog.WEAPONS[shot.weapon].damage))
		_event("damage",{"id":str(shot.id)+":damage","owner":int(shot.owner),"target":target.peer,"amount":before-target.hp,"hp":target.hp,"max_hp":float(target.spec.hp),"position":target.global_position+Vector3.UP*maxf(4,float(target.spec.width)*1.3)})
		var attacker:=ships.get(int(shot.owner)) as NavalShip
		if is_instance_valid(attacker) and attacker!=target:
			match_stats.hit(attacker.peer,target.peer,target.life,before-target.hp,target.hp==0,false,attacker.global_position.distance_to(target.global_position),time)
		if target.hp == 0.0: _destroy(target,int(shot.owner))
	_event("impact",{"id":shot.id,"position":hit.position,"water":bool(hit.get("water",false)),"hit_ship":is_instance_valid(target),"weapon":shot.weapon})

func _destroy(ship: NavalShip, killer: int) -> void:
	if ship.dead: return
	match_stats.death(ship.peer,ship.life)
	ship.dead = true
	ship.hp = 0.0
	ship.firing = false
	ship.throttle = 0.0
	ship.steering = 0.0
	ship.speed = 0.0
	ship.velocity = Vector3.ZERO
	ship.reload_left = 0.0
	ship.reload_weapon = ""
	ship.collision_layer = 0
	ship.collision_mask = 0
	ship.death_time = time
	ship.respawn_at = time+5.0
	room.stats[ship.identity].deaths = int(room.stats[ship.identity].deaths)+1
	if network.require_accounts:
		_persist_death_account.call_deferred({"match":room.match,"event":ship.ship_id+":death","victim":network.accounts[ship.identity].id})
	var attacker: NavalShip = ships.get(killer)
	if is_instance_valid(attacker) and attacker != ship:
		room.stats[attacker.identity].kills = int(room.stats[attacker.identity].kills)+1
		if network.require_accounts:
			_reward_account.call_deferred({"match":room.match,"event":ship.ship_id+":death","killer":network.accounts[attacker.identity].id,"victim":network.accounts[ship.identity].id,"peer":attacker.peer})
		var account: Dictionary = network.accounts[attacker.identity].duplicate(true)
		account.coins = int(account.coins)+100
		if not network.require_accounts and NavalStorage.save_account(account):
			network.accounts[attacker.identity] = account
			network._send(killer,"wallet",{"account":network._public_account(account)})
	if network.users.has(ship.peer): network.users[ship.peer].ready=false
	_event("destroyed",{"id":ship.ship_id+":death","ship":ship.ship_id,"victim":ship.display_name,"killer":attacker.display_name if is_instance_valid(attacker) else "Ambiente","position":ship.global_position,"respawn":ship.respawn_at})

	network._room_changed(room)

func _respawn(ship: NavalShip) -> void:
	ship.dead = false
	ship.hp = float(ship.spec.hp)
	ship.life += 1
	ship.ship_id = NavalCatalog.uid()
	ship.collision_layer = 2
	ship.collision_mask = 3
	ship.firing = false
	ship.throttle = 0.0
	ship.steering = 0.0
	ship.turn_speed = 0.0
	ship.speed = 0.0
	ship.velocity = Vector3.ZERO
	ship.reload_left = 0.0
	ship.reload_weapon = ""
	ship.components = {"engine":100.0,"steering":100.0,"turrets":100.0}
	for weapon in ship.ammo: ship.ammo[weapon] = int(NavalCatalog.WEAPONS[weapon].ammo)
	for weapon in ship.turrets:
		ship.turrets[weapon].yaw = 0.0
		ship.turrets[weapon].elevation = 0.0
		ship.turrets[weapon].recoil = 0.0
	_place(ship)
	_event("respawn",{"id":ship.ship_id+":spawn","peer":ship.peer,"ship":ship.ship_id})

func _event(kind: String, payload: Dictionary) -> void:
	payload["room"] = room.id
	payload["match"] = room.match
	network._broadcast_room(room,kind,payload)

func snapshot() -> Dictionary:
	if time-stats_ping_at>=1:
		stats_ping_at=time
		for peer in ships:
			if not match_stats.rows.has(peer): continue
			var packet:=GameNetworkPeers.connected(network.connection.multiplayer_peer as ENetMultiplayerPeer,peer) if peer!=1 else null
			if packet and packet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)>0: match_stats.rows[peer].ping=maxi(1,roundi(packet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))
	for ship: NavalShip in ships.values():
		if match_stats.rows.has(ship.peer): room.stats[ship.identity]=match_stats.rows[ship.peer].duplicate(true)
	var bodies: Array = []
	for ship in ships.values(): bodies.append(ship.snapshot())
	return {"room":room.id,"match":room.match,"tick":tick,"time":time,"ships":bodies,"projectiles":projectiles.values().duplicate(true),"scores":room.stats.duplicate(true)}

func can_change_ship(peer: int, kind: String) -> String:
	var ship: NavalShip = ships.get(peer)
	if not is_instance_valid(ship) or ship.dead: return "Aguarde renascer para trocar de navio."
	if ship.hp < float(ship.spec.hp)-0.001: return "Troca bloqueada: o navio precisa de 100% da vida."
	if time-ship.last_damage_at<10.0: return "Troca bloqueada: aguarde 10 segundos sem receber dano."
	if time-ship.last_change_at<10.0: return "Aguarde 10 segundos entre trocas de navio."
	if ship.firing or ship.reload_left>0.0: return "Pare de disparar e aguarde a recarga antes de trocar."
	if not NavalCatalog.safe_point(ship.global_position,NavalCatalog.ship_radius(kind)): return "Afaste o navio da ilha para trocar com segurança."
	for other: NavalShip in ships.values():
		if other != ship and not other.dead and ship.global_position.distance_to(other.global_position)<NavalCatalog.ship_radius(kind)+NavalCatalog.ship_radius(other.kind): return "Afaste-se dos outros navios para trocar."
	return ""

func change_ship(peer: int, kind: String) -> void:
	var old: NavalShip = ships[peer]
	if old.kind == kind: return
	var ship := NavalShip.new()
	world.add_child(ship)
	ship.build(kind,peer,old.identity,old.display_name)
	ship.global_transform = old.global_transform
	ship.heading = old.heading
	ship.speed = clampf(old.speed,-float(ship.spec.speed)*0.3,float(ship.spec.speed))
	ship.velocity = old.velocity.limit_length(float(ship.spec.speed))
	ship.aim = old.aim
	ship.life = old.life+1
	ship.last_change_at = time
	ship.last_damage_at = old.last_damage_at
	ship.latest_input = time
	old.collision_layer = 0
	old.collision_mask = 0
	old.queue_free()
	ships[peer] = ship
	for id in projectiles.keys():
		if int(projectiles[id].owner)==peer: projectiles.erase(id)
	network._broadcast_room(room,"snapshot",snapshot())

func _register_accounts() -> void:
	await get_tree().process_frame
	var service: NavalAccounts = network.get_parent().accounts_service
	var ids: Array = []
	for member in room.members:
		if network.users.has(member): ids.append(str(network.users[member].account_id))
	await service.call_api("match_register",{"match":room.match,"players":ids})

func _reward_account(data: Dictionary) -> void:
	await _register_accounts()
	var service: NavalAccounts = network.get_parent().accounts_service
	var result := await service.call_api("reward",data)
	if result.get("ok",false): network._send(int(data.peer),"refresh_account",{})

func _persist_death_account(data: Dictionary) -> void:
	await _register_accounts()
	for attempt in 3:
		if not is_inside_tree() or not is_instance_valid(network): return
		var service: NavalAccounts=network.get_parent().accounts_service
		var result:=await service.call_api("match_death",data)
		if result.get("ok",false): return
		if attempt<2 and is_inside_tree(): await get_tree().create_timer(.5*(attempt+1)).timeout
	push_warning("Não foi possível persistir uma morte naval após três tentativas.")


func deploy_player(peer: int,kind: String) -> bool:
	if not network.users.has(peer) or kind not in network.accounts[network.users[peer].identity].owned: return false
	var ship:=ships.get(peer) as NavalShip
	if not is_instance_valid(ship): add_player(peer,network.users[peer]);return true
	if not ship.dead: return false
	if time<ship.respawn_at: network._error(peer,"Aguarde %.0f s."%ceilf(ship.respawn_at-time));return false
	if kind!=ship.kind:
		var replacement:=NavalShip.new();world.add_child(replacement);replacement.build(kind,peer,ship.identity,ship.display_name)
		replacement.life=ship.life;replacement.dead=true;replacement.hp=0;replacement.collision_layer=0;replacement.collision_mask=0
		ships[peer]=replacement;ship.queue_free();ship=replacement
	_respawn(ship)
	return true
