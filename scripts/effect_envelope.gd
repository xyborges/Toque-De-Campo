extends RefCounted
class_name GameEffectEnvelope

static func opacity(age: float,total: float,attack: float,release: float) -> float:
	if age<=0 or age>=total: return 0
	return smoothstep(0,maxf(.001,attack),age)*smoothstep(0,maxf(.001,release),total-age)
