extends WarBotDirector

# Benchmark-only prototype. Do not use in released offline or server builds:
# hitbox history, authoritative projectile contacts and visual reconstruction
# for a 20 Hz actor still need deliberate design and multiplayer validation.
const DISTANCE:=180.0
const INTERVAL:=3
var accumulated: Dictionary={}
var deferred_ticks:=0
var full_rate_ticks:=0
var reduced_steps:=0

func _move(actor: WarPlayer,record: Dictionary,delta: float) -> void:
	var can_reduce:=actor.is_on_floor() and not bool(record.get("line_clear",false)) and int(record.get("target",0))==0
	# Approach and boarding require full-rate movement; the benchmark must not
	# gain FPS merely by preventing the existing vehicle crews from boarding.
	if int(record.get("slot",0))<4 and not bool(record.get("boarded_once",false)): can_reduce=false
	if can_reduce:
		for id in game.players:
			var other:=game.players[id] as WarPlayer
			if not is_instance_valid(other) or other==actor or bool(other.get_meta("war_bot",false)): continue
			if actor.global_position.distance_squared_to(other.global_position)<DISTANCE*DISTANCE:
				can_reduce=false;break
	if not can_reduce:
		accumulated.erase(actor.peer_id);full_rate_ticks+=1
		super._move(actor,record,delta);return
	var elapsed:=float(accumulated.get(actor.peer_id,0.))+delta
	if posmod(Engine.get_physics_frames()+actor.peer_id,INTERVAL)!=0:
		accumulated[actor.peer_id]=elapsed;deferred_ticks+=1;return
	accumulated.erase(actor.peer_id);reduced_steps+=1
	super._move(actor,record,minf(elapsed,delta*INTERVAL))
