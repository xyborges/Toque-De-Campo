extends RefCounted
class_name GameSnapshotMotion
const DELAY:=.12
const MAX_AHEAD:=.12
var samples: Array[Dictionary]=[]
var render_clock:=0.0
var clock_ready:=false
func clear() -> void:
	samples.clear();render_clock=0.;clock_ready=false
func push(point: Vector3,velocity: Vector3,rotation: Vector3,stamp: float) -> void:
	if not point.is_finite() or not velocity.is_finite() or not rotation.is_finite() or not is_finite(stamp): return
	if not samples.is_empty() and stamp<=float(samples.back().time): return
	samples.append({"position":point,"velocity":velocity,"rotation":rotation,"time":stamp})
	while samples.size()>12: samples.pop_front()
	if not clock_ready:
		render_clock=stamp;clock_ready=true

func advance(delta: float) -> float:
	if not clock_ready or samples.is_empty(): return render_clock
	if not is_finite(delta) or delta<=0: return render_clock
	var latest:=float(samples.back().time)
	# A presentation clock must not run seconds ahead while packets stall.
	# Otherwise each recovered snapshot switches between stale extrapolation
	# and interpolation, producing a repeated forward/backward correction.
	if latest-render_clock>1.: render_clock=latest
	var rate:=clampf(1.+(latest-render_clock)*.4,.9,1.1)
	render_clock=minf(render_clock+delta*rate,latest+DELAY+MAX_AHEAD)
	return render_clock

func sample(clock: float) -> Transform3D:
	if samples.is_empty(): return Transform3D.IDENTITY
	var at:=clock-DELAY
	while samples.size()>2 and float(samples[1].time)<at: samples.pop_front()
	var a: Dictionary=samples[0]
	if samples.size()>1 and at>=float(a.time) and at<=float(samples[1].time):
		var b: Dictionary=samples[1]
		var span:=maxf(.001,float(b.time)-float(a.time));var t:=clampf((at-float(a.time))/span,0,1)
		# Keep the velocity-aware curve, but limit its tangents. An impact can
		# leave a small displacement and a large prior velocity: unrestricted
		# Hermite overshoots that segment and then visibly travels backwards.
		var first: Vector3=a.velocity;var second: Vector3=b.velocity
		for axis in 3:
			var slope: float=(Vector3(b.position)[axis]-Vector3(a.position)[axis])/span
			if absf(slope)<.00001:
				first[axis]=0.;second[axis]=0.;continue
			var alpha:=maxf(0.,first[axis]/slope);var beta:=maxf(0.,second[axis]/slope)
			var length_squared:=alpha*alpha+beta*beta
			var limiter:=3./sqrt(length_squared) if length_squared>9. else 1.
			first[axis]=alpha*limiter*slope;second[axis]=beta*limiter*slope
		var p: Vector3=(2*t*t*t-3*t*t+1)*Vector3(a.position)+(t*t*t-2*t*t+t)*span*first+(-2*t*t*t+3*t*t)*Vector3(b.position)+(t*t*t-t*t)*span*second
		var q:=Quaternion.from_euler(a.rotation).slerp(Quaternion.from_euler(b.rotation),t)
		return Transform3D(Basis(q),p)
	var last: Dictionary=samples.back() if at>float(a.time) else a
	return Transform3D(Basis.from_euler(last.rotation),Vector3(last.position)+Vector3(last.velocity)*clampf(at-float(last.time),0,MAX_AHEAD))
