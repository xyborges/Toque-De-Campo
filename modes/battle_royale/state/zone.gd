extends RefCounted
class_name BRZone

const PHASES := [
	{"radius":750.0,"wait":150.0,"close":90.0},
	{"radius":525.0,"wait":100.0,"close":75.0},
	{"radius":350.0,"wait":80.0,"close":65.0},
	{"radius":210.0,"wait":60.0,"close":55.0},
	{"radius":110.0,"wait":45.0,"close":45.0},
	{"radius":50.0,"wait":35.0,"close":35.0},
	{"radius":17.5,"wait":20.0,"close":30.0},
	{"radius":0.0,"wait":10.0,"close":30.0}]
var stages: Array[Dictionary]=[]
var started_at:=0.0
var running:=false

func configure(seed_value: int,candidates: Array) -> void:
	stages.clear();running=false
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var center:=Vector2.ZERO
	# Final-zone candidates supplied by the map are reachable, not arbitrary
	# random coordinates on the mountain mesh.
	var safe: Array[Vector2]=[]
	for point in candidates:
		var p:=Vector2(point.x,point.z) if point is Vector3 else Vector2(point)
		if p.is_finite() and absf(p.x)<=900.0 and absf(p.y)<=900.0: safe.append(p)
	if safe.is_empty(): safe.append(Vector2.ZERO)
	# Prefer an accessible origin. Radius 1000 keeps the entire initial square
	# playable while phase one is pending; outside damage starts on closure.
	var nearest:=INF
	for p in safe:
		if p.length_squared()<nearest: nearest=p.length_squared();center=p
	var radius:=1500.0
	var offset:=0.0
	for spec: Dictionary in PHASES:
		var target_radius:=float(spec.radius)
		var valid: Array[Vector2]=[]
		for p in safe:
			if p.distance_to(center)+target_radius<=radius+0.001 and absf(p.x)+target_radius<=1000.0 and absf(p.y)+target_radius<=1000.0: valid.append(p)
		var target:=center
		if not valid.is_empty(): target=valid[rng.randi_range(0,valid.size()-1)]
		stages.append({"center":center,"radius":radius,"target_center":target,"target_radius":target_radius,"wait":float(spec.wait),"duration":float(spec.close),"offset":offset})
		offset+=float(spec.wait)+float(spec.close)
		center=target;radius=target_radius

func begin(now: float) -> void:
	started_at=now;running=true

func sample(now: float) -> Dictionary:
	if stages.is_empty(): return {"center":Vector2.ZERO,"radius":1500.0,"target_center":Vector2.ZERO,"target_radius":750.0,"phase":0,"closing":false,"remaining":0.0,"finished":false}
	var elapsed:=maxf(0.0,now-started_at) if running else 0.0
	var index:=stages.size()-1
	for i in stages.size():
		var item: Dictionary=stages[i]
		if elapsed<float(item.offset)+float(item.wait)+float(item.duration): index=i;break
	var stage: Dictionary=stages[index]
	var local_time:=elapsed-float(stage.offset)
	var closing_now:=local_time>=float(stage.wait)
	var progress:=clampf((local_time-float(stage.wait))/float(stage.duration),0.0,1.0)
	return {"center":Vector2(stage.center).lerp(Vector2(stage.target_center),progress),"radius":lerpf(float(stage.radius),float(stage.target_radius),progress),"target_center":stage.target_center,"target_radius":stage.target_radius,"phase":index+1,"closing":closing_now,"remaining":maxf(0.0,(float(stage.wait)+float(stage.duration)-local_time) if closing_now else (float(stage.wait)-local_time)),"finished":index==stages.size()-1 and progress>=1.0}

func snapshot(now: float) -> Dictionary:
	var state:=sample(now)
	var i:=clampi(int(state.phase)-1,0,maxi(0,stages.size()-1))
	if stages.is_empty(): return state
	var stage: Dictionary=stages[i]
	# Parameters, not a per-frame ring transform. Clients sample at their
	# synchronized server time using the same linear interpolation.
	return {"server_time":now,"round_started_at":started_at,"phase":i+1,"center":stage.center,"radius":stage.radius,"target_center":stage.target_center,"target_radius":stage.target_radius,"close_started_at":started_at+float(stage.offset)+float(stage.wait),"duration":stage.duration,"finished":state.finished}

static func sample_snapshot(state: Dictionary,server_now: float) -> Dictionary:
	var duration:=maxf(0.001,float(state.get("duration",1.0)))
	var start:=float(state.get("close_started_at",server_now))
	var progress:=clampf((server_now-start)/duration,0.0,1.0)
	var center:=Vector2(state.get("center",Vector2.ZERO)).lerp(Vector2(state.get("target_center",Vector2.ZERO)),progress)
	var radius:=lerpf(float(state.get("radius",1500.0)),float(state.get("target_radius",750.0)),progress)
	return {"center":center,"radius":radius,"target_center":state.get("target_center",Vector2.ZERO),"target_radius":state.get("target_radius",750.0),"phase":int(state.get("phase",1)),"closing":server_now>=start,"remaining":maxf(0.0,start+duration-server_now) if server_now>=start else maxf(0.0,start-server_now),"finished":bool(state.get("finished",false))}

func damage_per_second(now: float) -> float:
	return minf(25.0,1.5+pow(float(sample(now).phase),1.45))

func outside(position: Vector3,now: float) -> bool:
	var state:=sample(now)
	return Vector2(position.x,position.z).distance_to(state.center)>float(state.radius)
