extends SceneTree
const PROTECTION=preload("res://scripts/infantry_protection.gd")
var errors: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game:=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until:await process_frame
	check(game.join_ready,"world ready")
	if not game.join_ready:quit(1);return
	var slots:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",1)
	slots.vest="vest_1";slots.helmet="helmet_2"
	game.request_deploy(1,"soldier","ak","rpg","base",slots)
	var actor:=game.local_player as WarPlayer
	if game.bot_director:game.bot_director.stop()
	actor.set_physics_process(false)
	check(actor.infantry_protection.enabled,"deployment enables protection")
	check(actor.infantry_protection.gear.vest.durability==60.,"light vest starts at 60")
	check(actor.infantry_protection.gear.helmet.durability==100.,"standard helmet starts at 100")
	check(actor.infantry_protection.multiplier()<1.,"equipped armor contributes weight")
	actor.last_impact_weapon="ak";actor.take_damage(20.,"head",0)
	check(is_equal_approx(actor.hp,70.),"helmet allows a nonfatal head hit based on weapon damage")
	check(is_equal_approx(float(actor.infantry_protection.gear.helmet.durability),80.),"only the helmet absorbs head damage")
	actor.hp=100.;actor.take_damage(100.,"chest",0)
	check(is_equal_approx(actor.hp,30.),"light vest absorbs 30 percent")
	check(actor.infantry_protection.gear.vest.durability==30.,"absorbed damage consumes resistance")
	var snapshot:=actor.infantry_protection.snapshot()
	var copy:=GamePlayer.new();copy.life_id=actor.life_id
	check(copy.infantry_protection.receive(copy,copy.life_id,snapshot),"observer accepts full authoritative state")
	for repeat in 5:
		GameLoadouts.apply(actor,GameLoadouts.validate(slots,"war",GameWeapons.INFANTRY_IDS,"soldier",1),true)
		actor.apply_identity(1,"soldier");actor.infantry_protection.deploy(actor)
	check(actor.infantry_protection.gear.vest.durability==30.,"same-life equip and identity updates never repair or stack")
	actor.hp=100.;actor.take_damage(100.,"chest",0)
	check(actor.infantry_protection.gear.vest.level==0 and actor.infantry_protection.gear.vest.durability==0.,"breaking removes vest state atomically")
	var broken:=actor.infantry_protection.snapshot()
	var visual_count:=0
	for mesh in actor.body_root.find_children("*","MeshInstance3D",true,false):
		if str(mesh.get_meta("protection_slot",""))=="vest":visual_count+=1;check(not mesh.visible,"broken vest mesh is hidden")
	check(visual_count>0,"uniform retains identifiable vest meshes after batching")
	check(copy.infantry_protection.receive(copy,copy.life_id,broken,"vest"),"observer receives broken state")
	check(not copy.infantry_protection.receive(copy,copy.life_id,snapshot),"older state cannot restore broken gear")
	check(not copy.infantry_protection.receive(copy,copy.life_id,broken,"vest"),"duplicate break is ignored")
	actor.hp=100.;actor.take_damage(20.,"chest",0)
	check(is_equal_approx(actor.hp,80.),"broken vest provides no further protection")
	var old_life:=actor.life_id;actor.life_id+=1;actor.infantry_protection.deploy(actor)
	check(actor.infantry_protection.gear.vest.durability==60.,"new life restores exactly one selected vest")
	check(not actor.infantry_protection.receive(actor,old_life,broken),"previous-life break cannot affect respawn")
	actor.hp=100.;actor.take_damage(20.,"chest",0)
	check(is_equal_approx(actor.hp,86.),"respawn grants one reduction, not accumulated reductions")
	actor.last_impact_weapon="rpg"
	check(actor.infantry_protection.damage(actor,200.,"chest",200.)==200.,"antiarmor blast bypasses infantry protection")
	for mode in ["war","desert","offline_training","offline_desert"]:check(GameLoadouts.allowed(mode,GameWeapons.INFANTRY_IDS).has("vest"),"armor offered in "+mode)
	check(not GameLoadouts.allowed("br",GameWeapons.INFANTRY_IDS).has("vest"),"BR loadout rules remain separate")
	copy.free()
	var report:={"checks":checks,"errors":errors,"ok":errors.is_empty(),"scope":"production WarGame, deployment, damage, uniform batching, respawn and observer state ordering"}
	print("INFANTRY_PROTECTION_VALIDATION ",JSON.stringify(report))
	game.show_menu();game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
