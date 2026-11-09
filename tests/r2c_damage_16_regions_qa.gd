extends "res://tests/combat_integration.gd"

# Dedicated 16-region authority/damage regression. Uses the real physics world,
# every hitbox enabled, exterior raycasts and the gameplay _apply_hit() pipeline.
const GROUPS: Dictionary={
    "head":"head","chest":"torso","abdomen":"torso","abdomenPelvis":"torso",
    "armL":"armL","armR":"armR","forearmL":"armL","forearmR":"armR",
    "handL":"armL","handR":"armR","legL":"legL","legR":"legR",
    "shinL":"legL","shinR":"legR","footL":"legL","footR":"legR"
}

func run() -> void:
    game=load("res://scripts/main.gd").new()
    game.set_meta("test_mode",true)
    root.add_child(game)
    game.mode="training"
    game.map_kind="sandbox"
    game._enter_match_world()
    game._static_box(game.world_root,"TestFloor",Vector3(0,-0.25,-30),Vector3(200,0.4,200),Color.GRAY)
    var shooter: GamePlayer=game._spawn_player(1,true,false,Vector3.ZERO)
    shooter.set_physics_process(false)
    var target: GamePlayer=game._spawn_player(2,false,true,Vector3(0,0,-15))
    target.set_physics_process(false)
    await physics_frame
    await physics_frame
    check(target.hit_regions.size()==16,"all 16 combat regions present")
    for id: String in GROUPS:
        check(target.hit_regions.has(id),"physical area exists "+id)
        if not target.hit_regions.has(id):
            continue
        var area: Area3D=target.hit_regions[id]
        var label: String="abdomen" if id=="abdomenPelvis" else id
        check(area.collision_layer==2,"region shot collision layer "+id)
        check(str(area.get_meta("hit_region","none"))==label,"region metadata "+id)
        check(CombatRules.DAMAGE.has(label),"explicit damage coefficient "+id)
        check(CombatRules.region_group(id)==str(GROUPS[id]),"limb group "+id)
        var hit: Dictionary=cast_region(target,id)
        check(not hit.is_empty(),"exterior physical ray reaches "+id)
        if hit.is_empty():
            continue
        check(str(hit.collider.get_meta("hit_region","none"))==label,"physical first hit is "+id)
        if id=="head":
            check(CombatRules.health_damage(1.0,"head","training")==100.0,"fatal headshot unchanged")
            continue
        target.hp=100.0
        target.limbs=CombatRules.fresh_limbs()
        game._apply_hit(1,hit,10.0,"chest","glock",Vector3.FORWARD)
        var expected: float=100.0-10.0*float(CombatRules.DAMAGE[label])
        check(absf(target.hp-expected)<0.01,"damage from real hit "+id)
    print("R2C_16_REGION_GATE ",JSON.stringify({"checks":checks,"failures":errors,"physical_regions":target.hit_regions.size(),"expected_regions":GROUPS.size()}))
    game.queue_free()
    await process_frame
    quit(0 if errors.is_empty() else 1)
