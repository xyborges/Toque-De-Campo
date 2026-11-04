extends RefCounted
class_name GameCharacterColors

const DEFAULTS := {"skin":"c8946e","shirt":"998e72","pants":"4c5149","boots":"252b29"}
static var materials: Dictionary = {}

static func normalize(value: Variant) -> Dictionary:
	var result := DEFAULTS.duplicate()
	if value is Dictionary:
		for part in DEFAULTS:
			var text := str(value.get(part,DEFAULTS[part])).trim_prefix("#")
			if text.length()==6 and text.is_valid_hex_number(false): result[part]=text.to_lower()
	return result

static func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new(); mat.albedo_color=Color(color); mat.roughness=.94; materials[color]=mat
	return materials[color]

static func apply(actor: GamePlayer, value: Variant) -> void:
	if not is_instance_valid(actor.body_root): return
	var colors := normalize(value); actor.set_meta("body_colors",colors)
	var assignments := {"Head":"skin","Head/Nose":"skin","Torso":"shirt","Pelvis":"pants"}
	for side in ["L","R"]:
		assignments["Arm"+side+"/Arm"+side+"Mesh"]="shirt"
		assignments["Arm"+side+"/Forearm"+side+"Mesh"]="shirt"
		assignments["Arm"+side+"/Hand"+side]="skin"
		assignments["Leg"+side+"/Leg"+side+"Mesh"]="pants"
		assignments["Leg"+side+"/Knee"+side+"/Shin"+side]="pants"
		assignments["Leg"+side+"/Knee"+side+"/Shoe"+side]="boots"
		assignments["Leg"+side+"/Shoe"+side]="boots"
	for path in assignments:
		var mesh := actor.body_root.get_node_or_null(path) as MeshInstance3D
		if mesh: mesh.material_override=material(colors[assignments[path]])

	if is_instance_valid(actor.view_root):
		for part in ["GripHand","SupportHand","Left","Right"]:
			var mesh:=actor.view_root.get_node_or_null(part) as MeshInstance3D
			if mesh:mesh.material_override=material(colors.skin)
		for part in ["RightForearm","LeftForearm","ForearmLeft","ForearmRight","MeleeForearmR","MeleeForearmL"]:
			var mesh:=actor.view_root.get_node_or_null(part) as MeshInstance3D
			if mesh:mesh.material_override=material(colors.shirt)
