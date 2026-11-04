extends RefCounted
class_name GameTracerStyle
const COLORS:={"glock":Color("138cb5"),"ak":Color("cf5013"),"fal":Color("36b6cf"),"g3":Color("e3ac65"),"sniper":Color("d66dff"),"lightMG":Color("308d42"),"heavyMG":Color("b23524"),"missile":Color("b28913"),"torpedo":Color("197e77")}
const ENERGY:=.25
static func color_for(weapon: String) -> Color: return COLORS.get(weapon,Color("c18e39"))
static func radius_for(distance: float) -> float: return clampf(distance*.0008,.025,.11)
static func infantry_radius(camera: Camera3D,point: Vector3) -> float:
	if not is_instance_valid(camera): return .035
	var size:=camera.get_viewport().get_visible_rect().size
	var tangent:=tan(deg_to_rad(camera.fov)*.5)
	if camera.keep_aspect==Camera3D.KEEP_WIDTH: tangent/=maxf(1,size.x/maxf(1,size.y))
	return clampf(camera.global_position.distance_to(point)*tangent/maxf(1,size.y)*1.6,.035,.28)
static func energy_for(weapon: String) -> float: return 1.15 if weapon=="sniper" else ENERGY
static func sniper_radius(camera: Camera3D,point: Vector3) -> float:
	if not is_instance_valid(camera): return .045
	var size:=camera.get_viewport().get_visible_rect().size
	var tangent:=tan(deg_to_rad(camera.fov)*.5)
	if camera.keep_aspect==Camera3D.KEEP_WIDTH: tangent/=maxf(1,size.x/maxf(1,size.y))
	return clampf(camera.global_position.distance_to(point)*tangent/maxf(1,size.y)*1.8,.01,1.6)
static func visible_for(weapon: String,shot_id: String) -> bool:
	if weapon not in ["ak","fal","g3","lightMG","heavyMG"]: return true
	var sequence:=shot_id.get_slice(":",shot_id.get_slice_count(":")-1)
	return not sequence.is_valid_int() or int(sequence)%2==0
