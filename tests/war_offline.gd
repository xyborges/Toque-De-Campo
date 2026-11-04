extends SceneTree

# Full native offline operation. Combat positions and the short objective phase
# are deterministic fixtures; movement and shooting are executed by the real AI.
class NoNetworkAccounts extends NavalAccounts:
	var api_calls: Array[String]=[]
	func call_api(action: String,_payload: Dictionary={}) -> Dictionary:
		api_calls.append(action)
		return {"ok":false,"error":"No network accounts in this offline test"}

var game: WarGame
var accounts: NoNetworkAccounts
var checks:=0
var failures: Array[String]=[]
var notes: Array[String]=[]
var closed_count:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func wait_for(condition: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())
func capture(label_text: String) -> void:
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/war-offline-"+label_text+".png")
func team_counts() -> Array[int]:
	var result: Array[int]=[0,0]
	for member: Dictionary in game.members.values():
		if int(member.team) in [0,1]: result[int(member.team)]+=1
	return result
func pose(actor: WarPlayer,p: Vector3) -> void:
	actor.global_position=p+Vector3.UP*.12;actor.velocity=Vector3.ZERO
	actor.network_target=actor.global_position;actor.has_network_state=false
func open_game() -> void:
	accounts=NoNetworkAccounts.new();root.add_child(accounts)
	game=WarGame.new();game.offline_operation=true;game.accounts_service=accounts
	game.set_meta("war_test",true);game.set_meta("test_mode",true)
	game.closed.connect(func():closed_count+=1)
	root.add_child(game)
	check(await wait_for(func():return is_instance_valid(game.local_player) and game.join_ready and is_instance_valid(game.bot_director),25),"offline operation opens locally without account or server")
func close_game() -> void:
	var director_ref: WeakRef=weakref(game.bot_director);var world_ref: WeakRef=weakref(game.world_root)
	game.show_menu();await process_frame
	check(not game.online and game.closing and not game.is_physics_processing(),"leaving stops operation and leaves no online session")
	check(not game.bot_director.enabled and not game.bot_director.is_physics_processing(),"leaving stops AI before the world is destroyed")
	check(game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"leaving closes transports and restores offline peer")
	check(accounts.api_calls.is_empty() and game.reward_jobs.is_empty(),"offline operation never calls account or reward services")
	game.queue_free();await process_frame;await process_frame
	check(director_ref.get_ref()==null and world_ref.get_ref()==null,"leaving releases bots and their world")
	accounts.queue_free();await process_frame
func run() -> void:
	Engine.max_fps=60
	await open_game()
	if not is_instance_valid(game.local_player): finish();return
	check(not game.online and not game.dedicated_pvp and game.multiplayer.is_server(),"offline simulation owns local authority")
	check(game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and game.multiplayer.get_peers().is_empty(),"offline operation binds no ENet connection or room")
	check(not game.scoreboard_context().network,"offline scoreboard omits network latency")
	game.request_deploy(0,"soldier","fal","rpg","rally")
	check(await wait_for(func():return game.players.size()==12 and game.bot_director.bots.size()==11,15),"human deployment creates eleven local bots")
	check(team_counts()==[6,6],"one human and five allies face six enemies")
	var roles: Dictionary={};var safe_actors:=true;var starts: Dictionary={}
	for id in game.bot_director.bots:
		var actor:=game.players[id] as WarPlayer
		roles[actor.war_class]=true;starts[id]=actor.global_position
		safe_actors=safe_actors and not actor.is_npc and not actor.is_local and bool(actor.get_meta("war_bot",false)) and actor.deployed and actor.hp>0
	check(safe_actors,"bots reuse armed player actors and regional hitboxes")
	check(roles.size()==4,"offline squads include all four existing classes")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await create_timer(3.).timeout
	var moving:=0
	for id in starts:
		if game.players[id].global_position.distance_to(starts[id])>1.: moving+=1
	check(moving>=8 and int(game.bot_director.diagnostics.moves)>0,"bots move spontaneously toward conquest objectives")
	await capture("deployment")
	var director:=game.bot_director as WarBotDirector
	var full_records: Dictionary=director.bots.duplicate(true)
	var enemy_id:=0
	for id in director.bots:
		if int(director.bots[id].team)==1 and str(director.bots[id].role)=="soldier": enemy_id=id;break
	var enemy:=game.players[enemy_id] as WarPlayer
	var human:=game.local_player as WarPlayer
	# Isolate one real AI actor for deterministic hit/reload/occlusion checks.
	# Other actors remain in the world with their normal hitboxes and teams.
	director.bots={enemy_id:full_records[enemy_id]}
	director.think_cursor=0
	var clear:=WarTerrain.point(-100,280)
	pose(human,clear);pose(enemy,WarTerrain.point(-100,266))
	human.clear_aim();game.members[1].shield=0.;game.members[enemy_id].shield=0.
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await physics_frame
	var ammo_before:=int(enemy.ammo.fal);var shots_before:=int(director.diagnostics.shots)
	director.bots[enemy_id].next_shot=game.war_clock
	check(await wait_for(func():return human.hp<100 and int(enemy.ammo.fal)<ammo_before,8),"AI automatically fires real FAL projectiles that damage an enemy")
	check(int(director.diagnostics.shots)>shots_before,"AI shot uses authoritative ammunition consumption")
	director.enabled=false
	await capture("combat")
	human.hp=100;human.limbs=CombatRules.fresh_limbs();game.members[1].shield=game.war_clock+30.
	enemy.ammo.fal=0;enemy.reserves.fal=60
	director.bots[enemy_id].next_shot=game.war_clock;director.enabled=true
	check(await wait_for(func():return enemy.reload_left>0 and enemy.reload_weapon=="fal",3),"empty bot FAL starts the shared timed reload")
	check(await wait_for(func():return enemy.reload_left==0 and int(enemy.ammo.fal)>0,8),"bot reload finishes using the existing weapon timer")
	check(int(enemy.reserves.fal)==30,"bot reload transfers finite reserve ammunition")
	director.enabled=false
	var wall:=StaticBody3D.new();wall.position=WarTerrain.point(-100,273)+Vector3.UP*2
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,4,.6);shape.shape=box;wall.add_child(shape);game.world_root.add_child(wall)
	await physics_frame;await physics_frame
	var blocked_ammo:=int(enemy.ammo.fal)
	director.bots[enemy_id].target=0;director.bots[enemy_id].next_shot=game.war_clock;director.enabled=true
	await create_timer(1.2).timeout
	check(int(director.bots[enemy_id].target)==0 and int(enemy.ammo.fal)==blocked_ammo,"bot line of sight prevents firing through a solid wall")
	director.enabled=false;wall.queue_free();await physics_frame;await physics_frame
	# Kill the bot with a normal authoritative player shot, never direct damage.
	pose(human,clear);pose(enemy,WarTerrain.point(-100,266))
	enemy.velocity=Vector3.ZERO;game.members[enemy_id].shield=0.
	var direction: Vector3=(enemy.hit_regions.head.global_position-human.camera_pivot.global_position).normalized()
	human.yaw=atan2(-direction.x,-direction.z);human.rotation.y=human.yaw
	human.pitch=asin(direction.y);human.camera_pivot.rotation.x=human.pitch
	human.shot_sequence+=1
	var life:=enemy.life_id
	game._server_accept_shot(1,human.shot_sequence,human.life_id,human.camera_pivot.global_position,direction,"fal",1)
	check(await wait_for(func():return enemy.hp<=0,3),"normal player headshot kills an offline bot through the shared hitbox system")
	check(is_instance_valid(enemy) and game.players.has(enemy_id),"dead armed bot persists for the deployment respawn lifecycle")
	director.enabled=true
	check(await wait_for(func():return enemy.hp==100 and enemy.life_id>life,7),"dead bot redeploys after the existing respawn delay")
	check(enemy.deployed and enemy.weapon_id=="fal" and int(enemy.ammo.fal)==30,"redeployed bot restores class, hitboxes and magazine")
	director.enabled=false;director.bots=full_records
	# Arrange the actual conquest participants for a short deterministic phase.
	game.objective_states=WarRules.fresh_objectives();game.tickets=[300,300]
	var allies: Array[int]=[]
	for id in game.players:
		var actor:=game.players[id] as WarPlayer
		pose(actor,WarTerrain.point(-500 if actor.war_team==0 else 500,40+id%6*4))
		if actor.war_team==0 and id!=1 and allies.size()<3: allies.append(id)
	var objective: Vector3=WarRules.OBJECTIVES.A.position
	pose(human,WarTerrain.point(objective.x+5,objective.z+8))
	for i in allies.size(): pose(game.players[allies[i]],WarTerrain.point(objective.x-3+i*3,objective.z))
	check(await wait_for(func():return int(game.objective_states.A.owner)==0,16),"offline participants capture objective A through normal conquest rules")
	await create_timer(2.2).timeout
	check(int(game.tickets[1])<300,"captured objective drains enemy tickets in offline operation")
	check(int(game.match_stats.rows[1].objective)>=150,"offline conquest awards validated objective points")
	game.scoreboard.visible=true;game.scoreboard.refresh()
	check(game.scoreboard.heading.text.contains("OFFLINE") and game.scoreboard.map_label.text=="LINHA DE FRENTE","real offline scoreboard initializes its header without waiting for the refresh interval")
	check(game.scoreboard.groups[0].node.visible and game.scoreboard.groups[1].node.visible,"real offline scoreboard immediately separates both six-player teams")
	check(not game.scoreboard.groups[0].headers.ping.visible and not game.scoreboard.row_pool[0].cells.ping.visible,"real offline scoreboard omits latency immediately on opening")
	await capture("conquest-scoreboard")
	game.scoreboard.hide()
	check(game.reward_jobs.is_empty() and accounts.api_calls.is_empty(),"kills and objectives do not submit global account rewards")
	await close_game()
	await open_game()
	game.request_deploy(1,"marksman","sniper","rpg","rally")
	check(await wait_for(func():return game.players.size()==12,15),"another offline operation can start after leaving")
	check(team_counts()==[6,6] and game.local_player.war_team==1,"either selected human team receives five allies and six opponents")
	check(game.local_player.weapon_id=="sniper" and game.local_player.war_class=="marksman","new operation uses the newly chosen class and weapon")
	check(game.objective_states.A.owner==-1 and game.objective_states.B.owner==-1 and game.objective_states.C.owner==-1 and game.tickets==[300,300],"new operation starts with clean objectives and tickets")
	await close_game()
	check(closed_count==2,"both operations emit their normal return-to-menu event")
	finish()
func finish() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var report: Dictionary={"checks":checks,"failures":failures,"notes":notes,"fixture":"Deterministic combat positions and conquest participants; real AI movement, targeting, projectile damage, ammunition and reloads."}
	NavalStorage.write_json("res://tests/war-offline-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
