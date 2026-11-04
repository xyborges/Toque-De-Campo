extends RefCounted
class_name BRBotBrain

# A decision/path request is staggered between bots. Physics remains 60 Hz;
# waypoints do not teleport the actor and all walls still block movement.
var paths: Dictionary={}
var destinations: Dictionary={}
var blocked_until: Dictionary={}
var progress: Dictionary={}
var repath_at: Dictionary={}
# Global authority budget: at most two candidates, two LOS rays each, every
# half second. No per-player recurring timers or physics bodies are created.
var next_cover_query:=0.
var cover_goals: Dictionary={}

func clear() -> void:
	paths.clear();destinations.clear();blocked_until.clear();progress.clear();repath_at.clear();cover_goals.clear();next_cover_query=0.

func _can_take(game: BattleRoyaleGame,actor: BRPlayer,item: Dictionary) -> bool:
	var inv:=game.br_inventory.snapshot(actor.peer_id)
	match str(item.get("kind","")):
		"weapon":return actor.loadout.size()<2 and str(item.weapon) not in actor.loadout
		"ammo":
			var wanted:=false
			for weapon in actor.loadout:
				if BRInventory.calibre_for(weapon)==str(item.calibre) and int(actor.reserves.get(weapon,0))<int(BRInventory.MAGAZINES[weapon])*4:wanted=true
			return wanted and float(inv.weight)<float(inv.capacity)-float(BRInventory.AMMO_WEIGHT.get(item.calibre,1))
		"heal":return int(inv.medkits)<3 and float(inv.weight)+4<=float(inv.capacity)
		"grenade":return int(inv.get("grenades",0))<3 and float(inv.weight)+1.2<=float(inv.capacity)
		"pack":return int(item.level)>int(inv.backpack)
		"optic","attachment":
			var module:=str(item.get("attachment",item.get("optic","")))
			var definition:=GameAttachmentRegistry.definition(module)
			if not definition:return false
			for weapon in actor.loadout:
				var config: Dictionary=inv.weapon_attachments.get(weapon,{})
				for socket in GameAttachmentState.sockets(str(weapon),config):
					if not config.has(socket) and GameAttachmentState.can_install(str(weapon),config,str(socket),module).get("ok",false) and not inv.accessories.has(module):return float(inv.weight)+float(definition.weight)<=float(inv.capacity)
			return false
		"vest","helmet":
			var worn: Dictionary=inv.protection[item.kind]
			return int(item.level)>int(worn.level) or (int(item.level)==int(worn.level) and float(item.get("durability",0))>float(worn.durability))
		"container":return true
	return false

func step(game: BattleRoyaleGame,actor: BRPlayer,delta: float) -> void:
	if game.phase!="active" or not game.br_round.is_alive(actor.peer_id) or actor.applying_heal():actor.velocity=Vector3.ZERO;return
	var now:=game._now();actor.bot_clock-=delta
	var key:=actor.peer_id
	if actor.bot_clock<=0:
		actor.bot_clock=.24+float(posmod(key,7))*.017
		_decide(game,actor,now)
	if int(actor.get_meta("br_burst_remaining",0))>0:
		var target:=game.players.get(int(actor.get_meta("br_combat_target",-1))) as GamePlayer
		if target and target.hp>0 and actor.reload_left<=0 and int(actor.ammo.get(actor.weapon_id,0))>0:
			if now>=float(actor.get_meta("br_next_shot",0)):
				_shoot(game,actor,now);actor.set_meta("br_burst_remaining",int(actor.get_meta("br_burst_remaining",0))-1)
		else:actor.set_meta("br_burst_remaining",0)
	var path: PackedVector3Array=paths.get(key,PackedVector3Array())
	while not path.is_empty() and Vector2(actor.global_position.x-path[0].x,actor.global_position.z-path[0].z).length()<.65:path.remove_at(0)
	paths[key]=path
	var destination:=path[0] if not path.is_empty() else actor.bot_target
	var travel: Vector3=destination-actor.global_position;travel.y=0
	var direction:=travel.normalized() if travel.length()>.5 else Vector3.ZERO
	# A far target without a committed path means the navmesh rejected it. Do not
	# charge straight at it through walls; that is what makes a bot hug and loop
	# around an obstacle. Stand still and force a repath on the next decision.
	if path.is_empty() and travel.length()>2.0 and int(actor.get_meta("br_combat_target",-1))<0:
		direction=Vector3.ZERO;repath_at[key]=0.
	if direction.length_squared()>0 and int(actor.get_meta("br_combat_target",-1))<0:
		actor.yaw=atan2(-direction.x,-direction.z);actor.rotation.y=actor.yaw
	actor.velocity.x=direction.x*3.4;actor.velocity.z=direction.z*3.4
	if not actor.is_on_floor():actor.velocity.y-=9.81*delta
	GameStepMotion.move(actor,delta);actor._animate_walk()

func _decide(game: BattleRoyaleGame,actor: BRPlayer,now: float) -> void:
	var key:=actor.peer_id
	var bag:=game.br_inventory.snapshot(key)
	for weapon in actor.loadout:
		var config: Dictionary=bag.weapon_attachments.get(weapon,{})
		for module: Dictionary in bag.accessory_items:
			for socket in GameAttachmentState.sockets(str(weapon),config):
				if not config.has(socket) and GameAttachmentState.can_install(str(weapon),config,str(socket),str(module.id)).get("ok",false):
					game._br_action(key,"attachment",{"weapon":weapon,"socket":socket,"attachment":module.id,"uid":module.uid},actor.life_id,game.br_generation);break
	var last: Dictionary=progress.get(key,{"at":now,"position":actor.global_position})
	if now-float(last.at)>2.:
		if actor.global_position.distance_squared_to(last.position)<.4 and actor.global_position.distance_squared_to(actor.bot_target)>4.:
			blocked_until["%d:%s"%[key,str(destinations.get(key,Vector3.ZERO))]]=now+12.
			repath_at[key]=0.
		progress[key]={"at":now,"position":actor.global_position}
	else:progress[key]=last
	var state:=game.br_zone.sample(now)
	var safe_center:=BRAfghanMap.point(state.target_center.x,state.target_center.y)
	var zone_distance:=Vector2(actor.global_position.x,actor.global_position.z).distance_to(state.center)
	var danger:=zone_distance>float(state.radius)-maxf(8.,3.4*12.) or (bool(state.closing) and Vector2(actor.global_position.x,actor.global_position.z).distance_to(state.target_center)>float(state.target_radius)*.9)
	var enemy: GamePlayer=null;var closest:=70.
	if not danger:
		for other: GamePlayer in game.players.values():
			if other==actor or not game.br_round.is_alive(other.peer_id):continue
			var distance:=actor.global_position.distance_to(other.global_position)
			if distance<closest and game.npc_line_clear(actor.camera_pivot.global_position,other.global_position+Vector3.UP*.95):enemy=other;closest=distance
	actor.set_meta("br_combat_target",enemy.peer_id if enemy else -1)
	if not enemy:actor.set_meta("br_burst_remaining",0)
	# An empty weapon is not a reason to stare at an opponent forever. Seek
	# useful ammunition first; fists remain a last close-range alternative.
	var usable:=false
	for weapon in actor.loadout:
		if int(actor.ammo.get(weapon,0))+int(actor.reserves.get(weapon,0))>0:usable=true
	if enemy and not usable and closest>4.:
		enemy=null;actor.set_meta("br_combat_target",-1)
	if enemy:
		var target:=enemy.global_position+Vector3.UP*1.04
		var offset:=target-actor.camera_pivot.global_position
		actor.yaw=atan2(-offset.x,-offset.z);actor.pitch=actor.clamp_aim_pitch(atan2(offset.y,Vector2(offset.x,offset.z).length()))
		actor.rotation.y=actor.yaw;actor.camera_pivot.rotation.x=actor.pitch
		var chosen: String=actor.weapon_id
		if chosen=="fists" or int(actor.ammo.get(chosen,0))+int(actor.reserves.get(chosen,0))==0:
			chosen="fists"
			for weapon in actor.loadout:
				if int(actor.ammo.get(weapon,0))+int(actor.reserves.get(weapon,0))>0:chosen=str(weapon);break
		if chosen!=actor.weapon_id:game._equip_server(actor,chosen)
		if chosen=="fists":
			_set_target(game,actor,enemy.global_position,now)
			if closest<1.25:_shoot(game,actor,now)
		else:
			var cover: Dictionary=cover_goals.get(key,{})
			if int(cover.get("enemy",-1))!=enemy.peer_id or now>=float(cover.get("until",0.)):
				cover={}
				if now>=next_cover_query:
					next_cover_query=now+.5
					var point:=_find_cover(game,actor,enemy)
					if point.is_finite():
						cover={"point":point,"enemy":enemy.peer_id,"until":now+3.}
						cover_goals[key]=cover
			if not cover.is_empty() and actor.global_position.distance_squared_to(cover.point)>1.:
				_set_target(game,actor,cover.point,now)
			else:
				actor.bot_target=actor.global_position;paths.erase(key)
			if int(actor.ammo.get(chosen,0))>0 and actor.reload_left<=0:
				if str(actor.weapon_spec(chosen).mode)=="auto":
					if now>=float(actor.get_meta("br_burst_ready",0)):
						actor.set_meta("br_burst_remaining",3+posmod(key,3));actor.set_meta("br_burst_ready",now+1.25)
				else:_shoot(game,actor,now)
			elif actor.reload_left<=0:game._server_reload(key,chosen)
		return
	if actor.hp<65 and game.br_inventory.snapshot(key).get("medkits",0)>0 and not danger:
		actor.bot_target=actor.global_position;paths.erase(key)
		game._br_action(key,"heal",{},actor.life_id,game.br_generation);return
	if danger:
		_set_target(game,actor,safe_center,now);return
	var best:=INF;var selected: Dictionary={}
	for item: Dictionary in game.br_inventory.nearby(actor.global_position,200. if actor.loadout.is_empty() else 100.):
		if not _can_take(game,actor,item):continue
		if now<float(blocked_until.get("%d:%s"%[key,str(item.position)],0)):continue
		var score:=actor.global_position.distance_squared_to(item.position)
		if item.kind=="weapon" and actor.loadout.is_empty():score*=.15
		if score<best:best=score;selected=item
	if not selected.is_empty():
		if actor.global_position.distance_squared_to(selected.position)<7.:
			var sight:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,selected.position+Vector3.UP*.15,1,[actor.get_rid()])
			var visible:=game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty()
			# Being close to an item through a wall is not reaching it. Keep
			# following its indoor route rather than abandoning the door path.
			if visible:
				if game._br_action(key,"pickup",{"id":selected.id},actor.life_id,game.br_generation):
					paths.erase(key);return
				blocked_until["%d:%s"%[key,str(selected.position)]]=now+5.
			elif actor.global_position.distance_squared_to(selected.position)<.5:
				blocked_until["%d:%s"%[key,str(selected.position)]]=now+12.
		_set_target(game,actor,selected.position,now);return
	# Move between reachable settlement anchors instead of standing forever at
	# the circle centre when no useful nearby loot remains.
	var candidates: Array=BRAfghanMap.loot_points()
	if candidates.is_empty() and is_instance_valid(game.navigation) and game.navigation.ready:
		candidates=game.navigation.reachable_loot_points()
	if candidates.is_empty():candidates=game._navigation_candidates(false)
	if actor.global_position.distance_squared_to(actor.bot_target)<9. or not destinations.has(key):
		var rng:=RandomNumberGenerator.new();rng.seed=game.seed_value+key+int(now/8.)*97
		var best_point:=safe_center;var best_distance:=INF
		for index in mini(30,candidates.size()):
			var p: Vector3=candidates[rng.randi_range(0,candidates.size()-1)]
			if Vector2(p.x,p.z).distance_to(state.target_center)>float(state.target_radius)*.9:continue
			var distance:=actor.global_position.distance_to(p)
			if distance>25. and distance<best_distance:best_distance=distance;best_point=p
		_set_target(game,actor,best_point,now)
	else:_set_target(game,actor,actor.bot_target,now)

func _find_cover(game: BattleRoyaleGame,actor: BRPlayer,enemy: GamePlayer) -> Vector3:
	# A low obstacle must hide the body yet leave the eye-to-target line clear.
	# Two side candidates, a maximum of four world-only physics ray tests.
	var towards:=enemy.global_position-actor.global_position;towards.y=0.
	if towards.length_squared()<4.:return Vector3.INF
	var side:=towards.normalized().cross(Vector3.UP)
	var target:=enemy.global_position+Vector3.UP*.95
	var state:=game.get_world_3d().direct_space_state
	for sign_value in [-1.,1.]:
		var point: Vector3=actor.global_position+side*float(sign_value)*3.
		var body:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.90,target,1,[actor.get_rid(),enemy.get_rid()])
		if state.intersect_ray(body).is_empty():continue
		var eye_height:=clampf(actor.camera_pivot.global_position.y-actor.global_position.y,1.30,1.75)
		var eye:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*eye_height,target,1,[actor.get_rid(),enemy.get_rid()])
		if state.intersect_ray(eye).is_empty():return point
	return Vector3.INF

func _shoot(game: BattleRoyaleGame,actor: BRPlayer,now: float) -> void:
	if now<float(actor.get_meta("br_next_shot",0)):return
	var cadence:=float(actor.weapon_spec(actor.weapon_id).cooldown)
	actor.set_meta("br_next_shot",now+cadence)
	actor.shot_sequence+=1
	var direction:=(-actor.camera_pivot.global_basis.z).rotated(Vector3.UP,sin(now*2.+actor.peer_id)*.025)
	game._server_accept_shot(actor.peer_id,actor.shot_sequence,actor.life_id,actor.camera_pivot.global_position,direction,actor.weapon_id,0)

func _set_target(game: BattleRoyaleGame,actor: BRPlayer,to: Vector3,now: float) -> void:
	var key:=actor.peer_id
	var changed:=not destinations.has(key) or Vector3(destinations[key]).distance_squared_to(to)>4.
	actor.bot_target=to
	# A static loot/zone route remains valid while the actor progresses. A
	# distant full-map search is paid once, rather than again every 1.2 s.
	# The two-second stuck detector clears repath_at to request recovery.
	if not changed and float(repath_at.get(key,0))>0 and not PackedVector3Array(paths.get(key,PackedVector3Array())).is_empty():return
	if not changed and now<float(repath_at.get(key,0)):return
	repath_at[key]=now+1.2+float(posmod(key,5))*.1;destinations[key]=to
	if is_instance_valid(game.navigation) and game.navigation.ready:
		var path: PackedVector3Array=game.navigation.path_to(actor.global_position,to)
		if path.is_empty():blocked_until["%d:%s"%[key,str(to)]]=now+12.;paths.erase(key);actor.bot_target=actor.global_position
		else:paths[key]=path
	elif not is_instance_valid(game.afghan_map):paths[key]=PackedVector3Array([to]) # Flat unit fixture only.
	else:paths.erase(key);actor.bot_target=actor.global_position

