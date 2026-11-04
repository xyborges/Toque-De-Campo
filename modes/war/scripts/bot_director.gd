extends Node
class_name WarBotDirector

# The authority owns this director in offline operations and online bot-filled
# rooms. Bots use ordinary actors, hitboxes, inventory and authoritative shots.
# is_npc remains false: the original training NPC is an unarmed melee attacker.
const FIRST_ID:=10001
const BOT_ROLES: Array[String]=["soldier","medic","soldier","antitank","marksman","soldier"]
const CALLSIGNS: Array[String]=["RAMOS","LIMA","COSTA","NUNES","SILVA","ROCHA","VOLK","SOKOL","BURAN","KEDR","RYS","URAL"]
var game: WarGame
var bots: Dictionary={}
var navigation: BotRoutes
var enabled:=false
var online_fill:=false
var next_id:=FIRST_ID
var reconcile_clock:=0.0
var next_spawn_team:=0
var broadcast_clock:=0.0
var think_cursor:=0
var think_accumulator:=0.
var transit:=WarBotTransit.new()
var squads: Dictionary={}
var strategy_at:=0.0
var metrics_at:=0.
var bot_probe_enabled:=false
var next_cover_query:=0.
# Shared states avoid per-passenger timers and reboarding failed vehicles.
var blocked_vehicles: Dictionary={}
var evacuations: Dictionary={}
var bot_ids: Array=[]
var spatial: Dictionary={}
var spatial_at:=0.0
var world_los: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.new()
var diagnostics: Dictionary={"moves":0,"shots":0,"reloads":0,"deployments":0,"routes":0,"deploy_failures":0,"target_acquisitions":0,"clear_shot_ticks":0,"shot_attempts":0,"shot_rejections":0,"grenades":0,"armor_engagements":0,"vehicle_evacuations":0,"vehicle_detours":0}

class BotRoutes extends OfflineDirector:
	var heights:=PackedFloat32Array()
	func setup(owner_game: Node3D) -> void:
		game=owner_game;cell=4.
		origin=Vector2(-600,-260) if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN else Vector2(-350,-250)
		# Never load a Ukrainian baked navgrid on Afghan terrain. Afghan
		# currently uses a local grid around the central village plus transit.
		if load("res://scripts/maps/navigation_cache.gd").install(self,WarRules.map_content()):return
		# Central cover uses a fine local grid. Long transit uses the road graph
		# instead of searching a dense grid across all 3.5 kilometres.
		grid.region=Rect2i(Vector2i.ZERO,Vector2i(176,126))
		grid.cell_size=Vector2.ONE*cell;grid.offset=origin
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		var width:=grid.region.size.x;var depth:=grid.region.size.y
		heights.resize(width*depth)
		for z in depth:
			for x in width:
				var p:=grid.get_point_position(Vector2i(x,z))
				heights[z*width+x]=WarTerrain.height_at(p.x,p.y)
		for z in range(1,depth-1):
			for x in range(1,width-1):
				var slope_x:=absf(heights[z*width+x+1]-heights[z*width+x-1])/(cell*2)
				var slope_z:=absf(heights[(z+1)*width+x]-heights[(z-1)*width+x])/(cell*2)
				var slope:=maxf(slope_x,slope_z)
				if slope>.80: grid.set_point_solid(Vector2i(x,z),true)
				elif slope>.25: grid.set_point_weight_scale(Vector2i(x,z),1.+slope*1.5)
		# Reuse the training director's static-bound approach. Terrain itself is
		# sampled above; roofs higher than a standing actor do not block a route.
		for shape_node: CollisionShape3D in game.world_root.find_children("*","CollisionShape3D",true,false):
			var owner:=shape_node.get_parent()
			if shape_node.disabled or not (owner is StaticBody3D or bool(owner.get_meta("war_wreck",false))): continue
			var shape: Shape3D=shape_node.shape;var bounds:=AABB();var size:=Vector3.ZERO
			if shape is BoxShape3D: size=shape.size
			elif shape is CylinderShape3D: size=Vector3(shape.radius*2,shape.height,shape.radius*2)
			elif shape is SphereShape3D: size=Vector3.ONE*shape.radius*2
			elif shape is ConvexPolygonShape3D:
				if shape.points.is_empty(): continue
				bounds=AABB(shape.points[0],Vector3.ZERO)
				for point: Vector3 in shape.points: bounds=bounds.expand(point)
			else: continue
			if size!=Vector3.ZERO: bounds=AABB(-size*.5,size)
			bounds=shape_node.global_transform*bounds
			var floor_y:=WarTerrain.height_at(bounds.get_center().x,bounds.get_center().z)
			if bounds.end.y<floor_y+.20 or bounds.position.y>floor_y+1.85: continue
			# A regional cell represents its full square, not only its centre.
			# Including half a cell keeps thin walls between centres from vanishing
			# from navigation. Fine steering still uses the real physics geometry.
			var clearance:=.42+cell*.5
			var low:=Vector2i(ceil((bounds.position.x-clearance-origin.x)/cell),ceil((bounds.position.z-clearance-origin.y)/cell))
			var high:=Vector2i(floor((bounds.end.x+clearance-origin.x)/cell),floor((bounds.end.z+clearance-origin.y)/cell))
			var rect:=Rect2i(low,high-low+Vector2i.ONE).intersection(grid.region)
			if rect.has_area(): grid.fill_solid_region(rect,true)
	func world_point(id: Vector2i) -> Vector3:
		var p:=grid.get_point_position(id)
		return WarTerrain.point(p.x,p.y)+Vector3.UP*.08
	func direction_to(actor: WarPlayer,goal_position: Vector3,clock: float) -> Vector3:
		var direct:=goal_position-actor.global_position;direct.y=0
		if direct.length_squared()<.64: return Vector3.ZERO
		if direct.length_squared()<225 and game.npc_line_clear(actor.global_position,goal_position,.40): return direct.normalized()
		var goal:=nearest(goal_position);var start:=nearest(actor.global_position)
		var record: Dictionary=routes.get(actor.peer_id,{})
		if record.is_empty() or clock>float(record.get("until",0)) or record.goal!=goal:
			var path: Array[Vector2i]=[]
			if walkable(start) and walkable(goal): path=grid.get_id_path(start,goal,true)
			record={"goal":goal,"path":path,"index":1 if path.size()>1 else 0,"until":clock+1.25+posmod(actor.peer_id,5)*.09}
			routes[actor.peer_id]=record
		var path: Array=record.path
		while int(record.index)<path.size():
			var direction:=world_point(path[int(record.index)])-actor.global_position;direction.y=0
			if direction.length_squared()>1.: return direction.normalized()
			record.index=int(record.index)+1
		return direct.normalized() if game.npc_line_clear(actor.global_position,goal_position,.40) else Vector3.ZERO

func setup(owner_game: WarGame,fill_online:=false) -> void:
	game=owner_game
	bot_probe_enabled="--bot-ai-probe" in OS.get_cmdline_user_args()
	online_fill=fill_online
	enabled=game.multiplayer.is_server() and (bool(game.get("offline_operation")) or (fill_online and game.online))
	set_physics_process(enabled)
	if not enabled: return
	transit.configure(WarRules.map_content())
	navigation=BotRoutes.new();navigation.setup(game)

func populate(human_team: int) -> void:
	if not _active() or human_team not in [0,1] or not bots.is_empty(): return
	var serial:=0
	# All slots exist before deployment so normal team-limit validation sees
	# balanced teams, rather than refusing the second consecutive teammate.
	for team in [human_team,1-human_team]:
		var count:=game.offline_participants/2+(game.offline_participants%2 if team==human_team else 0)-(1 if team==human_team else 0)
		for slot in count:
			var id:=FIRST_ID+serial;serial+=1
			while game.players.has(id): id+=WarRules.CAPACITY
			var actor:=game._spawn_player(id,false,false,WarTerrain.point(WarRules.BASES[team].x,WarRules.BASES[team].z)) as WarPlayer
			actor.name=("ALIADO " if team==human_team else "OPONENTE ")+CALLSIGNS[(slot+(0 if team==human_team else 6))%CALLSIGNS.size()]
			actor.set_meta("war_bot",true)
			var role:=BOT_ROLES[slot%BOT_ROLES.size()]
			game.members[id]={"team":team,"role":role,"deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":WarRules.launcher_for_team(team),"pending":{},"last_gadget":-100.,"bot":true,"bot_lane":slot}
			# Offline combat stays on the three central frontline objectives.
			# Sending bots to distant port objectives leaves a small offline match
			# spread across the whole 3.5 km map and makes firefights too rare.
			var available: Array=["A","B","C"]
			if team==1: available.reverse()
			var objective:=str(available[slot%available.size()])
			var group:=str(team)+":"+str(slot/3)
			if not squads.has(group): squads[group]={"team":team,"members":[],"objective":objective}
			squads[group].members.append(id)
			bots[id]={"team":team,"role":role,"objective":objective,"squad":group,"slot":slot,"target":0,"direction":Vector3.ZERO,"goal":Vector3.ZERO,"line_clear":false,"next_shot":game.war_clock+1.+slot*.16,"next_deploy_attempt":0.,"burst":3+slot%3,"next_support":0.,"last_position":actor.global_position,"stuck":0.,"reaction_until":0.,"vehicle_path":[],"vehicle_goal":"","vehicle_index":0,"vehicle_stuck":0.,"vehicle_check_at":0.,"boarding_until":0.,"enemy_seen_at":-100.}
	bot_ids=bots.keys()
	for id in bots: _deploy_bot(id)

func reset() -> void:
	if navigation: navigation.routes.clear()
	blocked_vehicles.clear();evacuations.clear()
	metrics_at=0.
	think_cursor=0;think_accumulator=0
	for id in bots:
		bots[id].target=0;bots[id].direction=Vector3.ZERO;bots[id].next_shot=game.war_clock+1.
		bots[id].stuck=0.
		bots[id].boarded_once=false;bots[id].vehicle_path=[];bots[id].foot_path=[]

func stop() -> void:
	enabled=false;set_physics_process(false)
	if navigation: navigation.routes.clear()
	for id in bots:
		var actor:=game.players.get(id) as WarPlayer if is_instance_valid(game) else null
		if is_instance_valid(actor): actor.trigger_held=false;actor.velocity=Vector3.ZERO

func _active() -> bool:
	return enabled and is_instance_valid(game) and (bool(game.get("offline_operation")) or (online_fill and game.online)) and game.multiplayer.is_server() and not game.closing

func remove_bot(id: int) -> void:
	if not bots.has(id): return
	var record: Dictionary=bots[id]
	if is_instance_valid(game.vehicle_system): game.vehicle_system.release(id,true)
	if is_instance_valid(game.war_fx): game.war_fx.discard_owner(id)
	if navigation: navigation.routes.erase(id)
	if squads.has(record.squad):
		squads[record.squad].members.erase(id)
		if squads[record.squad].members.is_empty(): squads.erase(record.squad)
	game.members.erase(id);game.match_stats.remove(id);game.shot_clocks.erase(id);game.shot_sequences.erase(id)
	var actor:=game.players.get(id) as WarPlayer
	game.players.erase(id);bots.erase(id);bot_ids=bots.keys()
	if game.online: game._broadcast("remote_player_left",[id])
	if is_instance_valid(actor): game._retire_avatar(actor)

func evict_one(team:=-1) -> bool:
	for id in bot_ids.duplicate():
		if team<0 or int(bots[id].team)==team: remove_bot(int(id));return true
	return false

func clear_online() -> void:
	if not online_fill: return
	for id in bot_ids.duplicate(): remove_bot(int(id))

func _online_targets() -> Array:
	var humans:=[0,0];var total:=0
	for id in game.members:
		var member: Dictionary=game.members[id]
		if bool(member.get("bot",false)): continue
		total+=1
		if int(member.team) in [0,1]: humans[int(member.team)]+=1
	if humans[0]+humans[1]<1: return [0,0]
	var targets:=[14,14]
	# Keep bot population fixed; balance the smaller human team first.
	var difference:=int(humans[0])-int(humans[1]);var transfer:=floori(absf(float(difference))*.5)
	if difference>1: targets[0]-=transfer;targets[1]+=transfer
	elif difference< -1:targets[1]-=transfer;targets[0]+=transfer
	var unassigned: int=0
	for i in unassigned:
		var side:=0 if targets[0]>=targets[1] else 1
		targets[side]=maxi(0,targets[side]-1)
	return targets

func _add_online_bot(team: int,slot: int) -> void:
	var creation_started:=Time.get_ticks_usec()
	while game.players.has(next_id) or next_id in game.multiplayer.get_peers(): next_id+=1
	var id:=next_id;next_id+=1
	var actor:=game._spawn_player(id,false,false,WarTerrain.point(WarRules.BASES[team].x,WarRules.BASES[team].z)) as WarPlayer
	actor.name="BOT "+CALLSIGNS[(slot+team*6)%CALLSIGNS.size()];actor.set_meta("war_bot",true)
	var role:=BOT_ROLES[slot%BOT_ROLES.size()]
	game.members[id]={"team":team,"role":role,"deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":WarRules.launcher_for_team(team),"pending":{},"last_gadget":-100.,"bot":true,"bot_lane":slot}
	var available: Array=["A","B","C","D","E"]
	if team==1: available.reverse()
	var objective:=str(available[slot%available.size()]);var group:=str(team)+":"+str(slot/3)
	if not squads.has(group): squads[group]={"team":team,"members":[],"objective":objective}
	squads[group].members.append(id)
	bots[id]={"team":team,"role":role,"objective":objective,"squad":group,"slot":slot,"target":0,"direction":Vector3.ZERO,"goal":Vector3.ZERO,"line_clear":false,"next_shot":game.war_clock+1.+slot*.16,"next_deploy_attempt":0.,"burst":3+slot%3,"next_support":0.,"last_position":actor.global_position,"stuck":0.,"reaction_until":0.,"vehicle_path":[],"vehicle_goal":"","vehicle_index":0,"vehicle_stuck":0.,"vehicle_check_at":0.,"boarding_until":0.,"enemy_seen_at":-100.}
	bot_ids=bots.keys()
	game._broadcast("remote_add_player",[id,actor.name,{},actor.global_position])
	_deploy_bot(id)
	GameDiagnostics.record("war_bot_created",{"peer":id,"team":team,"milliseconds":(Time.get_ticks_usec()-creation_started)*.001,"total":bots.size()})

func _reconcile_online() -> void:
	if not online_fill: return
	var target:=_online_targets()
	var present_by_team: Array=[[],[]]
	var totals:=[0,0]
	for member: Dictionary in game.members.values():
		if int(member.team) in [0,1]:totals[int(member.team)]+=1
	for id in bot_ids:present_by_team[int(bots[id].team)].append(id)
	for team in [0,1]:
		var present: Array=present_by_team[team]
		if present.size()>int(target[team]): remove_bot(int(present[-1]));return
	if game.players.size()>=WarRules.CAPACITY:return
	var chosen:=-1
	for team in [next_spawn_team,1-next_spawn_team]:
		if present_by_team[team].size()<int(target[team]) and (chosen<0 or totals[team]<totals[chosen]):chosen=team
	if chosen<0:return
	var used: Array=[]
	for id in present_by_team[chosen]:used.append(int(bots[id].slot))
	for slot in 20:
		if slot not in used:
			_add_online_bot(chosen,slot);next_spawn_team=1-chosen;return

func _deploy_bot(id: int) -> void:
	var record: Dictionary=bots[id]
	var weapon: String=WarRules.primary_for(str(record.role),int(record.team))[0]
	if game._deploy(id,int(record.team),str(record.role),weapon,WarRules.launcher_for_team(int(record.team)),"base"):
		var actor:=game.players[id] as WarPlayer
		actor.camera.current=false
		game._register_match_stat(actor)
		record.target=0;record.direction=Vector3.ZERO;record.next_shot=game.war_clock+1.
		record.next_deploy_attempt=0.;record.boarded_once=false;record.vehicle_path=[];record.foot_path=[]
		record.target_vehicle="";record.grenade_throw_at=0.;record.next_grenade=game.war_clock+2.+float(id%7)*.6
		diagnostics.deployments=int(diagnostics.deployments)+1
	else:
		diagnostics.deploy_failures=int(diagnostics.deploy_failures)+1
		record.next_deploy_attempt=game.war_clock+2.

func _physics_process(delta: float) -> void:
	if not _active(): return
	if online_fill:
		reconcile_clock+=delta
		if reconcile_clock>=.25: reconcile_clock=0;_reconcile_online()
	if bots.is_empty(): return
	# Extra AI telemetry is opt-in to avoid periodic disk writes during play.
	if bot_probe_enabled and game.war_clock>=metrics_at:
		metrics_at=game.war_clock+15.
		var active_targets:=0;var in_vehicles:=0
		for bot_id: int in bot_ids:
			var state: Dictionary=bots[bot_id]
			if int(state.get("target",0))>0 or not str(state.get("target_vehicle","")).is_empty(): active_targets+=1
			var bot_actor:=game.players.get(bot_id) as WarPlayer
			if is_instance_valid(bot_actor) and not bot_actor.vehicle_id.is_empty(): in_vehicles+=1
		GameDiagnostics.record("war_bot_metrics",{"bots":bot_ids.size(),"engaged":active_targets,"in_vehicles":in_vehicles,"shots":diagnostics.shots,"grenades":diagnostics.grenades,"armor_engagements":diagnostics.armor_engagements,"vehicle_evacuations":diagnostics.vehicle_evacuations,"vehicle_detours":diagnostics.vehicle_detours})
	if game.match_ended:
		for id in bots:
			var actor:=game.players.get(id) as WarPlayer
			if is_instance_valid(actor): actor.velocity=Vector3.ZERO;actor.trigger_held=false
		return
	var ids:=bot_ids
	if game.war_clock>=strategy_at:
		strategy_at=game.war_clock+3.;_assign_objectives()
	if game.war_clock>=spatial_at:
		spatial_at=game.war_clock+.2;_index_actors()
	think_accumulator=minf(.05,think_accumulator+delta)
	# Stagger costly decisions without processing a bot's entire brain every tick.
	# 40 shared decisions/s supports 28 bots today and scales without a timer per bot.
	if think_accumulator>=.025:
		think_accumulator-=.025
		var id: int=ids[think_cursor%ids.size()];think_cursor+=1
		_think(id)
	for id: int in ids:
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed: continue
		if not actor.vehicle_id.is_empty():
			_drive(actor,bots[id],delta);continue
		# WarPlayer owns buoyancy and swimming once per physics tick.
		if actor.in_water(): continue
		_move(actor,bots[id],delta)
		var record: Dictionary=bots[id]
		var target:=game.players.get(int(record.target)) as WarPlayer
		if is_instance_valid(target) and target.hp>0 and not actor.grenade_selected and actor.grenade_held_id.is_empty() and bool(record.get("line_clear",false)): _shoot(actor,target,record)
	if online_fill:
		broadcast_clock+=delta
		if GameNetworkCadence.due(broadcast_clock,.1):
			broadcast_clock=GameNetworkCadence.consume(broadcast_clock,.1)
			var batch: Array=[]
			for id: int in bot_ids:
				var actor:=game.players.get(id) as WarPlayer
				if is_instance_valid(actor) and actor.deployed:
					batch.append([id,actor.global_position,actor.yaw,actor.pitch,actor.weapon_id,actor.hp,actor.crouched,actor.life_id,actor.kills,actor.deaths,2 if actor.iron_sights else (1 if actor.aiming else 0),actor.lean,game.network_diagnostics.next_pose_sequence(id,actor.life_id)])
					if batch.size()>=4: game._broadcast("war_bot_states",[batch]);batch=[]
			if not batch.is_empty(): game._broadcast("war_bot_states",[batch])

func _think(id: int) -> void:
	var actor:=game.players.get(id) as WarPlayer
	if not is_instance_valid(actor) or not game.members.has(id): return
	if actor.hp<=0 or not actor.deployed:
		if game.war_clock>=float(game.members[id].ready_at) and game.war_clock>=float(bots[id].get("next_deploy_attempt",0.)): _deploy_bot(id)
		return
	var record: Dictionary=bots[id]
	if not actor.vehicle_id.is_empty():
		var own_vehicle:=game.vehicle_system.find_target(actor.vehicle_id) as WarVehicle
		if not is_instance_valid(own_vehicle) or own_vehicle.driver!=actor.peer_id: return
		var enemy:=_vehicle_visible_infantry(own_vehicle)
		var enemy_armor:=_vehicle_visible_armor(own_vehicle)
		record.target=enemy.peer_id if is_instance_valid(enemy) else 0
		record.target_vehicle=enemy_armor.vehicle_id if is_instance_valid(enemy_armor) else ""
		record.line_clear=is_instance_valid(enemy)
		return
	var target:=_visible_enemy(actor)
	if actor.war_class=="soldier": _grenade_tactics(actor,record,target)
	var armored:=_visible_vehicle(actor) if actor.war_class=="antitank" and int(game.members[id].get("charges",0))>0 else null
	if is_instance_valid(armored) and (not is_instance_valid(target) or actor.position.distance_to(target.position)>45.):
		if _fight_armor(actor,record,armored): return
	if actor.gadget_equipped and actor.war_class=="antitank":
		actor.set_gadget(false,actor.gadget)
		game._broadcast("gadget_selected",[actor.peer_id,actor.gadget,false])
	if not is_instance_valid(target) and actor.grenade_held_id.is_empty() and _board(actor,record): return
	if is_instance_valid(target) and int(record.target)!=target.peer_id: record.reaction_until=game.war_clock+.5+(id%5)*.09
	record.target=target.peer_id if target else 0
	record.line_clear=is_instance_valid(target) and _has_clear_shot(actor,target)
	if is_instance_valid(target): diagnostics.target_acquisitions=int(diagnostics.target_acquisitions)+1
	if bool(record.line_clear): diagnostics.clear_shot_ticks=int(diagnostics.clear_shot_ticks)+1
	var data: Dictionary=WarRules.OBJECTIVES[str(record.objective)]
	var phase:=float(id%7)*TAU/7.+floorf(game.war_clock/12.)*.8
	var formation:=_formation(actor,record)
	if actor.war_class=="marksman":
		# Marksmen hold an offset firing lane instead of entering the capture
		# circle with the assault pair.  Their sniper remains relevant while the
		# squad advances and they still move when the front changes objective.
		formation+=Vector3(-34. if actor.war_team==0 else 34.,0,(id%3-1)*13.)
	var goal:=WarTerrain.point(data.position.x+cos(phase)*9+formation.x,data.position.z+sin(phase)*9+formation.z)
	record.goal=goal
	var direction:=_route_direction(actor,goal,record)
	diagnostics.routes=int(diagnostics.routes)+1
	if target:
		_look_at(actor,target)
		if not bool(record.line_clear):
			# A wall should make a bot maneuver toward a firing lane, not forget
			# the enemy and idle on its current objective.
			direction=navigation.direction_to(actor,target.global_position,game.war_clock)
		elif actor.global_position.distance_to(target.global_position)<(110 if actor.war_class=="marksman" else 65):
			var cover:=_cover_goal(actor,target,record)
			direction=_route_direction(actor,cover,record) if cover.is_finite() and actor.global_position.distance_squared_to(cover)>1. else Vector3.ZERO
	elif direction.length_squared()>.01:
		actor.yaw=atan2(-direction.x,-direction.z);actor.pitch=0;actor.rotation.y=actor.yaw
		actor.camera_pivot.rotation.x=0;actor.aiming=false
	record.direction=_avoid(actor,direction)
	if game.war_clock>=float(record.next_support):
		record.next_support=game.war_clock+3.
		_support(actor)

func _cover_goal(actor: WarPlayer,enemy: WarPlayer,record: Dictionary) -> Vector3:
	if int(record.get("cover_enemy",-1))==enemy.peer_id and game.war_clock<float(record.get("cover_until",0.)):
		return record.get("cover_point",Vector3.INF)
	if game.war_clock<next_cover_query:return Vector3.INF
	next_cover_query=game.war_clock+.5
	record.cover_enemy=enemy.peer_id;record.cover_until=game.war_clock+3.;record.cover_point=Vector3.INF
	var towards:=enemy.global_position-actor.global_position;towards.y=0.
	if towards.length_squared()<4.:return Vector3.INF
	var side:=towards.normalized().cross(Vector3.UP)
	var target: Vector3=enemy.hit_regions.chest.global_position
	var space:=game.get_world_3d().direct_space_state
	for sign_value in [-1.,1.]:
		var offset:=actor.global_position+side*float(sign_value)*3.
		var point:=WarTerrain.point(offset.x,offset.z)
		if absf(point.y-actor.global_position.y)>1.2:continue
		var body:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.9,target,1,[actor.get_rid(),enemy.get_rid()])
		if space.intersect_ray(body).is_empty():continue
		var eye:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.55,target,1,[actor.get_rid(),enemy.get_rid()])
		if space.intersect_ray(eye).is_empty():record.cover_point=point;return point
	return Vector3.INF


func _grenade_tactics(actor: WarPlayer,record: Dictionary,target: WarPlayer) -> void:
	if not is_instance_valid(game.grenades_system) or not game.grenade_allowed(actor): return
	var held:=not actor.grenade_held_id.is_empty()
	var throw_at:=float(record.get("grenade_throw_at",0.))
	if held and throw_at>0. and game.war_clock>=throw_at:
		var point: Vector3=record.get("grenade_goal",actor.global_position-actor.global_basis.z*22.)
		var offset:=point-actor.camera_pivot.global_position
		var horizontal:=Vector2(offset.x,offset.z).length()
		if horizontal<1.: return
		var ratio:=clampf(9.81*horizontal/(GameGrenades.THROW_SPEED*GameGrenades.THROW_SPEED),0.,.98)
		var angle:=.5*asin(ratio)+.04
		var direction:=Vector3(offset.x/horizontal*cos(angle),sin(angle),offset.z/horizontal*cos(angle)).normalized()
		actor.yaw=atan2(-direction.x,-direction.z);actor.pitch=angle
		actor.rotation.y=actor.yaw;actor.camera_pivot.rotation.x=angle
		if game.grenades_system.accept(actor,actor.life_id,actor.grenade_sequence,actor.camera_pivot.global_position,direction):
			record.grenade_throw_at=0.
		else: record.grenade_throw_at=game.war_clock+.1
		return
	if held or not is_instance_valid(target) or actor.grenades<=0 or game.war_clock<float(record.get("next_grenade",0.)): return
	var distance:=actor.global_position.distance_to(target.global_position)
	if distance<17. or distance>31.: return
	if not _has_clear_shot(actor,target): return
	# Avoid grenades near the allied capture group.
	for ally: WarPlayer in game.players.values():
		if ally==actor or ally.hp<=0 or not ally.deployed or ally.war_team!=actor.war_team: continue
		if ally.global_position.distance_squared_to(target.global_position)<10.*10.: return
	actor.grenade_sequence+=1
	if game.grenades_system.prime(actor,actor.life_id,actor.grenade_sequence):
		game.members[actor.peer_id].shield=0.
		record.grenade_goal=target.global_position+Vector3.UP*.2
		record.grenade_throw_at=game.war_clock+2.2
		record.next_grenade=game.war_clock+14.
		diagnostics.grenades=int(diagnostics.grenades)+1

# A vehicle is a separate tactical target. Infantry hidden inside one cannot
# be treated as a visible soldier, nor can rifle rounds penetrate a tank.
func _visible_vehicle(actor: WarPlayer) -> WarVehicle:
	if not is_instance_valid(game.vehicle_system): return null
	var best: WarVehicle=null
	var distance_best:=500.*500.
	for candidate: WarVehicle in game.vehicle_system.vehicles.values():
		if not is_instance_valid(candidate) or candidate.destroyed or candidate.hp<=0 or candidate.team==actor.war_team or candidate is WarShip: continue
		var distance:=actor.global_position.distance_squared_to(candidate.global_position)
		if distance>=distance_best: continue
		var target:=candidate.global_position+Vector3.UP*1.3
		var query:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,target,1|16,[actor.get_rid()])
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider")!=candidate: continue
		best=candidate;distance_best=distance
	return best

func _aim_armor(actor: WarPlayer,vehicle: WarVehicle) -> void:
	var point:=vehicle.global_position+Vector3.UP*1.25
	var item: Dictionary=WarRules.SPECIAL[actor.gadget]
	var travel:=actor.global_position.distance_to(point)/maxf(1.,float(item.speed))
	# Lock-on launchers must aim at the hull itself; aggressive lead can
	# move the 4-degree seeker outside its valid target cone.
	if actor.gadget=="rpg":
		point+=vehicle.velocity*minf(1.5,travel*.45)
		point.y+=float(item.gravity)*travel*travel*.50
	var aim: Vector3=(point-actor.camera_pivot.global_position).normalized()
	actor.yaw=atan2(-aim.x,-aim.z)
	actor.pitch=clampf(asin(clampf(aim.y,-1.,1.)),-1.2,1.2)
	actor.rotation.y=actor.yaw;actor.camera_pivot.rotation.x=actor.pitch
	actor.aiming=true;actor.iron_sights=false
	actor._update_weapon_pose()

func _fight_armor(actor: WarPlayer,record: Dictionary,vehicle: WarVehicle) -> bool:
	if actor.war_class!="antitank" or not bool(actor.get_meta("class_equipment",true)) or int(game.members[actor.peer_id].get("charges",0))<=0: return false
	var launcher:=WarRules.launcher_for_team(actor.war_team)
	if launcher.is_empty(): return false
	if not actor.gadget_equipped or actor.gadget!=launcher:
		actor.set_gadget(true,launcher)
		if not actor.gadget_equipped: return false
		game._broadcast("gadget_selected",[actor.peer_id,launcher,true])
		record.next_armor_shot=game.war_clock+1.6
	record.target=0;record.line_clear=false
	if str(record.get("target_vehicle",""))!=vehicle.vehicle_id:
		diagnostics.armor_engagements=int(diagnostics.armor_engagements)+1
	record.target_vehicle=vehicle.vehicle_id
	var distance:=actor.global_position.distance_to(vehicle.global_position)
	var effective:=340. if launcher=="stinger" else 210.
	if distance>effective:
		record.direction=_avoid(actor,_route_direction(actor,vehicle.global_position,record))
	else: record.direction=Vector3.ZERO
	_aim_armor(actor,vehicle)
	if distance<=effective and distance>14. and game.war_clock>=float(record.get("next_armor_shot",0.)):
		if _friendly_lane(actor,vehicle.global_position+Vector3.UP*1.2,2.):
			game.vehicle_system.use_gadget(actor.peer_id)
			record.next_armor_shot=game.war_clock+(1.8 if launcher=="stinger" else 2.)
	return true

func _vehicle_line_clear(vehicle: WarVehicle,point: Vector3,target_vehicle: WarVehicle=null) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(vehicle.muzzle.global_position,point,1|16,[vehicle.get_rid()])
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (is_instance_valid(target_vehicle) and hit.get("collider")==target_vehicle)

func _vehicle_visible_infantry(vehicle: WarVehicle) -> WarPlayer:
	var best: WarPlayer=null
	var distance_best:=420.*420.
	for candidate: WarPlayer in game.players.values():
		if not is_instance_valid(candidate) or candidate.hp<=0 or not candidate.deployed or candidate.war_team==vehicle.team or not candidate.vehicle_id.is_empty(): continue
		var distance:=vehicle.global_position.distance_squared_to(candidate.global_position)
		if distance>=distance_best: continue
		if not _vehicle_line_clear(vehicle,candidate.hit_regions.chest.global_position): continue
		best=candidate;distance_best=distance
	return best

func _vehicle_visible_armor(vehicle: WarVehicle) -> WarVehicle:
	var best: WarVehicle=null
	var distance_best:=700.*700.
	for candidate: WarVehicle in game.vehicle_system.vehicles.values():
		if not is_instance_valid(candidate) or candidate==vehicle or candidate.destroyed or candidate.hp<=0 or candidate.team==vehicle.team or candidate is WarShip: continue
		var distance:=vehicle.global_position.distance_squared_to(candidate.global_position)
		if distance>=distance_best: continue
		if not _vehicle_line_clear(vehicle,candidate.global_position+Vector3.UP*1.3,candidate): continue
		best=candidate;distance_best=distance
	return best

func _visible_enemy(actor: WarPlayer) -> WarPlayer:
	var visible: WarPlayer;var visible_distance:=INF
	var obstructed: WarPlayer;var obstructed_distance:=INF
	var limit:=pow(280. if actor.war_class=="marksman" else 190.,2)
	for other: WarPlayer in game.players.values():
		if other==actor or other.hp<=0 or not other.deployed or other.war_team==actor.war_team or not other.vehicle_id.is_empty(): continue
		var distance:=actor.global_position.distance_squared_to(other.global_position)
		if distance>=limit: continue
		if distance>25.*25. and int(bots[actor.peer_id].target)!=other.peer_id:
			var direction: Vector3=(other.position-actor.position).normalized()
			if direction.dot(-actor.global_basis.z)<-.20: continue
		if _has_clear_shot(actor,other):
			if distance<visible_distance: visible=other;visible_distance=distance
		# No tracking enemies hidden behind a wall: only pursue a recently
		# seen target, using its last observed point instead of omniscience.
	# Prefer any enemy with a firing lane. If all are covered, keep the nearest
	# one as a movement goal so the bot can path around the obstruction.
	return visible

func _has_clear_shot(actor: WarPlayer,target: WarPlayer) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,target.hit_regions.chest.global_position,1,[actor.get_rid(),target.get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _look_at(actor: WarPlayer,target: WarPlayer) -> Vector3:
	var item:=CombatRules.weapon(actor.weapon_id)
	var point: Vector3=target.hit_regions.chest.global_position
	var travel:=minf(.8,actor.global_position.distance_to(point)/maxf(1,float(item.speed)))
	point+=target.velocity*travel*.40+Vector3.UP*float(item.gravity)*travel*travel*.45
	var phase:=game.war_clock*1.7+actor.peer_id*.37
	var error:=.009 if actor.war_class=="marksman" else .022
	var direction: Vector3=(point-actor.camera_pivot.global_position).normalized()
	direction=(direction+Vector3(sin(phase)*error,cos(phase*.73)*error*.65,cos(phase)*error)).normalized()
	actor.yaw=atan2(-direction.x,-direction.z)
	actor.pitch=clampf(asin(direction.y),-1.2,1.2)
	actor.rotation.y=actor.yaw;actor.camera_pivot.rotation.x=actor.pitch
	actor.aiming=true;actor.iron_sights=false
	return direction

func _shoot(actor: WarPlayer,target: WarPlayer,record: Dictionary) -> void:
	if game.war_clock<float(record.next_shot) or game.war_clock<float(record.reaction_until) or actor.reload_left>0 or not game._eligible(actor.peer_id): return
	if CombatRules.limb_disability_enabled(game):
		if float(actor.limbs.armR)<=0:return
		if actor.weapon_id in ["fal","ak","sniper","g3"] and float(actor.limbs.armL)<=0:
			game._equip_server(actor,"glock");return
	# Shared cadence uses real monotonic time; do not spam rejected shots
	# during physics catch-up after a slow frame.
	var now:=Time.get_ticks_msec()*.001
	if now<float(game.shot_clocks.get(actor.peer_id,-100.))+float(CombatRules.weapon(actor.weapon_id).cooldown): return
	if not _friendly_lane(actor,target.hit_regions.chest.global_position): return
	diagnostics.shot_attempts=int(diagnostics.shot_attempts)+1
	if int(actor.ammo.get(actor.weapon_id,0))<=0:
		if int(actor.reserves.get(actor.weapon_id,0))>0:
			game._server_reload(actor.peer_id,actor.weapon_id);diagnostics.reloads=int(diagnostics.reloads)+1
		elif actor.weapon_id!="glock": game._equip_server(actor,"glock")
		record.next_shot=game.war_clock+.3
		return
	var direction:=_look_at(actor,target)
	actor._update_weapon_pose()
	var before:=int(actor.ammo.get(actor.weapon_id,0))
	actor.shot_sequence+=1
	game._server_accept_shot(actor.peer_id,actor.shot_sequence,actor.life_id,actor.camera_pivot.global_position,direction,actor.weapon_id,1)
	if int(actor.ammo.get(actor.weapon_id,0))<before: diagnostics.shots=int(diagnostics.shots)+1
	else: diagnostics.shot_rejections=int(diagnostics.shot_rejections)+1
	var item:=CombatRules.weapon(actor.weapon_id)
	record.burst=int(record.burst)-1
	var pause:=0.
	if int(record.burst)<=0:
		record.burst=3+actor.peer_id%3;pause=.65+(actor.peer_id%4)*.12
	record.next_shot=game.war_clock+float(item.cooldown)+pause

func _avoid(actor: WarPlayer,direction: Vector3) -> Vector3:
	if direction.length_squared()<.01: return Vector3.ZERO
	var start:=actor.global_position+Vector3.UP*.9
	var query:=PhysicsRayQueryParameters3D.create(start,start+direction*2.0,1,[actor.get_rid()])
	var space:=game.get_world_3d().direct_space_state
	if space.intersect_ray(query).is_empty(): return direction
	for angle in [.60,-.60,1.20,-1.20,1.90,-1.90,2.6,-2.6]:
		var trial:=direction.rotated(Vector3.UP,angle)
		query.to=start+trial*2.
		if space.intersect_ray(query).is_empty(): return trial
	return Vector3.ZERO

func _move(actor: WarPlayer,record: Dictionary,delta: float) -> void:
	var direction: Vector3=record.direction
	var separation:=Vector3.ZERO
	for ally: WarPlayer in _near_actors(actor.global_position):
		if not is_instance_valid(ally) or not ally.is_inside_tree() or ally==actor or ally.hp<=0 or not ally.deployed or not ally.vehicle_id.is_empty(): continue
		var offset:=actor.global_position-ally.global_position;offset.y=0
		var distance:=offset.length()
		if distance>.01 and distance<1.1: separation+=offset/distance*(1.1-distance)
	if direction.length_squared()>.01: direction=(direction+separation*.8).normalized()
	var leg_factor: float=(.55 if float(actor.limbs.legL)<=0 else 1.)*(.55 if float(actor.limbs.legR)<=0 else 1.) if CombatRules.limb_disability_enabled(game) else 1.0
	var speed:=actor.move_speed*.78*leg_factor*(.6 if actor.reaction>0 else 1.)*actor.infantry_protection.multiplier()
	actor.velocity.x=direction.x*speed;actor.velocity.z=direction.z*speed
	if not actor.is_on_floor(): actor.velocity.y-=9.81*delta
	else: actor.velocity.y=minf(0,actor.velocity.y)
	GameStepMotion.move(actor,delta)
	if direction.length_squared()>.1:
		diagnostics.moves=int(diagnostics.moves)+1
		var moved:=actor.global_position.distance_squared_to(record.last_position)
		record.stuck=float(record.stuck)+delta if moved<.00001 else 0.
		if float(record.stuck)>1.2:
			navigation.routes.erase(actor.peer_id);record.direction=direction.rotated(Vector3.UP,.9 if actor.peer_id%2 else -.9);record.stuck=0.
	else: record.stuck=0.
	record.last_position=actor.global_position
	# WarPlayer owns the authoritative terrain-fall reset every tick.
	# Do not evaluate the expensive Afghan height a second time per bot.
	# WarPlayer already poses this actor once per physics tick. The director
	# moves it, never solves the complete arms/clothing rig a second time.

func _support(actor: WarPlayer) -> void:
	if not is_instance_valid(game.vehicle_system) or int(game.members[actor.peer_id].charges)<=0: return
	if actor.war_class=="medic":
		for ally: WarPlayer in game.players.values():
			if ally!=actor and ally.war_team==actor.war_team and ally.hp>0 and ally.hp<80 and actor.global_position.distance_to(ally.global_position)<3.8:
				game.vehicle_system.use_gadget(actor.peer_id);return
	elif actor.war_class=="soldier":
		for ally: WarPlayer in game.players.values():
			if ally!=actor and ally.war_team==actor.war_team and ally.hp>0 and int(ally.reserves.get(ally.weapon_id,0))<30 and actor.global_position.distance_to(ally.global_position)<3.8:
				game.vehicle_system.resupply(actor.peer_id);return

func _index_actors() -> void:
	spatial.clear()
	for actor: WarPlayer in game.players.values():
		if actor.hp<=0 or not actor.deployed: continue
		var cell:=Vector2i(floori(actor.position.x/8),floori(actor.position.z/8))
		if not spatial.has(cell): spatial[cell]=[]
		spatial[cell].append(actor)

func _near_actors(at: Vector3) -> Array:
	var result: Array=[];var centre:=Vector2i(floori(at.x/8),floori(at.z/8))
	for z in range(-1,2):
		for x in range(-1,2): result.append_array(spatial.get(centre+Vector2i(x,z),[]))
	return result

func _assign_objectives() -> void:
	var assignments: Dictionary={}
	for squad: Dictionary in squads.values():
		var centre:=Vector3.ZERO;var alive:=0
		for id in squad.members:
			var actor:=game.players.get(id) as WarPlayer
			if is_instance_valid(actor) and actor.hp>0 and actor.deployed: centre+=actor.position;alive+=1
		if alive==0: continue
		centre/=alive
		var team:=int(squad.team)
		var best: String=squad.objective;var best_score:=-INF
		for key: String in WarRules.OBJECTIVES:
			var objective: Dictionary=WarRules.OBJECTIVES[key]
			if not bool(objective.get("active",false)): continue
			# Keep the majority of infantry in the main front, without ignoring
			# urgent nearby threats to another objective.
			if key in ["D","E"] and int(bots[squad.members[0]].slot)>=3: continue
			var state: Dictionary=game.objective_states[key]
			var position: Vector3=objective.position
			var allies:=int(state.count[team]);var enemies:=int(state.count[1-team])
			var owned:=int(state.owner)==team
			var score: float=(210. if not owned else -30.)-centre.distance_to(position)*.12
			if owned and enemies>allies: score+=360.
			elif owned and enemies>0: score+=180.
			elif not owned and enemies>0: score+=90.
			if int(state.get("side",-1))==1-team and owned: score+=170.
			if not owned and allies>enemies: score+=35.
			score-=float(assignments.get(str(team)+key,0))*112.
			if key==squad.objective: score+=32.
			if score>best_score: best_score=score;best=key
		squad.objective=best;assignments[str(team)+best]=int(assignments.get(str(team)+best,0))+1
		for id in squad.members: bots[id].objective=best

func _formation(actor: WarPlayer,record: Dictionary) -> Vector3:
	var members: Array=squads[record.squad].members
	var leader:=game.players.get(members[0]) as WarPlayer
	var index:=members.find(actor.peer_id)
	if not is_instance_valid(leader) or leader==actor or leader.hp<=0 or not leader.vehicle_id.is_empty(): return Vector3.ZERO
	var gap:=actor.position.distance_to(leader.position)
	if gap<12.: return Vector3((index-1)*4,0,index*3)
	# Cohesion uses a shared objective and nearby leader, without stacking
	# every actor onto the same navigation point or waiting across the map.
	if gap<80.: return (leader.position-Vector3(WarRules.OBJECTIVES[record.objective].position)).limit_length(45.)
	return Vector3.ZERO

func _route_direction(actor: WarPlayer,goal: Vector3,record: Dictionary) -> Vector3:
	if absf(actor.position.x)<340 and actor.position.z>-245 and actor.position.z<245 and absf(goal.x)<340 and goal.z>-245 and goal.z<245:
		return navigation.direction_to(actor,goal,game.war_clock)
	if record.get("transit_goal",Vector3.INF).distance_to(goal)>25 or record.get("foot_path",[]).is_empty():
		record.foot_path=transit.path(actor.position,goal);record.foot_index=0;record.transit_goal=goal
	var path: Array=record.foot_path
	while int(record.foot_index)<path.size()-1 and actor.position.distance_to(path[int(record.foot_index)])<9: record.foot_index+=1
	var point: Vector3=path[int(record.foot_index)]
	var direction:=point-actor.position;direction.y=0
	return direction.normalized() if direction.length_squared()>1 else Vector3.ZERO

func _friendly_lane(actor: WarPlayer,point: Vector3,radius:=.8) -> bool:
	var start:=actor.camera_pivot.global_position
	for other: WarPlayer in game.players.values():
		if other==actor or other.hp<=0 or not other.deployed or other.war_team!=actor.war_team or not other.vehicle_id.is_empty(): continue
		var centre: Vector3=other.hit_regions.chest.global_position
		var nearest:=Geometry3D.get_closest_point_to_segment(centre,start,point)
		if nearest.distance_to(centre)<radius: return false
	return true

func _board(actor: WarPlayer,record: Dictionary) -> bool:
	var slot:=int(record.slot)
	if record.get("boarded_once",false): return false
	var human:=game.local_player as WarPlayer
	# Leave the human's two vehicles untouched during initial preparation.
	if is_instance_valid(human) and actor.war_team==human.war_team and game.war_clock<35 and human.vehicle_id.is_empty() and human.position.distance_to(WarRules.BASES[human.war_team])<85:
		record.direction=Vector3.ZERO;return true
	var vehicle: WarVehicle
	if slot<=3:
		var kind: String=("guarani" if actor.war_team==0 else "bmp2") if slot!=1 else ("abrams" if actor.war_team==0 else "t90")
		vehicle=game.vehicle_system.vehicles.get("v_"+kind) as WarVehicle
	else:
		vehicle=_nearby_transport(actor,record)
	if not is_instance_valid(vehicle) or vehicle.destroyed: return false
	# A nearby teammate has first priority at the start, but a human on
	# another team must not disable APC AI for the whole online match.
	if online_fill and vehicle.kind in ["guarani","bmp2"] and game.war_clock<35.:
		for human_id in game.members:
			var member: Dictionary=game.members[human_id]
			if bool(member.get("bot",false)) or int(member.get("team",-1))!=actor.war_team: continue
			var human_actor:=game.players.get(human_id) as WarPlayer
			if is_instance_valid(human_actor) and human_actor.vehicle_id.is_empty() and human_actor.position.distance_to(vehicle.position)<40.: return false
	if game.war_clock<float(blocked_vehicles.get(vehicle.vehicle_id,0.)): return false
	if not bool(vehicle.spec.get("transport",false)):
		if slot<2 and vehicle.driver>0 and vehicle.driver!=actor.peer_id: record.boarded_once=true;return false
		if slot>=2 and (vehicle.driver<=0 or not bots.has(vehicle.driver)): return false
	if actor.position.distance_to(vehicle.position)>115: return false
	if game.vehicle_system.boarding_distance(actor,vehicle)<=5.3:
		game.vehicle_system.command_for(actor.peer_id,"enter",{"id":vehicle.vehicle_id})
		if actor.vehicle_id==vehicle.vehicle_id:
			record.boarded_once=true;record.boarding_until=game.war_clock+(.7 if bool(vehicle.spec.get("transport",false)) else (7. if slot==0 else 1.))
			return true
	var approach:=vehicle.position+Basis(Vector3.UP,vehicle.heading)*Vector3(-float(vehicle.spec.size.x)*.5-1.4,0,0)
	record.direction=_avoid(actor,(approach-actor.position).normalized());return true

func _nearby_transport(actor: WarPlayer,record: Dictionary) -> WarVehicle:
	var objective: Dictionary=WarRules.OBJECTIVES[str(record.objective)]
	var objective_position: Vector3=objective.position
	if actor.global_position.distance_to(objective_position)<220.: return null
	var chosen: WarVehicle;var best:=115.
	for candidate: WarVehicle in game.vehicle_system.vehicles.values():
		if not is_instance_valid(candidate) or candidate.destroyed or candidate.team!=actor.war_team: continue
		if not bool(candidate.spec.get("transport",false)) or candidate.first_available_seat()<0: continue
		var distance:=actor.global_position.distance_to(candidate.global_position)
		if distance<best: chosen=candidate;best=distance
	return chosen

# Cheap road-grade lookahead; avoid driving the whole chassis into a ditch.
# Uses the procedural terrain, never a per-frame navmesh or broad-phase scan.
func _vehicle_grade_clear(vehicle: WarVehicle,goal: Vector3) -> bool:
	var origin:=vehicle.global_position
	var base:=WarTerrain.height_at(origin.x,origin.z)
	# Piers/bridges sit above terrain. The ordinary hull casts handle them.
	if origin.y-base>3.: return true
	var advance:=goal-origin;advance.y=0.
	var length:=minf(15.,advance.length())
	if length<2.: return true
	var forward:=advance.normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	var half_width:=float(vehicle.spec.size.x)*.40
	var grade_limit:=1.85 if bool(vehicle.spec.tracked) else 1.45
	var previous:=base
	for step in range(1,7):
		var at:=origin+forward*minf(length,step*2.5)
		var centre:=WarTerrain.height_at(at.x,at.z)
		var left: Vector3=at+right*half_width
		var right_pos: Vector3=at-right*half_width
		var side_a:=WarTerrain.height_at(left.x,left.z)
		var side_b:=WarTerrain.height_at(right_pos.x,right_pos.z)
		if absf(centre-previous)>grade_limit or absf(side_a-side_b)>half_width*1.2: return false
		previous=centre
	return true

func _vehicle_grade_detour(vehicle: WarVehicle,goal: Vector3) -> Vector3:
	var towards:=goal-vehicle.global_position;towards.y=0.
	if towards.length_squared()<4.: return Vector3.INF
	var forward:=towards.normalized()
	var side:=forward.cross(Vector3.UP).normalized()
	for sign_value in [-1.,1.]:
		var wanted:=vehicle.global_position+forward*12.+side*float(sign_value)*(float(vehicle.spec.size.x)+4.)
		var point:=WarTerrain.point(wanted.x,wanted.z)
		if _vehicle_grade_clear(vehicle,point) and _traffic_clear(vehicle,vehicle.global_position,point): return point
	return Vector3.INF

func _begin_vehicle_evacuation(vehicle: WarVehicle) -> void:
	if evacuations.has(vehicle.vehicle_id): return
	blocked_vehicles[vehicle.vehicle_id]=game.war_clock+45.
	evacuations[vehicle.vehicle_id]={"since":game.war_clock,"next":0.}
	diagnostics.vehicle_evacuations=int(diagnostics.vehicle_evacuations)+1
	GameDiagnostics.record("war_bot_vehicle_stuck",{"vehicle":vehicle.vehicle_id,"occupants":vehicle.occupant_ids().size()})

func _step_vehicle_evacuation(vehicle: WarVehicle,manager: WarVehicles) -> void:
	var state: Dictionary=evacuations.get(vehicle.vehicle_id,{})
	if state.is_empty() or game.war_clock<float(state.next): return
	state.next=game.war_clock+1.5
	var occupants:=vehicle.occupant_ids()
	var remaining:=0
	for id: int in occupants:
		if not bots.has(id): continue
		if not manager.release(id):
			# A blocked ravine may have no valid exit. After several retries,
			# rescue the bot using the server's validated deployment fallback.
			if game.war_clock-float(state.since)>12.:
				manager.release(id,true)
				GameDiagnostics.record("war_bot_rescue_fallback",{"vehicle":vehicle.vehicle_id,"bot":id})
			else: remaining+=1
		elif bots.has(id): bots[id].boarded_once=true
	if remaining==0: evacuations.erase(vehicle.vehicle_id)

func _drive(actor: WarPlayer,record: Dictionary,delta: float) -> void:
	var manager:=game.vehicle_system as WarVehicles
	var vehicle:=manager.find_target(actor.vehicle_id) as WarVehicle
	if not is_instance_valid(vehicle) or vehicle.destroyed: return
	if evacuations.has(vehicle.vehicle_id):
		_step_vehicle_evacuation(vehicle,manager)
		return
	var point: Vector3=WarRules.OBJECTIVES[record.objective].position
	var goal:=WarTerrain.point(point.x,point.z)
	if bool(vehicle.spec.get("transport",false)) and vehicle.driver==actor.peer_id and vehicle.position.distance_to(goal)<48.:
		manager.release(actor.peer_id);return
	if vehicle.driver!=actor.peer_id:
		if vehicle.position.distance_to(goal)<65: manager.release(actor.peer_id)
		return
	if record.vehicle_goal!=record.objective or record.vehicle_path.is_empty():
		record.vehicle_path=transit.path(vehicle.position,goal);record.vehicle_index=0;record.vehicle_goal=record.objective
		record.terrain_detour=Vector3.INF;record.grade_check_at=0.
	var path: Array=record.vehicle_path
	while int(record.vehicle_index)<path.size()-1 and vehicle.position.distance_to(path[int(record.vehicle_index)])<10: record.vehicle_index+=1
	var traffic:=_traffic_plan(vehicle,record)
	var next_point: Vector3=traffic.get("point",path[int(record.vehicle_index)])
	var detour: Vector3=record.get("terrain_detour",Vector3.INF)
	if detour.is_finite() and game.war_clock<float(record.get("terrain_detour_until",0.)) and vehicle.position.distance_to(detour)>4.:
		next_point=detour
	else: record.terrain_detour=Vector3.INF
	if game.war_clock>=float(record.get("grade_check_at",0.)):
		record.grade_check_at=game.war_clock+.30
		record.terrain_blocked=not _vehicle_grade_clear(vehicle,next_point)
		if bool(record.terrain_blocked):
			var alternate:=_vehicle_grade_detour(vehicle,next_point)
			if alternate.is_finite():
				record.terrain_detour=alternate
				diagnostics.vehicle_detours=int(diagnostics.vehicle_detours)+1
				record.terrain_detour_until=game.war_clock+8.
				next_point=alternate
				record.terrain_blocked=false
	if bool(record.get("terrain_blocked",false)):
		if float(record.get("terrain_blocked_since",0.))==0.: record.terrain_blocked_since=game.war_clock
		elif game.war_clock-float(record.terrain_blocked_since)>9.:
			_begin_vehicle_evacuation(vehicle);return
	else: record.terrain_blocked_since=0.
	var towards: Vector3=next_point-vehicle.position;towards.y=0
	var error:=angle_difference(vehicle.heading,atan2(-towards.x,-towards.z))
	var throttle:=.30 if absf(error)<.6 else (.12 if absf(error)<1.4 else 0.)
	# A wheeled APC cannot pivot in place like a tracked tank. Back up and
	# counter-steer when the next road point is behind it, then drive forward.
	if not bool(vehicle.spec.tracked) and absf(error)>1.4:
		throttle=-.18;error=-error
	if vehicle.position.distance_to(goal)<18 or game.war_clock<float(record.boarding_until): throttle=0
	if bool(record.get("terrain_blocked",false)): throttle=0.
	if bool(traffic.get("brake",false)):
		throttle=0.
		if float(record.get("congestion_since",0.))==0.: record.congestion_since=game.war_clock
		elif game.war_clock-float(record.congestion_since)>18.:
			_begin_vehicle_evacuation(vehicle);return
	else: record.congestion_since=0.
	if game.war_clock>=float(record.vehicle_check_at):
		record.vehicle_check_at=game.war_clock+1.
		record.vehicle_stuck=float(record.vehicle_stuck)+1 if not bool(traffic.get("brake",false)) and absf(throttle)>.02 and vehicle.position.distance_to(record.last_position)<.35 else 0.
		record.last_position=vehicle.position
	if float(record.vehicle_stuck)>2 and not bool(traffic.get("brake",false)): throttle=-.25;error=-error
	if float(record.vehicle_stuck)>5:
		record.vehicle_stuck=0.;record.vehicle_path=[]
		_begin_vehicle_evacuation(vehicle);return
	var enemy:=game.players.get(int(record.get("target",0))) as WarPlayer
	var enemy_armor:=manager.vehicles.get(str(record.get("target_vehicle",""))) as WarVehicle
	var valid_armor:=is_instance_valid(enemy_armor) and not enemy_armor.destroyed and enemy_armor.hp>0 and enemy_armor.team!=vehicle.team
	var valid_infantry:=is_instance_valid(enemy) and enemy.hp>0 and enemy.deployed and enemy.war_team!=vehicle.team and enemy.vehicle_id.is_empty() and bool(record.get("line_clear",false))
	var tank:=vehicle.kind in ["abrams","t90"]
	var aim:=goal+Vector3.UP*2;var fire:=false;var distance:=INF
	if not bool(vehicle.spec.get("transport",false)):
		# Tanks prioritize armor with their main gun; coaxial MG suppresses
		# infantry. APCs use their 30 mm primary against both target types.
		var attack_armor:=valid_armor and (tank or not valid_infantry)
		if attack_armor:
			vehicle.selected="primary"
			var lead: Vector3=enemy_armor.velocity*.18
			aim=enemy_armor.global_position+Vector3.UP*1.25+lead
			distance=vehicle.global_position.distance_to(enemy_armor.global_position)
		elif valid_infantry:
			vehicle.selected="secondary" if tank else "primary"
			aim=enemy.hit_regions.chest.global_position+enemy.velocity*.12
			distance=vehicle.global_position.distance_to(enemy.global_position)
		if distance<INF:
			var miss:=.004 if tank else .008
			aim+=Vector3(sin(game.war_clock*1.3+actor.peer_id),.3*cos(game.war_clock),cos(game.war_clock*1.3))*distance*miss
			var marker: Marker3D=vehicle.secondary_muzzle if vehicle.selected=="secondary" else vehicle.muzzle
			var real_direction: Vector3=-marker.global_basis.z
			var aligned:=real_direction.dot((aim-marker.global_position).normalized())>.995
			fire=aligned and _friendly_lane(actor,aim,2.) and fmod(game.war_clock+actor.peer_id,3.2)<(1. if tank else 2.) and distance>18.
			if distance<180.: throttle=0.
	# Commands still use the server's existing ammunition, projectile and hit rules.
	if vehicle.selected=="secondary":
		if vehicle.secondary_ammo==0: vehicle.start_secondary_reload()
	elif vehicle.ammo==0: vehicle.start_reload()
	manager.controls[actor.peer_id]={"throttle":throttle,"steer":0. if bool(traffic.get("brake",false)) else clampf(-error*2,-1,1),"brake":bool(traffic.get("brake",false)),"aim":aim,"fire":fire,"at":game.war_clock}

func _traffic_clear(vehicle: WarVehicle,start: Vector3,end: Vector3) -> bool:
	# Sweep the complete hull-width corridor: two edge rays miss a person or
	# narrow obstacle between them. Leave extra space for steering overhang.
	var direction:=end-start;direction.y=0
	if direction.length_squared()<.01:return true
	var space:=game.get_world_3d().direct_space_state
	var shape:=BoxShape3D.new();shape.size=Vector3(float(vehicle.spec.size.x)+1.4,1.25,float(vehicle.spec.size.z)+.8)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1|4|16;query.exclude=[vehicle.get_rid()];query.margin=.03
	query.transform=Transform3D(Basis.looking_at(direction.normalized(),Vector3.UP),start+Vector3.UP*1.05)
	if not space.intersect_shape(query,1).is_empty():return false
	query.motion=direction
	var cast:=space.cast_motion(query)
	if cast.size()<2 or float(cast[0])<.999:return false
	# A player can walk into a route between two traffic decisions. Predict
	# only nearby friendly infantry from the shared 5 Hz spatial grid.
	var length:=direction.length();var heading:=direction/length;var side:=heading.cross(Vector3.UP)
	for ally: WarPlayer in _traffic_actors(start,end):
		if not _traffic_friend(vehicle,ally):continue
		for lead in [0.,.65]:
			var offset: Vector3=ally.global_position+ally.velocity*float(lead)-start;offset.y=0
			if offset.dot(heading)>-float(vehicle.spec.size.z)*.5 and offset.dot(heading)<length+float(vehicle.spec.size.z)*.5 and absf(offset.dot(side))<float(vehicle.spec.size.x)*.5+1.35:return false
	return true

func _traffic_actors(start: Vector3,end: Vector3) -> Array:
	if game.war_clock>=spatial_at:spatial_at=game.war_clock+.2;_index_actors()
	var result: Array=[];var minimum:=Vector2(start.x,start.z).min(Vector2(end.x,end.z))-Vector2.ONE*8.
	var maximum:=Vector2(start.x,start.z).max(Vector2(end.x,end.z))+Vector2.ONE*8.
	var low:=Vector2i(floori(minimum.x/8.),floori(minimum.y/8.));var high:=Vector2i(floori(maximum.x/8.),floori(maximum.y/8.))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):result.append_array(spatial.get(Vector2i(x,z),[]))
	return result

func _traffic_friend(vehicle: WarVehicle,actor: WarPlayer) -> bool:
	return is_instance_valid(actor) and actor.hp>0 and actor.deployed and actor.war_team==vehicle.team and actor.vehicle_id.is_empty() and absf(actor.global_position.y-vehicle.global_position.y)<3.5

func _friendly_traffic(vehicle: WarVehicle,forward: Vector3,right: Vector3) -> Dictionary:
	var speed:=absf(vehicle.speed);var half_length:=float(vehicle.spec.size.z)*.5
	var stop_distance:=half_length+4.+speed*.55+speed*speed/(2.*maxf(1.,float(vehicle.spec.acceleration)*3.5))
	var lookahead:=maxf(18.,stop_distance+12.)
	var nearest:=INF;var blocker: WarPlayer
	for ally: WarPlayer in _traffic_actors(vehicle.global_position,vehicle.global_position+forward*lookahead):
		if not _traffic_friend(vehicle,ally):continue
		for lead in [0.,.35,.8]:
			var offset: Vector3=ally.global_position+ally.velocity*float(lead)-vehicle.global_position;offset.y=0
			var ahead: float=offset.dot(forward)
			if ahead< -half_length-.6 or ahead>lookahead or absf(offset.dot(right))>float(vehicle.spec.size.x)*.5+1.25:continue
			if ahead<nearest:nearest=ahead;blocker=ally
	if not blocker:return {}
	return {"brake":nearest<=stop_distance,"position":blocker.global_position,"distance":nearest,"stop_distance":stop_distance,"kind":"infantry"}

func _traffic_plan(vehicle: WarVehicle,record: Dictionary) -> Dictionary:
	# Preserve a safe passing target briefly rather than alternating sides each frame.
	var old: Dictionary=record.get("traffic",{})
	if game.war_clock<float(record.get("traffic_check_at",0.)):return old
	record.traffic_check_at=game.war_clock+.12
	var forward: Vector3=Basis(Vector3.UP,vehicle.heading)*Vector3.FORWARD
	if vehicle.speed<-.15:forward=-forward
	var right:=forward.cross(Vector3.UP).normalized()
	var infantry:=_friendly_traffic(vehicle,forward,right)
	if not infantry.is_empty() and str(old.get("reason","")) in ["friendly_infantry","friendly_rear"]:
		record.traffic={"brake":true,"reason":"friendly_infantry"};return record.traffic
	if bool(infantry.get("brake",false)):record.traffic={"brake":true,"reason":"friendly_infantry"};return record.traffic
	# Reversing must also wait for infantry behind the running gear; never
	# let the stuck-recovery routine back over a teammate.
	if absf(vehicle.speed)<.2:
		var rear:=_friendly_traffic(vehicle,-forward,-right)
		if bool(rear.get("brake",false)):record.traffic={"brake":true,"reason":"friendly_rear"};return record.traffic
	if old.has("point") and game.war_clock<float(old.get("expires",0.)):
		var waypoint: Vector3=old.point
		var remaining:=Vector2(vehicle.global_position.x-waypoint.x,vehicle.global_position.z-waypoint.z).length()
		if remaining<3.0:
			if old.has("after"):
				old.point=old.after;old.erase("after")
			else:
				record.traffic={};return {}
		if _traffic_clear(vehicle,vehicle.global_position,old.point): return old
		record.traffic={"brake":true};return record.traffic
	var nearest: WarVehicle=null;var nearest_dist:=INF
	for other: WarVehicle in game.vehicle_system.vehicles.values():
		if not is_instance_valid(other) or other==vehicle or other.destroyed: continue
		var offset:=other.global_position-vehicle.global_position;offset.y=0
		var ahead:=offset.dot(forward)
		var clearance: float=(float(other.spec.size.x)+float(vehicle.spec.size.x))*.5+1.3
		var distance_limit: float=maxf(40.,absf(vehicle.speed)*2.8+float(vehicle.spec.size.z))
		if ahead>0 and ahead<distance_limit and absf(offset.dot(right))<clearance and ahead<nearest_dist:
			nearest=other;nearest_dist=ahead
	if not is_instance_valid(nearest) and not infantry.is_empty():
		var point: Vector3=infantry.position
		for side in [-1.,1.]:
			var gap:=float(vehicle.spec.size.x)*.5+3.5
			var beside: Vector3=vehicle.global_position+right*gap*float(side)+forward*maxf(2.,float(infantry.distance)-10.)
			var after: Vector3=point+right*gap*float(side)+forward*(float(vehicle.spec.size.z)+4.)
			if _traffic_clear(vehicle,vehicle.global_position,beside) and _traffic_clear(vehicle,beside,after):record.traffic={"point":beside,"after":after,"expires":game.war_clock+12.,"brake":false};return record.traffic
		record.traffic={"brake":true,"reason":"friendly_no_clear_bypass"};return record.traffic
	if not is_instance_valid(nearest):record.traffic={};return {}
	var relative:=maxf(0.,absf(vehicle.speed)-maxf(0.,nearest.speed))
	var hull_gap:=nearest_dist-(float(nearest.spec.size.z)+float(vehicle.spec.size.z))*.5
	var stop_gap:=2.+relative*.4+relative*relative/(2.*maxf(1.,float(vehicle.spec.acceleration)*3.5))
	if hull_gap<stop_gap:record.traffic={"brake":true,"reason":"vehicle_stopping_distance"};return record.traffic
	# A wheeled APC needs turning room before it can acquire a parallel lane.
	# When already too close, wait rather than curling into the lead's rear.
	if not bool(vehicle.spec.tracked) and nearest_dist<26.:record.traffic={"brake":true,"reason":"vehicle_turning_clearance"};return record.traffic
	if nearest.speed>vehicle.speed+.5 and nearest_dist>float(vehicle.spec.size.z)+5.:
		record.traffic={};return {}
	# A close vehicle or obstructed side requires stopping; only pass on a
	# corridor large enough for the hull and with room ahead of the slower one.
	var gap: float=(float(nearest.spec.size.x)+float(vehicle.spec.size.x))*.5+3.0
	var beyond: float=(float(nearest.spec.size.z)+float(vehicle.spec.size.z))*.5+8.0
	var approach: float=clampf(nearest_dist-(float(nearest.spec.size.z)+float(vehicle.spec.size.z))*.5-6.,6.,22.)
	for side in [-1.,1.]:
		var beside: Vector3=vehicle.global_position+right*gap*float(side)+forward*approach
		var destination: Vector3=nearest.global_position+right*gap*float(side)+forward*beyond
		if _traffic_clear(vehicle,vehicle.global_position,beside) and _traffic_clear(vehicle,beside,destination):
			record.traffic={"point":beside,"after":destination,"expires":game.war_clock+35.,"brake":false};return record.traffic
	record.traffic={"brake":true};return record.traffic
