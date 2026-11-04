extends RefCounted
class_name GameNetworkGuard

var rates: Dictionary={}
var motion: Dictionary={}

func allow(id: int,route: String,per_second: float,burst: float,now:=-1.0) -> bool:
	if id<=0: return false
	if now<0.0: now=Time.get_ticks_usec()*.000001
	var key:=str(id)+":"+route
	var state: Dictionary=rates.get(key,{"at":now,"tokens":burst})
	state.tokens=minf(burst,float(state.tokens)+maxf(0.0,now-float(state.at))*per_second)
	state.at=now;rates[key]=state
	if float(state.tokens)<1.0: return false
	state.tokens=float(state.tokens)-1.0
	return true

func movement(id: int,life: int,sequence: int,origin: Vector3,wanted: Vector3,speed: float,now:=-1.0) -> Dictionary:
	if sequence<1 or not CombatRules.finite_vector(wanted): return {"accepted":false,"position":origin}
	if now<0.0: now=Time.get_ticks_usec()*.000001
	var state: Dictionary=motion.get(id,{"life":life,"sequence":0,"at":now,"credit":1.25})
	if int(state.life)!=life: state={"life":life,"sequence":0,"at":now,"credit":1.25}
	if sequence<=int(state.sequence): return {"accepted":false,"position":origin}
	state.credit=minf(1.25,float(state.credit)+maxf(0.0,now-float(state.at))*speed)
	state.at=now;state.sequence=sequence
	var offset:=wanted-origin
	var travelled:=minf(offset.length(),float(state.credit))
	state.credit=maxf(0.0,float(state.credit)-travelled)
	motion[id]=state
	return {"accepted":true,"position":origin+offset.limit_length(travelled)}

func forget(id: int) -> void:
	motion.erase(id)
	var prefix:=str(id)+":"
	for key in rates.keys():
		if str(key).begins_with(prefix): rates.erase(key)

func clear() -> void:
	rates.clear();motion.clear()
