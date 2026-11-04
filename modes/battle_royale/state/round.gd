extends RefCounted
class_name BRRound

var participants: Dictionary={}
var started_at:=0.0
var ended:=false
var winner:=-1
var has_started:=false
var defer_end:=false

func begin(ids: Array,now: float) -> void:
	participants.clear();started_at=now;ended=false;winner=-1;has_started=true;defer_end=false
	for raw_id in ids:
		var id:=int(raw_id)
		if participants.has(id): continue
		participants[id]={"alive":true,"placement":0,"survival":0.0,"distance":0.0,"kills":0,"damage":0.0,"received":0.0,"shots":0,"hits":0,"items":0,"weapons":{},"killer":-1,"cause":"","kill_distance":0.0}

func alive_ids() -> Array[int]:
	var ids: Array[int]=[]
	for id in participants:
		if bool(participants[id].alive): ids.append(int(id))
	return ids

func is_alive(id: int) -> bool:
	return has_started and not ended and participants.has(id) and bool(participants[id].alive)

func record_shot(id: int,weapon: String) -> void:
	if not is_alive(id): return
	participants[id].shots+=1
	participants[id].weapons[weapon]=int(participants[id].weapons.get(weapon,0))+1

func record_damage(attacker: int,victim: int,amount: float) -> void:
	if not is_alive(victim) or amount<=0.0 or not is_finite(amount): return
	participants[victim].received+=amount
	if attacker!=victim and is_alive(attacker):
		participants[attacker].damage+=amount
		participants[attacker].hits+=1

func record_distance(id: int,meters: float) -> void:
	if is_alive(id) and is_finite(meters) and meters>=0.0: participants[id].distance+=meters

func record_pickup(id: int,count:=1) -> void:
	if is_alive(id): participants[id].items+=maxi(0,count)

func eliminate(id: int,killer: int,cause: String,distance: float,now: float) -> Dictionary:
	if not is_alive(id): return {"ok":false}
	var alive:=alive_ids()
	var row: Dictionary=participants[id]
	row.alive=false;row.placement=alive.size();row.survival=maxf(0.0,now-started_at)
	row.killer=killer;row.cause=cause;row.kill_distance=maxf(0.0,distance) if is_finite(distance) else 0.0
	if killer!=id and is_alive(killer): participants[killer].kills+=1
	if not defer_end:resolve_end(now)
	return {"ok":true,"victim":id,"killer":killer,"placement":row.placement,"ended":ended,"winner":winner,"result":result(id,now)}

func resolve_end(now: float) -> void:
	if ended:return
	var remaining:=alive_ids()
	if remaining.size()<=1:
		ended=true
		winner=remaining[0] if remaining.size()==1 else -1
		if winner>=0:
			participants[winner].placement=1;participants[winner].survival=maxf(0.0,now-started_at)

func result(id: int,now: float) -> Dictionary:
	if not participants.has(id): return {}
	var row: Dictionary=participants[id].duplicate(true)
	if row.alive and not ended: row.survival=maxf(0.0,now-started_at)
	row.id=id;row.accuracy=100.0*minf(float(row.hits),float(row.shots))/maxf(1.0,float(row.shots))
	row.kilometers=float(row.distance)/1000.0;row.favorite=""
	var count:=-1
	for weapon in row.weapons:
		if int(row.weapons[weapon])>count: count=int(row.weapons[weapon]);row.favorite=weapon
	row.victory=winner==id and ended
	return row
