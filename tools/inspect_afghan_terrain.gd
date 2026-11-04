extends SceneTree
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
func _initialize() -> void:
	LAND.building_layout()
	var spots: Array=[]
	for z in range(400,720,10):
		for x in range(-950,-550,10):
			var height:=LAND.rawheight(x,z);var original:=LAND.natural_height(x,z)
			var gradient:=Vector2(LAND.rawheight(x+3.,z)-LAND.rawheight(x-3.,z),LAND.rawheight(x,z+3.)-LAND.rawheight(x,z-3.))/6.
			if gradient.length()>1.4:spots.append({"p":Vector2(x,z),"height":height,"original":original,"slope":gradient.length(),"road":LAND._near_road(Vector2(x,z))})
	spots.sort_custom(func(a,b):return a.slope>b.slope)
	for i in mini(8,spots.size()):print("CUT ",spots[i])
	print("GARDENS ",LAND.garden_layout().size()," GROVES ",LAND.grove_layout().size());quit()
