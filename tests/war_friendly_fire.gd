extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var notices: Array[Dictionary]=[]
class Fixture extends WarGame:
	var notices: Array[Dictionary]=[]
	func _combat_notice(id: int,message: String) -> void:
		notices.append({"id":id,"message":message})
		if is_instance_valid(local_player) and local_player.peer_id==id: war_combat_notice(message)
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func member(id: int,team: int,local:=false) -> WarPlayer:
	var actor:=game._spawn_player(id,local,false,WarTerrain.point(-400+id,250)) as WarPlayer
	actor.set_physics_process(false);actor.apply_identity(team,"soldier");actor.deployed=true;actor.hp=100
	game.members[id]={"team":team,"role":"soldier","weapon":"fal","deployed":true,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	game._register_match_stat(actor);return actor
func reset_actor(actor: WarPlayer) -> void:
	actor.respawn();actor.deployed=true;game.members[actor.peer_id].deployed=true;game.members[actor.peer_id].shield=0.;actor.set_physics_process(false)
func run() -> void:
	game=Fixture.new();game.set_meta("war_host",true);game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	var author:=member(701,0,true);var ally:=member(703,0);var enemy:=member(702,1)
	game.join_ready=true;game.ui_focus.close_all();game.third_person=true;author._update_view()
	game.match_stats.award(author.peer_id,50,"initial")
	var coins:=int(game.profile.coins);var kills:=author.kills
	game._apply_hit(author.peer_id,{"collider":ally.hit_regions.chest},10,"chest","fal")
	check(ally.hp<100 and ally.hp>0,"nonfatal friendly bullets remove actual health")
	check(game.match_stats.rows[701].damage==0 and game.match_stats.rows[701].points==50,"friendly damage earns neither damage score nor points")
	game._apply_hit(author.peer_id,{"collider":ally.hit_regions.head},100,"head","fal")
	check(ally.hp==0 and ally.deaths==1 and game.match_stats.rows[703].deaths==1,"friendly headshot records the victim's real death")
	check(author.kills==kills and game.match_stats.rows[701].kills==0 and int(game.profile.coins)==coins,"teamkill grants no elimination or coins")
	check(game.match_stats.rows[701].points==-50,"one teamkill subtracts100 points even when the score becomes negative")
	check(game.notices.size()==2 and game.notices[0].id==701 and game.notices[0].message.contains("−100") and game.notices[1].id==703 and game.notices[1].message.contains("seu aliado"),"killer and victim receive distinct friendly-fire explanations")
	check(game.war_ui.combat_notice.visible and game.war_ui.combat_notice_text.text.contains("FOGO AMIGO"),"local killer's alert uses the War HUD and its red warning style")
	var points:=int(game.match_stats.rows[701].points);var count: int=game.notices.size()
	game._apply_hit(701,{"collider":ally.hit_regions.chest},1000,"chest","fal")
	check(game.match_stats.rows[701].points==points and game.notices.size()==count,"a repeated hit on a dead ally cannot double the penalty or alerts")
	check(not game.match_stats.teamkill(701,703,ally.life_id,100),"same-life teamkill event is idempotent")
	game._apply_hit(701,{"collider":enemy.hit_regions.head},100,"head","fal")
	check(enemy.hp==0 and author.kills==kills+1 and game.match_stats.rows[701].kills==1,"an opposing target still grants a normal elimination")
	check(int(game.profile.coins)==coins+30 and game.match_stats.rows[701].points>points,"enemy reward path is preserved")
	reset_actor(ally);game.members[703].shield=game.war_clock+4
	game._apply_hit(701,{"collider":ally.hit_regions.head},100,"head","fal")
	check(ally.hp==100,"the existing deployment shield remains valid for friendly and enemy fire")
	game.members[703].shield=0
	var before_self:=int(game.match_stats.rows[701].points);var previous_deaths:=author.deaths
	game._apply_hit(701,{"collider":author.hit_regions.chest},1000,"chest","grenade")
	check(author.hp==0 and author.deaths==previous_deaths+1,"the owner's live grenade can kill its holder")
	check(game.match_stats.rows[701].points==before_self and author.kills==kills+1,"self death is a death, not a teamkill or rewarded kill")
	reset_actor(author);reset_actor(ally)
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	vehicle.allocate_seat(703);ally.vehicle_id=vehicle.vehicle_id;game.members[703].vehicle=vehicle.vehicle_id
	game.members[703].vehicle_seat=0;game.members[703].vehicle_role="operator"
	var damage_before:=float(game.match_stats.rows[701].damage);var before_vehicle:=int(game.match_stats.rows[701].points)
	game.vehicle_system.damage_from_hit(701,vehicle,10000,"rpg",Vector3.FORWARD)
	check(vehicle.destroyed and ally.hp==0,"friendly explosives destroy an allied APC and kill its occupant")
	check(game.match_stats.rows[701].points==before_vehicle-100 and game.match_stats.rows[701].damage==damage_before,"allied hull damage gives no vehicle bonus and charges the occupant's teamkill penalty")
	check(author.kills==kills+1,"destroying an allied occupied vehicle grants no infantry elimination")
	game.war_ui.show_combat_notice("FOGO AMIGO · Você foi morto por seu aliado Teste.")
	game.open_deployment()
	check(game.war_ui.combat_notice.is_visible_in_tree(),"victim warning remains visible above the deployment menu")
	if DisplayServer.get_name()!="headless":
		await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/war-friendly-fire-alert.png")
	game.war_ui._process(8.1)
	check(not game.war_ui.combat_notice.visible,"the alert expires without a scene-tree timer or delayed node capture")
	game.show_menu();game.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/war-friendly-fire-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
