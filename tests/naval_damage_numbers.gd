extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var branch:=Node.new();root.add_child(branch)
	var network=load("res://tests/naval_damage_fixture.gd").new();branch.add_child(network)
	network.require_accounts=false # Local damage fixture has no remote account service.
	network.connection.multiplayer_peer=OfflineMultiplayerPeer.new()
	var battle:=NavalMatch.new();branch.add_child(battle)
	battle.build(network,{"id":"damage-room","match":"damage-match","state":"IN_PROGRESS","members":[1,2],"stats":{}});battle.set_physics_process(false)
	for peer in [1,2]:
		var identity:=str(peer).sha256_text()
		network.accounts[identity]={"id":identity,"coins":0,"owned":["light"],"selected":"light","transactions":{}}
		battle.add_player(peer,{"identity":identity,"ship":"light","name":str(peer)})
	var target: NavalShip=battle.ships[2]
	network.sent.clear()
	battle._impact({"id":"test:1","owner":1,"weapon":"lightMG"},{"collider":target,"position":target.global_position,"water":false})
	var damage_events: Array=network.sent.filter(func(event): return event.kind=="damage")
	check(damage_events.size()==2,"authoritative naval damage event reaches both room participants")
	var event: Dictionary=damage_events[0].payload
	check(event.amount==4 and event.owner==1 and event.target==2,"naval event records actual damage and attacker")
	check(event.room=="damage-room" and event.match=="damage-match","naval damage event is scoped to its room and match")
	var mode:=NavalMode.new();mode.network=network
	mode.world=NavalWorld.new();branch.add_child(mode.world)
	mode.damage_numbers=GameDamageNumbers.new();mode.world.add_child(mode.damage_numbers)
	mode.damage_flash=GameDamageFlash.new();branch.add_child(mode.damage_flash)
	mode._event("damage",event)
	check(mode.damage_numbers.active.size()==1 and mode.damage_numbers.active[0].amount==4,"naval attacker displays confirmed 3D damage")
	mode._event("damage",event)
	check(mode.damage_numbers.active.size()==1,"duplicate naval event creates no duplicate number")
	var other:=event.duplicate();other.id="enemy:shot";other.owner=2;mode._event("damage",other)
	check(mode.damage_numbers.active.size()==1,"enemy damage is not displayed as own inflicted damage")
	var incoming:=event.duplicate();incoming.id="incoming:shot";incoming.owner=2;incoming.target=1
	mode._event("damage",incoming)
	check(mode.damage_flash.color.a>.2,"naval victim screen pulses on each server-confirmed hit")
	await create_timer(.45).timeout
	check(mode.damage_flash.color.a<.01,"naval damage pulse fades despite reduced integrity")
	mode._event("damage",incoming)
	check(mode.damage_flash.color.a<.01,"duplicate naval hit does not repeat the screen flash")
	target.hp=2;network.sent.clear()
	battle._impact({"id":"test:2","owner":1,"weapon":"lightMG"},{"collider":target,"position":target.global_position,"water":false})
	damage_events=network.sent.filter(func(item): return item.kind=="damage")
	check(damage_events[0].payload.amount==2,"naval overkill is capped to remaining integrity")
	mode.free();branch.queue_free();await process_frame
	var report: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/naval-damage-numbers-results.json",report);print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
