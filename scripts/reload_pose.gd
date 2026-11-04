extends RefCounted
class_name GameReloadPose
# Presentation is a pure function of the existing authoritative timer. It
# cannot add ammunition, start a second reload or prolong the gameplay timer.
const FAL_HAND:=[
	[0.,Vector3(-.018,-.012,-.34)],[.12,Vector3(-.045,-.095,-.135)],
	[.26,Vector3(-.055,-.30,-.11)],[.42,Vector3(-.27,-.50,.10)],
	[.54,Vector3(-.27,-.50,.10)],[.61,Vector3(-.055,-.30,-.11)],
	[.77,Vector3(-.045,-.095,-.135)],[.83,Vector3(-.048,.076,-.135)],
	[.88,Vector3(-.048,.076,-.072)],[.92,Vector3(-.048,.076,-.135)],
	[1.,Vector3(-.018,-.012,-.34)]]
const GLOCK_HAND:=[
	[0.,Vector3(-.044,-.045,-.005)],[.13,Vector3(-.025,-.093,.013)],
	[.29,Vector3(-.032,-.255,.025)],[.42,Vector3(-.23,-.43,.16)],
	[.53,Vector3(-.23,-.43,.16)],[.62,Vector3(-.032,-.255,.025)],
	[.77,Vector3(-.025,-.093,.013)],[.83,Vector3(-.031,.075,-.02)],
	[.88,Vector3(-.031,.075,.012)],[.92,Vector3(-.031,.075,-.02)],
	[1.,Vector3(-.044,-.045,-.005)]]
# Sniper's imported mesh is one piece. Animate both hands around the rifle
# and its bolt without pretending its embedded magazine is a separate node.
const SNIPER_LEFT:=[
	[0.,Vector3(-.025,-.045,-.25)],[.16,Vector3(-.035,-.13,-.15)],
	[.30,Vector3(-.045,-.25,-.12)],[.46,Vector3(-.18,-.34,.03)],
	[.58,Vector3(-.10,-.26,-.08)],[.70,Vector3(-.035,-.13,-.15)],
	[.82,Vector3(-.025,-.045,-.25)],[1.,Vector3(-.025,-.045,-.25)]]
const SNIPER_RIGHT:=[
	[0.,Vector3(0,-.035,.03)],[.66,Vector3(0,-.035,.03)],
	[.76,Vector3(.09,.09,-.10)],[.83,Vector3(.09,.09,.00)],
	[.89,Vector3(.09,.09,-.10)],[.96,Vector3(0,-.035,.03)],
	[1.,Vector3(0,-.035,.03)]]
const AK_LEFT:=[
	[0.,GameAKReload.SUPPORT],[.11,Vector3(-.115,-.005,-.034)],
	[.23,Vector3(-.065,-.125,-.034)],[.36,Vector3(.005,-.235,-.040)],
	[.44,Vector3(-.19,-.30,-.15)],[.54,Vector3(-.19,-.30,-.15)],
	[.63,Vector3(-.04,-.22,-.034)],[.74,Vector3(-.095,-.08,-.034)],
	[.81,Vector3(-.115,-.005,-.034)],[.86,GameAKReload.SUPPORT],[1.,GameAKReload.SUPPORT]]
const AK_RIGHT:=[
	[0.,GameAKReload.GRIP],[.79,GameAKReload.GRIP],
	[.85,Vector3(-.145,.105,.052)],[.90,Vector3(-.225,.105,.052)],
	[.94,Vector3(-.145,.105,.052)],[1.,GameAKReload.GRIP]]
static func sample(keys: Array,t: float) -> Vector3:
	for i in range(1,keys.size()):
		if t<=float(keys[i][0]):
			var weight:=smoothstep(float(keys[i-1][0]),float(keys[i][0]),t)
			return Vector3(keys[i-1][1]).lerp(Vector3(keys[i][1]),weight)
	return keys[-1][1]
static func state(id: String,left: float,total: float) -> Dictionary:
	id=GameWeapons.canonical(id)
	if id=="ak":
		var active:=left>0 and total>0
		var t:=clampf(1-left/maxf(total,.001),0,1) if active else 0.
		var settle:=smoothstep(0,.11,t)*(1.-smoothstep(.94,1.,t)) if active else 0.
		var extraction:=smoothstep(.12,.36,t)*(1.-smoothstep(.62,.81,t)) if active else 0.
		var rocking:=smoothstep(.11,.23,t)*(1.-smoothstep(.74,.81,t)) if active else 0.
		var mechanism:=smoothstep(.85,.90,t)*(1.-smoothstep(.90,.94,t)) if active else 0.
		var magazine_offset:=Vector3(.075,-.205,-.01)*extraction
		var magazine_tilt:=-.30*rocking
		var magazine_grip:=GameAKReload.PIVOT+magazine_offset+Basis(Vector3.BACK,magazine_tilt)*Vector3(.055,-.112,-.035)
		var contact:=smoothstep(.08,.14,t)*(1.-smoothstep(.80,.87,t))*clampf(1.-smoothstep(.39,.44,t)+smoothstep(.54,.62,t),0.,1.) if active else 0.
		var hand:=sample(AK_LEFT,t).lerp(magazine_grip,contact)
		return {"active":active,"progress":t,"offset":Vector3(-.09,.055,-.075)*settle,"angles":Vector3(-.09,.10,-.22)*settle,"magazine_offset":magazine_offset,"magazine_tilt":magazine_tilt,"magazine_visible":not active or t<.44 or t>.54,"mechanism":mechanism*.080,"hand":hand,"right_hand":sample(AK_RIGHT,t),"hand_grabbing":active and t>.08 and t<.84}
	if id=="sniper":
		var active:=left>0 and total>0
		var t:=clampf(1-left/maxf(total,.001),0,1) if active else 0.
		var settle:=smoothstep(0,.14,t)*(1-smoothstep(.90,1.,t)) if active else 0.
		return {"active":active,"progress":t,"offset":Vector3(-.025,-.035,.035)*settle,"angles":Vector3(-.08,0,-.22)*settle,"hand":sample(SNIPER_LEFT,t),"right_hand":sample(SNIPER_RIGHT,t),"hand_grabbing":active and t>.12 and t<.78}
	var active:=left>0 and total>0 and id in ["fal","glock","g3"]
	var t:=clampf(1-left/maxf(total,.001),0,1) if active else 0.
	var settle:=smoothstep(0,.12,t)*(1-smoothstep(.92,1.,t)) if active else 0.
	var extract:=smoothstep(.12,.29,t)*(1-smoothstep(.62,.77,t)) if active else 0.
	var mechanism:=smoothstep(.83,.88,t)*(1-smoothstep(.88,.92,t)) if active else 0.
	var dock:=Vector3(0,-.095,-.135) if id in ["fal","g3"] else Vector3(0,-.067,.012)
	var hand:=sample(FAL_HAND if id in ["fal","g3"] else GLOCK_HAND,t)
	return {"active":active,"progress":t,"offset":Vector3(-.015,-.03,.02)*settle,"angles":Vector3(-.08,.10,-.31 if id in ["fal","g3"] else -.25)*settle,"magazine":dock+Vector3(-.015,-.24 if id in ["fal","g3"] else -.17,.03)*extract,"magazine_angles":Vector3(.08,0,-.10)*extract,"magazine_visible":not active or t<.40 or t>.54,"mechanism":mechanism*.063 if id in ["fal","g3"] else mechanism*.032,"hand":hand,"hand_grabbing":active and t>.08 and t<.95}
static func apply(model: Node3D,id: String,pose: Dictionary) -> void:
	id=GameWeapons.canonical(id)
	if id=="ak":GameAKReload.apply(model,pose);return
	if id=="sniper": return
	var mag:=model.get_node_or_null("Magazine") as Node3D
	if mag:
		mag.position=pose.magazine;mag.rotation=pose.magazine_angles;mag.visible=pose.magazine_visible
	var mechanism:=model.get_node_or_null("ChargingHandle" if id=="fal" else "SlideAssembly") as Node3D
	if mechanism: mechanism.position.z=float(pose.mechanism)

static func sniper_hand(model: Node3D,point: Vector3) -> Vector3:
	# Convert a grip authored in the resting weapon-root frame into the
	# animated model frame; usable for both the world and first-person copy.
	var rest_basis: Basis=model.get_meta("rest_basis",Basis.IDENTITY)
	var rest_position: Vector3=model.get_meta("rest_position",Vector3.ZERO)
	return model.transform*(rest_basis.inverse()*(point-rest_position))
