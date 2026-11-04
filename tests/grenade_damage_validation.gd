extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	var game: Node3D=load("res://tests/combat_153_fixture.gd").new()
	game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	var shooter: GamePlayer=game._spawn_player(1,true,false,Vector3(0,0,15))
	var exposed: GamePlayer=game._spawn_player(2,false,false,Vector3(-3,0,0))
	var covered: GamePlayer=game._spawn_player(3,false,false,Vector3(3,0,0))
	var distant: GamePlayer=game._spawn_player(4,false,false,Vector3(0,0,-9))
	for actor in [shooter,exposed,covered,distant]:actor.set_physics_process(false);actor.set_process(false)
	game._static_box(game.world_root,"BlastWall",Vector3(1.5,1.5,0),Vector3(.2,3,4),Color.GRAY)
	await physics_frame;await physics_frame
	var distance:=Vector3(-3,1,0).distance_to(Vector3(0,.12,0))
	var expected:=160.*(1.-distance/GameGrenades.RADIUS)
	game.grenades_system._damage({"owner":1,"position":Vector3(0,.12,0)})
	check(absf((100.-exposed.hp)-expected)<.01,"exposed infantry receives increased shared blast damage")
	check(100.-exposed.hp>120.*(1.-distance/GameGrenades.RADIUS),"increase exceeds previous damage at same distance")
	check(covered.hp==100.,"solid cover still blocks blast")
	check(distant.hp==100.,"increase does not extend existing radius")
	check(float(WarRules.SPECIAL.grenade.damage)==GameGrenades.DAMAGE,"legacy War projectile definition agrees with shared grenade")
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"damage":GameGrenades.DAMAGE,"radius":GameGrenades.RADIUS,"scope":"Shared grenade blast, actual physics cover and distance falloff; all infantry modes use GameGrenades."}
	NavalStorage.write_json("res://work/grenade-damage-validation.json",report);print("GRENADE_DAMAGE ",JSON.stringify(report))
	game.free();await process_frame;quit(0 if errors.is_empty() else 1)
