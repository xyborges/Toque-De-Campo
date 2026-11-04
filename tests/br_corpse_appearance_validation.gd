extends SceneTree
const FIXTURE=preload("res://tests/br_completion_fixture.gd")
const CORPSE=preload("res://modes/battle_royale/scripts/corpse_appearance.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func all_visible(pieces: Array) -> bool:
	for piece: MeshInstance3D in pieces:
		if not piece.visible:return false
	return true
func run() -> void:
	var game: BattleRoyaleGame=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame;game.flat_world()
	var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer
	actor.set_physics_process(false);actor.set_process(false);actor.life_id=8;actor.hp=100.
	BRProtectionAppearance.apply(actor,2,3,2);actor._animate_walk()
	await physics_frame;await physics_frame
	var torso:=CORPSE.create(game.world_root,actor,actor.global_position)
	var corpse:=torso.get_parent() as Node3D
	check(corpse.persistent and corpse.get_meta("br_corpse",false) and corpse.get_meta("br_owner",0)==1 and corpse.get_meta("br_life",0)==8,"BR corpse retains life and ownership metadata")
	check(corpse.get_node_or_null("SettleCorpse")!=null and corpse.get_children().filter(func(child):return child is Timer).size()==1,"persistent corpse has settle timer without fade or expiry")
	var helmet:=CORPSE.equipment_pieces(corpse,"helmet");var vest:=CORPSE.equipment_pieces(corpse,"vest");var pack:=CORPSE.equipment_pieces(corpse,"pack")
	check(not helmet.is_empty() and not vest.is_empty() and not pack.is_empty(),"all actual equipment geometry is tagged across cloned body parts")
	CORPSE.bind_loot(corpse,91,{"helmet":4,"vest":5,"pack":6});CORPSE.present(corpse,[4,5,6,7])
	check(all_visible(helmet) and all_visible(vest) and all_visible(pack),"original equipment stays visible while still in corpse container")
	CORPSE.present(corpse,[5,6,7])
	check(not all_visible(helmet) and all_visible(vest) and all_visible(pack),"taking helmet removes only helmet from dead model")
	CORPSE.present(corpse,[4,5,6,7])
	check(not all_visible(helmet),"delayed old contents do not restore looted helmet")
	CORPSE.present(corpse,[6,7,20])
	check(not all_visible(vest) and all_visible(pack),"replacement gear with new part ID does not replace original corpse vest")
	CORPSE.present(corpse,[])
	check(not all_visible(pack) and is_instance_valid(torso) and torso.get_child(0).visible,"empty loot removes equipment while leaving body visible")
	var lifetime: Timer=corpse.get_node("SettleCorpse");lifetime.timeout.emit();await process_frame
	var frozen:=true
	for body: RigidBody3D in corpse.bodies.values():
		if not body.freeze or body.collision_layer!=0 or body.collision_mask!=0 or body.linear_velocity!=Vector3.ZERO:frozen=false
	check(corpse.settled and frozen and corpse.find_children("*","Joint3D",false,false).is_empty(),"settled BR corpse freezes physics, releases joints and cannot block players")
	check(is_instance_valid(torso) and torso.visible,"death camera target remains valid after settling")
	# The living model can still show armor exhausted by the fatal hit. Binding
	# the actual remaining loot must remove that stale copied vest immediately.
	var broken_torso:=CORPSE.create(game.world_root,actor,actor.global_position)
	var broken:=broken_torso.get_parent() as Node3D
	CORPSE.bind_loot(broken,92,{"helmet":2,"pack":3});CORPSE.present(broken,[2,3])
	check(not all_visible(CORPSE.equipment_pieces(broken,"vest")) and all_visible(CORPSE.equipment_pieces(broken,"helmet")) and all_visible(CORPSE.equipment_pieces(broken,"pack")),"fatal exhausted vest is hidden while surviving helmet and backpack remain")
	# Existing modes retain their original timer policy.
	var normal:=DeathRagdoll.create(game.world_root,actor,actor.global_position)
	check(not normal.get_parent().persistent and normal.get_parent().get_children().filter(func(child):return child is Timer).size()==2,"ordinary mode ragdolls keep fade and lifetime behavior")
	game.leave_match();await create_timer(.05).timeout;game.free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual human rig and equipment cloning, persistent BR corpse lifecycle, stable loot-part removal, stale-event guard, bounded postsettle physics and ordinary-mode compatibility; local functional fixture, no network/FPS claim."}
	NavalStorage.write_json("res://work/br-corpse-appearance-validation.json",report);print("BR_CORPSE_APPEARANCE_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
