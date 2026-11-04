extends RefCounted
class_name GameMatchStats

const MAX_ROWS:=128
const ASSIST_SECONDS:=10.0
const ASSIST_DAMAGE:=20.0
const SUPPORT_LIMIT:=50
const MAX_SUPPORT_RECORDS:=512
var rows: Dictionary={}
var contributors: Dictionary={}
var events: Dictionary={}
var support_limits: Dictionary={}
var revision:=0

func register(id: int,label: String,team:=-1) -> void:
	if not rows.has(id):
		rows[id]={"id":id,"name":label.left(24),"team":team,"points":0,"kills":0,"deaths":0,"assists":0,"damage":0.0,"objective":0,"support":0,"ping":-1}
		revision+=1
	elif rows[id].name!=label or int(rows[id].team)!=team:
		rows[id].name=label.left(24);rows[id].team=team;revision+=1

func once(event: String) -> bool:
	if event.is_empty() or events.has(event): return false
	events[event]=true
	if events.size()>2048: events.erase(events.keys()[0])
	return true

func award(id: int,points: int,event: String,category:="") -> bool:
	if not rows.has(id) or points<=0 or not once(event+":"+str(id)): return false
	rows[id].points+=points
	if category in ["objective","support"]: rows[id][category]+=points
	revision+=1
	return true

func death(victim: int,life: int) -> void:
	if rows.has(victim) and once("death:%d:%d"%[victim,life]):
		rows[victim].deaths+=1;revision+=1

func teamkill(attacker: int,victim: int,life: int,penalty: int) -> bool:
	if attacker==victim or not rows.has(attacker) or penalty<=0 or not once("teamkill:%d:%d:%d"%[attacker,victim,life]): return false
	var key:="%d:%d"%[victim,life]
	rows[attacker].points-=penalty
	# No kill or assist can be awarded for this life after a friendly death.
	contributors.erase(key);once("kill:"+key);revision+=1
	return true

func valid_damage(id: int,amount: float) -> bool:
	if not rows.has(id) or not is_finite(amount) or amount<=0: return false
	var total:=float(rows[id].damage)+amount
	if not is_finite(total): return false
	rows[id].damage=total;revision+=1
	return true

func hit(attacker: int,victim: int,life: int,damage: float,killed: bool,headshot: bool,distance: float,now: float) -> void:
	if attacker==victim or not valid_damage(attacker,damage): return
	var key:="%d:%d"%[victim,life]
	# The caller passes actual HP removed, already clamped by server health.
	var ledger: Dictionary=contributors.get(key,{})
	var record: Dictionary=ledger.get(attacker,{"damage":0.0,"at":now})
	# Old contributions cannot be refreshed into an assist by a tiny new hit.
	if now-float(record.at)>ASSIST_SECONDS: record.damage=0.0
	record.damage=float(record.damage)+damage;record.at=now
	ledger[attacker]=record;contributors[key]=ledger
	if contributors.size()>128: contributors.erase(contributors.keys()[0])
	if not killed or not once("kill:"+key): return
	rows[attacker].kills+=1
	award(attacker,100,"elimination:"+key)
	if headshot: award(attacker,25,"headshot:"+key)
	if distance>=100: award(attacker,25,"range:"+key)
	for id in ledger:
		if id==attacker or not rows.has(id): continue
		if now-float(ledger[id].at)<=ASSIST_SECONDS and float(ledger[id].damage)>=ASSIST_DAMAGE:
			rows[id].assists+=1;award(id,50,"assist:"+key)
	contributors.erase(key)
	revision+=1

func support(id: int,recipient: int,amount: float,kind: String,now: float,event: String) -> int:
	if id==recipient or not rows.has(id) or not rows.has(recipient) or not is_finite(amount) or amount<=0 or not is_finite(now) or kind not in ["heal","ammo"] or event.is_empty(): return 0
	# One genuine action may help several allies. Deduplicate each recipient
	# before accumulating fractional credit, including sub-point actions.
	var event_key:="support:%d:%d:%s:%s"%[id,recipient,kind,event]
	if not once(event_key): return 0
	var key:="%d:%d:%s"%[id,recipient,kind]
	var record: Dictionary=support_limits.get(key,{"at":now,"points":0,"fraction":0.0,"provider":id,"recipient":recipient})
	if now-float(record.at)>=60: record={"at":now,"points":0,"fraction":0.0,"provider":id,"recipient":recipient}
	# Actual health restored / rounds supplied, with a per-recipient minute
	# cap. Self supply/heal and repeated event IDs never generate points.
	var remaining:=maxi(0,SUPPORT_LIMIT-int(record.points))
	var earned:=clampf(amount*(.5 if kind=="heal" else .1)+float(record.fraction),0,float(remaining))
	var points:=mini(remaining,floori(earned+0.000001))
	record.fraction=0.0 if points>=remaining else maxf(0,earned-float(points))
	if not support_limits.has(key) and support_limits.size()>=MAX_SUPPORT_RECORDS:
		for old_key in support_limits.keys():
			if now-float(support_limits[old_key].at)>=60: support_limits.erase(old_key)
		if support_limits.size()>=MAX_SUPPORT_RECORDS: support_limits.erase(support_limits.keys()[0])
	support_limits[key]=record
	if points<=0 or not award(id,points,event_key+":points","support"): return 0
	record.points=int(record.points)+points
	return points

func remove(id: int) -> void:
	rows.erase(id)
	for key in contributors: contributors[key].erase(id)
	for key in support_limits.keys():
		var record: Dictionary=support_limits[key]
		if int(record.provider)==id or int(record.recipient)==id: support_limits.erase(key)
	revision+=1

func clear() -> void:
	rows.clear();contributors.clear();events.clear();support_limits.clear();revision+=1

func snapshot() -> Array:
	var result: Array=rows.values().duplicate(true)
	result.sort_custom(func(a,b):
		if a.points!=b.points: return a.points>b.points
		if a.kills!=b.kills: return a.kills>b.kills
		if a.assists!=b.assists: return a.assists>b.assists
		return int(a.id)<int(b.id)
	)
	return result

func receive(values: Array) -> void:
	rows.clear()
	for value in values:
		if not value is Dictionary or not value.get("id") is int or int(value.id)<=0:continue
		var id:=int(value.id)
		if rows.has(id) or rows.size()<MAX_ROWS:rows[id]=value.duplicate(true)
	revision+=1
