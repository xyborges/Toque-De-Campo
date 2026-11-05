extends RefCounted
class_name GameSoundPropagation

const SPEED:=343.0
const LIMIT:=256
# A subtle 5% linear-amplitude boost for distant combat sounds.
# Keep close-range punch and the existing spatial attenuation untouched.
const FAR_GAIN_START_M:=350.0
const FAR_GAIN_FULL_M:=600.0
const FAR_GAIN_LINEAR:=1.05

static func distant_gain_db(distance: float) -> float:
	var blend:=smoothstep(FAR_GAIN_START_M,FAR_GAIN_FULL_M,maxf(0.0,distance))
	return linear_to_db(lerpf(1.0,FAR_GAIN_LINEAR,blend))
var clock:=0.0
var pending: Array[Dictionary]=[]
var dropped:=0

static func delay(distance: float,elapsed:=0.0) -> float:
	return maxf(0,maxf(0,distance)/SPEED-maxf(0,elapsed))

func schedule(data: Dictionary,listener: Vector3,range_value: float,priority: float,elapsed:=0.0) -> bool:
	var point: Vector3=data.point
	if not point.is_finite(): return false
	var distance:=point.distance_to(listener)
	if distance>=range_value: return false
	clock=Time.get_ticks_usec()*.000001
	var event:=data.duplicate()
	event.due=clock+delay(distance,elapsed);event.rank=priority/(1+distance/120);event.distance=distance
	if pending.size()>=LIMIT:
		var weakest:=0
		for i in range(1,pending.size()):
			if float(pending[i].rank)<float(pending[weakest].rank): weakest=i
		if float(event.rank)<=float(pending[weakest].rank): dropped+=1;return false
		pending.remove_at(weakest);dropped+=1
	pending.append(event);return true

func take_due(_delta: float) -> Array[Dictionary]:
	clock=Time.get_ticks_usec()*.000001
	var ready: Array[Dictionary]=[]
	for i in range(pending.size()-1,-1,-1):
		if float(pending[i].due)>clock: continue
		if clock-float(pending[i].due)<.4: ready.append(pending[i])
		else: dropped+=1
		pending.remove_at(i)
	ready.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.rank)>float(b.rank))
	return ready

func clear() -> void: pending.clear()
