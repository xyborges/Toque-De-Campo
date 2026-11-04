extends "res://tests/br_round_clock_fixture.gd"
var queue_closed_received:=false
var leave_notified:=false

func _spawn_player(id: int,local: bool,npc:=false,position:=Vector3.ZERO) -> GamePlayer:
	var actor:=super._spawn_player(id,local,npc,position)
	actor.set_physics_process(false);actor.set_process(false)
	return actor

@rpc("authority","call_remote","reliable")
func remote_br_queue_closed() -> void:
	# Observe the actual rejection without starting another account-service
	# search inside this isolated queue fixture.
	queue_closed_received=true
	# The normal client immediately retires this rejected attempt and retries
	# matchmaking. This fixture observes it and shuts down voice instead.
	if is_instance_valid(voice):voice.shutdown()

@rpc("authority","call_remote","reliable")
func qa_queue_check(label: String,expected_phase: String,humans: int,bots: int,remaining: float) -> void:
	var roster: Array=snapshot.get("roster",[])
	var human_count:=0;var bot_count:=0
	for item: Dictionary in roster:
		if bool(item.get("bot",false)):bot_count+=1
		else:human_count+=1
	var okay:=phase==expected_phase
	if expected_phase=="waiting":okay=okay and human_count==humans and bot_count==bots and absf(float(snapshot.get("countdown",-1.))-remaining)<.01
	else:okay=okay and int(snapshot.get("alive",0))==humans+bots and local_player and local_player.hp==100. and local_player.weapon_id=="fists"
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_prepare_leave(label: String) -> void:
	leave_notified=true
	if is_instance_valid(voice):voice.shutdown()
	qa_ack.rpc_id(1,label)

var hold_ready:=false
var ready_request:=""
var ready_generation:=0
@rpc("authority","call_remote","reliable")
func br_prepare_ready(nonce: String,generation: int) -> void:
	ready_request=nonce;ready_generation=generation
	if not hold_ready:rpc_id(1,"server_br_ready",nonce,generation)
func release_ready() -> void:
	rpc_id(1,"server_br_ready",ready_request,ready_generation)

@rpc("authority","call_remote","reliable")
func qa_heal_closed(label: String) -> void:
	ui_focus.open(br_hud.inventory_panel);request_br_heal();br_hud._close_inventory();qa_ack.rpc_id(1,label)

@rpc("authority","call_remote","reliable")
func qa_heal_check(label: String) -> void:
	_refresh_br_ui()
	var okay: bool=not ui_focus.blocked() and not br_hud.inventory_panel.is_visible_in_tree() and local_player.hp>40. and local_player.hp<50. and snapshot.get("heal_recovering",false)
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)
