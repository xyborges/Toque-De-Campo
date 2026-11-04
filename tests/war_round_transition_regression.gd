extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var game: WarGame
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)

func run() -> void:
	game=FIXTURE.new();root.add_child(game)
	await process_frame;await process_frame
	game.local_player.hp=100;game.local_player.deployed=true
	game.members[1].deployed=true
	game.local_player.trigger_held=true
	game.war_round_ended(0,60.,5)
	check(game.match_ended and game.war_ui.round_panel.visible,"round end displays results without closing the world")
	check(not game.local_player.trigger_held and is_instance_valid(game.world_root),"round end clears the trigger and retains world")
	check(is_equal_approx(game.round_restart_left,60.),"intermission remains sixty seconds")
	game.war_round_started(6)
	check(not game.ui_focus.blocked(),"new round releases modal input immediately")
	await create_timer(.15).timeout # Shared UI dismissal fades before hiding.
	check(not game.match_ended and not game.war_ui.round_panel.visible,"next round closes previous result")
	check(game.authority_round_generation==6,"new round generation is remembered")
	var clock:=game.war_clock;var tickets:=game.tickets.duplicate();var left:=game.match_left
	game.war_snapshot(clock-1.,0.,[0,0],WarRules.fresh_objectives(),true,1,0,0.,5)
	check(not game.match_ended and game.war_clock==clock and game.tickets==tickets and game.match_left==left,"old unreliable result cannot restore old time/tickets/end flags")
	check(not game.war_ui.round_panel.visible,"late old snapshot cannot reopen the result modal")
	game.war_round_ended(1,1.,5)
	check(not game.match_ended and not game.war_ui.round_panel.visible,"late reliable prior-round notification is ignored")
	game.war_round_started(5)
	check(game.authority_round_generation==6 and not game.match_ended,"late start cannot rewind the accepted generation")
	game.local_player.trigger_held=true
	game.war_round_started(6)
	check(game.local_player.trigger_held,"duplicate same-round start does not clear new-round input again")
	game.local_player.trigger_held=false
	game.war_snapshot(clock+1.,42.,[123,124],WarRules.fresh_objectives(),false,-1,0,60.,6)
	check(game.match_left==42. and game.tickets==[123,124],"current-generation snapshots remain accepted")
	game.war_round_ended(1,60.,6)
	check(game.match_ended and game.war_ui.round_panel.visible,"current round can still finish normally")
	game.war_round_started(7)
	check(not game.ui_focus.blocked(),"second round releases modal input immediately")
	await create_timer(.15).timeout
	check(not game.match_ended and not game.war_ui.round_panel.visible,"a second operation starts without freeing the client scene")
	check(is_instance_valid(game.local_player) and is_instance_valid(game.vehicle_system),"actors and vehicle system survive repeated transitions")
	game.show_menu()
	game.war_round_ended(0,60.,8)
	check(game.closing and not game.match_ended,"closing client ignores queued round events")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Real WarGame result/deployment UI transitions and stale-state regression. Not a native-crash reproduction or a multiplayer soak test."}
	NavalStorage.write_json("res://work/war-round-transition-regression.json",report)
	print("WAR_ROUND_TRANSITION ",JSON.stringify(report))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
