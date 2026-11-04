extends GameDayNight
class_name WarDayNight

var game: Node
func _process(_delta: float) -> void:
	if is_instance_valid(game) and bool(game.get_meta("war_mode",false)): apply_time(float(game.war_clock))

func apply_time(seconds: float,force:=false) -> float:
	if not force and absf(seconds-last_time)<.1: return daylight
	var result:=super.apply_time(seconds,force)
	if environment==null or not is_instance_valid(sun): return result
	# The dark/wet ground and Filmic toe compounded the old night fill.
	# Raise existing diffuse moon/ambient fill, retaining directional contrast
	# instead of making terrain emissive or adding shadowed point lights.
	sun.light_energy=.68*daylight
	sun.light_color=Color("d6d7c8").lerp(Color("b6a596"),clampf(1-absf(float(sample(seconds).altitude))*3,0,1))
	moon.light_energy=.32*(1-daylight)
	moon.light_color=Color("839cb8")
	environment.ambient_light_energy=lerpf(.44,.34,daylight)
	environment.ambient_light_color=Color("92a2b4").lerp(Color("a9b3b8"),daylight)
	var sky:=environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color=Color("0c1723").lerp(Color("5f6d75"),daylight)
	sky.sky_horizon_color=Color("2e3c4c").lerp(Color("9ba5a3"),daylight)
	sky.ground_horizon_color=sky.sky_horizon_color
	sky.ground_bottom_color=Color("1c2b3b").lerp(Color("46483f"),daylight)
	fog_color=Color("2e4152").lerp(Color("8e999b"),daylight)
	environment.fog_light_color=fog_color
	return result
